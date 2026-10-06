class_name TerrainHeightProfile
extends Resource

@export var profile_name := "Forest"
@export var height_scale := 40.0
@export var frequency := 0.005
@export var octaves := 4

## Optional
@export var height_curve: Curve

@export var vertical_offset := 0.0

var _noise: FastNoiseLite

func get_height(wx: float, wz: float, world_seed: int, salt: int) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = world_seed + salt
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = frequency
		_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_noise.fractal_octaves = octaves
	
	var raw := _noise.get_noise_2d(wx, wz) * 0.5 + 0.5
	var shaped := height_curve.sample(raw) if height_curve != null else raw
	return (shaped * 2.0 - 1.0) * height_scale + vertical_offset
