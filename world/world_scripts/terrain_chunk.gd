class_name TerrainChunk
extends Node3D

const CS := TerrainConfig.CHUNK_SIZE
const N := TerrainConfig.VERTS_PER_SIDE

const STRUCTURE_EDGE_BLEND := 1.5 # Smoothing past the edge of the structure

static var _indices := PackedInt32Array()

var data: TerrainChunkData
var mesh_instance := MeshInstance3D.new()
var body := StaticBody3D.new()
var shape_node := CollisionShape3D.new()
var height_shape := HeightMapShape3D.new()
var ground_clutter_root := MultiMeshInstance3D.new()
var ground_veg_root := MultiMeshInstance3D.new()
var large_veg_root := MultiMeshInstance3D.new()
var large_clutter_root := MultiMeshInstance3D.new()
var structures_root := Node3D.new()

func setup(p_data: TerrainChunkData, material: Material) -> void:
	data = p_data
	position = Vector3(data.coord.x * CS, 0, data.coord.y * CS)
	mesh_instance.material_override = material

func _ready() -> void:
	add_child(mesh_instance)
	add_child(body)
	add_child(ground_clutter_root)
	add_child(ground_veg_root)
	add_child(large_clutter_root)
	add_child(large_veg_root)
	add_child(structures_root)
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

func apply_biome(biome: TerrainBiome, sampler: Callable) -> void:
	if biome == null:
		return
	if biome.chunk_mat != null:
		mesh_instance.material_override = biome.chunk_mat

	_scatter_layer(ground_clutter_root, biome.ground_clutter, biome.ground_clutter_density, biome, 401, sampler)
	_scatter_layer(ground_veg_root, biome.ground_veg, biome.ground_veg_density, biome, 907, sampler)
	_scatter_layer(large_veg_root, biome.large_veg, biome.large_veg_density, biome, 1301, sampler)
	_scatter_layer(large_clutter_root, biome.large_clutter, biome.large_clutter_density, biome, 1747, sampler)

func _scatter_layer(root: Node3D, clutter_list: Array[ClutterMesh], layer_density: float, biome: TerrainBiome, seed_salt: int, sampler: Callable) -> void:
	var gx0 := data.coord.x * CS
	var gz0 := data.coord.y * CS
	
	for child in root.get_children():
		child.queue_free()

	if clutter_list.is_empty():
		return

	var total_weight := 0.0
	for c in clutter_list:
		total_weight += c.relative_density
	if total_weight <= 0.0:
		return

	var count := roundi(CS * CS * layer_density)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(data.coord.x, data.coord.y, seed_salt))

	# One transform list per distinct ClutterMesh entry, since a single
	# MultiMesh can only render one mesh — entries sharing a mesh still
	# get separate buckets here, kept simple at the cost of a few extra
	# MultiMeshInstance3D nodes per chunk when a category reuses a mesh.
	var buckets: Dictionary = {}   # ClutterMesh -> Array[Transform3D]

	for i in count:
		var roll := rng.randf() * total_weight
		var chosen: ClutterMesh = clutter_list[0]
		var acc := 0.0
		for c in clutter_list:
			acc += c.relative_density
			if roll <= acc:
				chosen = c
				break
		if chosen.mesh == null:
			continue

		var lx := rng.randf_range(0.0, CS)
		var lz := rng.randf_range(0.0, CS)
		
		if chosen.max_slope > 0.0:
			var normal := data.get_normal_interpolated(lx, lz, sampler, gx0, gz0)
			if normal.y < chosen.max_slope:
				continue
		var h := data.get_height_interpolated(lx, lz)

		var t := Transform3D()
		t = t.rotated(Vector3(1, 0, 0), deg_to_rad(rng.randf_range(-chosen.max_x_rot, chosen.max_x_rot)))
		t = t.rotated(Vector3(0, 0, 1), deg_to_rad(rng.randf_range(-chosen.max_z_rot, chosen.max_z_rot)))
		t = t.rotated(Vector3(0, 1, 0), rng.randf_range(0.0, TAU))
		t = t.scaled(Vector3.ONE * rng.randf_range(biome.min_scale, biome.max_scale))
		t.origin = Vector3(lx, h, lz)

		if not buckets.has(chosen):
			buckets[chosen] = []
		buckets[chosen].append(t)

	for chosen: ClutterMesh in buckets:
		var transforms: Array = buckets[chosen]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = chosen.mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)

# apply_terrain_stamp should be true only on a chunk's first-ever generation;
# see terrain_manager.gd's _load_chunk for how that's decided.
func scatter_structures(biome: TerrainBiome, apply_terrain_stamp: bool) -> void:
	for child in structures_root.get_children():
		child.queue_free()

	if biome == null or biome.structures.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(data.coord.x, data.coord.y, 5503))

	for entry in biome.structures:
		if not StructureRegistry.has_key(entry.structure_key):
			push_warning("Biome structure key '%s' not found in StructureRegistry" % entry.structure_key)
			continue
		var count := rng.randi_range(entry.min_count, entry.max_count)
		for i in count:
			_place_one_structure(entry, rng, apply_terrain_stamp)

func _place_one_structure(entry: StructureBiomeEntry, rng: RandomNumberGenerator, apply_terrain_stamp: bool) -> void:
	var scene := StructureRegistry.pick_random_scene(entry.structure_key, rng)
	if scene == null:
		return

	var inst := scene.instantiate()
	var terrain_form := TerrainFormSampler.find_terrain_form(inst)
	if terrain_form == null:
		push_warning("Structure '%s' has no TerrainForm shape, skipping" % scene.resource_path)
		inst.free()
		return

	# Must be inside the tree before any global_transform read — including
	# the reach check below, which only needs scale, not final position.
	structures_root.add_child(inst)

	var reach := TerrainFormSampler.get_footprint_reach(terrain_form)
	if reach * 2.0 >= CS:
		push_warning("Structure '%s' footprint too large for chunk size, skipping" % scene.resource_path)
		structures_root.remove_child(inst)
		inst.queue_free()
		return

	var lx := rng.randf_range(reach, CS - reach)
	var lz := rng.randf_range(reach, CS - reach)

	inst.position = Vector3(lx, data.get_height_interpolated(lx, lz), lz)
	inst.rotation.y = rng.randf_range(0.0, TAU)

	if apply_terrain_stamp:
		_stamp_footprint(terrain_form)

func _stamp_footprint(terrain_form: CollisionShape3D) -> void:
	var reach := TerrainFormSampler.get_footprint_reach(terrain_form) + STRUCTURE_EDGE_BLEND
	var target_h := TerrainFormSampler.get_target_height(terrain_form)
	var inv_transform := terrain_form.global_transform.affine_inverse()
	var shape_local_center := terrain_form.global_transform.origin - global_position

	var x_min := maxi(0, floori(shape_local_center.x - reach))
	var x_max := mini(N - 1, ceili(shape_local_center.x + reach))
	var z_min := maxi(0, floori(shape_local_center.z - reach))
	var z_max := mini(N - 1, ceili(shape_local_center.z + reach))

	for z in range(z_min, z_max + 1):
		for x in range(x_min, x_max + 1):
			var world_point := global_position + Vector3(x, 0, z)
			var local_point: Vector3 = inv_transform * world_point
			var dist := TerrainFormSampler.distance_outside(local_point, terrain_form.shape)
			if dist > STRUCTURE_EDGE_BLEND:
				continue
			var factor := 1.0 - smoothstep(0.0, STRUCTURE_EDGE_BLEND, dist)
			data.set_target_height(x, z, target_h, factor)
