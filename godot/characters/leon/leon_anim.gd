extends Node3D
## Locomotion driver for the Leon character (lives next to the model at res://characters/leon/).
##
## res://scripts/player.gd calls set_move_speed(speed, on_floor) on the node named
## "Model" every physics frame and rotates that node to face the movement direction.
## This driver picks the clip from ground speed and floor contact:
##   speed < idle_speed       -> "idle"
##   speed < run_threshold    -> "walk" (playback rate synced to ground speed)
##   speed >= run_threshold   -> "run"  (playback rate synced to ground speed)
##   on_floor == false        -> "jump", played once and held while airborne
##
## Clip names are resolved from the model, so provider clip names ("Walk", "walking", ...)
## all map to the same actions. Clips that are not inside the rig file are merged in from
## compact Animation resources on ready.

## Action name -> animation name in the shared Mixamo rig.
@export var clips: Dictionary = {
	"idle": "mixamo_com",
	"idle_alt_1": "IdleVariation1",
	"idle_alt_2": "IdleVariation2",
	"walk": "SwaggerWalk",
	"run": "StandardRun",
	"jump": "Jump",
	"run_jump": "RunningJump",
	"interact": "Waving",
	"fall": "Jump",
}
## Action -> compact Animation resource exported from the supplied FBX. Every file uses the
## same Mixamo skeleton, so the data is copied directly without procedural retargeting.
@export var animation_sources: Dictionary = {}
## Ground speed in m/s that matches the walk clip at playback rate 1.
@export var walk_clip_speed := 1.6
## Ground speed in m/s that matches the run clip at playback rate 1.
@export var run_clip_speed := 4.2
## At or above this ground speed (m/s) the run clip plays instead of walk.
@export var run_threshold := 3.4
## Below this ground speed (m/s) the idle clip plays.
@export var idle_speed := 0.15
@export var blend_time := 0.2
## Fit the model to target_height and drop its feet onto the model root (y = 0) on ready.
@export var normalize_on_ready := true
@export var target_height := 1.75

var anim: AnimationPlayer
var _speed := 0.0
var _on_floor := true
var _loco := ""
var _resolved: Dictionary = {}
var _rig_scale0 := Vector3.ZERO
var _t := 0.0
var _interaction_left := 0.0
var _idle_variation_left := 0.0
var _idle_variation_active := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	if normalize_on_ready:
		_normalize()
	anim = _resolve_player()
	if anim == null:
		push_warning("leon_anim: no AnimationPlayer under %s" % name)
		return
	_resolve_clips()
	_absorb_animation_sources()
	_resolve_clips()
	for action: String in ["idle", "walk", "run"]:
		var clip := _clip(action)
		if clip != "":
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for action: String in ["idle_alt_1", "idle_alt_2"]:
		var variation := _clip(action)
		if variation != "":
			anim.get_animation(variation).loop_mode = Animation.LOOP_NONE
	for action: String in ["jump", "run_jump", "interact"]:
		var one_shot := _clip(action)
		if one_shot != "":
			anim.get_animation(one_shot).loop_mode = Animation.LOOP_NONE
	_set_loco("idle")
	var rig := _rig_node()
	if rig:
		_rig_scale0 = rig.scale
	_schedule_idle_variation()


## Procedural layer while real idle/jump clips are missing: gentle breathing at rest
## and a small stretch in the air. Turns itself off once those clips exist.
func _process(delta: float) -> void:
	_interaction_left = maxf(0.0, _interaction_left - delta)
	_update_idle_variation(delta)
	var rig := _rig_node()
	if rig == null or _rig_scale0 == Vector3.ZERO:
		return
	_t += delta
	var sy := 1.0
	var sxz := 1.0
	if _loco == "idle" and not has_clip("idle"):
		sy = 1.0 + 0.012 * sin(_t * 2.1)
		sxz = 1.0 + 0.006 * sin(_t * 2.1 + 0.4)
	elif _loco == "air":
		sy = 1.04
		sxz = 0.98
	var target := Vector3(_rig_scale0.x * sxz, _rig_scale0.y * sy, _rig_scale0.z * sxz)
	rig.scale = rig.scale.lerp(target, 1.0 - exp(-10.0 * delta))


