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
var built_root := Node3D.new()
var large_destructibles_root := Node3D.new()
var small_destructibles_root := Node3D.new()
var large_tier_loaded := false
var small_tier_loaded := false
var manager: TerrainManager

func setup(p_data: TerrainChunkData, material: Material) -> void:
	data = p_data
	position = Vector3(data.coord.x * CS, 0, data.coord.y * CS)
	if material != null:
		mesh_instance.material_override = material
	if material == null:
		print("setup() got a null material for chunk ", p_data.coord)

func _ready() -> void:
	add_child(mesh_instance)
	add_child(body)
	add_child(ground_clutter_root)
	add_child(ground_veg_root)
	add_child(large_clutter_root)
	add_child(large_veg_root)
	add_child(structures_root)
	add_child(built_root)
	body.add_child(shape_node)
	height_shape.map_width = N
	height_shape.map_depth = N
	shape_node.shape = height_shape
	# HeightMapShape3D is centered on its origin, 1 unit between samples
	shape_node.position = Vector3(CS * 0.5, 0.0, CS * 0.5)

func apply_ground_material(biome: TerrainBiome) -> void:
	if biome != null and biome.chunk_mat != null:
		mesh_instance.material_override = biome.chunk_mat

func generate_manifest_entries(biome: TerrainBiome, sampler: Callable) -> void:
	if biome == null:
		return
	_generate_destructible_entries(biome.large_veg, biome.large_veg_density, biome, "large_veg", 1301, sampler)
	_generate_destructible_entries(biome.large_clutter, biome.large_clutter_density, biome, "large_clutter", 1747, sampler)
	_generate_layer_entries(biome.ground_veg, biome.ground_veg_density, biome, "ground_veg", 907, sampler)
	_generate_layer_entries(biome.ground_clutter, biome.ground_clutter_density, biome, "ground_clutter", 401, sampler)
	_generate_destructible_entries(biome.large_destructibles, biome.large_destructible_density, biome, "large_destructible", 2203, sampler)
	_generate_destructible_entries(biome.small_destructibles, biome.small_destructible_density, biome, "small_destructible", 2609, sampler)
	_generate_structure_entries(biome)

func _generate_layer_entries(clutter_list: Array[ClutterMesh], density: float, biome: TerrainBiome, cat: String, seed_salt: int, sampler: Callable) -> void:
	var valid: Array[ClutterMesh] = []
	for c in clutter_list:
		if c.mesh != null and c.mesh.resource_path != "":
			valid.append(c)
		else:
			push_warning("ClutterMesh in '%s' has no saved mesh resource — it can't be persisted, skipping" % cat)
	if valid.is_empty() or density <= 0.0:
		return

	var total_weight := 0.0
	for c in valid:
		total_weight += c.relative_density
	if total_weight <= 0.0:
		return

	var count := roundi(CS * CS * density)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(data.coord.x, data.coord.y, seed_salt))
	var gx0 := data.coord.x * CS
	var gz0 := data.coord.y * CS

	for i in count:
		var roll := rng.randf() * total_weight
		var chosen: ClutterMesh = valid[0]
		var acc := 0.0
		for c in valid:
			acc += c.relative_density
			if roll <= acc:
				chosen = c
				break

		var lx := rng.randf_range(0.0, CS)
		var lz := rng.randf_range(0.0, CS)

		if chosen.max_slope > 0.0:
			var normal := data.get_normal_interpolated(lx, lz, sampler, gx0, gz0)
			if normal.y < chosen.max_slope:
				continue

		var h := data.get_height_interpolated(lx, lz)
		if h < 0.0:
			continue
		var rot_x := deg_to_rad(rng.randf_range(-chosen.max_x_rot, chosen.max_x_rot))
		var rot_z := deg_to_rad(rng.randf_range(-chosen.max_z_rot, chosen.max_z_rot))
		var rot_y := rng.randf_range(0.0, TAU)
		var scl := rng.randf_range(biome.min_scale, biome.max_scale)

		data.manifest.instances.append({
			"cat": cat, "res": chosen.mesh.resource_path,
			"pos": [lx, h, lz], "rot": [rot_x, rot_y, rot_z], "scl": [scl, scl, scl],
		})

