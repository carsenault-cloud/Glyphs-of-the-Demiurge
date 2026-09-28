class_name TerrainGenerator
extends RefCounted

var noise := FastNoiseLite.new()
var height_scale := 40

func _init(world_seed: int) -> void:
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.005
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4

func get_base_height(wx: float, wz: float) -> float:
	return noise.get_noise_2d(wx, wz) * height_scale
