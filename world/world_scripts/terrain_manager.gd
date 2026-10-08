class_name TerrainManager
extends Node3D

const CS := TerrainConfig.CHUNK_SIZE

@export var target: Node3D
@export var world_seed: int
@export var chunk_material: Material
@export var player_inventory: PlayerInventory
@export var biome_defs: Array[TerrainBiome] = []
@export var water_level := 0.0
@export var ocean_threshold := 0.62
@export var ocean_falloff := 0.08
@export var ocean_depth := -25.0
@export var ocean_color := Color(0.1, 0.35, 0.75)
@export var map_size := 512

@onready var player = $Player

var generator: TerrainGenerator
var save_dir: String
var chunks: Dictionary = {}				# Vector2i -> TerrainChunk
var load_queue: Array[Vector2i] = []
var rebuild_queue: Dictionary = {}		# Vector2i -> true
var large_load_queue: Array[Vector2i] = []
var small_load_queue: Array[Vector2i] = []
var last_center := Vector2i(1 << 30, 1 << 30)
var world_map: WorldMapWriter
var _map_dirty_count := 0

func _ready() -> void:
	add_to_group("terrain_manager")
	if world_seed != 0:
		generator = TerrainGenerator.new(world_seed)
	else:
		world_seed = randi()
		generator = TerrainGenerator.new(world_seed)
	print("World Seed: ", world_seed)
	generator.ocean_threshold = ocean_threshold
	generator.ocean_falloff = ocean_falloff
	generator.ocean_depth = ocean_depth
	var fallback_profile := TerrainHeightProfile.new()
	generator.profiles.clear()
	if biome_defs.is_empty():
		generator.profiles.append(fallback_profile)
	else:
		for b in biome_defs:
			generator.profiles.append(b.height_profile if b.height_profile != null else fallback_profile)
	world_map = WorldMapWriter.new(world_seed, map_size)
	save_dir = "user://worlds/%d/chunks" % world_seed
	DirAccess.make_dir_recursive_absolute(save_dir)
	player.terrain = self
	
	var player_data := PlayerSave.load_data(world_seed)
	if not player_data.is_empty() and player_data.has("position"):
		PlayerSave.apply(player_data, target, player_inventory)
		_ensure_chunk_loaded_at(target.global_position)
	else:
		set_player()
	
	''' DEBUG
	var dbg := StandardMaterial3D.new()
	dbg.albedo_color = Color(0.3, 0.7, 0.3)
	dbg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dbg.cull_mode = BaseMaterial3D.CULL_DISABLED
	chunk_material = dbg'''

func _process(_delta: float) -> void:
	if target == null:
		return
	var center := _world_to_chunk(target.global_position)
	if center != last_center:
		last_center = center
		_refresh_streaming(center)
	_process_load_queue()
	_process_rebuild_queue()
	_update_tier_queues(center)
	_process_tier_queues()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("terrain_manager.gd: Close request notification received...")
		save_all_dirty()
		save_player()
		if world_map != null:
			world_map.save_if_dirty()

func _world_to_chunk(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CS), floori(p.z / CS))

func _refresh_streaming(center: Vector2i) -> void:
	for coord in chunks.keys():
		var d := maxi(absi(coord.x - center.x), absi(coord.y - center.y))
		if d > TerrainConfig.UNLOAD_RADIUS:
			_unload_chunk(coord)

	load_queue.clear()
	var r := TerrainConfig.LOAD_RADIUS
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := center + Vector2i(dx, dz)
			if not chunks.has(c):
				load_queue.append(c)
	load_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))

func _process_load_queue() -> void:
	var budget := TerrainConfig.MAX_LOADS_PER_FRAME
	while budget > 0 and not load_queue.is_empty():
		var coord: Vector2i = load_queue.pop_front()
		if not chunks.has(coord):
			_load_chunk(coord)
			budget -= 1

func _process_rebuild_queue() -> void:
	var budget := TerrainConfig.MAX_REBUILDS_PER_FRAME
	for coord in rebuild_queue.keys():
		if budget <= 0:
			break
		rebuild_queue.erase(coord)
		var chunk: TerrainChunk = chunks.get(coord)
		if chunk != null:
			chunk.rebuild(sample_height)
			budget -= 1

func _update_tier_queues(center: Vector2i) -> void:
	for coord in chunks.keys():
		var chunk: TerrainChunk = chunks[coord]
		var d := maxi(absi(coord.x - center.x), absi(coord.y - center.y))

		if d <= TerrainConfig.DETAIL_LOAD_RADIUS and not chunk.large_tier_loaded:
			if not large_load_queue.has(coord):
				large_load_queue.append(coord)
		elif d > TerrainConfig.DETAIL_UNLOAD_RADIUS and chunk.large_tier_loaded:
			chunk.unload_large_tier()

		if d <= TerrainConfig.CLUTTER_LOAD_RADIUS and not chunk.small_tier_loaded:
			if not small_load_queue.has(coord):
				small_load_queue.append(coord)
		elif d > TerrainConfig.CLUTTER_UNLOAD_RADIUS and chunk.small_tier_loaded:
			chunk.unload_small_tier()