func _generate_destructible_entries(defs: Array[DestructibleClutterDef], density: float, biome: TerrainBiome, cat: String, seed_salt: int, sampler: Callable) -> void:
	var valid: Array[DestructibleClutterDef] = []
	for d in defs:
		if d.scene != null and d.scene.resource_path != "":
			valid.append(d)
		else:
			push_warning("DestructibleClutterDef in '%s' has no saved scene — it can't be persisted, skipping" % cat)
	if valid.is_empty() or density <= 0.0:
		return

	var total_weight := 0.0
	for d in valid:
		total_weight += d.relative_density
	if total_weight <= 0.0:
		return

	var count := roundi(CS * CS * density)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(data.coord.x, data.coord.y, seed_salt))
	var gx0 := data.coord.x * CS
	var gz0 := data.coord.y * CS

	for i in count:
		var roll := rng.randf() * total_weight
		var chosen: DestructibleClutterDef = valid[0]
		var acc := 0.0
		for d in valid:
			acc += d.relative_density
			if roll <= acc:
				chosen = d
				break

		var lx := rng.randf_range(0.0, CS)
		var lz := rng.randf_range(0.0, CS)

		if chosen.max_slope > 0.0:
			var normal := data.get_normal_interpolated(lx, lz, sampler, gx0, gz0)
			if normal.y < chosen.max_slope:
				continue

		var h := data.get_height_interpolated(lx, lz)
		if h < 0.0:
			continue
		var rot_x := deg_to_rad(rng.randf_range(-chosen.max_x_rot, chosen.max_x_rot))
		var rot_z := deg_to_rad(rng.randf_range(-chosen.max_z_rot, chosen.max_z_rot))
		var rot_y := rng.randf_range(0.0, TAU)
		var scl := rng.randf_range(biome.min_scale, biome.max_scale)

		data.manifest.instances.append({
			"cat": cat, "res": chosen.scene.resource_path,
			"pos": [lx, h, lz], "rot": [rot_x, rot_y, rot_z], "scl": [scl, scl, scl],
			"destroyed": false, "health": -1.0, "breakables": {},
		})

func _generate_structure_entries(biome: TerrainBiome) -> void:
	if biome.structures.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(data.coord.x, data.coord.y, 5503))

	for entry_def in biome.structures:
		if not StructureRegistry.has_key(entry_def.structure_key):
			push_warning("Biome structure key '%s' not found in StructureRegistry" % entry_def.structure_key)
			continue
		var count := rng.randi_range(entry_def.min_count, entry_def.max_count)
		for i in count:
			_generate_one_structure_entry(entry_def, rng)

func _generate_one_structure_entry(entry_def: StructureBiomeEntry, rng: RandomNumberGenerator) -> void:
	var scene := StructureRegistry.pick_random_scene(entry_def.structure_key, rng)
	if scene == null or scene.resource_path == "":
		return

	var probe := scene.instantiate()
	var terrain_form := TerrainFormSampler.find_terrain_form(probe)
	if terrain_form == null:
		push_warning("Structure '%s' has no TerrainForm shape, skipping" % scene.resource_path)
		probe.free()
		return

	structures_root.add_child(probe)   # must be in-tree for global_transform reads

	var reach := TerrainFormSampler.get_footprint_reach(terrain_form)
	if reach * 2.0 >= CS:
		push_warning("Structure '%s' footprint too large for chunk size, skipping" % scene.resource_path)
		structures_root.remove_child(probe)
		probe.queue_free()
		return

	var lx := rng.randf_range(reach, CS - reach)
	var lz := rng.randf_range(reach, CS - reach)
	var h := data.get_height_interpolated(lx, lz)
	if h < 0.0:
		structures_root.remove_child(probe)
		probe.queue_free()
		return
	var yaw := rng.randf_range(0.0, TAU)

	probe.position = Vector3(lx, h, lz)
	probe.rotation.y = yaw
	_stamp_footprint(terrain_form)   # real stamp, only happens this one time ever

	data.manifest.instances.append({
		"cat": "structure", "res": scene.resource_path, "key": entry_def.structure_key,
		"pos": [lx, h, lz], "rot": [0.0, yaw, 0.0], "scl": [1.0, 1.0, 1.0], "breakables": {},
	})

	structures_root.remove_child(probe)
	probe.queue_free()

