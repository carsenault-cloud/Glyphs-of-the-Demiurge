class_name ClutterMesh
extends Resource

@export var mesh: Mesh
@export var relative_density: float = 1.0
## Degrees
@export var max_x_rot: float = 0.0
@export var max_z_rot: float = 0.0

## 1.0 is flat ground, 0.0 is any slope including vertical
@export_range(0.0, 1.0) var max_slope: float = 0.0
