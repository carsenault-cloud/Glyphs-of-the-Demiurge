class_name TerrainGenerator
extends RefCounted

var world_seed: int
var biome_noise := FastNoiseLite.new()
var ocean_noise := FastNoiseLite.new()
var profiles: Array[TerrainHeightProfile] = []

var ocean_threshold := 0.62
var ocean_falloff := 0.08
var ocean_depth := -25.0

func _init(p_world_seed: int) -> void:
	world_seed = p_world_seed
	biome_noise.seed = p_world_seed + 9001
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	biome_noise.frequency = 0.0008

	ocean_noise.seed = p_world_seed + 4242
	ocean_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ocean_noise.frequency = 0.0003   # much lower than biome_noise -> large contiguous blobs

func _biome_noise01(wx: float, wz: float) -> float:
	return biome_noise.get_noise_2d(wx, wz) * 0.5 + 0.5

func get_ocean_mask(wx: float, wz: float) -> float:
	return ocean_noise.get_noise_2d(wx, wz) * 0.5 + 0.5

func is_ocean_at(wx: float, wz: float) -> bool:
	return get_ocean_mask(wx, wz) > ocean_threshold

func get_base_height(wx: float, wz: float) -> float:
	var h_land := 0.0
	if not profiles.is_empty():
		var n := _biome_noise01(wx, wz)
		var f := clampf(n, 0.0, 0.999999) * profiles.size()
		var idx0 := int(floor(f))
		var idx1 := mini(idx0 + 1, profiles.size() - 1)
		var t := f - idx0
		var h0 := profiles[idx0].get_height(wx, wz, world_seed, idx0 * 131 + 17)
		var h1 := profiles[idx1].get_height(wx, wz, world_seed, idx1 * 131 + 17)
		h_land = lerp(h0, h1, t)

	var mask := get_ocean_mask(wx, wz)
	if mask > ocean_threshold - ocean_falloff:
		var factor := smoothstep(ocean_threshold - ocean_falloff, ocean_threshold, mask)
		return lerp(h_land, ocean_depth, factor)
	return h_land

func get_biome(coord: Vector2i, biome_count: int) -> int:
	if biome_count <= 0:
		return 0
	var cx := coord.x * TerrainConfig.CHUNK_SIZE + TerrainConfig.CHUNK_SIZE * 0.5
	var cz := coord.y * TerrainConfig.CHUNK_SIZE + TerrainConfig.CHUNK_SIZE * 0.5
	var n := _biome_noise01(cx, cz)
	return clampi(floori(n * biome_count), 0, biome_count - 1)
