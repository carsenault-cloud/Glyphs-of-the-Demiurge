class_name DroppedItem
extends RigidBody3D

const ROTATE_SPEED := 1.5
const PICKUP_DELAY := 0.5

var stack: ItemStack
var _age := 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var pickup_area: Area3D = $PickupArea

func _ready() -> void:
	pickup_area.body_entered.connect(_on_body_entered)
	_apply_visual()

func setup(p_stack: ItemStack) -> void:
	stack = p_stack
	if is_inside_tree():
		_apply_visual()

func _apply_visual() -> void:
	if stack == null or stack.item == null:
		return
	if stack.item.world_mesh != null:
		mesh_instance.mesh = stack.item.world_mesh
		mesh_instance.scale = stack.item.world_mesh_scale
		return

	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = stack.item.icon
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	mesh_instance.mesh = quad

func _process(delta: float) -> void:
	_age += delta
	mesh_instance.rotate_y(ROTATE_SPEED * delta)   # cosmetic spin on the mesh only — the body itself has rotation locked

func _on_body_entered(body: Node3D) -> void:
	if _age < PICKUP_DELAY or stack == null:
		return
	if not body.is_in_group("player"):
		return

	var inv: PlayerInventory = get_tree().get_first_node_in_group("player_inventory")
	if inv == null:
		return

	var leftover := inv.storage.add_item(stack.item, stack.count)
	if leftover <= 0:
		queue_free()
	else:
		stack.count = leftover

static func spawn(p_stack: ItemStack, world_position: Vector3, parent: Node, toss_velocity: Vector3 = Vector3.ZERO) -> DroppedItem:
	var scene: PackedScene = load("res://world/dropped_item.tscn")
	var instance: DroppedItem = scene.instantiate()
	parent.add_child(instance)
	instance.global_position = world_position
	instance.setup(p_stack)
	if toss_velocity != Vector3.ZERO:
		instance.linear_velocity = toss_velocity
	return instance