func _process_tier_queues() -> void:
	var large_budget := TerrainConfig.MAX_LARGE_LOADS_PER_FRAME
	while large_budget > 0 and not large_load_queue.is_empty():
		var coord: Vector2i = large_load_queue.pop_front()
		var chunk: TerrainChunk = chunks.get(coord)
		if chunk != null and not chunk.large_tier_loaded:
			@warning_ignore("unused_variable")
			var def: TerrainBiome = biome_defs[chunk.data.biome] if chunk.data.biome < biome_defs.size() else null
			chunk.load_large_tier()
			large_budget -= 1

	var small_budget := TerrainConfig.MAX_SMALL_LOADS_PER_FRAME
	while small_budget > 0 and not small_load_queue.is_empty():
		var coord: Vector2i = small_load_queue.pop_front()
		var chunk: TerrainChunk = chunks.get(coord)
		if chunk != null and not chunk.small_tier_loaded:
			@warning_ignore("unused_variable")
			var def: TerrainBiome = biome_defs[chunk.data.biome] if chunk.data.biome < biome_defs.size() else null
			chunk.load_small_tier()
			small_budget -= 1

func _load_chunk(coord: Vector2i) -> void:
	var data := TerrainChunkData.new(coord)
	data.generate_base(generator)

	var saved_deltas := TerrainStorage.load_deltas(save_dir, coord)
	if saved_deltas.size() == data.deltas.size():
		data.deltas = saved_deltas

	var chunk := TerrainChunk.new()
	chunk.manager = self
	chunk.setup(data, chunk_material)
	add_child(chunk)
	chunks[coord] = chunk
	rebuild_queue[coord] = true

	var loaded_manifest := TerrainStorage.load_manifest(save_dir, coord)
	if loaded_manifest != null:
		data.manifest = loaded_manifest
		data.biome = loaded_manifest.biome
	else:
		data.biome = generator.get_biome(coord, biome_defs.size())
		var manifest := ChunkManifest.new()
		manifest.biome = data.biome
		data.manifest = manifest
		
		if world_map != null:
			var cx := coord.x * CS + CS * 0.5
			var cz := coord.y * CS + CS * 0.5
			var color: Color
			if generator.is_ocean_at(cx, cz):
				color = ocean_color
			else:
				var b: TerrainBiome = biome_defs[data.biome] if data.biome < biome_defs.size() else null
				color = b.map_color if b != null else Color.WHITE
			world_map.set_chunk(coord, color)
			_map_dirty_count += 1
			if _map_dirty_count >= 16:
				world_map.save_if_dirty()
				_map_dirty_count = 0

		@warning_ignore("confusable_local_declaration")
		var def: TerrainBiome = biome_defs[data.biome] if data.biome < biome_defs.size() else null
		chunk.generate_manifest_entries(def, sample_height)   # may stamp deltas (structures)

		TerrainStorage.save_manifest(save_dir, coord, manifest)
		if data.dirty:
			TerrainStorage.save_deltas(save_dir, coord, data.deltas)
			data.dirty = false

	var def: TerrainBiome = biome_defs[data.biome] if data.biome < biome_defs.size() else null
	chunk.apply_ground_material(def)
	chunk.instantiate_structures()
	chunk.instantiate_built_pieces()

	if data.has_edits():
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var n := coord + Vector2i(dx, dz)
				if n != coord and chunks.has(n):
					rebuild_queue[n] = true

func request_save_manifest(coord: Vector2i) -> void:
	var chunk: TerrainChunk = chunks.get(coord)
	if chunk != null and chunk.data.manifest != null:
		TerrainStorage.save_manifest(save_dir, coord, chunk.data.manifest)

func _unload_chunk(coord: Vector2i) -> void:
	var chunk: TerrainChunk = chunks[coord]
	if chunk.data.dirty:
		if not TerrainStorage.save_deltas(save_dir, coord, chunk.data.deltas):
			return   # keep it loaded rather than lose edits
		chunk.data.dirty = false
	chunks.erase(coord)
	rebuild_queue.erase(coord)
	chunk.queue_free()

func save_all_dirty() -> void:
	for coord in chunks:
		var chunk: TerrainChunk = chunks[coord]
		if chunk.data.dirty:
			TerrainStorage.save_deltas(save_dir, coord, chunk.data.deltas)
			chunk.data.dirty = false

