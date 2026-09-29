class_name TerrainGenerator
extends RefCounted

var noise := FastNoiseLite.new()
var height_scale := 40
var biome_noise := FastNoiseLite.new()

func _init(world_seed: int) -> void:
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.005
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	biome_noise.seed = world_seed + 9001
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	biome_noise.frequency = 0.008

func get_base_height(wx: float, wz: float) -> float:
	return noise.get_noise_2d(wx, wz) * height_scale

func get_biome(coord: Vector2i, biome_count: int) -> int:
	if biome_count <= 0:
		return 0
	var cx := coord.x * TerrainConfig.CHUNK_SIZE + TerrainConfig.CHUNK_SIZE * 0.5
	var cz := coord.y * TerrainConfig.CHUNK_SIZE + TerrainConfig.CHUNK_SIZE * 0.5
	var n := biome_noise.get_noise_2d(cx, cz) * 0.5 + 0.5
	return clampi(floori(n * biome_count), 0, biome_count - 1)
	
	
	
