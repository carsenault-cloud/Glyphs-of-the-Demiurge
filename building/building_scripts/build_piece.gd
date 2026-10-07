class_name BuildPiece
extends Node3D

@export var piece_id := ""
@export var materials: Array[ItemStack] = []
@export var piece_name := "Build Piece"

var is_ghost := false

var _snap_points: Array[SnapPoint] = []

func _ready() -> void:
	_snap_points = _find_snap_points(self)
	if not is_ghost:
		add_to_group("build_pieces")

func _find_snap_points(root: Node) -> Array[SnapPoint]:
	var out: Array[SnapPoint] = []
	for child in root.get_children():
		if child is SnapPoint:
			out.append(child)
		else:
			out.append_array(_find_snap_points(child))
	return out

func get_snap_points() -> Array[SnapPoint]:
	return _snap_points
