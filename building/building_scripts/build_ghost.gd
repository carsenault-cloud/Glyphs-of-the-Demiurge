class_name BuildGhost
extends Node3D

signal groups_changed(ghost_group: String, target_group: String)

const STEP_ANGLE := TAU / 16.0

@export var reach := 6.0
@export_flags_3d_physics var collision_mask := 1
## A snapped piece stays snapped while its socket is within snap_radius * this.
## The same widened radius is how close to your crosshair a socket must be
## to get picked automatically.
@export var hold_radius_scale := 1.6
@export var aim_snap_enabled := true
## true: rotation steps pivot a snapped piece around the socket (angled walls).
## false: snapped pieces stay face-to-face and rotation only affects free placement.
@export var rotate_while_snapped := true

var piece_scene: PackedScene
var ghost_instance: Node3D
var is_valid := false

var _rotation_step := 0
var _ghost_piece: BuildPiece = null
var _lock_point: SnapPoint = null    # socket on the ghost
var _lock_target: SnapPoint = null   # socket on an already-placed piece
var _ghost_group := ""               # active snap_group on the ghost piece
var _target_group := ""              # active snap_group on already-placed pieces

func set_piece(scene: PackedScene) -> void:
	_clear_lock()
	_ghost_group = ""
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
	_emit_groups()

func rotate_step(dir: int) -> void:
	_rotation_step = posmod(_rotation_step + dir, 16)

func get_build_piece() -> BuildPiece:
	return _ghost_piece

func get_placement_transform() -> Transform3D:
	return ghost_instance.global_transform if ghost_instance != null else Transform3D()

# ---------- snap groups ----------

func cycle_ghost_group(dir: int) -> void:
	_ghost_group = _cycle(_ghost_groups(), _ghost_group, dir)
	_clear_lock()
	_emit_groups()

func cycle_target_group(dir: int) -> void:
	_target_group = _cycle(_target_groups(), _target_group, dir)
	_clear_lock()
	_emit_groups()

func _cycle(groups: Array[String], current: String, dir: int) -> String:
	if groups.is_empty():
		return ""
	var i := groups.find(current)
	if i < 0:
		return groups[0]
	return groups[posmod(i + dir, groups.size())]

func _ghost_groups() -> Array[String]:
	var out: Array[String] = []
	if _ghost_piece != null:
		for p in _ghost_piece.get_snap_points():
			if not out.has(p.snap_group):
				out.append(p.snap_group)
	out.sort()
	return out

func _target_groups() -> Array[String]:
	return SnapMatcher.get_groups(get_tree())

# Keeps the active groups valid, e.g. if the last piece with a "vertical"
# socket was deconstructed while "vertical" was selected.
func _normalize_groups() -> void:
	var g := _ghost_groups()
	if not g.has(_ghost_group):
		_ghost_group = g[0] if not g.is_empty() else ""
	var t := _target_groups()
	if not t.has(_target_group):
		_target_group = t[0] if not t.is_empty() else ""

func _emit_groups() -> void:
	_normalize_groups()
	groups_changed.emit(_ghost_group, _target_group)

# ---------- per-frame update ----------

func update(camera: Camera3D, space_state: PhysicsDirectSpaceState3D) -> void:
	if ghost_instance == null:
		return

	var origin := camera.global_position
	var dir := (-camera.global_transform.basis.z).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, collision_mask)
	var result := space_state.intersect_ray(query)
	var has_hit := not result.is_empty()
	var hit_pos := origin + dir * reach
	if has_hit:
		hit_pos = result.position
	var ray_len := origin.distance_to(hit_pos)

	# Free pose first, so the socket checks below see where it would sit unsnapped.
	if has_hit:
		ghost_instance.global_transform = Transform3D(Basis(Vector3.UP, _rotation_step * STEP_ANGLE), hit_pos)

	var did_snap := _ghost_piece != null and _update_snap(origin, dir, ray_len, has_hit, hit_pos)

	# Looking at a socket in open air still shows the ghost, since it snaps there.
	visible = has_hit or did_snap
	is_valid = visible

