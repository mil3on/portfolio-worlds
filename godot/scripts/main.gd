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
const MACHINA := preload("res://assets/fonts/PPNeueMachina-Ultrabold.otf")
const MANROPE := preload("res://assets/fonts/Manrope.ttf")
const AMBIENT_STREAM := preload("res://assets/audio/background-sounds.mp3")
const STEP_STREAM := preload("res://assets/audio/footstep-on-grass.mp3")
const USE_STREAM := preload("res://assets/audio/use-case.mp3")
const LOCK_ICON := preload("res://assets/ui/lock.svg")
const FLOWERS_SCENE := preload("res://assets/library/user/flowers_pack_1.glb")

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
var _ambient_audio: AudioStreamPlayer
var _step_audio: AudioStreamPlayer
var _use_audio: AudioStreamPlayer
var _opening_case := false


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
	hud.set_case_progress(CaseStudies.LOCATIONS, _discovered)
	hud.open_requested.connect(_on_open_requested)
	player.stepped.connect(_on_player_step)
	_setup_audio()

	await get_tree().process_frame
	await get_tree().process_frame
	_sun = find_child("Sun", true, false) as DirectionalLight3D
	if _sun:
		_sun_basis0 = _sun.global_basis
		_sun.light_energy *= 0.82
	var envs := find_children("*", "WorldEnvironment", true, false)
	if not envs.is_empty():
		_env = (envs[0] as WorldEnvironment).environment
	# Softer look: the bloom pass runs one frame after start, so tone it down after it.
	await get_tree().process_frame
	if _env:
		_env.tonemap_exposure = minf(_env.tonemap_exposure, 0.76)
		_env.glow_intensity *= 0.32
		_env.glow_bloom = minf(_env.glow_bloom, 0.03)
		_env.glow_hdr_threshold = maxf(_env.glow_hdr_threshold, 1.35)
	_make_night_side()


func _setup_audio() -> void:
	_ambient_audio = AudioStreamPlayer.new()
	_ambient_audio.name = "BirdsAndWind"
	_ambient_audio.stream = AMBIENT_STREAM
	_ambient_audio.volume_db = -31.0
	_ambient_audio.autoplay = true
	add_child(_ambient_audio)
	_step_audio = AudioStreamPlayer.new()
	_step_audio.name = "GrassSteps"
	_step_audio.stream = STEP_STREAM
	_step_audio.volume_db = -13.0
	add_child(_step_audio)
	_use_audio = AudioStreamPlayer.new()
	_use_audio.name = "CaseUse"
	_use_audio.stream = USE_STREAM
	_use_audio.volume_db = -10.0
	add_child(_use_audio)


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
	var plaque := _make_plaque(root, d)

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
		"plaque": plaque,
		"dir": up,
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


## A two-state 3D sign: compact and locked until the case has been visited, then a
## portfolio-like white card unfolds with the case context. The card itself is a
## SubViewport texture, so it remains crisp and always turns to the camera.
func _make_plaque(root: Node3D, d: Dictionary) -> Dictionary:
	var desc := String(d["description"])
	var cut := desc.find(" - ")
	# The location title is the name the visitor sees in both the HUD and its plaque.
	# Keep the longer case description below it as the explanatory text.
	var place := String(d["title"])
	var summary := desc.substr(cut + 3) if cut >= 0 else ""
	var holder := Node3D.new()
	holder.name = "CasePlaque"
	holder.position = Vector3(0.0, 11.3, 0.0)
	root.add_child(holder)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 410)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = 0.0105
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	holder.add_child(sprite)

	var closed := PanelContainer.new()
	closed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	closed.offset_left = 55
	closed.offset_right = -55
	closed.offset_top = 145
	closed.offset_bottom = -145
	closed.add_theme_stylebox_override("panel", _plaque_style(Color(1, 1, 1, 0.96), 90, 24))
	viewport.add_child(closed)
	var closed_row := HBoxContainer.new()
	closed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	closed_row.add_theme_constant_override("separation", 16)
	closed.add_child(closed_row)
	var lock := TextureRect.new()
	lock.texture = LOCK_ICON
	lock.custom_minimum_size = Vector2(34, 34)
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	closed_row.add_child(lock)
	var closed_text := Label.new()
	closed_text.text = place
	closed_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	closed_text.add_theme_font_override("font", MACHINA)
	closed_text.add_theme_font_size_override("font_size", 36)
	closed_text.add_theme_color_override("font_color", Color("161719"))
	closed_row.add_child(closed_text)

	var opened := PanelContainer.new()
	opened.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opened.add_theme_stylebox_override("panel", _plaque_style(Color(1, 1, 1, 0.97), 42, 42))
	opened.visible = false
	viewport.add_child(opened)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	opened.add_child(content)
	var tag := Label.new()
	tag.text = String(d["title"]).to_upper()
	tag.add_theme_font_override("font", MANROPE)
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", d["accentColor"])
	content.add_child(tag)
	var heading := Label.new()
	heading.text = place
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_override("font", MACHINA)
	heading.add_theme_font_size_override("font_size", 47)
	heading.add_theme_color_override("font_color", Color("0c0d0f"))
	content.add_child(heading)
	var client := Label.new()
	client.text = "Кейс " + String(d["title"])
	client.add_theme_font_override("font", MANROPE)
	client.add_theme_font_size_override("font_size", 26)
	client.add_theme_color_override("font_color", Color("272a2f"))
	content.add_child(client)
	var body := Label.new()
	body.text = summary
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", MANROPE)
	body.add_theme_font_size_override("font_size", 23)
	body.add_theme_color_override("font_color", Color("202227"))
	content.add_child(body)
	return {"holder": holder, "closed": closed, "opened": opened}


