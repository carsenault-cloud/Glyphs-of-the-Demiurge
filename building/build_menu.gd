# build_menu.gd
class_name BuildMenu
extends PanelContainer

signal piece_chosen(def: BuildPieceDef)

@export var button_scene: PackedScene
@export var tabs: TabBar
@export var grid: GridContainer
@export var info_label: Label

var _defs: Array[BuildPieceDef] = []
var _inventory: Inventory
var _categories: Array[String] = []
var _last_category := ""

func _ready() -> void:
	add_to_group("build_menu")
	visible = false
	tabs.tab_changed.connect(_on_tab_changed)

func open(defs: Array[BuildPieceDef], inventory: Inventory) -> void:
	_defs = defs
	_inventory = inventory
	_categories.clear()
	tabs.clear_tabs()
	for d in defs:
		if d != null and not _categories.has(d.category):
			_categories.append(d.category)
	for c in _categories:
		tabs.add_tab(c)
	visible = true
	if _categories.is_empty():
		_clear_grid()
		info_label.text = "No pieces available"
		return
	var start := maxi(_categories.find(_last_category), 0)
	tabs.current_tab = start
	_populate(_categories[start])

func close() -> void:
	visible = false

func _on_tab_changed(index: int) -> void:
	if index >= 0 and index < _categories.size():
		_populate(_categories[index])

func _populate(category: String) -> void:
	_last_category = category
	_clear_grid()
	info_label.text = ""
	for d in _defs:
		if d == null or d.category != category:
			continue
		var b: BuildPieceButton = button_scene.instantiate()
		grid.add_child(b)
		b.setup(d, _can_afford(d))
		b.chosen.connect(func(def: BuildPieceDef) -> void: piece_chosen.emit(def))
		b.hovered.connect(_on_hovered)

func _clear_grid() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()

func _can_afford(def: BuildPieceDef) -> bool:
	for stack in def.get_cost():
		if _inventory.count_item(stack.item.id) < stack.count:
			return false
	return true

func _on_hovered(def: BuildPieceDef) -> void:
	var lines: Array[String] = [def.display_name]
	for stack in def.get_cost():
		lines.append("%s  %d / %d" % [stack.item.item_name, _inventory.count_item(stack.item.id), stack.count])
	info_label.text = "\n".join(PackedStringArray(lines))
