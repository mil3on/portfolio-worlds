extends RefCounted
class_name LocKit
## Shared primitive helpers for the case-study landmarks.
##
## A location root's local space: +Y points away from the planet centre and -Z is the
## front (the player arrives facing it). Everything is built from flat-shaded primitives
## in one palette, so a landmark reads from across the planet by silhouette and colour.

const AURA := preload("res://starter/shader-healing-aura/healing_aura.tscn")
const Fonts := preload("res://starter/ui-fonts/fonts.gd")
const FLOWERS := preload("res://assets/library/user/flowers_pack_1.glb")

const CREAM := Color(0.95, 0.92, 0.85)
const WOOD := Color(0.55, 0.37, 0.23)
const WOOD_LIGHT := Color(0.66, 0.47, 0.30)
const GRAPHITE := Color(0.26, 0.28, 0.32)
const WHITE := Color(0.95, 0.96, 0.97)
const STONE := Color(0.83, 0.83, 0.81)
const DARK := Color(0.13, 0.14, 0.17)
const GLASS := Color(0.72, 0.86, 0.95)
const WATER := Color(0.24, 0.62, 0.86)

var root: Node3D
var accent := Color.WHITE
var landmark := Vector3(0.0, 1.0, 0.0)
var spins: Array[Node3D] = []
var bobs: Array[Node3D] = []
var _mats := {}
## Ground paint under the location (set by pad(); main.gd paints the planet with it).
var ground_color := Color(0, 0, 0, 0)
var ground_radius := 0.0

static var _detail_tex: NoiseTexture2D
static var _normal_tex: NoiseTexture2D


static func _textures() -> void:
	if _detail_tex:
		return
	var n := FastNoiseLite.new()
	n.seed = 7
	n.frequency = 0.035
	n.fractal_octaves = 4
	_detail_tex = NoiseTexture2D.new()
	_detail_tex.width = 256
	_detail_tex.height = 256
	_detail_tex.seamless = true
	_detail_tex.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.82, 0.82, 0.82))
	g.set_color(1, Color(1, 1, 1))
	_detail_tex.color_ramp = g
	_normal_tex = NoiseTexture2D.new()
	_normal_tex.width = 256
	_normal_tex.height = 256
	_normal_tex.seamless = true
	_normal_tex.as_normal_map = true
	_normal_tex.bump_strength = 6.0
	_normal_tex.noise = n


func begin(r: Node3D, accent_color: Color) -> void:
	root = r
	accent = accent_color


## The supplied Sketchfab flower composition is instanced at a deliberately small scale.
## It stays one shared packed scene rather than duplicating its meshes and textures.
func flowers(pos: Vector3, scale := 0.08, yaw := 0.0) -> Node3D:
	var plant := FLOWERS.instantiate() as Node3D
	plant.name = "FlowersPack"
	plant.position = pos
	plant.rotation.y = yaw
	plant.scale = Vector3.ONE * scale
	root.add_child(plant)
	return plant


func result() -> Dictionary:
	return {"landmark": landmark, "spins": spins, "bobs": bobs}


# ---------------------------------------------------------------- materials

