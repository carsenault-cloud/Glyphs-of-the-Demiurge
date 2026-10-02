class_name TerrainFormSampler
extends RefCounted

static func find_terrain_form(root: Node) -> CollisionShape3D:
	return root.find_child("TerrainForm", true, false) as CollisionShape3D

# Max XZ radius from the shape's own origin — used only to check whether a
# candidate placement fits inside this chunk before committing to it.
static func get_footprint_reach(collision_shape: CollisionShape3D) -> float:
	var shape := collision_shape.shape
	var scale := collision_shape.global_transform.basis.get_scale()
	if shape is BoxShape3D:
		return Vector2(shape.size.x * 0.5 * scale.x, shape.size.z * 0.5 * scale.z).length()
	elif shape is CylinderShape3D or shape is SphereShape3D or shape is CapsuleShape3D:
		return shape.radius * maxf(scale.x, scale.z)
	else:
		var aabb := shape.get_debug_mesh().get_aabb()
		return Vector2(aabb.size.x * scale.x, aabb.size.z * scale.z).length() * 0.5

# `local_point` must already be in the shape's local space (apply the
# inverse transform once per structure, not once per vertex — see caller).
# Returns 0 if inside or on the boundary, distance beyond it otherwise.
static func distance_outside(local_point: Vector3, shape: Shape3D) -> float:
	if shape is BoxShape3D:
		var half := Vector2(shape.size.x, shape.size.z) * 0.5
		var d := Vector2(maxf(absf(local_point.x) - half.x, 0.0), maxf(absf(local_point.z) - half.y, 0.0))
		return d.length()
	elif shape is CylinderShape3D or shape is SphereShape3D or shape is CapsuleShape3D:
		return maxf(Vector2(local_point.x, local_point.z).length() - shape.radius, 0.0)
	else:
		var aabb := shape.get_debug_mesh().get_aabb()
		var center := aabb.position + aabb.size * 0.5
		var half := Vector2(aabb.size.x, aabb.size.z) * 0.5
		var p := Vector2(local_point.x - center.x, local_point.z - center.z)
		var d := Vector2(maxf(absf(p.x) - half.x, 0.0), maxf(absf(p.y) - half.y, 0.0))
		return d.length()

# World-space Y of the top of the shape — terrain conforms to this.
static func get_target_height(collision_shape: CollisionShape3D) -> float:
	var shape := collision_shape.shape
	var top_local: Vector3
	if shape is BoxShape3D:
		top_local = Vector3(0, shape.size.y * 0.5, 0)
	elif shape is CylinderShape3D:
		top_local = Vector3(0, shape.height * 0.5, 0)
	elif shape is SphereShape3D or shape is CapsuleShape3D:
		top_local = Vector3(0, shape.radius, 0)   # approximate for capsule
	else:
		var aabb := shape.get_debug_mesh().get_aabb()
		top_local = Vector3(aabb.position.x + aabb.size.x * 0.5, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z * 0.5)
	return (collision_shape.global_transform * top_local).y
