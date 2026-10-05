class_name SlotRecipe
extends CraftingRecipe

## Must be exactly as long as the station's slot_count. Index i corresponds
## to slot i on the station. Leave an entry empty for a slot that must stay
## unfilled for this recipe to match.
@export var slots: Array[Item] = []

func matches(slot_items: Array[Item]) -> bool:
	if slots.size() != slot_items.size():
		return false
	for i in slot_items.size():
		var expected := slots[i]
		var actual := slot_items[i]
		if expected == null and actual == null:
			continue
		if expected == null or actual == null or expected.id != actual.id:
			return false
	return true