func add_built_piece(scene: PackedScene, world_xform: Transform3D) -> Node3D:
	if scene.resource_path == "":
		push_warning("Built piece scene has no saved path, can't persist it")
		return null
	var local := global_transform.affine_inverse() * world_xform
	var q := local.basis.get_rotation_quaternion()
	var entry := {
		"uid": _next_built_uid(),
		"res": scene.resource_path,
		"pos": [local.origin.x, local.origin.y, local.origin.z],
		"rot": [q.x, q.y, q.z, q.w],
		"breakables": {},
	}
	data.manifest.built.append(entry)
	var inst := _spawn_built_piece(entry)
	if manager != null:
		manager.request_save_manifest(data.coord)
	return inst

func _spawn_built_piece(entry: Dictionary) -> Node3D:
	var res_path: String = entry.get("res", "")
	if res_path == "" or not ResourceLoader.exists(res_path):
		push_warning("Built piece references missing scene: %s" % res_path)
		return null
	var scene := load(res_path)
	if not (scene is PackedScene):
		return null
	var inst: Node3D = scene.instantiate()
	built_root.add_child(inst)
	var p: Array = entry["pos"]
	var r: Array = entry["rot"]
	var q := Quaternion(r[0], r[1], r[2], r[3]).normalized()
	inst.transform = Transform3D(Basis(q), Vector3(p[0], p[1], p[2]))
	_wire_built_piece(inst, int(entry["uid"]))
	return inst

func _next_built_uid() -> int:
	var m := 0
	for e in data.manifest.built:
		m = maxi(m, int(e.get("uid", 0)))
	return m + 1

func _find_built_index(uid: int) -> int:
	for i in data.manifest.built.size():
		if int(data.manifest.built[i].get("uid", -1)) == uid:
			return i
	return -1

func _wire_built_piece(inst: Node, uid: int) -> void:
	var idx := _find_built_index(uid)
	if idx < 0:
		return
	var sub: Dictionary = data.manifest.built[idx].get("breakables", {})
	for b in _find_breakables(inst):
		var rel_path := String(inst.get_path_to(b))
		if sub.has(rel_path):
			b.health = sub[rel_path].get("health", b.health)
		b.state_changed.connect(_on_built_breakable_changed.bind(uid, rel_path))

func _on_built_breakable_changed(b: Breakable, uid: int, rel_path: String) -> void:
	var idx := _find_built_index(uid)
	if idx < 0:
		return
	if b.destroyed:
		data.manifest.built.remove_at(idx)   # player-made, so no tombstone needed
	else:
		var entry: Dictionary = data.manifest.built[idx]
		var sub: Dictionary = entry.get("breakables", {})
		sub[rel_path] = {"health": b.health}
		entry["breakables"] = sub
	if manager != null:
		manager.request_save_manifest(data.coord)

# ---------- instancing (no RNG) ----------

func instantiate_structures() -> void:
	_instantiate_category("structure", structures_root)

func instantiate_built_pieces() -> void:
	if data.manifest == null:
		return
	for entry in data.manifest.built:
		_spawn_built_piece(entry)

func load_large_tier() -> void:
	if large_tier_loaded or data.manifest == null:
		return
	large_tier_loaded = true
	_instantiate_category("large_veg", large_veg_root)
	_instantiate_category("large_clutter", large_clutter_root)
	_instantiate_category("large_destructible", large_destructibles_root)

func unload_large_tier() -> void:
	if not large_tier_loaded:
		return
	large_tier_loaded = false
	for c in large_veg_root.get_children():
		c.queue_free()
	for c in large_clutter_root.get_children():
		c.queue_free()
	for c in large_destructibles_root.get_children():
		c.queue_free()

func load_small_tier() -> void:
	if small_tier_loaded or data.manifest == null:
		return
	small_tier_loaded = true
	_instantiate_category("ground_veg", ground_veg_root)
	_instantiate_category("ground_clutter", ground_clutter_root)
	_instantiate_category("small_destructible", small_destructibles_root)

func unload_small_tier() -> void:
	if not small_tier_loaded:
		return
	small_tier_loaded = false
	for c in ground_veg_root.get_children():
		c.queue_free()
	for c in ground_clutter_root.get_children():
		c.queue_free()
	for c in small_destructibles_root.get_children():
		c.queue_free()

func _instantiate_category(cat: String, root: Node3D) -> void:
	if cat in ["ground_veg", "ground_clutter"]:
		_build_multimesh_category(cat, root)
	else:
		_build_node_category(cat, root)

