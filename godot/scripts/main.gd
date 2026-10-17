extends Node3D
## Portfolio planet: builds the world, the seven case-study locations and the interaction.
##
## Each location is one landmark built from flat-shaded primitives by scripts/locations.gd
## and scripts/locations_b.gd. Walking within its interaction radius shows the prompt and
## opens that case study in a new browser tab.

const CaseStudies := preload("res://scripts/case_studies.gd")
const LocA := preload("res://scripts/locations.gd")
const LocB := preload("res://scripts/locations_b.gd")
const K := preload("res://scripts/loc_kit.gd")
const TREE_SCRIPT := preload("res://starter/nature-chunky-trees/chunky_tree.gd")
const Fonts := preload("res://starter/ui-fonts/fonts.gd")
const LIB := "res://assets/library/survival-nature/"

const DEFAULT_INTERACT_RADIUS := 2.5

@onready var planet: StaticBody3D = $Planet
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var decor: Node3D = $Decor

var _locations: Array[Dictionary] = []
var _discovered := {}
var _near := -1
var _sun: DirectionalLight3D
var _sun_basis0 := Basis.IDENTITY
var _env: Environment
var _clouds: Node3D
var _time := 0.0
var _flat_dirs: Array[Vector3] = []


func _ready() -> void:
	_flat_dirs.append(Vector3.UP)
	for d: Dictionary in CaseStudies.LOCATIONS:
		_flat_dirs.append((d["position"] as Vector3).normalized())
	planet.flat_dirs = _flat_dirs
	planet.sea_dir = CaseStudies.SEA_DIR.normalized()

	# Locations first (they register their ground paint), then the planet mesh.
	for d: Dictionary in CaseStudies.LOCATIONS:
		_make_location(d)
	planet.build()
	_scatter()
	_make_clouds()

	player.global_position = planet.surface_point(Vector3.UP) + Vector3.UP * 0.3
	hud.set_discovered(0, CaseStudies.LOCATIONS.size())
	hud.open_requested.connect(_on_open_requested)

	await get_tree().process_frame
	await get_tree().process_frame
	_sun = find_child("Sun", true, false) as DirectionalLight3D
	if _sun:
		_sun_basis0 = _sun.global_basis
		_sun.light_energy *= 0.75
	var envs := find_children("*", "WorldEnvironment", true, false)
	if not envs.is_empty():
		_env = (envs[0] as WorldEnvironment).environment
	# Softer look: the bloom pass runs one frame after start, so tone it down after it.
	await get_tree().process_frame
	if _env:
		_env.tonemap_exposure = minf(_env.tonemap_exposure, 0.9)
		_env.glow_intensity *= 0.45
		_env.glow_bloom = minf(_env.glow_bloom, 0.03)
		_env.glow_hdr_threshold = maxf(_env.glow_hdr_threshold, 1.2)


# ---------- helpers ----------

func _basis_from_up(up: Vector3, yaw := 0.0) -> Basis:
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var z := (ref - up * ref.dot(up)).normalized()
	var x := up.cross(z).normalized()
	var b := Basis(x, up, z)
	return b.rotated(up, yaw)


func _place(node: Node3D, dir: Vector3, yaw := 0.0, s := 1.0, sink := 0.05, parent: Node = null) -> Node3D:
	var up := dir.normalized()
	(parent if parent else decor).add_child(node)
	var b := _basis_from_up(up, yaw).scaled(Vector3.ONE * s)
	node.global_transform = Transform3D(b, planet.surface_point(up) - up * sink)
	return node


func _too_close(dir: Vector3, min_angle: float) -> bool:
	for f in _flat_dirs:
		if dir.angle_to(f) < min_angle:
			return true
	return false


## Reserves a circular footprint (radius in metres) on the planet; false if it overlaps one.
func _claim(taken: Array, dir: Vector3, radius_m: float) -> bool:
	for t in taken:
		if dir.angle_to(t[0]) * planet.radius < radius_m + float(t[1]):
			return false
	taken.append([dir, radius_m])
	return true


