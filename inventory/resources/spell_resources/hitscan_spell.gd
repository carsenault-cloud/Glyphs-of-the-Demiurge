class_name HitscanSpell
extends SpellBase

@export var range := 30.0
@export_flags_3d_physics var collision_mask := 1

func _on_cast() -> void:
	var from := global_position
	var to := from - global_transform.basis.z * range
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		hit(result.collider)
