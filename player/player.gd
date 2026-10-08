extends CharacterBody3D


const SPEED = 16.0 # Default is 8.0 (for now)
const SPRINT_MULT = 4.0
const JUMP_VELOCITY = 20 # Default: 4.5
const LOOK_SPEED = 0.01
const BOOM_INCR = 0.5

@onready var boom := $SpringArm3D
@onready var camera := $SpringArm3D/Camera3D
@onready var terrain: TerrainManager
@onready var pause: Control
@onready var focus_point: Vector3
@onready var focus_ray := $SpringArm3D/Camera3D/FocusRay
@onready var inventory: PlayerInventory = $PlayerInventory
@onready var bmc: BuildModeController = get_tree().get_first_node_in_group("build_mode_controller")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED: ## Pan the camera and interaction raycast
		rotation.y = rotation.y - event.relative.x * LOOK_SPEED
		boom.rotation.x = boom.rotation.x - event.relative.y * LOOK_SPEED
		boom.rotation.x = clamp(boom.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
	
	if bmc == null or not bmc.active:
		if focus_ray.is_colliding():
			focus_point = focus_ray.get_collision_point()
		else:
			focus_point = $SpringArm3D/Camera3D/FocusRay/FallbackFocus.global_position
		if Input.is_action_pressed("god_boom_zin"): ## Zoom in
			boom.spring_length -= BOOM_INCR
			boom.spring_length = clampf(boom.spring_length, 1.0, 5.0)
		elif Input.is_action_pressed("god_boom_zout"): ## Zoom out
			boom.spring_length += BOOM_INCR
			boom.spring_length = clampf(boom.spring_length, 1.0, 5.0)
		if Input.is_action_just_pressed("god_shoulder_swap"): ## Swap camera shoulder
			boom.position.x *= -1
		## NOTE: Currently, this commented code gets the camera stuck directly behind the player, and the print
		## always reads 0 for both values. Nearest I can figure, it's some issue with lerp I don't understand.
		#print("Current boom position: %d | Target boom position: %d" % [boom.position.x, boom.position.x * -1])
		#boom.position = lerp(boom.position, Vector3(boom.position.x * -1, boom.position.z, boom.position.y), 0.1)

	if event.is_action_pressed("god_primary"):
		_handle_use()
	if event.is_action_pressed("god_build"):
		pass
	if event.is_action_pressed("god_mine"):
		_handle_mine()
	
	'if event.is_action_pressed("god_debug_spawn"):
		DroppedItem.spawn(ItemStack.new(ItemRegistry.get_item(1000), 1), interact_ray.get_collision_point(), get_tree().current_scene)'
func _handle_mine() -> void:
	if bmc != null and bmc.active:
		return
	var stack := inventory.get_selected_stack()
	if stack == null or stack.item == null:
		#print("_handle_mine: No item found")
		return
	if stack.item is ItemPickaxe:
		#print("_handle_mine: I think this is a pickaxe")
		_do_mining_raycast()

func _handle_use() -> void:
	if bmc != null and bmc.active:
		return
	var stack := inventory.get_selected_stack()
	if stack == null or stack.item == null:
		return
	if stack.item is UsableItem:
		inventory.use_selected(self)

func _do_mining_raycast() -> void:
	#print("_do_mining_raycast: Firing")
	#terrain.apply_brush(interact_ray.get_collision_point(), 1.0, -1.0)
	pass

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_pressed("god_jump"): # and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("god_left", "god_right", "god_forward", "god_backwards")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if Input.is_action_pressed("god_sprint"):
			velocity.x = direction.x * SPEED * SPRINT_MULT
			velocity.z = direction.z * SPEED * SPRINT_MULT
		else:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
