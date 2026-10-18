extends RefCounted
## Landmark builders, part B: Dragontrans, Book At Home, Shots.

const K := preload("res://scripts/loc_kit.gd")

const RED := Color(0.86, 0.25, 0.24)
const NAVY := Color(0.13, 0.24, 0.45)
const CONCRETE := Color(0.80, 0.82, 0.84)
const ORANGE := Color(0.95, 0.62, 0.25)
const CREAM := Color(0.97, 0.94, 0.86)
const BOOK_GREEN := Color(0.20, 0.38, 0.27)
const ELECTRIC := Color(0.20, 0.50, 1.00)
const PINK := Color(0.98, 0.36, 0.66)
const LIME := Color(0.62, 0.88, 0.24)
const LEAF := Color(0.44, 0.68, 0.36)


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


# ---------------------------------------------------------------- 5. Dragontrans

## Port of Routes: a toy-like container terminal with a red gantry crane, a truck, a short
## rail spur and a cargo vessel, all linked by glowing route lines.
static func dragontrans(k: K) -> void:
	k.pad(7.1, CONCRETE)
	k.ring(6.5, RED)
	zone(k, "rage", 3.0, Vector3(0.0, 0.0, -3.4))

	# Glowing route lines tying the terminal, the ship and the truck together.
	k.line(Vector3(-4.2, 0.0, -0.6), Vector3(-1.2, 0.0, 2.2), 0.16, RED, 2.4)
	k.line(Vector3(-1.2, 0.0, 2.2), Vector3(2.0, 0.0, 3.4), 0.16, RED, 2.4)
	k.line(Vector3(-1.2, 0.0, 2.2), Vector3(0.6, 0.0, -1.0), 0.16, RED, 2.4)

	# The landmark: the red gantry crane with the branded sign.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 2.9, 3.0, -3.4 + sz * 1.5), Vector3(0.46, 6.0, 0.46), K.GRAPHITE, Vector3.ZERO, true)
	k.box(Vector3(0.0, 6.25, -3.4), Vector3(7.4, 0.8, 1.1), RED)
	k.box(Vector3(0.0, 6.25, -3.4), Vector3(7.5, 0.22, 1.2), K.WHITE, Vector3.ZERO, false, 0.8)
	k.box(Vector3(1.0, 5.6, -3.4), Vector3(0.9, 0.6, 0.7), RED, Vector3.ZERO, true)
	k.box(Vector3(1.0, 3.4, -3.4), Vector3(0.1, 4.0, 0.1), K.GRAPHITE)
	k.box(Vector3(1.0, 1.2, -3.4), Vector3(2.2, 1.1, 1.2), RED, Vector3.ZERO, true)
	k.sign(Vector3(0.0, 7.3, -3.4), "DRAGONTRANS", 46, K.WHITE)
	k.light(Vector3(0.0, 5.0, -3.4), RED, 1.6, 12.0)

	# Container terminal.
	var stacks := [
		[Vector3(-4.6, 0.0, -0.4), RED],
		[Vector3(-4.6, 1.20, -0.4), K.WHITE],
		[Vector3(-4.6, 0.0, 1.0), NAVY],
		[Vector3(-2.0, 0.0, -0.4), NAVY],
		[Vector3(-2.0, 0.0, 1.0), K.WHITE],
		[Vector3(-2.0, 1.20, 1.0), RED],
	]
	for s in stacks:
		k.box(s[0] + Vector3(0.0, 0.70, 0.0), Vector3(2.3, 1.2, 1.2), s[1], Vector3.ZERO, true)

	# Truck (one holder so the whole truck sits on the curve as one piece).
	var truck := Node3D.new()
	truck.position = Vector3(1.8, 0.0, 2.6)
	k.root.add_child(truck)
	var parts: Array[Node3D] = [
		k.box(Vector3(0.0, 1.35, -1.05), Vector3(2.0, 1.9, 2.2), K.WHITE),
		k.box(Vector3(0.0, 2.45, -1.05), Vector3(1.5, 0.7, 2.1), K.GLASS, Vector3.ZERO, false, 0.4, 0.6),
		k.box(Vector3(0.0, 1.1, 1.05), Vector3(1.9, 1.4, 2.1), K.GRAPHITE),
	]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			parts.append(k.cyl(Vector3(sx * 1.0, 0.38, sz * 1.2), 0.38, 0.3, K.DARK, Vector3(0.0, 0.0, PI * 0.5), false, 10))
	for p in parts:
		p.reparent(truck, false)
	var tb := StaticBody3D.new()
	var tcs := CollisionShape3D.new()
	var tsh := BoxShape3D.new()
	tsh.size = Vector3(2.0, 1.9, 4.3)
	tcs.shape = tsh
	tcs.position = Vector3(0.0, 1.2, 0.0)
	tb.add_child(tcs)
	truck.add_child(tb)

	# Short railway spur.
	for side in [-1.0, 1.0]:
		k.box(Vector3(-0.4, 0.16, 5.6 + side * 0.55), Vector3(5.2, 0.12, 0.1), K.GRAPHITE)
	for i in 5:
		k.box(Vector3(-2.6 + float(i) * 1.2, 0.08, 5.6), Vector3(0.5, 0.12, 1.5), K.WOOD)
	k.box(Vector3(-1.2, 0.55, 5.6), Vector3(2.4, 0.5, 1.4), RED, Vector3.ZERO, true)

	# Pier out into the real sea (+X faces the water); pieces over water float.
	for i in 4:
		var plank := k.box(Vector3(3.6 + float(i) * 1.5, 0.32, -0.6), Vector3(1.55, 0.18, 1.8), K.WOOD_LIGHT, Vector3.ZERO, true)
		plank.get_parent().set_meta("float", true)
		k.cyl(Vector3(3.6 + float(i) * 1.5, 0.0, 0.25), 0.1, 1.2, K.WOOD, Vector3.ZERO, false, 8).set_meta("float", true)
	k.line(Vector3(0.6, 0.0, -1.0), Vector3(3.2, 0.0, -0.6), 0.16, RED, 2.4)

	# Cargo vessel floating at the end of the pier.
	var ship := Node3D.new()
	ship.position = Vector3(9.4, 0.0, -0.6)
	ship.set_meta("float", true)
	k.root.add_child(ship)
	var hull: Array[Node3D] = [
		k.box(Vector3(0.0, 0.25, 0.0), Vector3(2.4, 1.2, 4.4), NAVY),
		k.box(Vector3(0.0, 0.95, 0.0), Vector3(2.2, 0.2, 4.2), K.WHITE),
		k.box(Vector3(0.0, 1.5, -1.5), Vector3(1.5, 0.9, 1.1), K.WHITE),
		k.cyl(Vector3(0.0, 2.2, -1.1), 0.24, 0.9, RED, Vector3.ZERO, false, 8),
		k.box(Vector3(0.0, 1.4, 0.6), Vector3(1.7, 0.7, 0.8), RED),
		k.box(Vector3(0.0, 1.4, 1.5), Vector3(1.7, 0.7, 0.8), K.WHITE),
	]
	for h in hull:
		h.reparent(ship, false)
	var sb := StaticBody3D.new()
	var scs := CollisionShape3D.new()
	var ssh := BoxShape3D.new()
	ssh.size = Vector3(2.4, 1.4, 4.4)
	scs.shape = ssh
	scs.position = Vector3(0.0, 0.4, 0.0)
	sb.add_child(scs)
	ship.add_child(sb)
	k.landmark = Vector3(0.0, 0.0, -3.4)


