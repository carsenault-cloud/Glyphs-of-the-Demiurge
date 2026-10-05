class_name ShapelessRecipe
extends CraftingRecipe

## Array of Item, duplicates allowed (e.g. [wood, wood, stone] for 2 wood + 1 stone)
@export var ingredients: Array[Item] = []

func matches(slot_items: Array[Item]) -> bool:
	var remaining := ingredients.duplicate()
	for item in slot_items:
		if item == null:
			continue
		var found := false
		for i in remaining.size():
			if remaining[i].id == item.id:
				remaining.remove_at(i)
				found = true
				break
		if not found:
			return false
	return remaining.is_empty()
