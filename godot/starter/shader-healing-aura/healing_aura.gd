@tool
extends Node3D
## Healing / holy aura effect: glowing rune circle on the ground, a soft light column, rising plus
## sparkles and a coloured light. Visual only: it detects no bodies and heals nothing.
##   var a := preload("res://starter/shader-healing-aura/healing_aura.tscn").instantiate()
##   a.radius = 2.0; a.preset = "heal"; add_child(a); a.position = spot_on_ground
##   a.pulse()           # flash the circle and column (e.g. when your own code heals someone)
## Presets: heal (green), holy (gold), mana (blue), arcane (violet), rage (red), frost (cyan).
## Node origin = ground centre. Original work (Summer, s06-fantasy).

const GROUND := preload("res://starter/shader-healing-aura/aura_ground.gdshader")
const BEAM := preload("res://starter/shader-healing-aura/aura_beam.gdshader")
const SPARK := preload("res://starter/shader-healing-aura/aura_spark.gdshader")
const PRESETS := {
	"heal": {"color": Color(0.3, 1.0, 0.45), "hot": Color(0.85, 1.0, 0.75), "shape": 0},
	"holy": {"color": Color(1.0, 0.75, 0.3), "hot": Color(1.0, 0.97, 0.82), "shape": 1},
	"mana": {"color": Color(0.3, 0.6, 1.0), "hot": Color(0.8, 0.92, 1.0), "shape": 1},
	"arcane": {"color": Color(0.6, 0.3, 1.0), "hot": Color(0.92, 0.8, 1.0), "shape": 1},
	"rage": {"color": Color(1.0, 0.25, 0.12), "hot": Color(1.0, 0.75, 0.45), "shape": 1},
	"frost": {"color": Color(0.45, 0.85, 1.0), "hot": Color(0.92, 1.0, 1.0), "shape": 1},
}

@export_enum("heal", "holy", "mana", "arcane", "rage", "frost") var preset := "heal":
	set(v): preset = v; _apply()
@export var radius := 1.5:
	set(v): radius = v; _apply()
@export var beam := true:
	set(v): beam = v; _apply()
@export var beam_height := 4.0:
	set(v): beam_height = v; _apply()
@export_range(0.0, 2.0) var intensity := 1.0:
	set(v): intensity = v; _apply()
@export var sparkles := true:
	set(v): sparkles = v; _apply()
@export var light_energy := 1.6:
	set(v): light_energy = v; _apply()

var _ground_mat: ShaderMaterial
var _beam_mat: ShaderMaterial
var _boost := 0.0

func _ready() -> void:
	_build()
	_apply()

func _build() -> void:
	var g := get_node_or_null("Circle") as MeshInstance3D
	if g and _ground_mat == null:
		_ground_mat = ShaderMaterial.new(); _ground_mat.shader = GROUND
		g.material_override = _ground_mat
	var b := get_node_or_null("Beam") as MeshInstance3D
	if b and _beam_mat == null:
		_beam_mat = ShaderMaterial.new(); _beam_mat.shader = BEAM
		b.material_override = _beam_mat
	var p := get_node_or_null("Motes") as CPUParticles3D
	if p and p.mesh and p.mesh.surface_get_material(0) == null:
		var sm := ShaderMaterial.new(); sm.shader = SPARK
		(p.mesh as PrimitiveMesh).material = sm

func _apply() -> void:
	if not is_inside_tree():
		return
	_build()
	var c: Dictionary = PRESETS.get(preset, PRESETS["heal"])
	var g := get_node_or_null("Circle") as MeshInstance3D
	if g:
		g.scale = Vector3(radius, 1.0, radius)
		_ground_mat.set_shader_parameter("color", c.color)
		_ground_mat.set_shader_parameter("hot_color", c.hot)
		_ground_mat.set_shader_parameter("intensity", intensity)
		_ground_mat.set_shader_parameter("rune_count", roundf(clampf(radius * 12.0, 10.0, 40.0)))
	var b := get_node_or_null("Beam") as MeshInstance3D
	if b:
		b.visible = beam
		b.scale = Vector3(radius * 0.8, beam_height, radius * 0.8)
		b.position = Vector3(0, beam_height * 0.5, 0)
		_beam_mat.set_shader_parameter("color", c.color)
		_beam_mat.set_shader_parameter("hot_color", c.hot)
		_beam_mat.set_shader_parameter("intensity", intensity)
	var p := get_node_or_null("Motes") as CPUParticles3D
	if p:
		p.visible = sparkles
		p.emitting = sparkles and intensity > 0.05
		p.emission_ring_radius = radius * 0.9
		p.emission_ring_inner_radius = 0.0
		p.amount = int(clampf(radius * radius * 14.0, 12.0, 120.0))
		var grad := Gradient.new()
		grad.set_color(0, Color(c.hot, 0.0)); grad.set_color(1, Color(c.color, 0.0))
		grad.add_point(0.2, Color(c.hot, 1.0)); grad.add_point(0.7, Color(c.color, 0.8))
		p.color_ramp = grad
		var sm := (p.mesh as PrimitiveMesh).material as ShaderMaterial
		if sm: sm.set_shader_parameter("shape", c.shape)
	var l := get_node_or_null("Light") as OmniLight3D
	if l:
		l.light_color = c.color
		l.light_energy = light_energy * intensity
		l.omni_range = radius * 2.5
		l.position = Vector3(0, minf(radius * 0.5, 1.2), 0)

## Flash the circle and column.
func pulse(strength := 1.5) -> void:
	_boost = strength

func _process(delta: float) -> void:
	if _boost > 0.0:
		_boost = maxf(_boost - delta * 3.0, 0.0)
		if _ground_mat: _ground_mat.set_shader_parameter("pulse_boost", _boost)
		if _beam_mat: _beam_mat.set_shader_parameter("pulse_boost", _boost)
