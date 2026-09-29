class_name CraftingRecipe
extends Resource

@export var output: ItemStack

func matches(_grid_items: Array[Item], _width: int, _height: int) -> bool:
	push_error("CraftingRecipe.matches() must be overridden")
	return false
