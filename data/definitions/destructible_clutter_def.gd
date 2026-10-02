class_name DestructibleClutterDef
extends Resource

## Scene must contain a mesh, collision, and a Breakable node.
@export var scene: PackedScene
@export var relative_density: float = 1.0
@export var max_x_rot: float = 0.0
@export var max_z_rot: float = 0.0
@export_range(0.0, 1.0) var max_slope: float = 0.0