# ---------------------------------------------------------------- 6. Book At Home

## Garden of Stories: a bright library house and terrace under a huge open book, with
## pages and paper birds drifting around it.
static func book(k: K) -> void:
	k.pad(7.1, Color(0.50, 0.66, 0.40))
	k.ring(6.5, ORANGE)
	zone(k, "heal", 3.0, Vector3(0.0, 0.0, -3.2))

	# The landmark: a huge open book turned into a canopy.
	k.box(Vector3(-2.05, 1.9, -3.2), Vector3(0.3, 3.8, 0.3), K.DARK, Vector3.ZERO, true)
	k.box(Vector3(2.05, 1.9, -3.2), Vector3(0.3, 3.8, 0.3), K.DARK, Vector3.ZERO, true)
	k.box(Vector3(0.0, 3.9, -3.2), Vector3(0.34, 0.3, 3.2), BOOK_GREEN)
	for side in [-1.0, 1.0]:
		k.box(Vector3(side * 1.9, 4.45, -3.2), Vector3(3.7, 0.22, 3.0), CREAM, Vector3(0.0, 0.0, side * -0.28), true)
		k.box(Vector3(side * 1.95, 4.3, -3.2), Vector3(3.8, 0.14, 3.1), BOOK_GREEN, Vector3(0.0, 0.0, side * -0.28))
	k.box(Vector3(0.0, 4.6, -3.2), Vector3(0.5, 1.0, 3.2), BOOK_GREEN)
	k.light(Vector3(0.0, 3.4, -3.2), ORANGE, 2.4, 12.0)
	k.sign(Vector3(0.0, 5.6, -3.2), "BOOK AT HOME", 42, K.WHITE)

	# Floating pages and paper birds.
	var pages := [
		[Vector3(-1.5, 2.6, -1.4), 0.0],
		[Vector3(1.6, 3.1, -1.1), 0.7],
		[Vector3(0.2, 4.9, -1.6), 1.4],
		[Vector3(-2.6, 3.6, -2.2), 2.1],
		[Vector3(2.5, 2.2, -2.6), 2.8],
		[Vector3(-0.9, 3.3, -4.6), 3.5],
	]
	for p in pages:
		var page := k.box(p[0], Vector3(0.62, 0.03, 0.86), CREAM, Vector3(0.2, float(p[1]), 0.35), false, 0.5)
		k.spin(page, 0.9)
		k.bob(page, 0.24, 1.1, float(p[1]))

	# The library house.
	k.box(Vector3(-4.5, 1.5, -1.8), Vector3(2.8, 3.0, 2.6), CREAM, Vector3.ZERO, true)
	k.cone(Vector3(-4.5, 3.6, -1.8), 2.3, 1.5, ORANGE, Vector3.ZERO, 4)
	k.box(Vector3(-4.5, 1.1, -0.46), Vector3(0.9, 2.2, 0.14), K.DARK)
	k.box(Vector3(-3.6, 2.0, -0.48), Vector3(0.9, 0.9, 0.12), ORANGE, Vector3.ZERO, false, 2.6)
	k.box(Vector3(-5.4, 2.0, -0.48), Vector3(0.9, 0.9, 0.12), ORANGE, Vector3.ZERO, false, 2.6)

	# Terrace with lanterns.
	k.box(Vector3(3.9, 0.12, -1.2), Vector3(3.0, 0.24, 2.8), K.WOOD_LIGHT, Vector3.ZERO, true)
	for sx in [-1.0, 1.0]:
		k.cyl(Vector3(3.9 + sx * 1.4, 0.85, -2.5), 0.08, 1.3, K.WOOD, Vector3.ZERO, false, 6)
		k.cyl(Vector3(3.9 + sx * 1.4, 0.85, 0.1), 0.08, 1.3, K.WOOD, Vector3.ZERO, false, 6)
	k.box(Vector3(3.9, 0.88, -1.2), Vector3(1.4, 0.12, 1.4), K.WOOD)
	k.cyl(Vector3(3.9, 0.55, -1.2), 0.14, 0.7, K.WOOD, Vector3.ZERO, false, 8)
	k.lantern(Vector3(1.2, 0.0, 1.6), ORANGE)
	k.lantern(Vector3(-2.4, 0.0, 1.4), ORANGE)
	k.lantern(Vector3(5.6, 0.0, 1.2), ORANGE)

	# Individual flowers only: the library stays quiet and does not become a flower bed.
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	for i in 4:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(1.8, 6.3)
		var p := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if p.z < -0.5 and p.x > -6.0 and p.x < 2.6:
			continue
		k.flowers(p + Vector3(0.0, 0.02, 0.0), rng.randf_range(0.09, 0.13), rng.randf() * TAU, i + 6)
	k.landmark = Vector3(0.0, 0.0, -3.2)


