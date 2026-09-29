extends Node

const ITEMS_PATH := "res://items/"

var _items: Dictionary = {}   # id -> Item

func _ready() -> void:
	_scan_dir(ITEMS_PATH)

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ItemRegistry: could not open %s" % path)
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
				if res is Item:
					_register(res as Item, full_path)
		entry = dir.get_next()
	dir.list_dir_end()

func _register(item: Item, path: String) -> void:
	if item.id == -1:
		push_warning("ItemRegistry: item at %s has no id, skipping" % path)
		return
	if _items.has(item.id):
		push_warning("ItemRegistry: duplicate id '%s' (%s), keeping first" % [item.id, path])
		return
	_items[item.id] = item

func get_item(id: int) -> Item:
	return _items.get(id, null)

func has_item(id: int) -> bool:
	return _items.has(id)

func all_items() -> Array[Item]:
	var out: Array[Item] = []
	for k in _items:
		out.append(_items[k])
	return out
