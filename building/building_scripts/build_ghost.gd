class_name BuildGhost
extends Node3D

const STEP_ANGLE := TAU / 16.0

@export var reach := 6.0
@export_flags_3d_physics var collision_mask := 1

var piece_scene: PackedScene
var ghost_instance: Node3D
var is_valid := false

var _rotation_step := 0
var _ghost_piece: BuildPiece = null

func set_piece(scene: PackedScene) -> void:
	if ghost_instance != null:
		ghost_instance.queue_free()
		ghost_instance = null
		_ghost_piece = null
	
	piece_scene = scene
	if scene == null:
		return
	
	ghost_instance = scene.instantiate()
	_ghost_piece = _find_build_piece(ghost_instance)
	if _ghost_piece != null:
		_ghost_piece.is_ghost = true
	add_child(ghost_instance)
	_disable_collision(ghost_instance)
	_apply_ghost_material(ghost_instance)
	
func rotate_step(dir: int) -> void:
	_rotation_step = posmod(_rotation_step + dir, 16)

func get_build_piece() -> BuildPiece:
	return _ghost_piece

func get_placement_transform() -> Transform3D:
	return ghost_instance.global_transform if ghost_instance != null else Transform3D()

func update(camera: Camera3D, space_state: PhysicsDirectSpaceState3D) -> void:
	if ghost_instance == null:
		return
	
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	var result := space_state.intersect_ray(query)
	
	if result.is_empty():
		is_valid = false
		visible = false
		return
	
	visible = true
	is_valid = true
	
	var cam_fwd: Vector3 = -camera.global_transform.basis.z
	var yaw := _rotation_step * STEP_ANGLE #atan2(cam_fwd.x, cam_fwd.z) + _rotation_step * STEP_ANGLE
	ghost_instance.global_transform = Transform3D(Basis(Vector3.UP, yaw), result.position)
	
	if _ghost_piece != null:
		for point in _ghost_piece.get_snap_points():
			var found := SnapMatcher.find_best_match(point, self)
			if not found.is_empty():
				_apply_snap(point, found["point"])
				break

func _apply_snap(ghost_point: SnapPoint, target_point: SnapPoint) -> void:
	## NOTE: No support for top to bottom connections yet
	var up_axis := target_point.global_transform.basis.y.normalized()
	var desired_basis := target_point.global_transform.basis.rotated(up_axis, PI)
	desired_basis = desired_basis.rotated(up_axis, _rotation_step * STEP_ANGLE)
	var desired_transform := Transform3D(desired_basis, target_point.global_position)
	
	var point_local := ghost_instance.global_transform.affine_inverse() * ghost_point.global_transform
	ghost_instance.global_transform = desired_transform * point_local.affine_inverse()

func _find_build_piece(root: Node) -> BuildPiece:
	if root is BuildPiece:
		return root
	for child in root.get_children():
		var found := _find_build_piece(child)
		if found != null:
			return found
	return null

func _disable_collision(root: Node) -> void:
	for child in root.get_children():
		if child is CollisionShape3D:
			child.disabled = true
		if child is CollisionObject3D:
			child.collision_layer = 0
			child.collision_mask = 0
		_disable_collision(child)

func _apply_ghost_material(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			child.material_override = mat
		_apply_ghost_material(child)
