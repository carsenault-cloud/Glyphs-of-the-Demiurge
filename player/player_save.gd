class_name PlayerSave
extends RefCounted

static func save_path(world_seed: int) -> String:
	return "user://worlds/%d/player.json" % world_seed

static func save(world_seed: int, player: Node3D, inventory: PlayerInventory) -> bool:
	var data := {
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"rotation_y": player.rotation.y,
		"inventory": inventory.to_save_data(),
	}
	var f := FileAccess.open(save_path(world_seed), FileAccess.WRITE)
	if f == null:
		push_error("PlayerSave: failed to save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data))
	return true

static func load_data(world_seed: int) -> Dictionary:
	var path := save_path(world_seed)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

static func apply(data: Dictionary, player: Node3D, inventory: PlayerInventory) -> void:
	if data.has("position"):
		var p: Array = data["position"]
		player.global_position = Vector3(p[0], p[1], p[2])
	if data.has("rotation_y"):
		player.rotation.y = data["rotation_y"]
	if data.has("inventory"):
		inventory.load_save_data(data["inventory"])
