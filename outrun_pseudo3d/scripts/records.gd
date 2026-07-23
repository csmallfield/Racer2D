class_name Records
extends RefCounted
## Persistent best times: top 10 per level per bucket, saved as JSON in
## user:// (survives updates; per-OS user data directory).
##
## Keys are level filenames ("level_01_coastal.gd") so records survive
## reordering. Buckets are the three difficulties plus Time Trial — TT gets
## its own board rather than a difficulty, because the menu forces it to
## Normal and because a lap drafted in traffic isn't comparable to a clean
## solo one.
##
## What a time MEANS is decided by the track, not the mode:
##   circuit (level.laps > 0)  -> best lap
##   tour    (level.laps == 0) -> total race time
##
## Entries are dictionaries: {"t": float, "racer": String, "initials": String}.
## `racer` is the profile's resource stem ("viper"), not a roster index —
## indices shift when race_settings.tres is reordered, which is the same
## failure mode the level-filename keys already avoid.

const SAVE_PATH := "user://best_times.json"
const MAX_ENTRIES := 10
const VERSION := 2

## Board buckets, in filter order.
const BUCKETS: Array[String] = ["easy", "normal", "hard", "time_trial"]
const BUCKET_NAMES: Array[String] = ["EASY", "NORMAL", "HARD", "TIME TRIAL"]


## Bucket for a finished race. Time Trial always lands in its own board.
static func bucket_for(is_time_trial: bool, difficulty: int) -> String:
	if is_time_trial:
		return "time_trial"
	return BUCKETS[clampi(difficulty, 0, 2)]


## True if `t` would place in the top MAX_ENTRIES. Checked BEFORE prompting
## for initials, so the player is only interrupted for a time that counts.
static func qualifies(level_file: String, bucket: String, t: float) -> bool:
	if t <= 0.0 or is_inf(t):
		return false
	var list := get_entries(level_file, bucket)
	if list.size() < MAX_ENTRIES:
		return true
	return t < float((list[MAX_ENTRIES - 1] as Dictionary).get("t", INF))


## Insert an entry; returns its 1-based rank, or -1 if it missed the board.
## The insertion index is computed directly rather than searched for after
## sorting — dictionary identity isn't a safe thing to match on.
static func add_entry(level_file: String, bucket: String, entry: Dictionary) -> int:
	var all := _load_all()
	var boards: Dictionary = all.get("boards", {})
	var per_level: Dictionary = boards.get(level_file, {})
	var list: Array = per_level.get(bucket, [])

	var t := float(entry.get("t", INF))
	var idx := list.size()
	for k in range(list.size()):
		if t < float((list[k] as Dictionary).get("t", INF)):
			idx = k
			break
	if idx >= MAX_ENTRIES:
		return -1

	list.insert(idx, entry)
	if list.size() > MAX_ENTRIES:
		list.resize(MAX_ENTRIES)
	per_level[bucket] = list
	boards[level_file] = per_level
	all["boards"] = boards
	all["version"] = VERSION
	_save_all(all)
	return idx + 1


static func get_entries(level_file: String, bucket: String) -> Array:
	var all := _load_all()
	var boards: Dictionary = all.get("boards", {})
	if not boards.has(level_file):
		return []
	var per_level: Dictionary = boards[level_file]
	if not per_level.has(bucket):
		return []
	var list: Variant = per_level[bucket]
	return list if list is Array else []


## Older schemas are discarded rather than migrated — deliberate, so a format
## change can never quietly reinterpret old times as something they aren't.
static func _load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != VERSION:
		return {}
	return d


static func _save_all(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Records: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
