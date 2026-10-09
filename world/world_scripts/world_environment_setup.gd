extends Node3D

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)
	
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.005
	env.fog_light_color = Color(0.70, 0.78, 0.85)
	env.glow_enabled = true
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
