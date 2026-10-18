extends RefCounted
## Landmark builders, part A: Origin, DOM TN, SMTU, ITMO NIOKTR.
##
## Every landmark is built from flat-shaded primitives in the location's own palette, so it
## is recognisable from across the planet by silhouette and colour alone. Local space:
## +Y points away from the planet centre, -Z is the front the player walks up to.

const K := preload("res://scripts/loc_kit.gd")

const GREEN := Color(0.42, 0.66, 0.34)
const GREEN_DARK := Color(0.31, 0.54, 0.29)
const LEAF_LIGHT := Color(0.52, 0.75, 0.38)
const YELLOW := Color(0.99, 0.81, 0.34)
const CORAL := Color(0.96, 0.52, 0.42)
const PURPLE := Color(0.63, 0.47, 0.86)
const GRASS := Color(0.46, 0.69, 0.37)
const DIRT := Color(0.78, 0.70, 0.52)
const NAVY := Color(0.13, 0.24, 0.45)
const RED := Color(0.86, 0.25, 0.24)
const ICE := Color(0.62, 0.82, 0.95)
const CYAN := Color(0.25, 0.85, 0.88)
const FUCHSIA := Color(0.93, 0.31, 0.72)
const VIVID := Color(0.20, 0.44, 0.95)


## The glowing ground zone that marks where the player can interact.
static func zone(k: K, preset: String, radius := 3.0, pos := Vector3.ZERO) -> void:
	var aura := K.AURA.instantiate()
	k.root.add_child(aura)
	aura.set("preset", preset)
	aura.set("radius", radius)
	aura.set("beam", true)
	aura.set("beam_height", 5.0)
	aura.set("intensity", 0.55)
	aura.set("light_energy", 0.6)
	aura.set("position", Vector3(pos.x, 0.06, pos.z))
	k.root.set_meta("aura", aura)
	k.root.set_meta("radius", radius)


# ---------------------------------------------------------------- 1. Origin

