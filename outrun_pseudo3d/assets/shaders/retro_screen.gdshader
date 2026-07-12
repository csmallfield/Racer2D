shader_type canvas_item;
// Full-resolution retro/VHS screen filter. No downscaling: scanlines, color
// fringe, grain, and flicker are layered over the native image. Scanline
// dimming is luminance-compensated so the picture doesn't darken.
// Applied as a full-window ColorRect on a top CanvasLayer (see settings.gd).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float curvature : hint_range(0.0, 0.25) = 0.04;      // barrel distortion (0 = flat)
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_density : hint_range(100.0, 1080.0) = 540.0;
uniform float aberration : hint_range(0.0, 6.0) = 1.4;       // color fringe, pixels
uniform float vignette : hint_range(0.0, 1.0) = 0.25;
uniform float noise_strength : hint_range(0.0, 0.3) = 0.05;  // animated VHS grain
uniform float flicker : hint_range(0.0, 0.1) = 0.01;         // luminance wobble


vec2 curve(vec2 uv, float amt) {
	vec2 c = uv * 2.0 - 1.0;
	c += c * dot(c, c) * amt;
	return c * 0.5 + 0.5;
}


float hash(vec2 p) {
	return fract(sin(dot(p + fract(TIME), vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	vec2 uv = curve(SCREEN_UV, curvature);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));

		// Chromatic fringe: red and blue sampled slightly apart.
		float r = texture(screen_tex, uv + vec2(px.x * aberration, 0.0)).r;
		float g = texture(screen_tex, uv).g;
		float b = texture(screen_tex, uv - vec2(px.x * aberration, 0.0)).b;
		vec3 col = vec3(r, g, b);

		// Scanlines with luminance preservation: the mean of the dimming
		// wave is divided back out, so overall brightness holds.
		float s = 0.5 + 0.5 * sin(uv.y * scanline_density * 6.2831853);
		col *= (1.0 - scanline_strength * s) / (1.0 - scanline_strength * 0.5);

		// Soft vignette.
		vec2 v = uv * (1.0 - uv);
		col *= 1.0 - vignette * (1.0 - clamp(v.x * v.y * 15.0, 0.0, 1.0));

		// Animated grain + gentle flicker.
		col += (hash(FRAGCOORD.xy) - 0.5) * noise_strength;
		col *= 1.0 + flicker * sin(TIME * 73.0);

		COLOR = vec4(col, 1.0);
	}
}
