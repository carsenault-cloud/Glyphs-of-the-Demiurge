class_name BuildModeController
extends Node

@export var camera: Camera3D
@export var player_inventory: PlayerInventory
@export var group_label: Label
@export var deconstruct_reach := 15.0
@export_flags_3d_physics var deconstruct_mask := 1

var ghost: BuildGhost
var menu: BuildMenu
var current_def: BuildPieceDef
var active := false
var menu_open := false

func _ready() -> void:
	add_to_group("build_mode_controller")
	ghost = BuildGhost.new()
	ghost.groups_changed.connect(_on_groups_changed)
	get_tree().current_scene.add_child.call_deferred(ghost)
	ghost.visible = false

func toggle() -> void:
	if active:
		_exit_build_mode()
	else:
		_enter_build_mode()

func _enter_build_mode() -> void:
	var hammer := _get_hammer()
	if hammer == null or hammer.pieces.is_empty():
		push_warning("BuildModeController: hammer has no pieces assigned")
		return
	active = true
	if current_def == null or not hammer.pieces.has(current_def):
		current_def = hammer.pieces[0]
	ghost.set_piece(current_def.scene)
	ghost.visible = true

func _exit_build_mode() -> void:
	close_menu()
	active = false
	ghost.visible = false
	ghost.set_piece(null)

func select_piece(def: BuildPieceDef) -> void:
	if def == null or def.scene == null:
		return
	current_def = def
	ghost.set_piece(def.scene)
	close_menu()

# ---------- menu ----------

func _get_menu() -> BuildMenu:
	if menu == null:
		menu = get_tree().get_first_node_in_group("build_menu") as BuildMenu
		if menu != null:
			menu.piece_chosen.connect(select_piece)
	return menu

func open_menu() -> void:
	var hammer := _get_hammer()
	var m := _get_menu()
	if menu_open or hammer == null or m == null:
		return
	menu_open = true
	ghost.visible = false
	m.open(hammer.pieces, player_inventory.storage)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Safe to call anytime; does nothing if the menu isn't open.
func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	if menu != null:
		menu.close()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---------- per-frame / input ----------

func _process(_delta: float) -> void:
	if active and _get_hammer() == null:
		_exit_build_mode()
	if not active or menu_open or camera == null:
		return
	ghost.update(camera, camera.get_world_3d().direct_space_state)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("god_build_menu"):
		if menu_open:
			close_menu()
		else:
			open_menu()
		return
	if menu_open:
		if event.is_action_pressed("god_build_menu"):
			close_menu()
		return

	if event.is_action_pressed("build_rotate_cw"):
		ghost.rotate_step(1)
	elif event.is_action_pressed("build_rotate_ccw"):
		ghost.rotate_step(-1)
	elif event.is_action_pressed("build_place"):
		_confirm_placement()
	#elif event.is_action_pressed("build_cancel"):
		#_exit_build_mode()
	elif event.is_action_pressed("god_deconstruct"):
		_try_deconstruct()

func _confirm_placement() -> void:
	if current_def == null or not ghost.is_valid or ghost.piece_scene == null:
		return
	var cost := current_def.get_cost()
	if player_inventory != null:
		for stack in cost:
			if player_inventory.storage.count_item(stack.item.id) < stack.count:
				return

	var terrain: TerrainManager = get_tree().get_first_node_in_group("terrain_manager")
	if terrain == null:
		push_warning("BuildModeController: no node in group 'terrain_manager'")
		return
	var placed := terrain.place_built_piece(ghost.piece_scene, ghost.get_placement_transform())
	if placed == null:
		return

	if player_inventory != null:
		for stack in cost:
			player_inventory.storage.remove_item_by_id(stack.item.id, stack.count)

func _try_deconstruct() -> void:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * deconstruct_reach
	var query := PhysicsRayQueryParameters3D.create(from, to, deconstruct_mask)
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var b := _find_breakable(hit.collider)
	if b != null and b.buildable:
		b.deconstruct()

func _find_breakable(node: Node) -> Breakable:
	if node is Breakable:
		return node
	for child in node.get_children():
		if child is Breakable:
			return child
	return null

func _get_hammer() -> ItemHammer:
	if player_inventory == null:
		return null
	var stack := player_inventory.get_selected_stack()
	if stack != null and stack.item is ItemHammer:
		return stack.item as ItemHammer
	return null