## Forest of Goals: a warm forest of round treehouses and bridges, with a glowing house
## up in the largest tree at the end of the path.
static func origin(k: K) -> void:
	k.pad(7.2, GRASS)
	k.ring(6.5, YELLOW)
	zone(k, "holy", 3.0, Vector3(0.0, 0.0, -4.5))

	# Path from where the player arrives to the great tree.
	var z := 4.4
	while z > -1.2:
		k.box(Vector3(0.0, 0.08, z), Vector3(1.05, 0.14, 0.44), DIRT)
		z -= 0.62

	# The landmark: a house in a large tree.
	k.cyl(Vector3(0.0, 2.7, -4.5), 0.62, 5.4, K.WOOD, Vector3.ZERO, true, 8)
	k.sphere(Vector3(0.0, 6.6, -4.5), 2.6, GREEN, 10, 6)
	k.sphere(Vector3(1.5, 5.8, -4.0), 1.6, GREEN_DARK, 9, 5)
	k.sphere(Vector3(-1.4, 6.1, -5.0), 1.5, LEAF_LIGHT, 9, 5)
	k.sphere(Vector3(0.2, 8.1, -4.3), 1.4, GREEN_DARK, 9, 5)
	k.box(Vector3(0.0, 5.9, -3.0), Vector3(2.6, 2.2, 2.4), Color(0.98, 0.90, 0.66))
	k.cone(Vector3(0.0, 7.5, -3.0), 1.95, 1.5, CORAL, Vector3.ZERO, 8)
	k.box(Vector3(0.0, 5.2, -1.85), Vector3(0.8, 1.3, 0.14), K.WOOD)
	k.box(Vector3(-0.85, 6.15, -1.86), Vector3(0.7, 0.7, 0.12), YELLOW, Vector3.ZERO, false, 3.4)
	k.box(Vector3(0.85, 6.15, -1.86), Vector3(0.7, 0.7, 0.12), YELLOW, Vector3.ZERO, false, 3.4)
	k.light(Vector3(0.0, 6.2, -2.6), YELLOW, 2.2, 10.0)

	# Round treehouses on poles, joined to the great tree by plank bridges.
	var houses := [
		[Vector3(-3.7, 0.0, 0.4), -0.5],
		[Vector3(3.7, 0.0, 0.1), 0.6],
	]
	for h in houses:
		var p: Vector3 = h[0]
		k.cyl(p + Vector3(0.0, 1.4, 0.0), 0.24, 2.8, K.WOOD, Vector3.ZERO, true, 6)
		k.box(p + Vector3(0.0, 3.6, 0.0), Vector3(2.1, 1.8, 2.0), Color(0.96, 0.90, 0.72))
		k.cone(p + Vector3(0.0, 5.0, 0.0), 1.6, 1.2, CORAL if h[1] < 0.0 else PURPLE, Vector3.ZERO, 8)
		k.box(p + Vector3(0.0, 3.7, 1.02), Vector3(0.7, 0.7, 0.12), YELLOW, Vector3.ZERO, false, 2.8)
	k.plank_bridge(Vector3(-2.6, 3.4, 0.5), Vector3(-1.1, 3.9, -2.6), 0.9)
	k.plank_bridge(Vector3(2.6, 3.4, 0.2), Vector3(1.2, 3.9, -2.7), 0.9)

	# Lanterns along the path and a tiny workshop.
	k.lantern(Vector3(-1.5, 0.0, 2.4), YELLOW)
	k.lantern(Vector3(1.5, 0.0, 1.0), CORAL)
	k.lantern(Vector3(-1.5, 0.0, -0.6), PURPLE)
	k.box(Vector3(4.8, 0.8, 3.2), Vector3(2.3, 1.6, 1.9), K.WOOD_LIGHT)
	k.box(Vector3(4.8, 1.75, 3.2), Vector3(2.5, 0.25, 2.1), CORAL)
	k.screen(Vector3(4.8, 0.95, 2.2), Vector2(1.2, 0.7), YELLOW, Vector3(0.0, 0.0, 0.0), 2)

	# A few individual flowers soften the forest edge without turning it into a flower bed.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 5:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(1.6, 6.2)
		k.flowers(Vector3(cos(ang) * r, 0.02, sin(ang) * r), rng.randf_range(0.09, 0.13), rng.randf() * TAU, i)

	k.sign(Vector3(0.0, 9.6, -4.5), "ORIGIN", 46, K.WHITE)
	k.landmark = Vector3(0.0, 0.0, -4.5)


# ---------------------------------------------------------------- 2. DOM TN

