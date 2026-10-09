extends AnimatedSprite3D

@export var max_glow_boost: float = 2.5 # HDR Multiplier
@export var base_color: Color
@export var base_particle_count: int = 25 # 25 for lesser

@onready var detection_area: Area3D = $Area3D
@onready var detection_shape: SphereShape3D = $Area3D/CollisionShape3D.shape
@onready var prox_particles: CPUParticles3D = $CPUParticles3D

var player: Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	modulate.a = 0.0
	prox_particles.emitting = false
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body
		prox_particles.emitting = true

func _on_body_exited(body: Node) -> void:
	if body == player:
		player = null
		create_tween().tween_property(self, "modulate:a", 0.0, 0.3)
		prox_particles.emitting = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player == null:
		return
	
	var max_dist: float = detection_shape.radius
	var dist := global_position.distance_to(player.global_position)
	var proximity := clampf(remap(dist, max_dist, 0.5, 0.0, 1.0), 0.0, 1.0)
	
	var current_alpha := proximity
	var glow := 1.0 + (proximity * (max_glow_boost - 1.0))
	modulate = Color(base_color.r * glow, base_color.g * glow, base_color.b * glow, current_alpha)
	
	#prox_particles.amount = base_particle_count * proximity
