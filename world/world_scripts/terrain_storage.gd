class_name TerrainStorage
extends RefCounted

const MAGIC := 0x54455252	# "TERR"
const VERSION := 1

static func chunk_path(dir: String, coord: Vector2i) -> String:
	return "%s/chunk_%d_%d.dat" % [dir, coord.x, coord.y]

static func save_deltas(dir: String, coord: Vector2i, deltas: PackedFloat32Array) -> bool:
	print("terrain_storage.gd: Saving deltas...")
	var f := FileAccess.open(chunk_path(dir, coord), FileAccess.WRITE)
	if f == null:
		push_error("Failed to save chunk %s: %s" % [coord, error_string(FileAccess.get_open_error())])
		return false
	f.store_32(MAGIC)
	f.store_16(VERSION)
	f.store_32(deltas.size())
	f.store_buffer(deltas.to_byte_array())
	return true

static func load_deltas(dir: String, coord: Vector2i) -> PackedFloat32Array:
	var path := chunk_path(dir, coord)
	if not FileAccess.file_exists(path):
		return PackedFloat32Array()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_32() != MAGIC:
		return PackedFloat32Array()
	var _version := f.get_16()
	var count := f.get_32()
	return f.get_buffer(count * 4).to_float32_array()
