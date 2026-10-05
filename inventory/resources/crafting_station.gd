class_name CraftingStation
extends RefCounted

var grid: Inventory
var output: Inventory
var slot_count: int
var recognizer: CraftingRecognizer
var station_id: String

var _current_recipe: CraftingRecipe = null
var _output_is_auto := false

func _init(p_slot_count: int, p_recognizer: CraftingRecognizer, p_station_id: String) -> void:
	slot_count = p_slot_count
	recognizer = p_recognizer
	station_id = p_station_id
	grid = Inventory.new(slot_count)
	output = Inventory.new(1)
	grid.changed.connect(_on_grid_changed)
	output.changed.connect(_on_output_changed)

func _on_grid_changed(_i: int) -> void:
	var match_recipe := recognizer.find_match(grid.as_item_array(), station_id)
	var out_stack := output.get_stack(0)

	if match_recipe == null:
		if _output_is_auto and out_stack != null:
			output.set_stack(0, null)
		_current_recipe = null
		_output_is_auto = false
		return

	if out_stack == null:
		output.set_stack(0, match_recipe.output.duplicate_stack())
		_current_recipe = match_recipe
		_output_is_auto = true
	elif _output_is_auto and out_stack.item.id == match_recipe.output.item.id:
		out_stack.count = match_recipe.output.count
		_current_recipe = match_recipe

func _on_output_changed(_i: int) -> void:
	if _output_is_auto and output.is_empty(0) and _current_recipe != null:
		_consume_ingredients(_current_recipe)
		_current_recipe = null
		_output_is_auto = false

func _consume_ingredients(recipe: CraftingRecipe) -> void:
	if recipe is ShapelessRecipe:
		var remaining: Array[Item] = recipe.ingredients.duplicate()
		for i in grid.size:
			var s := grid.get_stack(i)
			if s == null:
				continue
			for j in remaining.size():
				if remaining[j].id == s.item.id:
					grid.remove_at(i, 1)
					remaining.remove_at(j)
					break
	else:
		for i in grid.size:
			if not grid.is_empty(i):
				grid.remove_at(i, 1)
