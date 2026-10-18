extends Node3D
## A compact electric scooter with arcade-style inertia for the portfolio planet.
## It stays glued to the curved ground rather than using a flat-world vehicle body.

const DECK_COLOR := Color("253245")
const ACCENT_COLOR := Color("ff6b37")
const RUBBER := Color("10151d")

@export var max_speed := 8.0
@export var reverse_speed := 2.0
@export var acceleration := 7.8
@export var brake_force := 12.0
@export var coast_drag := 1.25
@export var turn_rate := 1.55

var planet: StaticBody3D
var rider: CharacterBody3D
var active := false
var speed := 0.0
var _steer := 0.0
var _front_fork: Node3D
var _front_wheel: Node3D
var _back_wheel: Node3D
var _left_handle: Node3D
var _right_handle: Node3D
var _motor: AudioStreamPlayer
var _motor_playback: AudioStreamGeneratorPlayback
var _phase := 0.0


func setup(planet_ref: StaticBody3D, rider_ref: CharacterBody3D) -> void:
	planet = planet_ref
	rider = rider_ref
	_build_model()
	_setup_motor()


func place_on_planet(dir: Vector3, yaw := 0.0) -> void:
	if planet == null:
		return
	var up := dir.normalized()
	var reference := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var forward := (reference - up * reference.dot(up)).normalized().rotated(up, yaw)
	_set_surface_transform(up, forward)


func mount() -> void:
	if active or rider == null:
		return
	active = true
	rider.call("mount_scooter", self, _left_handle, _right_handle)
	if _motor and not _motor.playing:
		_motor.play()


func dismount() -> void:
	if not active:
		return
	active = false
	speed *= 0.45
	if rider:
		rider.call("dismount_scooter", self)


func rider_transform() -> Transform3D:
	var up := (global_position - planet.global_position).normalized()
	var forward := -global_basis.z.normalized()
	# Player's origin is at the feet, just above the deck.
	return Transform3D(global_basis, global_position + up * 0.38 + forward * 0.08)


func _physics_process(delta: float) -> void:
	if not active or planet == null:
		return
	var throttle := Input.get_axis("move_back", "move_forward")
	var steering := Input.get_axis("move_left", "move_right")
	if throttle > 0.0:
		speed = move_toward(speed, max_speed * throttle, acceleration * delta)
	elif throttle < 0.0:
		# Reverse doubles as a strong, intuitive brake while moving forward.
		var target := -reverse_speed * -throttle
		speed = move_toward(speed, target, brake_force * delta)
	else:
		speed = move_toward(speed, 0.0, coast_drag * delta)

	var up := (global_position - planet.global_position).normalized()
	var forward := -global_basis.z
	forward = (forward - up * forward.dot(up)).normalized()
	var speed_ratio := clampf(absf(speed) / max_speed, 0.0, 1.0)
	_steer = move_toward(_steer, steering * 0.48, delta * 2.8)
	if absf(speed) > 0.03:
		var yaw := _steer * turn_rate * (0.25 + speed_ratio * 0.75) * signf(speed) * delta
		forward = forward.rotated(up, yaw).normalized()
	var next_pos := global_position + forward * speed * delta
	var next_dir := (next_pos - planet.global_position).normalized()
	_set_surface_transform(next_dir, forward)
	_update_visuals(delta)


func _process(_delta: float) -> void:
	_feed_motor()


func _set_surface_transform(up: Vector3, desired_forward: Vector3) -> void:
	var forward := (desired_forward - up * desired_forward.dot(up)).normalized()
	var right := forward.cross(up).normalized()
	global_basis = Basis(right, up, -forward).orthonormalized()
	global_position = planet.surface_point(up) + up * 0.04


func _update_visuals(delta: float) -> void:
	if _front_fork:
		_front_fork.rotation.y = _steer
	var wheel_turn := speed * delta / 0.18
	if _front_wheel:
		_front_wheel.rotate_x(wheel_turn)
	if _back_wheel:
		_back_wheel.rotate_x(wheel_turn)


