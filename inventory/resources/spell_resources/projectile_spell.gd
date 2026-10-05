class_name ProjectileSpell
extends SpellBase

@export var speed := 15.0
@export_flags_3d_physics var collision_mask := 1

func _on_cast() -> void:
	cast_direction = cast_direction * speed
	#print("projectile_spell: direction is: ", cast_direction)

func _on_process(delta: float) -> void:
	var motion := cast_direction * delta
	var to := global_position + motion

	var query := PhysicsRayQueryParameters3D.create(global_position, to, collision_mask)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		hit(result.collider)
		_expire()
		return

	global_position = to
