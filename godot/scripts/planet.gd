extends StaticBody3D
## Builds a flat-shaded low-poly planet with gentle hills, trimesh collision and a water shell.

@export var radius := 30.0
@export var hill_height := 1.6
@export var radial_segments := 112
@export var rings := 56
## Directions kept flat (spawn + locations), filled by main.gd before _ready.
var flat_dirs: Array[Vector3] = []
## Centre of the sea basin (zero = no sea).
var sea_dir := Vector3.ZERO
## Ground paint under each location: [dir: Vector3, angle: float, color: Color].
var tints: Array = []

var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.seed = 11
	_noise.frequency = 0.9
	_noise.fractal_octaves = 3


## Called by main.gd after flat_dirs is filled.
func build() -> void:
	_build()


func height_at(dir: Vector3) -> float:
	var d := dir.normalized()
	var h := _noise.get_noise_3dv(d * 1.6) * hill_height
	h = maxf(h, -0.5)
	var flat := 1.0
	for f in flat_dirs:
		var ang := d.angle_to(f)
		flat = minf(flat, smoothstep(0.26, 0.36, ang))
	var out := radius + h * flat
	if sea_dir != Vector3.ZERO:
		out -= 1.6 * (1.0 - smoothstep(0.38, 0.62, d.angle_to(sea_dir)))
	return out


func water_level() -> float:
	return radius - 0.12


func surface_point(dir: Vector3) -> Vector3:
	return global_position + dir.normalized() * height_at(dir)


func _face_color(center_dir: Vector3, h: float, rng: RandomNumberGenerator) -> Color:
	var rel := h - radius
	var c: Color
	if rel < -0.25:
		c = Color(0.95, 0.84, 0.6)
	elif rel < 0.6:
		c = Color(0.44, 0.72, 0.36).lerp(Color(0.56, 0.8, 0.38), rng.randf())
	elif rel < 1.0:
		c = Color(0.36, 0.64, 0.33).lerp(Color(0.46, 0.7, 0.34), rng.randf())
	else:
		c = Color(0.62, 0.78, 0.42).lerp(Color(0.7, 0.82, 0.5), rng.randf())
	if rel >= -0.25:
		for t in tints:
			var ang := center_dir.angle_to(t[0])
			var a: float = t[1]
			if ang < a:
				var tc: Color = t[2]
				tc = tc.lerp(tc.darkened(0.06), rng.randf())
				c = c.lerp(tc, smoothstep(a, a * 0.8, ang))
	return c


func _build() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	var arrays := sphere.get_mesh_arrays()
	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var disp := PackedVector3Array()
	disp.resize(src_verts.size())
	for i in src_verts.size():
		var d := src_verts[i].normalized()
		disp[i] = d * height_at(d)

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var faces := PackedVector3Array()
	for t in range(0, idx.size(), 3):
		var a := disp[idx[t]]
		var b := disp[idx[t + 1]]
		var c := disp[idx[t + 2]]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 0.000001:
			continue
		n = n.normalized()
		var center := (a + b + c) / 3.0
		if n.dot(center) < 0.0:
			n = -n
		var col := _face_color(center.normalized(), center.length(), rng)
		for v in [a, b, c]:
			verts.append(v)
			normals.append(n)
			colors.append(col)
		faces.append(a)
		faces.append(b)
		faces.append(c)

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	add_child(mi)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

	# Shallow water shell: dips in the terrain become little lakes.
	var water := MeshInstance3D.new()
	water.name = "Water"
	var ws := SphereMesh.new()
	ws.radius = radius - 0.12
	ws.height = (radius - 0.12) * 2.0
	ws.radial_segments = 72
	ws.rings = 36
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.3, 0.72, 0.9, 0.78)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08
	wm.metallic_specular = 0.9
	ws.material = wm
	water.mesh = ws
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
