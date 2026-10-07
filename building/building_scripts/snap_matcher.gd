class_name SnapMatcher
extends RefCounted

static func find_best_match(candidate: SnapPoint, from_node: Node) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF

	for piece in from_node.get_tree().get_nodes_in_group("build_pieces"):
		if not (piece is BuildPiece):
			continue
		for point in piece.get_snap_points():
			if point.snap_type != candidate.snap_type:
				continue
			var dist = point.global_position.distance_to(candidate.global_position)
			if dist <= point.snap_radius and dist < best_dist:
				best_dist = dist
				best = {"point": point, "piece": piece}

	return best

static func _find_pieces(root: Node) -> Array[BuildPiece]:
	var out: Array[BuildPiece] = []
	for child in root.get_children():
		if child is BuildPiece:
			out.append(child)
		out.append_array(_find_pieces(child))
	return out
