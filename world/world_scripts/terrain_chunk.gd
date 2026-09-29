class_name TerrainChunk
extends Node3D

const CS := TerrainConfig.CHUNK_SIZE
const N := TerrainConfig.VERTS_PER_SIDE

static var _indices := PackedInt32Array()

var data: TerrainChunkData
var mesh_instance := MeshInstance3D.new()
var body := StaticBody3D.new()
var shape_node := CollisionShape3D.new()
var height_shape := HeightMapShape3D.new()
var vegetation := MultiMeshInstance3D.new()

func setup(p_data: TerrainChunkData, material: Material) -> void:
	data = p_data
	position = Vector3(data.coord.x * CS, 0, data.coord.y * CS)
	mesh_instance.material_override = material

func _ready() -> void:
	add_child(mesh_instance)
	add_child(body)
	add_child(vegetation)
	body.add_child(shape_node)
	height_shape.map_width = N
	height_shape.map_depth = N
	shape_node.shape = height_shape
	# HeightMapShape3D is centered on its origin, 1 unit between samples
	shape_node.position = Vector3(CS * 0.5, 0.0, CS * 0.5)

static func _get_indices() -> PackedInt32Array:
	if _indices.is_empty():
		for z in CS:
			for x in CS:
				var a := z * N + x
				var b := a + 1
				var c := a + N
				var d := c + 1
				_indices.append_array([a, b, c, b, d, c])
	return _indices

# sampler(gx: int, gz: int) -> float, using global vertex coordinates
func rebuild(sampler: Callable) -> void:
	var gx0 := data.coord.x * CS
	var gz0 := data.coord.y * CS
	var P := N + 2
	var padded := PackedFloat32Array()
	padded.resize(P * P)
	for z in P:
		for x in P:
			padded[z * P + x] = sampler.call(gx0 + x - 1, gz0 + z - 1)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var heights := PackedFloat32Array()
	verts.resize(N * N)
	normals.resize(N * N)
	uvs.resize(N * N)
	heights.resize(N * N)

	for z in N:
		for x in N:
			var pi := (z + 1) * P + (x + 1)
			var h := padded[pi]
			var i := z * N + x
			heights[i] = h
			verts[i] = Vector3(x, h, z)
			normals[i] = Vector3(padded[pi - 1] - padded[pi + 1], 2.0, padded[pi - P] - padded[pi + P]).normalized()
			uvs[i] = Vector2(gx0 + x, gz0 + z)   # world-space UVs, 1 tile per meter

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _get_indices()

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	height_shape.map_data = heights

func scatter_vegetation(def: TerrainBiome) -> void:
	if def == null or def.mesh == null or def.density <= 0.0:
		vegetation.multimesh = null
		return
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = def.mesh
	mm.instance_count = roundi(CS * CS * def.density)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(data.coord.x, data.coord.y, 7919))
	
	for i in mm.instance_count:
		var lx := rng.randf_range(0.0, CS)
		var lz := rng.randf_range(0.0, CS)
		var h = data.get_height_interpolated(lx, lz)
		
		var t := Transform3D()
		t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		t = t.scaled(Vector3.ONE * rng.randf_range(def.min_scale, def.max_scale))
		t.origin = Vector3(lx, h, lz)
		mm.set_instance_transform(i, t)
	
	vegetation.multimesh = mm
