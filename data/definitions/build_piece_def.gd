class_name BuildPieceDef
extends Resource

@export var display_name := "Piece"
@export var category := "Misc"
@export var icon: Texture2D
@export var scene: PackedScene

var _cost: Array[ItemStack] = []
var _cost_loaded := false

func get_cost() -> Array[ItemStack]:
	if _cost_loaded:
		return _cost
	_cost_loaded = true
	if scene == null:
		return _cost
	var inst := scene.instantiate()
	var piece := _find_piece(inst)
	if piece != null:
		for s in piece.materials:
			if s != null and s.item != null:
				_cost.append(s)
	inst.free()
	return _cost

func _find_piece(root: Node) -> BuildPiece:
	if root is BuildPiece:
		return root
	for child in root.get_children():
		var found := _find_piece(child)
		if found != null:
			return found
	return null
