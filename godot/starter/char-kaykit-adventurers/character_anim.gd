extends Node3D
## Character animation helper (Summer starter shelf). Sits on the root of a character scene.
## Plays clips by standard name and drives idle / walk / run / jump / fall from movement speed.
##
## Standard names: idle, walk, run, jump, fall, attack, hit, death, plus any extra key in `clips`
## (for example "cheer", "cast", "block"). A name that is not a key is used as a raw clip name.
##
## One-step use: instance the character as a child of a CharacterBody3D. With `auto_from_parent`
## on (default) it reads the body's velocity every physics frame, picks idle/walk/run/jump/fall,
## syncs the playback rate to ground speed and turns to face the direction of travel.
## Manual use: set auto_from_parent = false and call set_move_speed(speed, on_floor) yourself.
## Actions: play_action("attack") plays a one-shot and returns to locomotion when it ends.
## die() plays "death" and holds the last frame; revive() returns to idle.

signal action_finished(action: String)

## Standard name -> clip name in this model's AnimationPlayer.
@export var clips: Dictionary = {}
## Clips that must loop (standard or raw names). idle/walk/run/fall always loop.
@export var loop_clips: PackedStringArray = []
## Ground speed in m/s that the walk clip matches at playback rate 1.
@export var walk_clip_speed := 1.5
## Ground speed in m/s that the run clip matches at playback rate 1.
@export var run_clip_speed := 4.5
## At or above this ground speed (m/s) the run clip plays instead of walk.
@export var run_threshold := 2.6
@export var blend_time := 0.15
## Read velocity from a CharacterBody3D parent every physics frame.
@export var auto_from_parent := true
## Turn to face the horizontal velocity (only with auto_from_parent).
@export var face_movement := true
@export var turn_speed := 12.0
## Attachment meshes (weapons, props) to show. Names listed in optional_props but not here are hidden.
@export var show_props: PackedStringArray = []
@export var optional_props: PackedStringArray = []
## Material name -> Color: recolours flat-colour materials (for example team uniforms).
@export var recolor: Dictionary = {}

var anim: AnimationPlayer
var _action := ""
var _dead := false
var _speed := 0.0
var _on_floor := true
var _loco := ""


func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("character_anim: no AnimationPlayer under %s" % name)
		return
	anim = players[0] as AnimationPlayer
	for n: String in ["idle", "walk", "run", "fall"] + Array(loop_clips):
		var clip := _clip(n)
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.animation_finished.connect(_on_animation_finished)
	apply_props()
	apply_recolor()
	_set_loco("idle")


## Re-applies show_props / optional_props (call after changing show_props at runtime).
func apply_props() -> void:
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		if optional_props.has(String(mi.name)):
			(mi as Node3D).visible = show_props.has(String(mi.name))


## Re-applies `recolor` (material name -> Color) to every surface using those materials.
func apply_recolor() -> void:
	if recolor.is_empty():
		return
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat and recolor.has(mat.resource_name):
				var m := mat.duplicate() as BaseMaterial3D
				m.albedo_color = recolor[mat.resource_name]
				mi.set_surface_override_material(i, m)


func has_clip(action: String) -> bool:
	return anim != null and anim.has_animation(_clip(action))


## Feed ground speed (m/s) and floor contact when auto_from_parent is off.
func set_move_speed(speed: float, on_floor := true) -> void:
	_speed = speed
	_on_floor = on_floor
	_update_locomotion()


## Plays a one-shot clip by standard or raw name. Returns its duration in seconds (0 if missing).
func play_action(action: String, rate := 1.0) -> float:
	if anim == null or _dead:
		return 0.0
	if action == "death":
		return die()
	var clip := _clip(action)
	if not anim.has_animation(clip):
		return 0.0
	_action = action
	_loco = ""
	anim.speed_scale = 1.0
	anim.play(clip, blend_time * 0.5, rate)
	anim.seek(0.0, true)
	return anim.get_animation(clip).length / maxf(rate, 0.01)


## Ends a looping action (for example "sit" or "block") and returns to locomotion.
func stop_action() -> void:
	_action = ""
	_update_locomotion()


func is_busy() -> bool:
	return _action != ""


func is_dead() -> bool:
	return _dead


## Plays "death" and holds its last frame. Returns the clip length.
func die() -> float:
	if anim == null or _dead:
		return 0.0
	_dead = true
	_action = ""
	var clip := _clip("death")
	if not anim.has_animation(clip):
		return 0.0
	anim.get_animation(clip).loop_mode = Animation.LOOP_NONE
	anim.speed_scale = 1.0
	anim.play(clip, blend_time)
	return anim.get_animation(clip).length


func revive() -> void:
	_dead = false
	_action = ""
	_loco = ""
	_set_loco("idle")


func _clip(action: String) -> String:
	return String(clips.get(action, action))


func _physics_process(delta: float) -> void:
	if not auto_from_parent or anim == null:
		return
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	var v := body.velocity
	_speed = Vector2(v.x, v.z).length()
	_on_floor = body.is_on_floor()
	if face_movement and _speed > 0.2 and not _dead:
		var yaw := atan2(-v.x, -v.z)
		global_rotation.y = lerp_angle(global_rotation.y, yaw, 1.0 - exp(-turn_speed * delta))
	_update_locomotion()


func _update_locomotion() -> void:
	if anim == null or _dead or _action != "":
		return
	if not _on_floor:
		if _loco != "jump" and _loco != "fall":
			_set_loco("jump" if has_clip("jump") else "fall")
		elif _loco == "jump" and not anim.is_playing():
			_set_loco("fall")
		return
	if _speed < 0.15:
		_set_loco("idle")
	elif _speed < run_threshold or not has_clip("run"):
		_set_loco("walk", clampf(_speed / walk_clip_speed, 0.5, 2.0))
	else:
		_set_loco("run", clampf(_speed / run_clip_speed, 0.6, 2.0))


func _set_loco(action: String, rate := 1.0) -> void:
	var clip := _clip(action)
	if not anim.has_animation(clip):
		return
	anim.speed_scale = rate
	if _loco != action:
		_loco = action
		anim.play(clip, blend_time)


func _on_animation_finished(clip: StringName) -> void:
	if _action != "" and String(clip) == _clip(_action):
		var done := _action
		_action = ""
		action_finished.emit(done)
		_update_locomotion()