func _setup_motor() -> void:
	_motor = AudioStreamPlayer.new()
	_motor.name = "ScooterRidingSound"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.25
	_motor.stream = stream
	_motor.volume_db = -70.0
	add_child(_motor)
	_motor.play()
	_motor_playback = _motor.get_stream_playback() as AudioStreamGeneratorPlayback


func _feed_motor() -> void:
	if _motor_playback == null:
		if _motor:
			_motor_playback = _motor.get_stream_playback() as AudioStreamGeneratorPlayback
		return
	var intensity := clampf(absf(speed) / max_speed, 0.0, 1.0) if active else 0.0
	_motor.volume_db = lerpf(-62.0, -15.0, intensity)
	var frames: int = mini(_motor_playback.get_frames_available(), 1024)
	var rate := 22050.0
	var tone := 62.0 + intensity * 390.0
	for i in frames:
		_phase = fmod(_phase + TAU * tone / rate, TAU)
		var harmonic := sin(_phase) * 0.62 + sin(_phase * 2.02) * 0.25 + sin(_phase * 0.5) * 0.13
		var amplitude := lerpf(0.005, 0.115, intensity)
		var sample := harmonic * amplitude
		_motor_playback.push_frame(Vector2(sample, sample))


func _build_model() -> void:
	var metal := _material(DECK_COLOR, 0.38)
	var orange := _material(ACCENT_COLOR, 0.26)
	var black := _material(RUBBER, 0.92)
	var silver := _material(Color("d9e7ef"), 0.23)

	_box("Deck", Vector3(0.28, 0.09, 1.12), Vector3(0.0, 0.28, 0.08), metal)
	_box("Grip", Vector3(0.23, 0.025, 0.68), Vector3(0.0, 0.345, 0.10), black)
	_box("TailLight", Vector3(0.15, 0.08, 0.05), Vector3(0.0, 0.35, 0.61), orange)

	_back_wheel = _wheel("BackWheel", Vector3(0.0, 0.18, 0.48), black)
	_front_fork = Node3D.new()
	_front_fork.name = "FrontFork"
	_front_fork.position = Vector3(0.0, 0.32, -0.43)
	add_child(_front_fork)
	_front_wheel = _wheel("FrontWheel", Vector3(0.0, -0.14, 0.02), black, _front_fork)
	_cylinder("Stem", 0.035, 0.035, 0.84, Vector3(0.0, 0.34, 0.0), silver, _front_fork, Vector3(deg_to_rad(-11.0), 0.0, 0.0))
	_box("Handlebar", Vector3(0.72, 0.055, 0.06), Vector3(0.0, 0.77, -0.13), silver, _front_fork)
	_box("LeftGrip", Vector3(0.16, 0.075, 0.075), Vector3(-0.42, 0.77, -0.13), black, _front_fork)
	_box("RightGrip", Vector3(0.16, 0.075, 0.075), Vector3(0.42, 0.77, -0.13), black, _front_fork)
	_left_handle = Node3D.new()
	_left_handle.name = "LeftHandTarget"
	_left_handle.position = Vector3(-0.39, 0.80, -0.13)
	_front_fork.add_child(_left_handle)
	_right_handle = Node3D.new()
	_right_handle.name = "RightHandTarget"
	_right_handle.position = Vector3(0.39, 0.80, -0.13)
	_front_fork.add_child(_right_handle)


func _wheel(name_: String, pos: Vector3, material: Material, parent: Node3D = null) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = pos
	(parent if parent else self).add_child(pivot)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.17
	mesh.bottom_radius = 0.17
	mesh.height = 0.075
	mesh.radial_segments = 14
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.rotation.z = PI * 0.5
	pivot.add_child(node)
	return pivot


func _box(name_: String, size: Vector3, pos: Vector3, material: Material, parent: Node3D = null) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.position = pos
	(parent if parent else self).add_child(node)


func _cylinder(name_: String, top: float, bottom: float, height: float, pos: Vector3, material: Material, parent: Node3D = null, rot := Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.position = pos
	node.rotation = rot
	(parent if parent else self).add_child(node)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.24 if roughness < 0.5 else 0.0
	material.roughness = roughness
	return material
