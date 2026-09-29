class_name ItemStack
extends Resource

var item: Item
var count: int

func _init(p_item: Item = null, p_count: int = 1) -> void:
	item = p_item
	count = p_count

func duplicate_stack() -> ItemStack:
	return ItemStack.new(item, count) as ItemStack

func can_merge_with(other: ItemStack) -> bool:
	return other != null and other.item != null and item != null and other.item_id == item.id
