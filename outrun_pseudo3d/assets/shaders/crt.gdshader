// CRT Shader by Harrison Allen — V4
// https://godotshaders.com/shader/crt-with-luminance-preservation/
// License: CC0 (public domain).
//
// Adapted for this project: gl_compatibility-safe (no hint_enum, no const
// arrays, no `flat` varying — these fail to compile in compatibility mode),
// otherwise the V4 scanline/mask math is preserved verbatim, including the
// luminance preservation. Fed a low-res ViewportTexture (the SubViewports
// render at container size / crt_shrink); scanline count = texture height.

shader_type canvas_item;

uniform sampler2D tex : filter_linear;

// 0=Null, 1=Dots, 2=Aperture Grille, 3=Wide Grille, 4=Wide Soft Grille, 5=Slot
uniform int mask_type = 2;

uniform float curve : hint_range(0.0, 0.5) = 0.12;
uniform float sharpness : hint_range(0.5, 1.0) = 0.6666667;
uniform float color_offset : hint_range(-0.5, 0.5) = 0.15;
uniform float mask_brightness : hint_range(0.0, 1.0) = 1.0;
uniform float scanline_brightness : hint_range(0.5, 1.0) = 1.0;
uniform float min_scanline_thickness : hint_range(0.25, 1.0) = 0.5;
uniform float aspect : hint_range(0.1, 1.0) = 0.5625;
uniform float wobble_strength : hint_range(0.0, 1.0) = 0.0;

varying float wobble;

void vertex()
{
	wobble = cos(TIME * TAU * 15.0) * wobble_strength / 8192.0;
}

vec2 warp(vec2 uv, float _aspect, float _curve)
{
	uv -= 0.5;
	uv.x /= _aspect;
	float warping = dot(uv, uv) * _curve;
	warping -= _curve * 0.25;
	uv /= 1.0 - warping;
	uv.x *= _aspect;
	uv += 0.5;
	return uv;
}

vec3 linear_to_srgb(vec3 col)
{
	return mix(
		(pow(col, vec3(1.0 / 2.4)) * 1.055) - 0.055,
		col * 12.92,
		vec3(lessThan(col, vec3(0.0031318)))
	);
}

vec3 srgb_to_linear(vec3 col)
{
	return mix(
		pow((col + 0.055) / 1.055, vec3(2.4)),
		col / 12.92,
		vec3(lessThan(col, vec3(0.04045)))
	);
}

// V4 scanlines, verbatim math (returns linear color).
vec3 scanlines(vec2 uv)
{
	uv *= vec2(textureSize(tex, 0));

	int y = int(uv.y + 0.5) - 1;
	float x = floor(uv.x);

	float ax = x - 2.0;
	float bx = x - 1.0;
	float cx = x;
	float dx = x + 1.0;
	float ex = x + 2.0;

	vec3 upper_a = srgb_to_linear(texelFetch(tex, ivec2(int(ax), y), 0).rgb);
	vec3 upper_b = srgb_to_linear(texelFetch(tex, ivec2(int(bx), y), 0).rgb);
	vec3 upper_c = srgb_to_linear(texelFetch(tex, ivec2(int(cx), y), 0).rgb);
	vec3 upper_d = srgb_to_linear(texelFetch(tex, ivec2(int(dx), y), 0).rgb);
	vec3 upper_e = srgb_to_linear(texelFetch(tex, ivec2(int(ex), y), 0).rgb);

	y += 1;

	vec3 lower_a = srgb_to_linear(texelFetch(tex, ivec2(int(ax), y), 0).rgb);
	vec3 lower_b = srgb_to_linear(texelFetch(tex, ivec2(int(bx), y), 0).rgb);
	vec3 lower_c = srgb_to_linear(texelFetch(tex, ivec2(int(cx), y), 0).rgb);
	vec3 lower_d = srgb_to_linear(texelFetch(tex, ivec2(int(dx), y), 0).rgb);
	vec3 lower_e = srgb_to_linear(texelFetch(tex, ivec2(int(ex), y), 0).rgb);

	vec3 beam = vec3(uv.x - 0.5);
	beam.r -= color_offset;
	beam.b += color_offset;

	vec3 weight_a = smoothstep(1.0, 0.0, (beam - ax) * sharpness);
	vec3 weight_b = smoothstep(1.0, 0.0, (beam - bx) * sharpness);
	vec3 weight_c = smoothstep(1.0, 0.0, abs(beam - cx) * sharpness);
	vec3 weight_d = smoothstep(1.0, 0.0, (dx - beam) * sharpness);
	vec3 weight_e = smoothstep(1.0, 0.0, (ex - beam) * sharpness);

	vec3 upper_col = upper_a * weight_a + upper_b * weight_b
			+ upper_c * weight_c + upper_d * weight_d + upper_e * weight_e;
	vec3 lower_col = lower_a * weight_a + lower_b * weight_b
			+ lower_c * weight_c + lower_d * weight_d + lower_e * weight_e;

	vec3 weight_scaler = vec3(1.0)
			/ (weight_a + weight_b + weight_c + weight_d + weight_e);

	upper_col *= weight_scaler;
	lower_col *= weight_scaler;

	upper_col *= scanline_brightness;
	lower_col *= scanline_brightness;

	vec3 upper_thickness = mix(vec3(min_scanline_thickness), vec3(1.0), upper_col);
	vec3 lower_thickness = mix(vec3(min_scanline_thickness), vec3(1.0), lower_col);

	float sawtooth = (uv.y + 0.5) - float(y);

	vec3 upper_line = vec3(sawtooth) / upper_thickness;
	upper_line = smoothstep(1.0, 0.0, upper_line);

	vec3 lower_line = vec3(1.0 - sawtooth) / lower_thickness;
	lower_line = smoothstep(1.0, 0.0, lower_line);

	upper_line *= upper_col / upper_thickness;
	lower_line *= lower_col / lower_thickness;

	return upper_line + lower_line;
}

