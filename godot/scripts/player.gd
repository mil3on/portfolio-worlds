extends CharacterBody3D
## Third-person walker on a spherical planet. Body Y always points away from the planet centre.

signal stepped(world_pos: Vector3, up: Vector3, running: bool)

@export var planet_center := Vector3.ZERO
@export var walk_speed := 2.6
@export var run_speed := 4.8
## Vertical camera limits in radians (negative looks down at the player).
@export var pitch_min := -1.15
@export var pitch_max := 0.35
@export var jump_velocity := 6.5
@export var gravity := 18.0
@export var mouse_sensitivity := 0.0025

var input_enabled := true
var _scooter: Node3D
var _collision_was_disabled := false

@onready var cam_yaw: Node3D = $CameraYaw
@onready var spring: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var model: Node3D = $Model

var _yaw := 0.0
var _pitch := -0.22
var _step_left := 0.0
@onready var cam_pitch: Node3D = $CameraYaw/CameraPitch


func _ready() -> void:
	add_to_group("player")
	spring.add_excluded_object(get_rid())
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.5
	cam_pitch.rotation = Vector3(_pitch, 0.0, 0.0)
	_align()


func play_interaction() -> void:
	if model.has_method("play_interaction"):
		model.play_interaction()


func mount_scooter(scooter: Node3D, left_handle: Node3D, right_handle: Node3D) -> void:
	_scooter = scooter
	_collision_was_disabled = $Collision.disabled
	$Collision.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	model.rotation.y = 0.0
	if model.has_method("set_riding"):
		model.set_riding(true, left_handle, right_handle)


func dismount_scooter(scooter: Node3D) -> void:
	if _scooter != scooter:
		return
	var up := scooter.global_basis.y.normalized()
	var right := scooter.global_basis.x.normalized()
	global_position = scooter.global_position + right * 0.85 + up * 0.32
	global_basis = scooter.global_basis
	_scooter = null
	$Collision.set_deferred("disabled", _collision_was_disabled)
	if model.has_method("set_riding"):
		model.set_riding(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion:
		# Orbit 360 degrees: with the cursor captured, or while holding any mouse button.
		var dragging: bool = event.button_mask != 0
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or dragging:
			_yaw -= event.relative.x * mouse_sensitivity
			_yaw = wrapf(_yaw, -PI, PI)
			cam_yaw.rotation.y = _yaw
			_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, pitch_min, pitch_max)
			cam_pitch.rotation = Vector3(_pitch, 0.0, 0.0)


func _align() -> void:
	var up := (global_position - planet_center).normalized()
	var cur := global_basis.orthonormalized()
	var q := Quaternion(cur.y.normalized(), up)
	global_basis = Basis(q) * cur
	up_direction = up


func _physics_process(delta: float) -> void:
	if _scooter != null:
		global_transform = _scooter.call("rider_transform")
		up_direction = global_basis.y.normalized()
		velocity = Vector3.ZERO
		if model.has_method("set_move_speed"):
			model.set_move_speed(0.0, true)
		return
	_align()
	var up := up_direction
	var vert := velocity.dot(up)
	var tangent := velocity - up * vert

	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
			pass
	var cb := cam_yaw.global_basis
	var fwd := -cb.z
	var right := cb.x
	var dir := (right * input.x - fwd * input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := run_speed if (input_enabled and Input.is_action_pressed("sprint")) else walk_speed
	var accel := 10.0 if is_on_floor() else 3.0
	tangent = tangent.lerp(dir * speed, 1.0 - exp(-accel * delta))

	vert -= gravity * delta
	if is_on_floor() and input_enabled and Input.is_action_just_pressed("jump"):
		vert = jump_velocity

	velocity = tangent + up * vert
	move_and_slide()

	# A compact, speed-driven step event powers both the grass sound and the small
	# ground puffs. Keeping it here means the effects stay in sync with movement.
	_step_left -= delta
	if is_on_floor() and tangent.length() > 0.35 and _step_left <= 0.0:
		var running := tangent.length() >= run_threshold()
		_step_left = 0.29 if running else 0.47
		stepped.emit(global_position - up * 0.78, up, running)
	elif tangent.length() <= 0.35:
		_step_left = minf(_step_left, 0.08)

	# Face movement in the body's local frame (KayKit models face -Z).
	if dir.length() > 0.1:
		var local_dir := global_basis.orthonormalized().inverse() * dir
		var target := atan2(-local_dir.x, -local_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, 1.0 - exp(-12.0 * delta))
	if model.has_method("set_move_speed"):
		model.set_move_speed(tangent.length(), is_on_floor())


func run_threshold() -> float:
	return (walk_speed + run_speed) * 0.5
