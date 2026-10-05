class_name SpellBase
extends Node3D

@export var lifetime := 1.0      # seconds; -1 = infinite
@export var max_travel := 10.0   # meters; -1 = infinite
@export var damage := 5.0

var caster: Node = null
var _age := 0.0
var _start_position: Vector3
var cast_direction: Vector3

## Called once by ItemStaff right after instancing. from is where the spell
## starts (position + facing) — typically a cast point on the player/camera.
func cast(from: Node3D, user: Node, direction: Vector3) -> void:
	caster = user
	global_transform = from.global_transform
	_start_position = global_position
	cast_direction = direction
	_on_cast()

## Override per spell type for anything that happens at the moment of cast
## (an instant raycast, a VFX burst, etc).
func _on_cast() -> void:
	pass

## Override per spell type for anything that happens every frame
## (projectile movement, a homing update, a persisting beam).
func _on_process(_delta: float) -> void:
	pass

func _process(delta: float) -> void:
	_age += delta
	if lifetime >= 0.0 and _age >= lifetime:
		_expire()
		return
	if max_travel >= 0.0 and global_position.distance_to(_start_position) >= max_travel:
		_expire()
		return
	_on_process(delta)

func _expire() -> void:
	queue_free()

## Shared hit-resolution so every spell type damages things the same way.
func hit(target: Object) -> void:
	print("spell_base.gd: hit target: ", target)
	if target is Breakable:
		print("Target is breakable")
		(target as Breakable).take_damage(damage)
