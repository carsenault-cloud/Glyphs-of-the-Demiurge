class_name BuildModeController
extends Node

@export var camera: Camera3D
@export var player_inventory: PlayerInventory
@export var ghost_scene_default: PackedScene   # single test piece for now — a real piece-select menu is a follow-up

var interact_range: int
@onready var interact_ray: RayCast3D = $BuildRay
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
	interact_ray.target_position = Vector3(0, 0, -5.0)
	if event.is_action_pressed("build_rotate_cw"):
		ghost.rotate_step(1)
	elif event.is_action_pressed("build_rotate_ccw"):
		ghost.rotate_step(-1)
	elif event.is_action_pressed("build_place"):
		_confirm_placement()
	elif event.is_action_pressed("build_cancel"):
		_exit_build_mode()
	elif event.is_action_pressed("god_deconstruct"):
		interact_ray.target_position = Vector3(0, 0, -10.0)
		var target := interact_ray.get_collider()
		if target != null:
			if target.buildable and target.is_class("Breakable"): target.deconstruct()

func _confirm_placement() -> void:
	if not ghost.is_valid or ghost.piece_scene == null:
		#print("confirm blocked: is_valid=", ghost.is_valid, " piece_scene=", ghost.piece_scene)
		return
	var piece_def := ghost.get_build_piece()
	if piece_def == null:
		#print("confirm blocked: no BuildPiece found in ghost instance")
		return

	if player_inventory != null:
		for stack in piece_def.materials:
			if stack == null or stack.item == null:
				continue
			if player_inventory.storage.count_item(stack.item.id) < stack.count:
				return   # not enough materials — silently refuse for now
		for stack in piece_def.materials:
			if stack == null or stack.item == null:
				continue
			player_inventory.storage.remove_item_by_id(stack.item.id, stack.count)

	var placed := ghost.piece_scene.instantiate()
	get_tree().current_scene.add_child(placed)
	placed.global_transform = ghost.get_placement_transform()

func _hammer_still_selected() -> bool:
	if player_inventory == null:
		return false
	var stack := player_inventory.get_selected_stack()
	return stack != null and stack.item is ItemHammer
