class_name WorldMapWriter
extends RefCounted

var image: Image
var path: String
var map_size: int
var dirty := false

func _init(world_seed: int, p_map_size: int) -> void:
	map_size = p_map_size
	path = "user://worlds/%d/map.png" % world_seed
	if FileAccess.file_exists(path):
		image = Image.load_from_file(path)
	if image == null or image.get_width() != map_size:
		image = Image.create(map_size, map_size, false, Image.FORMAT_RGB8)

func set_chunk(coord:Vector2i, color: Color) -> void:
	var px := coord.x + map_size / 2
	var pz := coord.y + map_size / 2
	if px < 0 or px >= map_size or pz < 0 or pz >= map_size:
		return
	image.set_pixel(px, pz, color)
	dirty = true

func save_if_dirty() -> void:
	if dirty:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		image.save_png(path)
		dirty = false