func mat(c: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [c.to_html(false), emission, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.62
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.05
		m.metallic_specular = 0.9
		m.rim_enabled = true
		m.rim = 0.6
	elif emission <= 0.0:
		# Soft surface texture: subtle colour variation plus a fine bumpy normal.
		_textures()
		m.albedo_texture = _detail_tex
		m.normal_enabled = true
		m.normal_texture = _normal_tex
		m.normal_scale = 0.35
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission * 0.45
	_mats[key] = m
	return m


# ---------------------------------------------------------------- shapes

func box(pos: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO, collide := false, emission := 0.0, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = mat(c, emission, alpha)
	mi.mesh = m
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation = rot
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		body.add_child(mi)
		root.add_child(body)
		return mi
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi


func cyl(pos: Vector3, radius: float, height: float, c: Color, rot := Vector3.ZERO, collide := false, seg := 12, emission := 0.0, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = clampi(seg * 3, 24, 64)
	m.rings = 1
	m.material = mat(c, emission, alpha)
	mi.mesh = m
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation = rot
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		body.add_child(cs)
		body.add_child(mi)
		root.add_child(body)
		return mi
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi


func cone(pos: Vector3, radius: float, height: float, c: Color, rot := Vector3.ZERO, seg := 12, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = seg if seg <= 4 else clampi(seg * 3, 24, 48)
	m.rings = 1
	m.material = mat(c, emission)
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi


func sphere(pos: Vector3, radius: float, c: Color, seg := 10, rings := 6, emission := 0.0, alpha := 1.0, hemi := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	# seg <= 4 is a deliberate faceted crystal; everything else is smooth.
	m.radial_segments = seg if seg <= 4 else clampi(seg * 3, 24, 64)
	m.rings = rings if seg <= 4 else clampi(rings * 3, 12, 32)
	m.is_hemisphere = hemi
	m.material = mat(c, emission, alpha)
	mi.mesh = m
	mi.position = pos
	root.add_child(mi)
	return mi


## No foundation slab any more: records the ground colour, and main.gd paints the
## planet's own curved surface with it under the location.
func pad(radius: float, c: Color, _y := 0.05) -> MeshInstance3D:
	ground_color = c
	ground_radius = radius
	return null


## The flat accent ring was removed (it could not follow the planet's curve).
func ring(_radius: float, _c: Color, _y := 0.12, _thickness := 0.14) -> MeshInstance3D:
	return null


func _unused_ring(radius: float, c: Color, y := 0.12, thickness := 0.14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius
	t.outer_radius = radius + thickness
	t.rings = 32
	t.ring_segments = 6
	t.material = mat(c, 1.8)
	mi.mesh = t
	mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	mi.position = Vector3(0.0, y, 0.0)
	root.add_child(mi)
	return mi


func light(pos: Vector3, c: Color, energy := 1.6, range_m := 9.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy * 0.5
	l.omni_range = range_m
	l.position = pos
	root.add_child(l)
	return l


## Brand signs. Location titles are drawn by main.gd above every landmark, so only the
## SHOTS word (part of the arch itself) is kept here.
func sign(pos: Vector3, text: String, size := 64, c := Color.WHITE) -> Label3D:
	if text != "SHOTS":
		return null
	var l := Label3D.new()
	l.text = text
	l.font = Fonts.sans(800)
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = c
	l.outline_size = 14
	l.outline_modulate = Color(0.06, 0.07, 0.1, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	root.add_child(l)
	return l


# ---------------------------------------------------------------- composites

## A glowing route or connection line laid flat on the ground.
func line(a: Vector3, b: Vector3, w: float, c: Color, emission := 2.0, y := 0.14) -> void:
	# Split into short pieces so every piece can follow the planet's curve.
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	var n := maxi(1, ceili(len / 1.4))
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var p := a + d * t
		box(Vector3(p.x, y, p.z), Vector3(w, 0.06, len / float(n) + 0.04), c, Vector3(0.0, atan2(d.x, d.z), 0.0), false, emission)


## A white-framed screen showing a coloured interface panel.
func screen(pos: Vector3, size: Vector2, c: Color, rot := Vector3.ZERO, rows := 3) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation = rot
	root.add_child(holder)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(size.x, size.y, 0.10)
	fm.material = mat(WHITE)
	frame.mesh = fm
	holder.add_child(frame)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(size.x - 0.16, size.y - 0.16, 0.06)
	pm.material = mat(c.darkened(0.55), 2.2)
	panel.mesh = pm
	panel.position = Vector3(0.0, 0.0, 0.05)
	holder.add_child(panel)
	for i in rows:
		var row := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3((size.x - 0.5) * (0.5 + 0.4 * float(i % 3)), 0.12, 0.04)
		rm.material = mat(c, 2.8)
		row.mesh = rm
		row.position = Vector3(-(size.x - 0.5) * 0.15, size.y * 0.5 - 0.32 - float(i) * 0.30, 0.1)
		holder.add_child(row)
	return holder


func lantern(pos: Vector3, c: Color) -> void:
	cyl(pos + Vector3(0.0, 0.9, 0.0), 0.07, 1.8, WOOD, Vector3.ZERO, false, 6)
	box(pos + Vector3(0.0, 1.95, 0.0), Vector3(0.34, 0.40, 0.34), c, Vector3.ZERO, false, 2.4)


func plank_bridge(a: Vector3, b: Vector3, w := 1.0) -> void:
	var d := b - a
	var perp := Vector3(d.z, 0.0, -d.x).normalized()
	var yaw := atan2(d.x, d.z)
	var mid := (a + b) * 0.5
	var len := Vector2(d.x, d.z).length()
	box(mid, Vector3(w, 0.10, len), WOOD_LIGHT, Vector3(0.0, yaw, 0.0))
	for side in [-1.0, 1.0]:
		box(mid + perp * (w * 0.5 * side) + Vector3(0.0, 0.52, 0.0), Vector3(0.07, 0.07, len), WOOD, Vector3(0.0, yaw, 0.0))


func spin(n: Node3D, speed := 1.0) -> Node3D:
	n.set_meta("spin_speed", speed)
	spins.append(n)
	return n


func bob(n: Node3D, amp := 0.2, speed := 1.2, phase := 0.0) -> Node3D:
	n.set_meta("bob_base", n.position)
	n.set_meta("bob_amp", amp)
	n.set_meta("bob_speed", speed)
	n.set_meta("bob_phase", phase)
	bobs.append(n)
	return n
