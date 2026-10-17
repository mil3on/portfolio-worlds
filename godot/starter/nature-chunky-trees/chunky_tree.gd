@tool
extends Node3D
## Chunky stylised tree generated in code: "round" = trunk + merged lumpy sphere crown,
## "pine" = trunk + four stacked cones. Foliage uses chunky_foliage.gdshader (warm top to cool
## underside ramp, vertex-noise lumps, sway, optional frost). Base at the origin, metres
## (round ~5.5 m tall, pine ~6.5 m). Adds a trunk collider unless `collision` is off.

@export_enum("round", "pine") var kind: String = "round": set = _set_kind
## Shape variant (any int; same value gives the same tree).
@export var variant: int = 0: set = _set_variant
@export_enum("summer", "spring", "autumn", "blossom", "winter", "custom") var palette: String = "summer": set = _set_palette
## Used when palette = "custom".
@export var top_color: Color = Color(0.5, 0.76, 0.2): set = _set_top
@export var bottom_color: Color = Color(0.13, 0.36, 0.18): set = _set_bottom
@export var trunk_color: Color = Color(0.45, 0.3, 0.19): set = _set_trunk
@export var collision: bool = true: set = _set_collision

const FOLIAGE_SHADER := preload("res://starter/nature-chunky-trees/chunky_foliage.gdshader")
const PALETTES := {
	"summer": {"round": [Color(0.5, 0.76, 0.2), Color(0.13, 0.36, 0.18)], "pine": [Color(0.24, 0.52, 0.22), Color(0.05, 0.24, 0.17)], "frost": 0.0},
	"spring": {"round": [Color(0.66, 0.86, 0.3), Color(0.26, 0.5, 0.2)], "pine": [Color(0.36, 0.64, 0.3), Color(0.1, 0.33, 0.22)], "frost": 0.0},
	"autumn": {"round": [Color(0.96, 0.56, 0.16), Color(0.55, 0.18, 0.08)], "pine": [Color(0.3, 0.48, 0.22), Color(0.08, 0.24, 0.17)], "frost": 0.0},
	"blossom": {"round": [Color(0.98, 0.7, 0.82), Color(0.7, 0.34, 0.5)], "pine": [Color(0.24, 0.52, 0.22), Color(0.05, 0.24, 0.17)], "frost": 0.0},
	"winter": {"round": [Color(0.45, 0.62, 0.4), Color(0.18, 0.34, 0.34)], "pine": [Color(0.24, 0.48, 0.36), Color(0.07, 0.25, 0.27)], "frost": 1.0},
}

static var _meshes: Dictionary = {}
var _mesh_node: MeshInstance3D
var _body: StaticBody3D
var _pending := false

func _ready() -> void:
	_rebuild()

func _set_kind(v: String) -> void: kind = v; _queue()
func _set_variant(v: int) -> void: variant = v; _queue()
func _set_palette(v: String) -> void: palette = v; _queue()
func _set_top(v: Color) -> void: top_color = v; _queue()
func _set_bottom(v: Color) -> void: bottom_color = v; _queue()
func _set_trunk(v: Color) -> void: trunk_color = v; _queue()
func _set_collision(v: bool) -> void: collision = v; _queue()

func _queue() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()

func _colors() -> Array:
	if palette == "custom" or not PALETTES.has(palette):
		return [top_color, bottom_color, 0.0]
	var p: Dictionary = PALETTES[palette]
	var c: Array = p[kind]
	return [c[0], c[1], p["frost"]]

func _rebuild() -> void:
	_pending = false
	for n: Node in [_mesh_node, _body]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	var cols := _colors()
	var key := "%s_%d_%s_%s_%s_%s" % [kind, variant, cols[0].to_html(), cols[1].to_html(), str(cols[2]), trunk_color.to_html()]
	var mesh: ArrayMesh = _meshes.get(key)
	if mesh == null:
		mesh = build_mesh(kind, variant, cols[0], cols[1], float(cols[2]), trunk_color)
		_meshes[key] = mesh
	_mesh_node = MeshInstance3D.new()
	_mesh_node.name = "TreeMesh"
	_mesh_node.mesh = mesh
	add_child(_mesh_node, false, Node.INTERNAL_MODE_FRONT)
	if collision:
		_body = StaticBody3D.new()
		_body.name = "TrunkBody"
		var shape := CylinderShape3D.new()
		shape.radius = 0.3 if kind == "round" else 0.25
		shape.height = 2.4
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position.y = 1.2
		_body.add_child(cs)
		add_child(_body, false, Node.INTERNAL_MODE_FRONT)

static func build_mesh(p_kind: String, p_variant: int, top: Color, bottom: Color, frost: float, trunk_col: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d" % [p_kind, p_variant])
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 16
	blob.rings = 8
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 14
	cone.rings = 2
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.68
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 9
	trunk.rings = 1
	trunk.cap_top = false
	var foliage := ShaderMaterial.new()
	foliage.shader = FOLIAGE_SHADER
	if p_kind == "round":
		# Warm trunk, one big crown clump, four shoulder clumps and a top knot.
		var trunk_h := rng.randf_range(2.1, 2.6)
		bark.append_from(trunk, 0, Transform3D(Basis().scaled(Vector3(0.24, trunk_h, 0.24)), Vector3(0, trunk_h * 0.5, 0)))
		var crown := Vector3(0, trunk_h + 1.05, 0)
		leaves.append_from(blob, 0, _blob(crown, 1.55, 0.86))
		var turn := rng.randf() * TAU
		for i: int in 4:
			var a := turn + TAU * float(i) / 4.0 + rng.randf_range(-0.35, 0.35)
			var at := crown + Vector3(cos(a) * 1.05, rng.randf_range(-0.45, -0.1), sin(a) * 1.05)
			leaves.append_from(blob, 0, _blob(at, rng.randf_range(0.9, 1.1), 0.84))
		leaves.append_from(blob, 0, _blob(crown + Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)), 1.0, 0.9))
	else:
		# Two-tone pine: short trunk, four stacked cones.
		bark.append_from(trunk, 0, Transform3D(Basis().scaled(Vector3(0.2, 1.3, 0.2)), Vector3(0, 0.65, 0)))
		var y := 0.9
		for i: int in 4:
			var r := 1.75 - float(i) * 0.36 + rng.randf_range(-0.08, 0.08)
			var h := 2.0 - float(i) * 0.16
			var twist := Basis(Vector3.UP, rng.randf() * TAU)
			leaves.append_from(cone, 0, Transform3D(twist.scaled(Vector3(r, h, r)), Vector3(0, y + h * 0.5, 0)))
			y += h * 0.56
		foliage.set_shader_parameter("ramp_low", 0.05)
		foliage.set_shader_parameter("ramp_high", 0.55)
		foliage.set_shader_parameter("lump", 0.05)
	foliage.set_shader_parameter("top_color", top)
	foliage.set_shader_parameter("bottom_color", bottom)
	foliage.set_shader_parameter("frost", frost)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = trunk_col
	wood.roughness = 0.95
	var mesh := leaves.commit()
	mesh.surface_set_material(0, foliage)
	bark.commit(mesh)
	mesh.surface_set_material(1, wood)
	return mesh

static func _blob(at: Vector3, radius: float, squash: float) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3(radius, radius * squash, radius)), at)
