class_name CraftingRecipe
extends Resource

@export var station_id := "inventory"
@export var output: ItemStack

func matches(_slot_items: Array[Item]) -> bool:
	push_error("CraftingRecipe.matches() must be overridden")
	return false
