class_name Records
extends RefCounted
## Persistent best times: top 10 per level per mode, saved as JSON in
## user:// (survives updates; per-OS user data directory).
## Keys are level filenames ("level_01_coastal.gd") so records survive
## reordering; modes are "race" and "time_trial".

const SAVE_PATH := "user://best_times.json"
const MAX_ENTRIES := 10


## Insert a time; returns its 1-based rank if it made the top 10, else -1.
static func add_time(level_file: String, mode: String, t: float) -> int:
	var all := _load_all()
	if not all.has(level_file):
		all[level_file] = {}
	var per_level: Dictionary = all[level_file]
	if not per_level.has(mode):
		per_level[mode] = []
	var times: Array = per_level[mode]
	times.append(t)
	times.sort()
	if times.size() > MAX_ENTRIES:
		times.resize(MAX_ENTRIES)
	per_level[mode] = times
	_save_all(all)
	var rank := times.find(t)
	return rank + 1 if rank >= 0 else -1


static func get_times(level_file: String, mode: String) -> Array:
	var all := _load_all()
	if all.has(level_file) and (all[level_file] as Dictionary).has(mode):
		return all[level_file][mode]
	return []


static func _load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _save_all(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Records: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