# ---------------------------------------------------------------- 7. Shots

## Interface Gallery: a low white stage under an arch of screens spelling SHOTS, ringed by
## interface portals and rotating concept cards.
static func shots(k: K) -> void:
	k.pad(7.1, Color(0.93, 0.94, 0.96))
	k.ring(6.5, ELECTRIC)
	zone(k, "mana", 3.0, Vector3(0.0, 0.0, -2.6))

	# The elevated stage, with a ramp up from where the player arrives.
	k.cyl(Vector3(0.0, 0.35, 0.0), 4.6, 0.7, K.WHITE, Vector3.ZERO, true, 28)
	k.cyl(Vector3(0.0, 0.72, 0.0), 4.5, 0.06, Color(0.97, 0.98, 0.99), Vector3.ZERO, false, 28)
	for i in 3:
		k.box(Vector3(0.0, 0.05 + 0.2333 * float(i), 6.267 - 0.667 * float(i)), Vector3(2.2, 0.14, 0.7), K.WHITE, Vector3(0.3367, 0.0, 0.0), true)

	# The landmark: a tall arch built out of screens, with the word SHOTS above it.
	for side in [-1.0, 1.0]:
		for i in 3:
			k.screen(Vector3(side * 2.3, 1.5 + float(i) * 1.55, -2.6), Vector2(1.7, 1.35), [ELECTRIC, PINK, LIME][(i + (0 if side < 0.0 else 1)) % 3], Vector3(0.0, 0.0, 0.0), 3)
		k.box(Vector3(side * 2.3, 1.5, -2.6), Vector3(0.2, 5.4, 0.2), K.WHITE)
	k.screen(Vector3(0.0, 6.0, -2.6), Vector2(4.2, 1.4), ELECTRIC, Vector3.ZERO, 2)
	k.sign(Vector3(0.0, 7.4, -2.6), "SHOTS", 78, K.WHITE)
	k.light(Vector3(0.0, 4.0, -2.6), ELECTRIC, 2.2, 13.0)

	# Vertical interface portals around the stage.
	var portals := [
		[Vector3(-3.5, 0.7, 1.6), PINK],
		[Vector3(3.6, 0.7, 1.3), LIME],
		[Vector3(-2.0, 0.7, 3.4), ORANGE],
		[Vector3(2.2, 0.7, 3.5), ELECTRIC],
	]
	for p in portals:
		var pos: Vector3 = p[0]
		var face := Vector3(-pos.x, 0.0, -pos.z).normalized()
		var yaw := atan2(face.x, face.z)
		k.box(pos + Vector3(0.0, 1.7, 0.0), Vector3(0.18, 3.4, 1.9), K.WHITE, Vector3(0.0, yaw, 0.0), true)
		k.box(pos + Vector3(0.0, 1.7, 0.0) + face * 0.12, Vector3(0.1, 3.0, 1.5), p[1], Vector3(0.0, yaw, 0.0), false, 2.0)

	# Rotating concept cards on poles.
	var cards := [
		[Vector3(-3.0, 0.0, -0.6), ELECTRIC],
		[Vector3(3.0, 0.0, -0.9), PINK],
		[Vector3(-1.1, 0.0, 2.4), LIME],
		[Vector3(1.3, 0.0, 2.2), ORANGE],
		[Vector3(0.0, 0.0, -1.0), K.WHITE],
	]
	for c in cards:
		var pos: Vector3 = c[0]
		k.cyl(pos + Vector3(0.0, 1.0, 0.0), 0.09, 2.0, K.GRAPHITE, Vector3.ZERO, true, 8)
		var card := k.box(pos + Vector3(0.0, 2.2, 0.0), Vector3(1.7, 1.05, 0.09), c[1], Vector3.ZERO, false, 1.4)
		k.spin(card, 0.8)

	# Colourful objects scattered on the stage.
	k.sphere(Vector3(-3.4, 1.05, -2.6), 0.34, PINK, 8, 6)
	k.sphere(Vector3(3.4, 1.05, -2.8), 0.34, LIME, 8, 6)
	k.box(Vector3(-1.0, 1.05, -4.2), Vector3(0.7, 0.7, 0.7), ORANGE, Vector3(0.4, 0.5, 0.0))
	k.box(Vector3(1.2, 1.05, -4.0), Vector3(0.7, 0.7, 0.7), ELECTRIC, Vector3(0.2, 0.9, 0.3))
	k.landmark = Vector3(0.0, 0.0, -2.6)
