class_name BuildPieceButton
extends Button

signal chosen(def: BuildPieceDef)
signal hovered(def: BuildPieceDef)

var def: BuildPieceDef

func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(def))
	mouse_entered.connect(func() -> void: hovered.emit(def))
	focus_entered.connect(func() -> void: hovered.emit(def))

func setup(p_def: BuildPieceDef, affordable: bool) -> void:
	def = p_def
	icon = def.icon
	text = "" if def.icon != null else def.display_name
	modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.45)
