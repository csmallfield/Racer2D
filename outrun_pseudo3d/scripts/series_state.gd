class_name SeriesState
extends RefCounted
## A tournament in progress: the cup, which round we're on, the fixed field,
## and accumulated points. Session-only — abandoned when you leave to the
## menu, never written to disk.
##
## Entrants are keyed by identity, not by finishing position:
##   humans -> "p0", "p1", ...
##   AI     -> the profile .tres stem ("viper"), the same identifier the
##             records system stores, so renaming display text is safe.

## Points by field size: first always 15, last always 1. A big step for the
## win, shallow gaps through the midfield so one bad round doesn't end a
## championship. Shape follows Mario Kart, which scores every finisher.
const POINTS: Dictionary = {
	10: [15, 12, 10, 9, 8, 7, 5, 4, 2, 1],
	9:  [15, 12, 10, 9, 8, 6, 4, 2, 1],
	8:  [15, 12, 10, 8, 6, 4, 2, 1],
	7:  [15, 12, 10, 7, 5, 3, 1],
	6:  [15, 12, 9, 6, 3, 1],
	5:  [15, 12, 8, 4, 1],
	4:  [15, 11, 6, 1],
	3:  [15, 9, 1],
	2:  [15, 1],
}

var cup: CupDefinition
var round_index := 0                  # 0-based position in cup.tracks
var field_size := 0                   # players + rivals, constant for the cup
var rival_indices: Array = []         # roster indices contesting this cup
var player_racers: Array = []         # roster index per player slot, locked
var player_count := 1

var points: Dictionary = {}           # entrant key -> accumulated points
var names: Dictionary = {}            # entrant key -> display name
var wins: Dictionary = {}             # entrant key -> race wins, tie-break 1
var best_finish: Dictionary = {}      # entrant key -> best position, break 2
var total_time: Dictionary = {}       # entrant key -> summed time, break 3
var last_positions: Dictionary = {}   # entrant key -> standings position
var last_awarded: Dictionary = {}     # entrant key -> points from last round

var _table: Array = []


func setup(p_cup: CupDefinition, p_player_count: int, p_player_racers: Array,
		p_rival_indices: Array, roster: Array) -> void:
	cup = p_cup
	round_index = 0
	player_count = maxi(p_player_count, 1)
	player_racers = p_player_racers.duplicate()
	rival_indices = p_rival_indices.duplicate()
	field_size = player_count + rival_indices.size()
	_table = _points_table()

	points.clear(); names.clear(); wins.clear()
	best_finish.clear(); total_time.clear()
	last_positions.clear(); last_awarded.clear()

	for i in range(player_count):
		var key := player_key(i)
		_register(key, "PLAYER %d" % (i + 1) if player_count > 1 else "YOU")
	for idx in rival_indices:
		var prof: RivalProfile = roster[int(idx)]
		_register(racer_key(prof), String(prof.display_name))


func _register(key: String, display: String) -> void:
	points[key] = 0
	names[key] = display
	wins[key] = 0
	best_finish[key] = 9999
	total_time[key] = 0.0
	last_awarded[key] = 0


## Points for each placing, longest table that fits the field. A cup may
## override; otherwise the default for this field size, falling back to the
## nearest smaller table if the field is somehow larger than any entry.
func _points_table() -> Array:
	if cup != null and not cup.points_table.is_empty():
		return cup.points_table.duplicate()
	if POINTS.has(field_size):
		return (POINTS[field_size] as Array).duplicate()
	var best: Array = []
	for n in POINTS.keys():
		if int(n) <= field_size and int(n) > best.size():
			best = POINTS[n]
	return best.duplicate() if not best.is_empty() else [1]


static func player_key(slot: int) -> String:
	return "p%d" % slot


## Stable identity for an AI entrant: the profile's .tres stem.
static func racer_key(profile: RivalProfile) -> String:
	if profile == null:
		return ""
	var path := String(profile.resource_path)
	if path.is_empty():
		return String(profile.display_name).to_lower()
	return path.get_file().get_basename()


func points_for(position: int) -> int:
	if position < 1 or position > _table.size():
		return 0
	return int(_table[position - 1])


## Score one round. `order` is the finishing order as entrant keys, best
## first. `dnf` holds keys that failed to finish — they score 0, which is the
## only thing separating a timeout from finishing last.
func score_round(order: Array, dnf: Array, times: Dictionary) -> void:
	last_awarded.clear()
	for key in points.keys():
		last_awarded[key] = 0

	var pos := 1
	for key in order:
		var k := String(key)
		if dnf.has(k):
			continue
		var got := points_for(pos)
		points[k] = int(points.get(k, 0)) + got
		last_awarded[k] = got
		if pos == 1:
			wins[k] = int(wins.get(k, 0)) + 1
		if pos < int(best_finish.get(k, 9999)):
			best_finish[k] = pos
		if times.has(k):
			total_time[k] = float(total_time.get(k, 0.0)) + float(times[k])
		pos += 1
	round_index += 1


## Standings, best first. Ties break on wins, then best single finish, then
## lowest total race time.
func standings() -> Array:
	var rows: Array = []
	for key in points.keys():
		rows.append({
			"key": key,
			"name": String(names.get(key, key)),
			"points": int(points[key]),
			"awarded": int(last_awarded.get(key, 0)),
			"is_player": String(key).begins_with("p") and String(key).length() <= 3
					and String(key).substr(1).is_valid_int(),
			"delta": 0,
		})
	rows.sort_custom(_compare)
	for i in range(rows.size()):
		var key: String = rows[i].key
		if last_positions.has(key):
			rows[i]["delta"] = int(last_positions[key]) - (i + 1)
	return rows


## Call once the standings screen has been shown, so the next round can
## report movement against this ordering.
func commit_positions(rows: Array) -> void:
	for i in range(rows.size()):
		last_positions[String(rows[i].key)] = i + 1


func _compare(a: Dictionary, b: Dictionary) -> bool:
	if int(a.points) != int(b.points):
		return int(a.points) > int(b.points)
	var ak := String(a.key)
	var bk := String(b.key)
	if int(wins.get(ak, 0)) != int(wins.get(bk, 0)):
		return int(wins.get(ak, 0)) > int(wins.get(bk, 0))
	if int(best_finish.get(ak, 9999)) != int(best_finish.get(bk, 9999)):
		return int(best_finish.get(ak, 9999)) < int(best_finish.get(bk, 9999))
	return float(total_time.get(ak, 0.0)) < float(total_time.get(bk, 0.0))


func total_rounds() -> int:
	return cup.tracks.size() if cup != null else 0


func is_final_round() -> bool:
	return round_index >= total_rounds()


## Level filename for the round about to be raced, or "" when the cup is done.
func current_track() -> String:
	if cup == null or round_index >= cup.tracks.size():
		return ""
	return String(cup.tracks[round_index])
