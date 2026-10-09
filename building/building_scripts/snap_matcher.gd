class_name SnapMatcher
extends RefCounted

## Every placed socket, optionally limited to one snap_group ("" = all groups).
static func _all_points(tree: SceneTree, group := "") -> Array[SnapPoint]:
	var out: Array[SnapPoint] = []
	for piece in tree.get_nodes_in_group("build_pieces"):
		if piece is BuildPiece:
			for point in piece.get_snap_points():
				if group == "" or point.snap_group == group:
					out.append(point)
	return out

## Distinct snap_group names across all placed pieces, alphabetical.
static func get_groups(tree: SceneTree) -> Array[String]:
	var out: Array[String] = []
	for point in _all_points(tree):
		if not out.has(point.snap_group):
			out.append(point.snap_group)
	out.sort()
	return out

## Closest compatible placed socket to `candidate`.
## Returns {"point": SnapPoint, "dist": float} or {}.
static func find_best_match(candidate: SnapPoint, from_node: Node, radius_scale := 1.0, target_group := "") -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for point in _all_points(from_node.get_tree(), target_group):
		if point.snap_type != candidate.snap_type:
			continue
		var dist := point.global_position.distance_to(candidate.global_position)
		if dist <= point.snap_radius * radius_scale and dist < best_dist:
			best_dist = dist
			best = {"point": point, "dist": dist}
	return best

## Distance from a world position to the aim ray, or INF if it's behind
## the camera or farther along the ray than max_len.
static func aim_distance(pos: Vector3, ray_origin: Vector3, ray_dir: Vector3, max_len: float) -> float:
	var along := (pos - ray_origin).dot(ray_dir)
	if along < 0.0 or along > max_len:
		return INF
	return (ray_origin + ray_dir * along).distance_to(pos)

## Compatible placed sockets near the aim ray, closest to the ray first.
## Each entry: {"point": SnapPoint, "ray_dist": float}
static func find_aimed(from_node: Node, ray_origin: Vector3, ray_dir: Vector3, max_len: float, radius_scale: float, snap_types: Array, target_group := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for point in _all_points(from_node.get_tree(), target_group):
		if not snap_types.has(point.snap_type):
			continue
		var d := aim_distance(point.global_position, ray_origin, ray_dir, max_len)
		if d <= point.snap_radius * radius_scale:
			out.append({"point": point, "ray_dist": d})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ray_dist < b.ray_dist)
	return out