func sample_height(gx: int, gz: int) -> float:
	var c := Vector2i(floori(float(gx) / CS), floori(float(gz) / CS))
	var chunk: TerrainChunk = chunks.get(c)
	if chunk != null:
		return chunk.data.get_height(gx - c.x * CS, gz - c.y * CS)
	return generator.get_base_height(gx, gz)

func _chunks_containing(gx: int, gz: int, pad: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x0 := ceili(float(gx - pad - CS) / CS)
	var x1 := floori(float(gx + pad) / CS)
	var z0 := ceili(float(gz - pad - CS) / CS)
	var z1 := floori(float(gz + pad) / CS)
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			result.append(Vector2i(cx, cz))
	return result

func modify_height(gx: int, gz: int, amount: float) -> void:
	for c in _chunks_containing(gx, gz, 0):
		var chunk: TerrainChunk = chunks.get(c)
		if chunk != null:
			chunk.data.add_delta(gx - c.x * CS, gz - c.y * CS, amount)
	for c in _chunks_containing(gx, gz, 1):
		if chunks.has(c):
			rebuild_queue[c] = true

func apply_brush(world_pos: Vector3, radius: float, strength: float) -> void:
	var r := ceili(radius)
	var cx := roundi(world_pos.x)
	var cz := roundi(world_pos.z)
	for gz in range(cz - r, cz + r + 1):
		for gx in range(cx - r, cx + r + 1):
			var dist := Vector2(gx - world_pos.x, gz - world_pos.z).length()
			if dist > radius:
				continue
			var falloff := 1.0 - smoothstep(0.0, radius, dist)
			modify_height(gx, gz, strength * falloff)

func clear_delta() -> void:
	var coord := _world_to_chunk(player.global_position)
	var chunk: TerrainChunk = chunks.get(coord)
	if chunk == null:
		return

	# Zero the whole chunk
	chunk.data.deltas.fill(0.0)

	# Zero the shared border vertices in neighbors so the seams stay consistent
	var n := TerrainConfig.VERTS_PER_SIDE
	var gx0 := coord.x * CS
	var gz0 := coord.y * CS
	for i in n:
		for edge in [Vector2i(i, 0), Vector2i(i, n - 1), Vector2i(0, i), Vector2i(n - 1, i)]:
			var gx = gx0 + edge.x
			var gz = gz0 + edge.y
			for c in _chunks_containing(gx, gz, 0):
				var other: TerrainChunk = chunks.get(c)
				if other != null and c != coord:
					other.data.deltas[(gz - c.y * CS) * n + (gx - c.x * CS)] = 0.0
					other.data.dirty = true

	TerrainStorage.save_deltas(save_dir, coord, chunk.data.deltas)
	chunk.data.dirty = false

	# Rebuild this chunk and any loaded neighbors
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := coord + Vector2i(dx, dz)
			if chunks.has(c):
				rebuild_queue[c] = true

	set_player()

func reset_player() -> void:
	player.global_position = Vector3.ZERO
	set_player()

func set_player() -> void:
	var pos: Vector3 = player.global_position
	var coord := _world_to_chunk(pos)

	if not chunks.has(coord):
		_load_chunk(coord)
		chunks[coord].rebuild(sample_height)
		rebuild_queue.erase(coord)
	
	var h := sample_height(floori(pos.x), floori(pos.z))
	player.global_position.y = h + 5.0

func _on_reset_terrain_pressed() -> void:
	clear_delta()

func _on_quit_pressed() -> void:
	print("Quit pressed")
	notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()

func reset_world() -> void:
	for coord in chunks.keys():
		chunks[coord].queue_free()
	chunks.clear()
	load_queue.clear()
	rebuild_queue.clear()
	
	var dir := DirAccess.open(save_dir)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir():
				dir.remove(entry)
			entry = dir.get_next()
		dir.list_dir_end()
	else:
		push_warning("reset_world: could not open save_dir %s" % save_dir)
	
	last_center = Vector2i(1 << 30, 1 << 30)
	set_player()

func save_player() -> void:
	if player_inventory != null:
		PlayerSave.save(world_seed, target, player_inventory)

func _ensure_chunk_loaded_at(pos: Vector3) -> void:
	var coord := _world_to_chunk(pos)
	if not chunks.has(coord):
		_load_chunk(coord)
		chunks[coord].rebuild(sample_height)
		rebuild_queue.erase(coord)

func place_built_piece(scene: PackedScene, world_xform: Transform3D) -> Node3D:
	var chunk: TerrainChunk = chunks.get(_world_to_chunk(world_xform.origin))
	if chunk == null:
		return null
	return chunk.add_built_piece(scene, world_xform)
