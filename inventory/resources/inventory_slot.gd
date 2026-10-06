class_name InventorySlot
extends Panel

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $Count

var inventory: Inventory
var index: int
var clickable := true   # hotbar slots set this false at bind time

func bind(inv: Inventory, idx: int, p_clickable: bool = true) -> void:
	if inventory != null:
		inventory.changed.disconnect(_on_changed)
	inventory = inv
	index = idx
	clickable = p_clickable
	inventory.changed.connect(_on_changed)
	_refresh()

func _on_changed(changed_index: int) -> void:
	if changed_index == index:
		_refresh()

func _refresh() -> void:
	var stack := inventory.get_stack(index)
	if stack == null or stack.count <= 0:
		icon.texture = null
		count_label.text = ""
	else:
		icon.texture = stack.item.icon
		icon.custom_maximum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		count_label.text = str(stack.count) if stack.count > 1 else ""

func _gui_input(event: InputEvent) -> void:
	if not clickable or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(event.shift_pressed, event.ctrl_pressed)

func _handle_left_click() -> void:
	var held := CursorHeld.stack
	var mine := inventory.get_stack(index)

	if held == null:
		if mine != null:
			CursorHeld.set_stack(mine)
			inventory.set_stack(index, null)
		return

	if mine == null:
		inventory.set_stack(index, held)
		CursorHeld.set_stack(null)
	elif mine.can_merge_with(held):
		var room := mine.item.max_stack - mine.count
		var moved := mini(room, held.count)
		mine.count += moved
		held.count -= moved
		inventory.set_stack(index, mine)   # re-emits changed, refreshes this slot
		CursorHeld.set_stack(null if held.count <= 0 else held)
	else:
		inventory.set_stack(index, held)
		CursorHeld.set_stack(mine)

func _handle_right_click(shift: bool, ctrl: bool) -> void:
	var mine := inventory.get_stack(index)
	if mine == null:
		return
	
	if shift and CursorHeld.stack == null:
		_split_half(mine)
		return
	
	if ctrl:
		_take_one(mine)
		return
	
	if mine.item is UsableItem:
		(mine.item as UsableItem).use(_find_user())

func _split_half(mine: ItemStack) -> void:
	if mine.count <= 1:
		CursorHeld.set_stack(mine)
		inventory.set_stack(index, null)
		return
	var half := ceili(mine.count / 2.0)
	var held := ItemStack.new(mine.item, half)
	mine.count -= half
	CursorHeld.set_stack(held)
	inventory.set_stack(index, mine)

func _take_one(mine: ItemStack) -> void:
	var held := CursorHeld.stack
	if held != null and (not held.can_merge_with(mine) or held.count >= held.item.max_stack):
		return
	mine.count -= 1
	if held == null:
		CursorHeld.set_stack(ItemStack.new(mine.item, 1))
	else:
		held.count += 1
		CursorHeld.set_stack(held)
	inventory.set_stack(index, null if mine.count <= 0 else mine)

func _find_user() -> Node:
	return get_tree().get_first_node_in_group("player")


	
