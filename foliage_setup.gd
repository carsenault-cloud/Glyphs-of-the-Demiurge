extends Node3D

@export var multimesh_instance: MultiMeshInstance3D
@export var terrain: TerrainManager
@export var density := 0.15          # instances per square meter
@export var min_scale := 0.8
@export var max_scale := 1.3
@export var scatter_seed := 1

func scatter_chunk(coord: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(coord.x, coord.y, scatter_seed))

	var count := roundi(TerrainConfig.CHUNK_SIZE * TerrainConfig.CHUNK_SIZE * density)
	var mm := multimesh_instance.multimesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count

	var gx0 := coord.x * TerrainConfig.CHUNK_SIZE
	var gz0 := coord.y * TerrainConfig.CHUNK_SIZE

	for i in count:
		var lx := rng.randf_range(0.0, TerrainConfig.CHUNK_SIZE)
		var lz := rng.randf_range(0.0, TerrainConfig.CHUNK_SIZE)
		var gx := gx0 + lx
		var gz := gz0 + lz
		var h := terrain.sample_height(floori(gx), floori(gz))

		var t := Transform3D()
		t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		t = t.scaled(Vector3.ONE * rng.randf_range(min_scale, max_scale))
		t.origin = Vector3(gx, h, gz)
		mm.set_instance_transform_3d(i, t)