func _build_multimesh_category(cat: String, root: Node3D) -> void:
	var buckets: Dictionary = {}
	for entry in data.manifest.instances:
		if entry.get("cat") != cat:
			continue
		var res_path: String = entry.get("res", "")
		if res_path == "" or not ResourceLoader.exists(res_path):
			continue
		if not buckets.has(res_path):
			buckets[res_path] = []
		buckets[res_path].append(_entry_transform(entry))

	for res_path in buckets.keys():
		var mesh := load(res_path)
		if not (mesh is Mesh):
			continue
		var transforms: Array = buckets[res_path]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)

func _build_node_category(cat: String, root: Node3D) -> void:
	for i in data.manifest.instances.size():
		var entry: Dictionary = data.manifest.instances[i]
		if entry.get("cat") != cat:
			continue
		if cat != "structure" and entry.get("destroyed", false):
			continue   # fully gone — nothing to instance

		var res_path: String = entry.get("res", "")
		if res_path == "" or not ResourceLoader.exists(res_path):
			push_warning("Manifest entry references missing resource: %s" % res_path)
			continue
		var scene := load(res_path)
		if not (scene is PackedScene):
			continue

		var inst: Node3D = scene.instantiate()
		root.add_child(inst)
		var pos: Array = entry.get("pos", [0.0, 0.0, 0.0])
		var rot: Array = entry.get("rot", [0.0, 0.0, 0.0])
		inst.position = Vector3(pos[0], pos[1], pos[2])
		inst.rotation = Vector3(rot[0], rot[1], rot[2])
		_wire_persistence(inst, i)

func _entry_transform(entry: Dictionary) -> Transform3D:
	var pos: Array = entry.get("pos", [0.0, 0.0, 0.0])
	var rot: Array = entry.get("rot", [0.0, 0.0, 0.0])
	var scl: Array = entry.get("scl", [1.0, 1.0, 1.0])
	var t := Transform3D()
	t = t.rotated(Vector3(1, 0, 0), rot[0])
	t = t.rotated(Vector3(0, 0, 1), rot[2])
	t = t.rotated(Vector3(0, 1, 0), rot[1])
	t = t.scaled(Vector3(scl[0], scl[1], scl[2]))
	t.origin = Vector3(pos[0], pos[1], pos[2])
	return t

# ---------- persistence wiring ----------

func _find_breakables(root: Node) -> Array[Breakable]:
	var out: Array[Breakable] = []
	for child in root.get_children():
		if child is Breakable:
			out.append(child)
		out.append_array(_find_breakables(child))
	return out

func _wire_persistence(inst: Node, entry_index: int) -> void:
	var entry: Dictionary = data.manifest.instances[entry_index]
	var is_structure: bool = entry.get("cat", "") == "structure"
	var breakables := _find_breakables(inst)

	for b in breakables:
		var rel_path := String(inst.get_path_to(b))
		if is_structure:
			var sub_states: Dictionary = entry.get("breakables", {})
			if sub_states.has(rel_path):
				var s: Dictionary = sub_states[rel_path]
				if s.get("destroyed", false):
					var piece := b.get_piece()
					if piece != null:
						piece.queue_free()
					else:
						b.queue_free()
					continue
				if s.get("health", -1.0) >= 0.0:
					b.health = s["health"]
			b.state_changed.connect(_on_structure_breakable_changed.bind(entry_index, rel_path))
		else:
			if entry.get("health", -1.0) >= 0.0:
				b.health = entry["health"]
			b.state_changed.connect(_on_destructible_changed.bind(entry_index))

func _on_destructible_changed(b: Breakable, entry_index: int) -> void:
	var entry: Dictionary = data.manifest.instances[entry_index]
	entry["destroyed"] = b.destroyed
	entry["health"] = b.health
	if manager != null:
		manager.request_save_manifest(data.coord)

func _on_structure_breakable_changed(b: Breakable, entry_index: int, rel_path: String) -> void:
	var entry: Dictionary = data.manifest.instances[entry_index]
	var sub: Dictionary = entry.get("breakables", {})
	sub[rel_path] = {"destroyed": b.destroyed, "health": b.health}
	entry["breakables"] = sub
	if manager != null:
		manager.request_save_manifest(data.coord)

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
