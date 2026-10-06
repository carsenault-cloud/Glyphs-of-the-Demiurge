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

func get_piece() -> Node3D:
	var as_node: Node = self
	var as_3d := as_node as Node3D
	if as_3d != null:
		return as_3d
	return get_parent() as Node3D

func take_damage(amount: float, tool_hardness: float = INF) -> bool:
	if destroyed or tool_hardness < hardness:
		#print("breakable.gd: Tool not hard enough")
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
	if destroyed: # If it was already destroyed, exit the function
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
	
	print("_break: Dropping ", result)
	var piece := get_piece()
	_drop_materials(result, piece)

	if piece != null:
		piece.queue_free()
	else:
		queue_free()

func _drop_materials(stacks: Array[ItemStack], piece: Node3D) -> void:
	var origin: Vector3 = piece.global_position if piece != null else Vector3.ZERO
	for stack in stacks:
		DroppedItem.spawn(stack, origin + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), get_tree().current_scene)