// Compatibility-safe mask selection (if-chains instead of const arrays).
vec3 pick4(int idx, vec3 a, vec3 b, vec3 c, vec3 d)
{
	if (idx == 0) { return a; }
	if (idx == 1) { return b; }
	if (idx == 2) { return c; }
	return d;
}

vec3 slot_color(int idx)
{
	if (idx == 0) { return vec3(1, 0, 1); }
	if (idx == 1) { return vec3(0, 1, 0); }
	if (idx == 2) { return vec3(1, 0, 1); }
	if (idx == 3) { return vec3(0, 1, 0); }
	if (idx == 4) { return vec3(0, 0, 1); }
	if (idx == 5) { return vec3(0, 1, 0); }
	if (idx == 6) { return vec3(1, 0, 0); }
	if (idx == 7) { return vec3(0, 0, 0); }
	if (idx == 8) { return vec3(1, 0, 1); }
	if (idx == 9) { return vec3(0, 1, 0); }
	if (idx == 10) { return vec3(1, 0, 1); }
	if (idx == 11) { return vec3(0, 1, 0); }
	if (idx == 12) { return vec3(1, 0, 0); }
	if (idx == 13) { return vec3(0, 0, 0); }
	if (idx == 14) { return vec3(0, 0, 1); }
	return vec3(0, 1, 0);
}

vec4 generate_mask(vec2 fragcoord)
{
	if (mask_type == 1) {
		ivec2 icoords = ivec2(fragcoord);
		int idx = (icoords.y * 2 + icoords.x) % 4;
		return vec4(pick4(idx, vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1),
				vec3(0, 0, 0)), 0.25);
	} else if (mask_type == 2) {
		if (int(fragcoord.x) % 2 == 0) { return vec4(0, 1, 0, 0.5); }
		return vec4(1, 0, 1, 0.5);
	} else if (mask_type == 3) {
		int idx = int(fragcoord.x) % 4;
		return vec4(pick4(idx, vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1),
				vec3(0, 0, 0)), 0.25);
	} else if (mask_type == 4) {
		int idx = int(fragcoord.x) % 4;
		return vec4(pick4(idx, vec3(1.0, 0.125, 0.0), vec3(0.125, 1.0, 0.125),
				vec3(0.0, 0.125, 1.0), vec3(0.125, 0.0, 0.125)), 0.3125);
	} else if (mask_type == 5) {
		ivec2 icoords = ivec2(fragcoord) % 4;
		return vec4(slot_color(icoords.y * 4 + icoords.x), 0.375);
	}
	return vec4(0.5);
}

vec3 mask(vec3 linear_color, vec2 fragcoord)
{
	vec4 m = generate_mask(fragcoord);
	linear_color *= mix(m.w, 1.0, mask_brightness);
	vec3 target_color = linear_color / m.w;
	vec3 primary_col = clamp(target_color, 0.0, 1.0);
	vec3 highlights = target_color - primary_col;
	highlights /= 1.0 / m.w - 1.0;
	primary_col *= m.rgb;
	primary_col += highlights * (1.0 - m.rgb);
	return primary_col;
}

void fragment()
{
	vec2 warped_coords = warp(UV, aspect, curve);
	warped_coords.x += wobble;
	vec3 col = scanlines(warped_coords);
	col = mask(col, FRAGCOORD.xy);
	col = linear_to_srgb(col);
	COLOR.rgb = col;
}
