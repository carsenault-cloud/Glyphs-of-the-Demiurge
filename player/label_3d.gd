extends Label3D

@onready var player := self.get_parent_node_3d()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text = str("Y: ", int(player.global_position.y), "\nX: ", int(player.global_position.x), "\nZ: ", int(player.global_position.z))
