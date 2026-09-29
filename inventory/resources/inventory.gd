class_name Inventory
extends RefCounted

signal changed(index: int)

var size: int
var _slots: Array[ItemStack]

func _init(p_size: int) -> void:
	size = p_size
	_slots.resize(size)

func get_stack(i: int) -> ItemStack:
	return _slots[i]

func set_stack(i: int, stack: ItemStack) -> void:
	_slots[i] = stack
	changed.emit(i)

func is_empty(i: int) -> bool:
	return _slots[i] == null or _slots[i].count <= 0

func add_item(item: Item, count: int) -> int:
	var remaining := count
	for i in size:
		if remaining <= 0:
			break
		var s := _slots[i]
		if s != null and s.item.id == item.id and s.count < item.max_stack:
			var room := item.max_stack - s.count
			var moved := mini(room, remaining)
			s.count += moved
			remaining -= moved
			changed.emit(i)
	for i in size:
		if remaining <= 0:
			break
		if is_empty(i):
			var moved := mini(item.max_stack, remaining)
			_slots[i] = ItemStack.new(item, moved)
			remaining -= moved
			changed.emit(i)
			
	return remaining

func remove_at(i: int, count: int) -> void:
	var s := _slots[i]
	if s == null:
		return
	s.count -= count
	if s.count <= 0:
		_slots[i] = null
	changed.emit(i)

func swap(i: int, j: int) -> void:
	var tmp := _slots[i]
	_slots[i] = _slots[j]
	_slots[j] = tmp
	changed.emit(i)
	changed.emit(j) 

func as_item_array() -> Array[Item]:
	var out: Array[Item] = []
	out.resize(size)
	for i in size:
		out[i] = _slots[i].item if _slots[i] != null else null
	return out