## Request District: a clean plaza of minimal blocks wired to a transparent dispatch
## pavilion holding the requests dashboard.
static func domtn(k: K) -> void:
	k.pad(7.0, Color(0.89, 0.91, 0.93))
	k.ring(6.4, K.GLASS)
	zone(k, "mana", 3.0, Vector3.ZERO)

	# Plaza grid: glowing cool-blue lines running through the district.
	for i in 3:
		var o := float(i - 1) * 3.0
		k.line(Vector3(o, 0.0, -6.4), Vector3(o, 0.0, 6.4), 0.10, VIVID, 1.6)
		k.line(Vector3(-6.4, 0.0, o), Vector3(6.4, 0.0, o), 0.10, VIVID, 1.6)

	# The landmark: a transparent dispatch pavilion with the dashboard inside.
	k.box(Vector3(0.0, 0.09, 0.0), Vector3(4.5, 0.18, 4.5), K.WHITE)
	k.box(Vector3(0.0, 1.7, 0.0), Vector3(4.2, 3.2, 4.2), K.GLASS, Vector3.ZERO, false, 0.0, 0.30)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 2.05, 1.7, sz * 2.05), Vector3(0.2, 3.2, 0.2), K.WHITE, Vector3.ZERO, true)
	k.box(Vector3(0.0, 3.45, 0.0), Vector3(4.7, 0.24, 4.7), K.WHITE)
	k.screen(Vector3(0.0, 1.75, -1.15), Vector2(3.3, 1.9), VIVID, Vector3.ZERO, 4)
	k.spin(k.box(Vector3(0.0, 4.35, 0.0), Vector3(0.7, 0.7, 0.7), VIVID, Vector3(0.6, 0.4, 0.0), false, 2.6), 1.1)

	# Minimal blocks, each linked to the pavilion by a glowing line.
	var blocks := [
		[Vector3(-5.0, 0.0, -3.4), 3.0, K.GRAPHITE],
		[Vector3(5.0, 0.0, -3.4), 2.6, K.WHITE],
		[Vector3(-5.2, 0.0, 3.2), 2.4, K.WHITE],
		[Vector3(5.2, 0.0, 3.2), 3.2, K.GRAPHITE],
	]
	for b in blocks:
		var p: Vector3 = b[0]
		var h: float = b[1]
		k.box(p + Vector3(0.0, h * 0.5, 0.0), Vector3(2.9, h, 2.9), b[2], Vector3.ZERO, true)
		k.box(p + Vector3(0.0, h - 0.45, 0.0), Vector3(2.96, 0.22, 2.96), VIVID, Vector3.ZERO, false, 2.4)
		k.screen(p + Vector3(0.0, h * 0.55, 1.48), Vector2(1.6, 0.9), K.GLASS, Vector3.ZERO, 2)
		k.line(p.normalized() * 2.5, p.normalized() * 4.4, 0.14, VIVID, 2.2)

	k.light(Vector3(0.0, 2.4, 0.0), VIVID, 2.0, 12.0)
	k.sign(Vector3(0.0, 4.9, -1.2), "DOM TN", 48, K.WHITE)
	k.landmark = Vector3(0.0, 0.0, -2.6)


# ---------------------------------------------------------------- 3. SMTU