func _update_snap(origin: Vector3, dir: Vector3, ray_len: float, has_hit: bool, hit_pos: Vector3) -> bool:
	_normalize_groups()

	# Only ghost sockets in the active group take part.
	var points: Array[SnapPoint] = []
	for p in _ghost_piece.get_snap_points():
		if p.snap_group == _ghost_group:
			points.append(p)
	if points.is_empty():
		_clear_lock()
		return false

	# 1) Stay attached while the socket is within the widened radius, either
	#    because you're still looking at it or the free pose is still near it.
	if _lock_is_alive():
		var radius := _lock_target.snap_radius * hold_radius_scale
		var held := SnapMatcher.aim_distance(_lock_target.global_position, origin, dir, ray_len + radius) <= radius
		if not held and has_hit:
			held = _lock_point.global_position.distance_to(_lock_target.global_position) <= radius
		if held:
			_apply_snap(_lock_point, _lock_target)
			return true
	_clear_lock()

	# 2) Normal proximity snap: a ghost socket sitting within a placed socket's radius.
	if has_hit:
		var near_dist := INF
		var near_point: SnapPoint = null
		var near_target: SnapPoint = null
		for point in points:
			var found := SnapMatcher.find_best_match(point, self, 1.0, _target_group)
			if not found.is_empty() and found.dist < near_dist:
				near_dist = found.dist
				near_point = point
				near_target = found.point
		if near_point != null:
			_lock(near_point, near_target)
			_apply_snap(near_point, near_target)
			return true

	# 3) Aim snap: a compatible placed socket near the crosshair ray.
	if aim_snap_enabled:
		var types: Array = []
		for p in points:
			if not types.has(p.snap_type):
				types.append(p.snap_type)
		var aimed := SnapMatcher.find_aimed(self, origin, dir, ray_len + 0.5, hold_radius_scale, types, _target_group)
		if not aimed.is_empty():
			var target: SnapPoint = aimed[0].point
			var ref_pos := hit_pos if has_hit else target.global_position
			var aim_point: SnapPoint = null
			var aim_d := INF
			# If the active group has several compatible sockets, use the one whose
			# resulting placement lands closest to where you're pointing.
			for p in points:
				if p.snap_type != target.snap_type:
					continue
				var d := _snapped_transform(p, target).origin.distance_to(ref_pos)
				if d < aim_d:
					aim_d = d
					aim_point = p
			if aim_point != null:
				_lock(aim_point, target)
				_apply_snap(aim_point, target)
				return true

	return false

func _lock(ghost_point: SnapPoint, target_point: SnapPoint) -> void:
	_lock_point = ghost_point
	_lock_target = target_point

func _clear_lock() -> void:
	_lock_point = null
	_lock_target = null

func _lock_is_alive() -> bool:
	# A piece can be deconstructed while locked to it, so check validity first.
	return is_instance_valid(_lock_point) and is_instance_valid(_lock_target) \
		and _lock_target.is_inside_tree() \
		and _lock_point.snap_group == _ghost_group and _lock_target.snap_group == _target_group

func _snapped_transform(ghost_point: SnapPoint, target_point: SnapPoint) -> Transform3D:
	## NOTE: No support for top to bottom connections yet
	var up_axis := target_point.global_transform.basis.y.normalized()
	var desired_basis := target_point.global_transform.basis.rotated(up_axis, PI)
	if rotate_while_snapped:
		desired_basis = desired_basis.rotated(up_axis, _rotation_step * STEP_ANGLE)
	var desired_transform := Transform3D(desired_basis, target_point.global_position)

	var point_local := ghost_instance.global_transform.affine_inverse() * ghost_point.global_transform
	return desired_transform * point_local.affine_inverse()

func _apply_snap(ghost_point: SnapPoint, target_point: SnapPoint) -> void:
	ghost_instance.global_transform = _snapped_transform(ghost_point, target_point)

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