func _schedule_idle_variation() -> void:
	_idle_variation_left = _random.randf_range(6.0, 11.0)


func _update_idle_variation(delta: float) -> void:
	if anim == null or _loco != "idle" or _interaction_left > 0.0:
		return
	if _idle_variation_active:
		if not anim.is_playing():
			_idle_variation_active = false
			_schedule_idle_variation()
			_set_loco("idle")
		return
	_idle_variation_left -= delta
	if _idle_variation_left > 0.0:
		return
	var candidates: Array[String] = []
	for action in ["idle_alt_1", "idle_alt_2"]:
		if has_clip(action):
			candidates.append(action)
	if candidates.is_empty():
		_schedule_idle_variation()
		return
	_idle_variation_active = true
	anim.play(_clip(candidates[_random.randi_range(0, candidates.size() - 1)]), blend_time)


## Called by res://scripts/player.gd every physics frame.
func set_move_speed(speed: float, on_floor := true) -> void:
	_speed = speed
	_on_floor = on_floor
	_update_locomotion()


## Current locomotion state: "idle", "walk", "run", "jump" or "fall".
func get_locomotion() -> String:
	return _loco


## Plays the supplied `use.fbx` gesture when opening a nearby case.
func play_interaction() -> void:
	if anim == null or not has_clip("interact"):
		return
	var clip := _clip("interact")
	_interaction_left = anim.get_animation(clip).length
	_set_loco("interact")


func has_clip(action: String) -> bool:
	return _clip(action) != ""


## Every action this model can actually play.
func available_actions() -> Array:
	return _resolved.keys()


func _clip(action: String) -> String:
	return String(_resolved.get(action, ""))


func _resolve_player() -> AnimationPlayer:
	var players := find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		return players[0] as AnimationPlayer
	var rig := _rig_node()
	var made := AnimationPlayer.new()
	made.name = "LeonAnim"
	add_child(made)
	if rig != null:
		made.root_node = made.get_path_to(rig)
	return made


func _main_library() -> AnimationLibrary:
	var lib := anim.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		anim.add_animation_library("", lib)
	return lib


func _first_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	var found := root.find_children("*", "AnimationPlayer", true, false)
	return (found[0] as AnimationPlayer) if not found.is_empty() else null


## Pulls in compact clips extracted from the supplied Mixamo FBX files. They all target the
## exact same Skeleton3D hierarchy as the main character FBX, so no bone-name mapping is needed.
func _absorb_animation_sources() -> void:
	if animation_sources.is_empty():
		return
	var main_lib := _main_library()
	for action: String in animation_sources.keys():
		if has_clip(action):
			continue
		var path := String(animation_sources[action])
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var source := load(path) as Animation
		if source == null:
			continue
		main_lib.add_animation(String(clips.get(action, action)), _copy_mixamo_clip(source))


## The controller owns horizontal travel. Keep each imported animation in place,
## including files that were downloaded with forward root motion.
func _copy_mixamo_clip(source: Animation) -> Animation:
	var clip := source.duplicate(true) as Animation
	for track_i in clip.get_track_count():
		if clip.track_get_type(track_i) != Animation.TYPE_POSITION_3D:
			continue
		if String(clip.track_get_path(track_i).get_concatenated_subnames()) != "mixamorig_Hips":
			continue
		for key_i in clip.track_get_key_count(track_i):
			var position := clip.track_get_key_value(track_i, key_i) as Vector3
			position.x = 0.0
			position.z = 0.0
			clip.track_set_key_value(track_i, key_i, position)
	return clip


func _first_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	if root is Skeleton3D:
		return root as Skeleton3D
	var found := root.find_children("*", "Skeleton3D", true, false)
	return (found[0] as Skeleton3D) if not found.is_empty() else null


func _skeleton_height(skeleton: Skeleton3D) -> float:
	var lo := INF
	var hi := -INF
	for i in skeleton.get_bone_count():
		var y := skeleton.get_bone_global_rest(i).origin.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo


