extends CanvasLayer
## Portfolio HUD: title card, discovery counter, the interaction prompt, a short toast and
## the mobile interaction button. There is deliberately no case-study overlay - opening a
## location sends the player to the case study's page in a new browser tab.

signal open_requested

const MACHINA := preload("res://assets/fonts/PPNeueMachina-Ultrabold.otf")
const MANROPE := preload("res://assets/fonts/Manrope.ttf")
const CHECK_ICON := preload("res://assets/ui/figma-check.svg")
const CIRCLE_ICON := preload("res://assets/ui/figma-circle.svg")
const MENU_ORDER := ["origin", "dragontrans", "itmo", "smtu", "domtn", "book", "shots"]

## Show the touch button even on desktop, for testing the mobile layout.
@export var force_mobile_button := false

var _counter: Label
var _progress: VBoxContainer
var _prompt: PanelContainer
var _prompt_title: Label
var _prompt_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _button: Button
var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	_build_corner()
	_build_controls()
	_build_prompt()
	_build_toast()
	_build_button()
	_build_title_card()


func _style(bg: Color, radius := 18, pad := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.border_color = Color(1, 1, 1, 0.52)
	s.set_border_width_all(1)
	s.shadow_color = Color(0.03, 0.05, 0.08, 0.18)
	s.shadow_size = 16
	return s


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_corner() -> void:
	var menu_root := Control.new()
	# It intentionally starts beyond the left edge: only its rounded right part is visible.
	menu_root.position = Vector2(-6, 18)
	menu_root.size = Vector2(292, 390)
	menu_root.scale = Vector2(0.5, 0.5)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_root)
	var blur := ColorRect.new()
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur_material := ShaderMaterial.new()
	blur_material.shader = preload("res://assets/ui/menu_blur.gdshader")
	blur.material = blur_material
	menu_root.add_child(blur)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _menu_body_style())
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	v.add_theme_constant_override("separation", 0)
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(292, 112)
	header.add_theme_stylebox_override("panel", _menu_header_style())
	v.add_child(header)
	var header_row := HBoxContainer.new()
	header.add_child(header_row)
	var header_title := _label("Осмотрите\nвсе локации", 27, Color.WHITE, MACHINA)
	header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.add_theme_constant_override("line_spacing", -4)
	header_row.add_child(header_title)
	_counter = _label("0/7", 31, Color.WHITE, MANROPE)
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(_counter)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 20)
	margins.add_theme_constant_override("margin_right", 20)
	margins.add_theme_constant_override("margin_top", 22)
	margins.add_theme_constant_override("margin_bottom", 22)
	v.add_child(margins)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margins.add_child(body)
	_progress = VBoxContainer.new()
	_progress.add_theme_constant_override("separation", 10)
	body.add_child(_progress)



func _menu_body_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	# The glass itself is rendered by menu_blur.gdshader. This panel only clips the
	# content to the intended silhouette, avoiding a second rounded outer frame.
	s.bg_color = Color(1, 1, 1, 0.12)
	s.corner_radius_top_left = 0
	s.corner_radius_bottom_left = 0
	s.corner_radius_top_right = 28
	s.corner_radius_bottom_right = 28
	return s


func _menu_header_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("050505")
	s.corner_radius_top_left = 0
	s.corner_radius_bottom_left = 0
	s.corner_radius_top_right = 28
	s.corner_radius_bottom_right = 28
	s.content_margin_left = 20
	s.content_margin_right = 22
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


func _build_controls() -> void:
	# Keep the controls as the approved portfolio artwork rather than rebuilding
	# its carefully spaced keyboard layout out of individual UI widgets.
	var controls := TextureRect.new()
	controls.texture = load("res://assets/ui/controls-reference.png")
	controls.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	controls.stretch_mode = TextureRect.STRETCH_KEEP
	controls.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	controls.offset_left = -388
	controls.offset_top = -307
	controls.offset_right = -24
	controls.offset_bottom = -24
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.10, 0.78), 28, 24))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_bottom = -110
	_prompt.visible = false
	add_child(_prompt)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	_prompt.add_child(v)
	_prompt_title = _label("", 14, Color(1, 1, 1, 0.72), MANROPE)
	_prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_prompt_title)
	_prompt_label = _label("", 23, Color.WHITE, MACHINA)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_prompt_label)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.1, 0.88), 22, 22))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 40
	_toast.visible = false
	add_child(_toast)
	_toast_label = _label("", 18, Color.WHITE, MANROPE)
	_toast.add_child(_toast_label)


func _build_button() -> void:
	_button = Button.new()
	_button.custom_minimum_size = Vector2(112, 112)
	_button.focus_mode = Control.FOCUS_NONE
	_button.text = "ОТКРЫТЬ"
	_button.add_theme_font_override("font", MACHINA)
	_button.add_theme_font_size_override("font_size", 20)
	_button.add_theme_color_override("font_color", Color(0.1, 0.12, 0.18))
	var normal := _style(Color(1, 1, 1, 0.92), 56, 12)
	var pressed := _style(Color(0.85, 0.88, 0.94, 0.95), 56, 12)
	_button.add_theme_stylebox_override("normal", normal)
	_button.add_theme_stylebox_override("hover", normal)
	_button.add_theme_stylebox_override("pressed", pressed)
	_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_button.offset_right = -32
	_button.offset_bottom = -32
	_button.visible = force_mobile_button or DisplayServer.is_touchscreen_available()
	_button.pressed.connect(func() -> void: open_requested.emit())
	add_child(_button)


func _build_title_card() -> void:
	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.offset_top = -180
	add_child(card)
	var t := _label("Мир портфолио", 60, Color.WHITE, MACHINA)
	var s := _label("Семь локаций — семь историй. Подойди к любой и нажми E.", 20, Color.WHITE, MANROPE)
	for l: Label in [t, s]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.3, 0.55))
		l.add_theme_constant_override("outline_size", 10)
		card.add_child(l)
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(card, "modulate:a", 0.0, 1.2)
	tw.tween_callback(card.hide)


func set_discovered(n: int, total: int) -> void:
	_counter.text = "%d/%d" % [n, total]


func set_case_progress(cases: Array, discovered: Dictionary) -> void:
	if _progress == null:
		return
	for child in _progress.get_children():
		child.queue_free()
	var by_id := {}
	for data: Dictionary in cases:
		by_id[data["id"]] = data
	for id: String in MENU_ORDER:
		if not by_id.has(id):
			continue
		var data: Dictionary = by_id[id]
		var done := discovered.has(data["id"])
		var row := Control.new()
		row.custom_minimum_size = Vector2(252, 24)
		var icon := TextureRect.new()
		icon.texture = CHECK_ICON if done else CIRCLE_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(0, 4)
		icon.size = Vector2(18, 18)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		row.add_child(icon)
		var text := _label(String(data["title"]), 20, Color("666666") if done else Color("171719"), MANROPE)
		text.position = Vector2(27, 0)
		text.size = Vector2(220, 24)
		row.add_child(text)
		if done:
			var strike := ColorRect.new()
			strike.color = Color("666666")
			strike.position = Vector2(27, 13)
			strike.size = Vector2(210, 1)
			row.add_child(strike)
		_progress.add_child(row)


func show_prompt(title: String, label: String) -> void:
	_prompt_title.text = title
	_prompt_label.text = label
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


## Short message near the top of the screen, for example when a URL is still a placeholder.
func flash(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(_toast.hide)
