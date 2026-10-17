extends Node
## Glow tuned for the Compatibility renderer (browser + cloud editor), applied on top
## of whatever Environment the scene already uses (any look pack or your own
## WorldEnvironment). Bright emissive materials (emission energy 2-6) and the sun disc
## bloom; ordinary lit surfaces stay crisp. Compatibility keeps only a little range
## above 1.0, so its threshold must stay below about 1.0 (Forward+ gets its own value).
## If the scene has no Environment at all, one is created (clear-colour background).

@export_enum("punch", "soft", "dreamy") var preset := "punch"
## Multiplies the preset's glow intensity.
@export_range(0.0, 3.0) var intensity_scale := 1.0

const PRESETS := {
	"punch": {"glow_intensity": 1.2, "glow_strength": 1.0, "glow_bloom": 0.0, "glow_hdr_threshold": 0.75,
		"glow_hdr_scale": 3.0, "glow_blend_mode": Environment.GLOW_BLEND_MODE_ADDITIVE,
		"levels": [0.0, 0.4, 1.0, 1.0, 0.7, 0.3, 0.0]},
	"soft": {"glow_intensity": 0.6, "glow_strength": 1.0, "glow_bloom": 0.0, "glow_hdr_threshold": 0.9,
		"glow_hdr_scale": 2.0, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT,
		"levels": [0.0, 0.0, 1.0, 0.8, 0.5, 0.0, 0.0]},
	"dreamy": {"glow_intensity": 0.9, "glow_strength": 1.2, "glow_bloom": 0.12, "glow_hdr_threshold": 0.7,
		"glow_hdr_scale": 2.0, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SCREEN,
		"levels": [0.0, 0.3, 0.8, 1.0, 1.0, 0.7, 0.4]},
}
## Forward+ keeps real HDR, so it needs a higher threshold for the same result.
const FORWARD_PLUS_THRESHOLD_ADD := 0.35
## Compatibility glow is tighter and dimmer than Forward+ at the same settings.
const COMPAT_INTENSITY_SCALE := 1.8

func _ready() -> void:
	# Deferred so look packs (which hand their Environment to the scene) apply first.
	apply.call_deferred()

func apply() -> void:
	var world := get_viewport().find_world_3d()
	if world == null:
		return
	var env := world.environment
	if env == null:
		var we := WorldEnvironment.new()
		we.name = "BloomPunchEnvironment"
		we.environment = Environment.new()
		add_child(we)
		env = we.environment
	var p: Dictionary = PRESETS.get(preset, PRESETS["punch"])
	env.glow_enabled = true
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	env.glow_intensity = p["glow_intensity"] * intensity_scale * (COMPAT_INTENSITY_SCALE if compat else 1.0)
	env.glow_strength = p["glow_strength"]
	env.glow_bloom = p["glow_bloom"]
	env.glow_hdr_scale = p["glow_hdr_scale"]
	env.glow_blend_mode = p["glow_blend_mode"]
	var threshold: float = p["glow_hdr_threshold"]
	if not compat:
		threshold += FORWARD_PLUS_THRESHOLD_ADD
	env.glow_hdr_threshold = threshold
	var levels: Array = p["levels"]
	for i in levels.size():
		env.set_glow_level(i, levels[i])
