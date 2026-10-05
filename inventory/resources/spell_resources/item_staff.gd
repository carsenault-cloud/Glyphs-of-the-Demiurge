class_name ItemStaff
extends UsableItem

@export var spell_scene: PackedScene
@export var cooldown := 0.5

var _last_cast_time := -INF

func use(user: Node) -> void:
	if spell_scene == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_cast_time < cooldown:
		return
	_last_cast_time = now

	var cast_point := _find_cast_point(user)
	if cast_point == null:
		return
	var cast_direction := Vector3(user.focus_point - cast_point.global_position).normalized()
	#print("item_staff: Cast direction is: ", cast_direction)

	var spell: SpellBase = spell_scene.instantiate()
	spell.cast_direction = cast_direction
	#print("item_staff: spell.cast_direction should be: ", spell.cast_direction)
	user.get_tree().current_scene.add_child(spell)
	spell.cast(cast_point, user, cast_direction)

func _find_cast_point(user: Node) -> Node3D:
	if user.has_node("CastPoint"):
		return user.get_node("CastPoint")
	return user as Node3D