func _resolve_clips() -> void:
	_resolved.clear()
	var names: PackedStringArray = PackedStringArray()
	for lib_name: StringName in anim.get_animation_library_list():
		var lib := anim.get_animation_library(lib_name)
		for clip: StringName in lib.get_animation_list():
			names.append(String(clip))
	for action: String in clips.keys():
		var hit := _match(String(clips[action]), action, names)
		if hit != "":
			_resolved[action] = hit


func _match(wanted: String, action: String, names: PackedStringArray) -> String:
	for n in names:
		if n == wanted:
			return n
	for n in names:
		if n.to_lower() == wanted.to_lower():
			return n
	for n in names:
		var low := n.to_lower()
		if low.contains(wanted.to_lower()) or low.contains(action.to_lower()):
			return n
	return ""


func _update_locomotion() -> void:
	if anim == null:
		return
	if _interaction_left > 0.0:
		return
	if _idle_variation_active and (_speed >= idle_speed or not _on_floor):
		_idle_variation_active = false
	if not _on_floor:
		if _loco != "jump" and _loco != "fall" and _loco != "air":
			if _speed >= run_threshold and has_clip("run_jump"):
				_set_loco("run_jump")
			elif has_clip("jump"):
				_set_loco("jump")
			elif has_clip("fall"):
				_set_loco("fall")
			elif has_clip("walk"):
				# No jump clip yet: hold a mid-stride pose from the walk cycle in the air.
				_loco = "air"
				var walk := _clip("walk")
				anim.play(walk, 0.1)
				anim.speed_scale = 0.0
				anim.seek(anim.get_animation(walk).length * 0.1, true)
		return
	if _speed < idle_speed:
		if not _idle_variation_active:
			_set_loco("idle")
	elif _speed < run_threshold or not has_clip("run"):
		_set_loco("walk", clampf(_speed / maxf(walk_clip_speed, 0.01), 0.5, 2.0))
	else:
		_set_loco("run", clampf(_speed / maxf(run_clip_speed, 0.01), 0.6, 2.0))


func _set_loco(action: String, rate := 1.0) -> void:
	if anim == null:
		return
	var clip := _clip(action)
	var snap := false
	if clip == "" and action == "idle" and has_clip("walk"):
		# No idle clip in this model yet: hold the stance frame of the walk clip instead
		# of showing the bind pose. Replaced automatically once an idle clip exists.
		clip = _clip("walk")
		rate = 0.0
		snap = true
	if clip == "":
		return
	if _loco != action or not anim.is_playing():
		_loco = action
		anim.play(clip, 0.0 if snap else blend_time)
		anim.speed_scale = rate
		if snap:
			# Hold the passing pose (legs together) instead of frame 0 mid-stride.
			anim.seek(anim.get_animation(clip).length * 0.25, true)
	elif not snap:
		anim.speed_scale = rate


## The first 3D child of this wrapper: the node that carries the imported rig.
func _rig_node() -> Node3D:
	for child: Node in get_children():
		var n := child as Node3D
		if n != null:
			return n
	return null


func _normalize() -> void:
	var rig := _rig_node()
	if rig == null:
		return
	# Skinned mesh AABBs ignore the armature scale, so measure the skeleton instead:
	# the rest-pose bone span (ankles to head) is about 92% of the full body height.
	var span := _bone_span()
	var height := span.y / 0.92 if span.y > 0.0001 else _mesh_bounds().size.y
	if height <= 0.0001:
		return
	rig.scale *= target_height / height
	span = _bone_span()
	if span.y > 0.0001:
		rig.position.y -= span.x - 0.06
	else:
		var box := _mesh_bounds()
		rig.position.y -= box.position.y


## Vector2(min_y, height) of the rest-pose bone positions in this node's local space.
func _bone_span() -> Vector2:
	var skels := find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return Vector2.ZERO
	var skel := skels[0] as Skeleton3D
	if skel.get_bone_count() == 0:
		return Vector2.ZERO
	var inv := global_transform.affine_inverse()
	var lo := INF
	var hi := -INF
	for i in skel.get_bone_count():
		var p := inv * (skel.global_transform * skel.get_bone_global_rest(i).origin)
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	return Vector2(lo, hi - lo)


## Mesh bounds of the whole model in this node's local space.
func _mesh_bounds() -> AABB:
	var out := AABB()
	var first := true
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var box: AABB = (global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out