func _rand_dir(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()


func _lib(file: String) -> Node3D:
	var ps := load(LIB + file) as PackedScene
	return ps.instantiate() as Node3D if ps else Node3D.new()


func _mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


# ---------- locations ----------

func _make_location(d: Dictionary) -> void:
	var up := (d["position"] as Vector3).normalized()
	var root := Node3D.new()
	root.name = "Location_" + String(d["id"])
	add_child(root)
	var yaw := 0.0
	if d.get("faceSea", false):
		# Turn the location so its local +X (harbour side) points at the sea.
		var x := _basis_from_up(up).x
		var sea := CaseStudies.SEA_DIR.normalized()
		var t := (sea - up * sea.dot(up)).normalized()
		yaw = atan2(up.dot(x.cross(t)), x.dot(t))
	root.global_transform = Transform3D(_basis_from_up(up, yaw), planet.surface_point(up))

	var k: K = K.new()
	k.begin(root, d["accentColor"])
	match String(d["builder"]):
		"origin":
			LocA.origin(k)
		"domtn":
			LocA.domtn(k)
		"smtu":
			LocA.smtu(k)
		"itmo":
			LocA.itmo(k)
		"dragontrans":
			LocB.dragontrans(k)
		"book":
			LocB.book(k)
		"shots":
			LocB.shots(k)
		_:
			LocA.origin(k)

	if k.ground_radius > 0.0:
		planet.tints.append([up, (k.ground_radius + 0.6) / planet.radius, k.ground_color])
	_conform(root)
	_make_title(root, d)

	var radius := DEFAULT_INTERACT_RADIUS
	if root.has_meta("radius"):
		radius = float(root.get_meta("radius"))
	var aura: Node = null
	if root.has_meta("aura"):
		aura = root.get_meta("aura") as Node
	_locations.append({
		"data": d,
		"aura": aura,
		"pos": root.global_transform * k.landmark,
		"radius": radius,
		"spins": k.spins,
		"bobs": k.bobs,
	})


## Moves every piece of a location from its flat build plane onto the curved planet:
## each piece is carried around the planet centre so its foot rests on the surface and
## its up axis follows the local surface normal. Pieces tagged "float" stay on the sea.
func _conform(root: Node3D) -> void:
	var center := planet.global_position
	var rt := root.global_transform
	var root_up := rt.basis.y.normalized()
	for c in root.get_children():
		var n := c as Node3D
		if n == null:
			continue
		var p := n.position
		var foot := rt * Vector3(p.x, 0.0, p.z)
		var dir := (foot - center).normalized()
		var h: float = planet.height_at(dir)
		if n.has_meta("float"):
			h = maxf(h, planet.water_level())
		var q := Quaternion(root_up, dir)
		var t := n.global_transform
		var origin := center + dir * h + q * (t.origin - foot) - dir * _sink(n, p.y)
		n.global_transform = Transform3D(Basis(q) * t.basis, origin)


## How far a wide grounded piece must sink so its rim does not float above the curve.
func _sink(n: Node3D, y: float) -> float:
	var mi := n as MeshInstance3D
	if mi == null:
		for ch in n.get_children():
			if ch is MeshInstance3D:
				mi = ch
				break
	if mi == null or mi.mesh == null:
		return 0.0
	var box := mi.mesh.get_aabb()
	if y + box.position.y > 0.3:
		return 0.0
	var r := Vector2(box.size.x, box.size.z).length() * 0.5 * n.scale.x
	return minf(r * r / (2.0 * planet.radius) + 0.02, 0.8)


## Large floating title over the location: place name, case name and a one-line summary.
func _make_title(root: Node3D, d: Dictionary) -> void:
	var desc := String(d["description"])
	var place := desc
	var summary := ""
	var cut := desc.find(" - ")
	if cut >= 0:
		place = desc.substr(0, cut)
		summary = desc.substr(cut + 3)
		summary = summary.substr(0, 1).to_upper() + summary.substr(1)
	var accent: Color = d["accentColor"]
	var holder := Node3D.new()
	holder.name = "Title"
	root.add_child(holder)
	holder.position = Vector3(0.0, 13.0, 0.0)
	# [text, font size, colour, y, wrap width px, vertical alignment]
	# Title is centred on y = 0 (about 1.5 m tall); the place line sits above it and the
	# summary hangs below it, each with a clear gap so the rows never touch.
	var rows := [
		[place.to_upper(), 60, accent.lightened(0.35), 1.25, 0, VERTICAL_ALIGNMENT_BOTTOM],
		[String(d["title"]), 130, Color.WHITE, 0.0, 0, VERTICAL_ALIGNMENT_CENTER],
		[summary, 50, Color(1, 1, 1, 0.95), -1.2, 1000, VERTICAL_ALIGNMENT_TOP],
	]
	for r in rows:
		var l := Label3D.new()
		l.text = r[0]
		l.font = Fonts.sans(800)
		l.font_size = r[1]
		l.pixel_size = 0.011
		l.modulate = r[2]
		l.outline_size = 22
		l.outline_modulate = Color(0.06, 0.08, 0.14, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(0.0, r[3], 0.0)
		l.vertical_alignment = r[5]
		l.line_spacing = 6.0
		if int(r[4]) > 0:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.width = float(r[4])
		holder.add_child(l)


# ---------- world dressing ----------

func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var palettes := ["summer", "summer", "spring", "blossom", "autumn"]
	var birches := ["birch-tree-1.glb", "birch-tree-3.glb", "birch-tree-5.glb", "birch-tree-autumn-2.glb"]
	var bushes := ["bush-1.glb", "bush-2.glb", "bush-berries-1.glb"]
	var rocks := ["rock-1.glb", "rock-3.glb", "rock-7.glb"]
	# Every placed piece reserves a footprint, so nothing grows into anything else.
	var taken: Array = []
	var placed := 0
	var tries := 0
	while placed < 60 and tries < 900:
		tries += 1
		var dir := _rand_dir(rng)
		if _too_close(dir, 0.38) or planet.height_at(dir) < planet.radius - 0.1:
			continue
		if not _claim(taken, dir, 2.4):
			continue
		placed += 1
		if rng.randf() < 0.6:
			var t := Node3D.new()
			t.set_script(TREE_SCRIPT)
			t.set("kind", "pine" if rng.randf() < 0.3 else "round")
			t.set("variant", rng.randi_range(0, 9))
			t.set("palette", palettes[rng.randi() % palettes.size()])
			t.set("collision", true)
			_place(t, dir, rng.randf() * TAU, rng.randf_range(0.9, 1.4), 0.1)
		else:
			_place(_lib(birches[rng.randi() % birches.size()]), dir, rng.randf() * TAU, rng.randf_range(0.9, 1.2), 0.1)
	for i in 45:
		var dir := _rand_dir(rng)
		if _too_close(dir, 0.34) or planet.height_at(dir) < planet.radius - 0.1:
			continue
		if not _claim(taken, dir, 1.1):
			continue
		_place(_lib(bushes[rng.randi() % bushes.size()]), dir, rng.randf() * TAU, rng.randf_range(0.7, 1.1), 0.1)
	for i in 35:
		var dir := _rand_dir(rng)
		if _too_close(dir, 0.32) or planet.height_at(dir) < planet.radius - 0.3:
			continue
		if not _claim(taken, dir, 1.0):
			continue
		_place(_lib(rocks[rng.randi() % rocks.size()]), dir, rng.randf() * TAU, rng.randf_range(0.8, 2.2), 0.15)


func _make_clouds() -> void:
	_clouds = Node3D.new()
	_clouds.name = "Clouds"
	add_child(_clouds)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.85, 0.9, 1.0)
	m.emission_energy_multiplier = 0.35
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 16:
		var dir := _rand_dir(rng)
		var cloud := Node3D.new()
		_clouds.add_child(cloud)
		cloud.global_transform = Transform3D(_basis_from_up(dir, rng.randf() * TAU), dir * rng.randf_range(42.0, 47.0))
		for j in rng.randi_range(3, 5):
			var puff := MeshInstance3D.new()
			var s := SphereMesh.new()
			var r := rng.randf_range(1.2, 2.2)
			s.radius = r
			s.height = r * 1.4
			s.radial_segments = 8
			s.rings = 4
			s.material = m
			puff.mesh = s
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			puff.position = Vector3(j * 1.8 - 3.0, rng.randf_range(-0.3, 0.4), rng.randf_range(-0.8, 0.8))
			cloud.add_child(puff)


# ---------- loop ----------

func _process(delta: float) -> void:
	_time += delta
	for loc in _locations:
		for s: Node3D in loc["spins"]:
			s.rotate_y(delta * float(s.get_meta("spin_speed")))
		for b: Node3D in loc["bobs"]:
			var base: Vector3 = b.get_meta("bob_base")
			var amp := float(b.get_meta("bob_amp"))
			var speed := float(b.get_meta("bob_speed"))
			var phase := float(b.get_meta("bob_phase"))
			b.position = base + Vector3(0.0, sin(_time * speed + phase) * amp, 0.0)

	var best := -1
	var best_d := 0.0
	for i in _locations.size():
		var dist := player.global_position.distance_to(_locations[i]["pos"])
		if dist < float(_locations[i]["radius"]) and (best < 0 or dist < best_d):
			best_d = dist
			best = i
	_near = best
	if best >= 0:
		hud.show_prompt(String(_locations[best]["data"]["title"]), String(_locations[best]["data"]["interactionLabel"]))
	else:
		hud.hide_prompt()

	# Keep the local sky and sun upright wherever the player stands on the planet.
	var pb := player.global_basis.orthonormalized()
	if _sun:
		_sun.global_basis = pb * _sun_basis0
	if _env:
		_env.sky_rotation = pb.get_euler()
	if _clouds:
		_clouds.rotate(Vector3(0.2, 1.0, 0.1).normalized(), delta * 0.015)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _near >= 0:
		_open(_near)
		get_viewport().set_input_as_handled()


func _on_open_requested() -> void:
	if _near >= 0:
		_open(_near)


## Opens the case study in a new browser tab. No overlay, no scene change.
func _open(i: int) -> void:
	if player and player.has_method("play_interaction"):
		player.play_interaction()
	var loc := _locations[i]
	var data: Dictionary = loc["data"]
	var aura: Node = loc["aura"]
	if aura and aura.has_method("pulse"):
		aura.pulse(2.0)
	var url := String(data["caseUrl"])
	if not url.begins_with("http"):
		hud.flash("Ссылка для \"" + String(data["title"]) + "\" пока не указана (scripts/case_studies.gd)")
		return
	OS.shell_open(url)
	_discovered[data["id"]] = true
	hud.set_discovered(_discovered.size(), CaseStudies.LOCATIONS.size())
	hud.flash("Открываю кейс " + String(data["title"]) + "...")
