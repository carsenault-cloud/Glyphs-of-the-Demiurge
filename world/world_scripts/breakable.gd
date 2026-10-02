class_name Breakable
extends Node

signal broken(stacks: Array[ItemStack])
signal state_changed(breakable: Breakable)

@export var hardness := 1.0
@export var max_health := 10.0
@export var materials: Array[ItemStack] = []
@export var buildable := false

var health: float
var destroyed := false

func _ready() -> void:
	health = max_health

func take_damage(amount: float, tool_hardness: float = INF) -> bool:
	if destroyed or tool_hardness < hardness:
		return false
	health -= amount
	if health <= 0.0:
		_break(false)
		return true
	state_changed.emit(self)
	return false

func deconstruct() -> void:
	_break(true)

func _break(full_value: bool) -> void:
	if destroyed:
		return
	destroyed = true
	health = 0.0

	var result: Array[ItemStack] = []
	for stack in materials:
		if stack == null or stack.item == null or stack.count <= 0:
			continue
		var amount: int
		if full_value:
			amount = stack.count
		else:
			amount = roundi(stack.count * randf_range(0.0, 1.0))
		if amount > 0:
			result.append(ItemStack.new(stack.item, amount))

	state_changed.emit(self)   # let the chunk persist this before the node is gone
	broken.emit(result)

	if not full_value:
		_drop_materials(result)
	else:
		_drop_materials(materials)

	get_parent().queue_free()

func _drop_materials(stacks: Array[ItemStack]) -> void:
	var origin: Vector3 = (get_parent() as Node3D).global_position if get_parent() is Node3D else Vector3.ZERO
	for stack in stacks:
		DroppedItem.spawn(stack, origin + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), get_tree().current_scene)
