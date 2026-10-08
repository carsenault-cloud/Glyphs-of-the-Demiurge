class_name BuildModeController
extends Node

@export var camera: Camera3D
@export var player_inventory: PlayerInventory
@export var ghost_scene_default: PackedScene   # single test piece for now — a real piece-select menu is a follow-up

@export var deconstruct_reach := 6.0
@export_flags_3d_physics var deconstruct_mask := 1
var ghost: BuildGhost
var active := false

func _ready() -> void:
	add_to_group("build_mode_controller")
	ghost = BuildGhost.new()
	get_tree().current_scene.add_child.call_deferred(ghost)
	ghost.visible = false

func toggle() -> void:
	if active:
		_exit_build_mode()
	else:
		_enter_build_mode()

func _enter_build_mode() -> void:
	if ghost_scene_default == null:
		push_warning("BuildModeController: no ghost_scene_default set")
		return
	active = true
	ghost.set_piece(ghost_scene_default)
	ghost.visible = true

func _exit_build_mode() -> void:
	active = false
	ghost.visible = false
	ghost.set_piece(null)

func _process(_delta: float) -> void:
	if active and not _hammer_still_selected():
		_exit_build_mode()
	if not active or camera == null:
		return
	ghost.update(camera, camera.get_world_3d().direct_space_state)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("build_rotate_cw"):
		ghost.rotate_step(1)
	elif event.is_action_pressed("build_rotate_ccw"):
		ghost.rotate_step(-1)
	elif event.is_action_pressed("build_place"):
		_confirm_placement()
	elif event.is_action_pressed("build_cancel"):
		_exit_build_mode()
	elif event.is_action_pressed("god_deconstruct"):
		_try_deconstruct()

func _confirm_placement() -> void:
	if not ghost.is_valid or ghost.piece_scene == null:
		return
	var piece_def := ghost.get_build_piece()
	if piece_def == null:
		return

	if player_inventory != null:
		for stack in piece_def.materials:
			if stack == null or stack.item == null:
				continue
			if player_inventory.storage.count_item(stack.item.id) < stack.count:
				return

	var terrain: TerrainManager = get_tree().get_first_node_in_group("terrain_manager")
	if terrain == null:
		push_warning("BuildModeController: no node in group 'terrain_manager'")
		return
	var placed = terrain.place_built_piece(ghost.piece_scene, ghost.get_placement_transform())
	if placed == null:
		return

	if player_inventory != null:
		for stack in piece_def.materials:
			if stack == null or stack.item == null:
				continue
			player_inventory.storage.remove_item_by_id(stack.item.id, stack.count)

func _hammer_still_selected() -> bool:
	if player_inventory == null:
		return false
	var stack := player_inventory.get_selected_stack()
	return stack != null and stack.item is ItemHammer

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
