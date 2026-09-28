class_name TerrainManager
extends Node3D

const CS := TerrainConfig.CHUNK_SIZE

@export var target: Node3D
@export var world_seed := 12345
@export var chunk_material: Material

@onready var player = $Player

var generator: TerrainGenerator
var save_dir: String
var chunks: Dictionary = {}				# Vector2i -> TerrainChunk
var load_queue: Array[Vector2i] = []
var rebuild_queue: Dictionary = {}		# Vector2i -> true
var last_center := Vector2i(1 << 30, 1 << 30)

func _ready() -> void:
	generator = TerrainGenerator.new(world_seed)
	save_dir = "user://worlds/%d/chunks" % world_seed
	DirAccess.make_dir_recursive_absolute(save_dir)
	player.terrain = self
	
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("terrain_manager.gd: Close request notification received...")
		save_all_dirty()

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

func _load_chunk(coord: Vector2i) -> void:
	var data := TerrainChunkData.new(coord)
	data.generate_base(generator)
	var saved := TerrainStorage.load_deltas(save_dir, coord)
	if saved.size() == data.deltas.size():
		data.deltas = saved

	var chunk := TerrainChunk.new()
	chunk.setup(data, chunk_material)
	add_child(chunk)
	chunks[coord] = chunk
	rebuild_queue[coord] = true

	# Saved edits on our border change neighbors' edge normals
	if data.has_edits():
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var n := coord + Vector2i(dx, dz)
				if n != coord and chunks.has(n):
					rebuild_queue[n] = true

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
	notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()
