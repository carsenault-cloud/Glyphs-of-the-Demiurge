extends Node

const RECIPES_PATH := "res://recipes/"

var recognizer := CraftingRecognizer.new()

func _ready() -> void:
	_scan_dir(RECIPES_PATH)

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("RecipeRegistry: could not open %s" % path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path := path.path_join(entry)
			if dir.current_is_dir():
				_scan_dir(full_path + "/")
			elif entry.ends_with(".tres") or entry.ends_with(".res"):
				var res := load(full_path)
				if res is CraftingRecipe:
					recognizer.register(res as CraftingRecipe)
		entry = dir.get_next()
	dir.list_dir_end()