func _plaque_style(color: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.shadow_color = Color(0.05, 0.06, 0.08, 0.22)
	s.shadow_size = 18
	return s


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
	# Small reusable grass clumps and flowers fill the quiet parts of the planet. They are
	# never sampled from the lowered sea basin and each clump reserves its own footprint.
	for i in 110:
		var dir := _rand_dir(rng)
		if _too_close(dir, 0.30) or planet.height_at(dir) <= planet.water_level() + 0.16:
			continue
		if not _claim(taken, dir, 0.48):
			continue
		_place(_grass_clump(rng), dir, rng.randf() * TAU, rng.randf_range(0.75, 1.18), 0.0)
	for i in 18:
		var dir := _rand_dir(rng)
		if _too_close(dir, 0.31) or planet.height_at(dir) <= planet.water_level() + 0.16:
			continue
		if not _claim(taken, dir, 0.72):
			continue
		_place(_flower_clump(rng), dir, rng.randf() * TAU, rng.randf_range(0.06, 0.10), 0.0)


func _grass_clump(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	for i in 4:
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, rng.randf_range(0.24, 0.42), 0.025)
		mesh.material = _mat(Color(0.27, rng.randf_range(0.50, 0.68), 0.27))
		blade.mesh = mesh
		blade.position = Vector3(rng.randf_range(-0.22, 0.22), mesh.size.y * 0.5, rng.randf_range(-0.22, 0.22))
		blade.rotation.y = rng.randf() * TAU
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(blade)
	return root


func _flower_clump(rng: RandomNumberGenerator) -> Node3D:
	var root := FLOWERS_SCENE.instantiate() as Node3D
	root.name = "FlowersPack"
	# The model is reused as an instanced scene; only its transforms vary across the planet.
	for n in _all_meshes(root):
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func _all_meshes(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
		meshes.append_array(_all_meshes(child))
	return meshes


func _make_night_side() -> void:
	# The moon and its cool directional fill stay fixed, opposite the sun. The warm
	# lanterns make the night hemisphere navigable without flattening the day-side light.
	var sun_dir := Vector3(0.45, -0.72, 0.52).normalized()
	if _sun:
		sun_dir = -_sun.global_transform.basis.z.normalized()
	var moon_dir := -sun_dir
	var moon := Node3D.new()
	moon.name = "Moon"
	add_child(moon)
	moon.global_position = planet.global_position + moon_dir * 66.0
	var moon_mesh := MeshInstance3D.new()
	var moon_sphere := SphereMesh.new()
	moon_sphere.radius = 4.2
	moon_sphere.height = 8.4
	moon_sphere.radial_segments = 24
	moon_sphere.rings = 12
	moon_mesh.mesh = moon_sphere
	moon_mesh.material_override = _mat(Color("dce8ff"), 0.24)
	moon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.add_child(moon_mesh)
	for p in [Vector3(-1.4, 0.8, -3.5), Vector3(1.8, -1.0, -3.6), Vector3(0.2, 1.9, -3.7)]:
		var crater := MeshInstance3D.new()
		var crater_mesh := SphereMesh.new()
		crater_mesh.radius = 0.42
		crater_mesh.height = 0.16
		crater_mesh.radial_segments = 12
		crater.mesh = crater_mesh
		crater.material_override = _mat(Color("aebbd1"))
		crater.position = p
		crater.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		moon.add_child(crater)
	var moonlight := DirectionalLight3D.new()
	moonlight.name = "Moonlight"
	moonlight.light_color = Color("9bb8ff")
	moonlight.light_energy = 0.23
	moonlight.shadow_enabled = false
	moonlight.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP)
	add_child(moonlight)
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 240:
		tries += 1
		var dir := _rand_dir(rng)
		if dir.dot(moon_dir) < 0.28 or _too_close(dir, 0.22):
			continue
		if planet.height_at(dir) <= planet.water_level() + 0.18:
			continue
		_place(_night_lantern(), dir, rng.randf() * TAU, rng.randf_range(0.75, 1.05), 0.0)
		placed += 1


func _night_lantern() -> Node3D:
	var root := Node3D.new()
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.07
	post_mesh.bottom_radius = 0.09
	post_mesh.height = 1.7
	post_mesh.radial_segments = 8
	post.mesh = post_mesh
	post.material_override = _mat(Color("49372f"))
	post.position.y = 0.85
	root.add_child(post)
	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.20
	glow_mesh.height = 0.40
	glow_mesh.radial_segments = 10
	glow.mesh = glow_mesh
	glow.material_override = _mat(Color("ffcb70"), 1.9)
	glow.position.y = 1.72
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = Color("ffcf85")
	light.light_energy = 0.7
	light.omni_range = 4.0
	light.shadow_enabled = false
	light.position.y = 1.65
	root.add_child(light)
	return root


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
		# Signs on the far side of the sphere are explicitly hidden. The small positive
		# threshold keeps them from popping up before the player reaches the horizon.
		var plaque: Dictionary = loc["plaque"]
		if plaque:
			var player_dir := (player.global_position - planet.global_position).normalized()
			plaque["holder"].visible = player_dir.dot(loc["dir"]) > 0.04

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

	# The sun is fixed in world space: travelling around the planet naturally leads
	# from its warm day side to the dark night side.
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
	if _opening_case:
		return
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
	_opening_case = true
	player.input_enabled = false
	if _use_audio:
		_use_audio.play()
	_discovered[data["id"]] = true
	hud.set_discovered(_discovered.size(), CaseStudies.LOCATIONS.size())
	hud.set_case_progress(CaseStudies.LOCATIONS, _discovered)
	var plaque: Dictionary = loc["plaque"]
	if plaque:
		plaque["closed"].visible = false
		plaque["opened"].visible = true
	hud.flash("Открываю кейс через 3 секунды...")
	await get_tree().create_timer(3.0).timeout
	OS.shell_open(url)
	player.input_enabled = true
	_opening_case = false


func _on_player_step(world_pos: Vector3, up: Vector3, running: bool) -> void:
	if _step_audio:
		_step_audio.pitch_scale = randf_range(0.92, 1.08)
		_step_audio.play()
	_spawn_step_fx(world_pos, up, running)


func _spawn_step_fx(world_pos: Vector3, up: Vector3, running: bool) -> void:
	var root := Node3D.new()
	decor.add_child(root)
	root.global_transform = Transform3D(_basis_from_up(up), world_pos + up * 0.04)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.36, 0.21, 0.46)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var count := 6 if running else 3
	for i in count:
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.055 if not running else 0.08
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 6
		mesh.rings = 3
		mesh.material = material
		puff.mesh = mesh
		puff.position = Vector3(randf_range(-0.18, 0.18), 0.04, randf_range(-0.18, 0.18))
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(puff)
		var end := puff.position + Vector3(randf_range(-0.36, 0.36), randf_range(0.14, 0.30), randf_range(-0.16, 0.30)) * (1.45 if running else 1.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "position", end, 0.46)
		tw.tween_property(puff, "scale", Vector3.ONE * (1.8 if running else 1.4), 0.46)
	var cleanup := create_tween()
	cleanup.tween_interval(0.5)
	cleanup.tween_callback(root.queue_free)
