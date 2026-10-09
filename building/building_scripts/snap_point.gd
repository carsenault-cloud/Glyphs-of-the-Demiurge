@tool
class_name SnapPoint
extends Marker3D

# Once this list is settled, I'll switch it to an enum, but for now keep it small until
# things work
@export var snap_type := "generic"
@export_enum("horizontal", "vertical") var snap_group: String = "horizontal"

@export var snap_radius := 0.5

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)

func _get_configuration_warnings() -> PackedStringArray:
	if snap_type == "":
		return ["SnapPoint has no snap_type set."]
	return []

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_build_gizmo_mesh()

func _build_gizmo_mesh() -> void:
	var gizmo_root := Node3D.new()
	gizmo_root.name = "_EditorGizmo"
	add_child(gizmo_root)

	# Flat disc = the connection face. Its flat side sits in the plane
	# where this piece touches the one it snaps to.
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.15
	disc_mesh.bottom_radius = 0.15
	disc_mesh.height = 0.02
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.3, 0.6, 1.0, 0.6)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc_mesh.material = disc_mat
	disc.mesh = disc_mesh
	disc.rotation_degrees.x = -90   # lays the disc's flat face perpendicular to local -Z
	gizmo_root.add_child(disc)

	# Small center sphere, just to mark the exact point.
	var dot := MeshInstance3D.new()
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.04
	dot_mesh.height = 0.08
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = Color(0.2, 1.0, 0.4)
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mesh.material = dot_mat
	dot.mesh = dot_mesh
	gizmo_root.add_child(dot)

	# Arrow pointing along local -Z = "out" = the direction another piece's
	# matching point should approach from.
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.015
	shaft_mesh.bottom_radius = 0.015
	shaft_mesh.height = 0.3
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(1.0, 0.3, 0.2)
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_mesh.material = arrow_mat
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0, 0, -0.17)
	shaft.rotation_degrees.x = -90
	gizmo_root.add_child(shaft)

	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.05
	head_mesh.height = 0.12
	head_mesh.material = arrow_mat
	head.mesh = head_mesh
	head.position = Vector3(0, 0, -0.36)
	head.rotation_degrees.x = -90
	gizmo_root.add_child(head)
