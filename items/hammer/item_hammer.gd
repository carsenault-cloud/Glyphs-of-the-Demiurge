class_name ItemHammer
extends UsableItem

@export var pieces: Array[BuildPieceDef] = []

func use(_user: Node) -> void:
	var controller: BuildModeController = _user.get_tree().get_first_node_in_group("build_mode_controller")
	if controller != null:
		controller.toggle()