## Shipbuilding University: an academic building with a lighthouse tower on the water,
## reached across a bridge, with a small ship at the pier.
static func smtu(k: K) -> void:
	k.pad(7.2, Color(0.90, 0.88, 0.80))
	k.ring(6.5, NAVY)
	zone(k, "frost", 3.0, Vector3(0.0, 0.0, -2.4))

	# The harbour: a shallow basin on the plaza, crossed by the bridge to the entrance.
	k.cyl(Vector3(0.0, 0.0, 1.5), 3.05, 0.14, Color(0.86, 0.84, 0.78), Vector3.ZERO, false, 28)
	k.cyl(Vector3(0.0, 0.075, 1.5), 2.8, 0.12, K.WATER, Vector3.ZERO, false, 28, 0.0, 0.82)
	k.box(Vector3(0.0, 0.09, 1.55), Vector3(1.4, 0.18, 5.2), K.WOOD_LIGHT, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		k.box(Vector3(side * 0.7, 0.46, 1.55), Vector3(0.09, 0.09, 5.2), K.WOOD)
		for zz in [-1.6, 0.0, 1.6, 3.1]:
			k.cyl(Vector3(side * 0.7, 0.28, 1.55 + zz), 0.07, 0.5, K.WOOD, Vector3.ZERO, false, 6)

	# The academic building with its lighthouse tower.
	k.box(Vector3(0.0, 1.7, -4.4), Vector3(5.8, 3.4, 4.0), NAVY, Vector3.ZERO, true)
	k.box(Vector3(0.0, 3.5, -4.4), Vector3(6.0, 0.3, 4.2), K.WHITE)
	for i in 3:
		k.box(Vector3(-1.7 + float(i) * 1.7, 2.1, -2.36), Vector3(1.1, 1.2, 0.12), ICE, Vector3.ZERO, false, 2.0)
	k.box(Vector3(0.0, 1.15, -2.36), Vector3(1.3, 2.3, 0.16), Color(0.10, 0.18, 0.34))
	k.cyl(Vector3(3.1, 3.7, -3.4), 1.05, 7.4, NAVY, Vector3.ZERO, true, 12)
	k.cyl(Vector3(3.1, 2.7, -3.4), 1.12, 0.5, K.WHITE, Vector3.ZERO, false, 12)
	k.cyl(Vector3(3.1, 5.4, -3.4), 1.12, 0.5, K.WHITE, Vector3.ZERO, false, 12)
	k.cyl(Vector3(3.1, 7.55, -3.4), 1.45, 0.24, K.WHITE, Vector3.ZERO, false, 12)
	k.cyl(Vector3(3.1, 8.3, -3.4), 0.92, 1.3, ICE, Vector3.ZERO, false, 12, 2.6)
	k.cone(Vector3(3.1, 9.6, -3.4), 1.2, 1.3, RED, Vector3.ZERO, 10)
	k.light(Vector3(3.1, 8.3, -3.4), ICE, 3.2, 16.0)
	k.sphere(Vector3(3.1, 10.4, -3.4), 0.16, RED, 6, 4, 3.0)

	# The ship at the pier.
	var ship := Node3D.new()
	ship.position = Vector3(-1.7, 0.0, 1.9)
	ship.scale = Vector3.ONE * 0.75
	k.root.add_child(ship)
	var hull := k.box(Vector3.ZERO, Vector3.ONE, NAVY)
	hull.get_parent().remove_child(hull)
	ship.add_child(hull)
	hull.mesh.size = Vector3(1.9, 1.0, 4.6)
	hull.position = Vector3(0.0, 0.5, 0.0)
	var deck := k.box(Vector3.ZERO, Vector3.ONE, K.WHITE)
	deck.get_parent().remove_child(deck)
	ship.add_child(deck)
	deck.mesh.size = Vector3(1.75, 0.25, 4.3)
	deck.position = Vector3(0.0, 1.05, 0.0)
	var cabin := k.box(Vector3.ZERO, Vector3.ONE, K.WHITE)
	cabin.get_parent().remove_child(cabin)
	ship.add_child(cabin)
	cabin.mesh.size = Vector3(1.3, 0.9, 1.4)
	cabin.position = Vector3(0.0, 1.6, -1.3)
	var funnel := k.cyl(Vector3.ZERO, 0.28, 1.1, RED, Vector3.ZERO, false, 8)
	funnel.get_parent().remove_child(funnel)
	ship.add_child(funnel)
	funnel.position = Vector3(0.0, 1.85, -0.4)
	var mast := k.cyl(Vector3.ZERO, 0.07, 2.6, K.WOOD, Vector3.ZERO, false, 6)
	mast.get_parent().remove_child(mast)
	ship.add_child(mast)
	mast.position = Vector3(0.0, 2.4, 0.9)
	var flag := k.box(Vector3.ZERO, Vector3.ONE, RED)
	flag.get_parent().remove_child(flag)
	ship.add_child(flag)
	flag.mesh.size = Vector3(0.7, 0.4, 0.06)
	flag.position = Vector3(0.38, 3.5, 0.9)

	# Flags and navigation signs along the approach.
	for i in 3:
		var x := -3.0 + float(i) * 3.0
		k.cyl(Vector3(x, 1.3, 4.9), 0.08, 2.6, K.WHITE, Vector3.ZERO, false, 6)
		k.box(Vector3(x + 0.34, 2.3, 4.9), Vector3(0.68, 0.42, 0.05), RED if i % 2 == 0 else NAVY)
	k.box(Vector3(-1.9, 0.7, 3.9), Vector3(0.12, 1.4, 0.12), K.WHITE)
	k.box(Vector3(-1.9, 1.5, 3.9), Vector3(1.0, 0.5, 0.08), NAVY)
	k.sign(Vector3(0.0, 5.3, -3.0), "SMTU", 48, K.WHITE)
	k.landmark = Vector3(0.0, 0.0, -2.4)


# ---------------------------------------------------------------- 4. ITMO NIOKTR

## Science Garden: a glass research dome with geometric figures floating inside, an
## amphitheatre and lab modules among plants.
static func itmo(k: K) -> void:
	k.pad(7.2, Color(0.94, 0.95, 0.96))
	k.ring(6.5, CYAN)
	zone(k, "arcane", 3.0, Vector3(0.0, 0.0, -1.5))

	# The landmark: the round glass dome with floating geometry.
	k.cyl(Vector3(0.0, 0.2, -3.6), 3.5, 0.4, K.WHITE, Vector3.ZERO, false, 28)
	k.cyl(Vector3(0.0, 0.42, -3.6), 3.1, 0.12, Color(0.90, 0.94, 0.97), Vector3.ZERO, false, 28)
	k.sphere(Vector3(0.0, 0.46, -3.6), 3.15, K.GLASS, 20, 10, 0.0, 0.26, true)
	k.cyl(Vector3(0.0, 2.4, -3.6), 0.07, 4.4, CYAN, Vector3.ZERO, false, 8, 2.2)
	var shapes := [
		[Vector3(-1.1, 1.5, -3.6), 0.62, CYAN, 0],
		[Vector3(0.6, 2.5, -3.9), 0.55, FUCHSIA, 1],
		[Vector3(1.2, 1.1, -3.1), 0.5, VIVID, 2],
	]
	for s in shapes:
		var p: Vector3 = s[0]
		var r: float = s[1]
		var node: Node3D
		if int(s[3]) == 0:
			node = k.sphere(p, r, s[2], 4, 2, 1.8)
		elif int(s[3]) == 1:
			node = k.box(p, Vector3.ONE * r * 1.5, s[2], Vector3(0.7, 0.5, 0.3), false, 1.8)
		else:
			node = k.cone(p, r, r * 2.2, s[2], Vector3(0.0, 0.0, PI), 6, 1.8)
		k.spin(node, 0.7 + 0.3 * float(s[3]))
		k.bob(node, 0.22, 1.0 + 0.2 * float(s[3]), float(s[3]))
	k.light(Vector3(0.0, 2.2, -3.6), CYAN, 2.4, 13.0)

	# Amphitheatre of concentric steps.
	for i in 3:
		k.cyl(Vector3(-4.4, 0.13 + float(i) * 0.26, 1.8), 2.7 - float(i) * 0.6, 0.26, K.WHITE if i % 2 == 0 else ICE, Vector3.ZERO, true, 20)

	# Lab modules with screens showing abstract diagrams.
	var labs := [
		[Vector3(4.7, 0.0, -1.2), CYAN],
		[Vector3(5.3, 0.0, 1.5), FUCHSIA],
		[Vector3(3.6, 0.0, 3.4), VIVID],
	]
	for l in labs:
		var p: Vector3 = l[0]
		k.box(p + Vector3(0.0, 1.2, 0.0), Vector3(2.2, 2.4, 2.2), K.WHITE, Vector3.ZERO, true)
		k.box(p + Vector3(0.0, 2.5, 0.0), Vector3(2.32, 0.24, 2.32), l[1], Vector3.ZERO, false, 2.2)
		var face := Vector3(-p.x, 0.0, -p.z).normalized()
		k.screen(p + Vector3(0.0, 1.4, 0.0) + face * 1.16, Vector2(1.5, 1.0), l[1], Vector3(0.0, atan2(face.x, face.z), 0.0), 3)
	k.screen(Vector3(-1.6, 1.3, 2.6), Vector2(1.8, 1.1), CYAN, Vector3(0.0, 0.5, 0.0), 3)

	# Plants between the paths.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 16:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(2.6, 6.4)
		var p := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if absf(p.z + 3.6) < 3.0 and absf(p.x) < 3.0:
			continue
		k.sphere(p + Vector3(0.0, 0.34, 0.0), 0.36, LEAF_LIGHT, 6, 4)
		k.sphere(p + Vector3(0.14, 0.62, 0.1), 0.12, FUCHSIA if i % 2 == 0 else CYAN, 6, 4, 0.6)
	k.sign(Vector3(0.0, 5.6, -2.0), "ITMO NIOKTR", 40, K.WHITE)
	k.landmark = Vector3(0.0, 0.0, -1.5)
