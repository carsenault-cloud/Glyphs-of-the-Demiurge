class_name CraftingRecognizer
extends RefCounted

var recipes: Array[CraftingRecipe] = []

func register(recipe: CraftingRecipe) -> void:
	recipes.append(recipe)

func find_match(grid_items: Array[Item], width: int, height: int) -> CraftingRecipe:
	for r in recipes:
		if r.matches(grid_items, width, height):
			return r
	return null
