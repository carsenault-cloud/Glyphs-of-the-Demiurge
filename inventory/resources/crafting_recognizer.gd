class_name CraftingRecognizer
extends RefCounted

var recipes: Array[CraftingRecipe] = []

func register(recipe: CraftingRecipe) -> void:
	recipes.append(recipe)

func find_match(slot_items: Array[Item], station_id: String) -> CraftingRecipe:
	for r in recipes:
		if r.station_id != station_id:
			continue
		if r.matches(slot_items):
			return r
	return null
