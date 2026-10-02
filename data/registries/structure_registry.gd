extends Node

const DATA_PATH := "res://data/structures.json"

var _variants: Dictionary = {}   # structure_key -> Array[String] (scene paths)

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("StructureRegistry: %s not found" % DATA_PATH)
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("StructureRegistry: failed to parse %s" % DATA_PATH)
		return
	for key in parsed.keys():
		var entry = parsed[key]
		if entry is Array:
			var paths: Array[String] = []
			for p in entry:
				paths.append(str(p))
			_variants[key] = paths
		else:
			push_warning("StructureRegistry: '%s' is not an array, skipping" % key)

func has_key(key: String) -> bool:
	return _variants.has(key) and not _variants[key].is_empty()

func pick_random_scene(key: String, rng: RandomNumberGenerator) -> PackedScene:
	var paths: Array[String] = _variants.get(key, [])
	if paths.is_empty():
		return null
	var res := load(paths[rng.randi_range(0, paths.size() - 1)])
	if res is PackedScene:
		return res
	push_warning("StructureRegistry: '%s' is not a PackedScene" % paths[0])
	return null
