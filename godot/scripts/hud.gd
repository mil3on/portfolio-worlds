extends CanvasLayer
## Portfolio HUD: title card, discovery counter, the interaction prompt, a short toast and
## the mobile interaction button. There is deliberately no case-study overlay - opening a
## location sends the player to the case study's page in a new browser tab.

signal open_requested

const Fonts := preload("res://starter/ui-fonts/fonts.gd")

## Show the touch button even on desktop, for testing the mobile layout.
@export var force_mobile_button := false

var _counter: Label
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
	return s


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_corner() -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.82), 16, 16))
	box.position = Vector2(24, 24)
	add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	v.add_child(_label("ПЛАНЕТА ПОРТФОЛИО", 14, Color(0.4, 0.45, 0.55), Fonts.sans(800)))
	_counter = _label("Открыто 0 / 7", 20, Color(0.12, 0.14, 0.2), Fonts.sans(700))
	v.add_child(_counter)

	var hint := _label("WASD - ходьба  |  Shift - бег  |  Пробел - прыжок  |  Мышь - камера  |  E - открыть кейс", 15, Color(1, 1, 1, 0.9), Fonts.sans(600))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	hint.add_theme_constant_override("outline_size", 6)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_top = -44
	hint.offset_bottom = -20
	hint.offset_left = 24
	add_child(hint)


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", _style(Color(0.1, 0.12, 0.18, 0.85), 30, 26))
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
	_prompt_title = _label("", 16, Color(1, 1, 1, 0.75), Fonts.sans(700))
	_prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_prompt_title)
	_prompt_label = _label("", 24, Color.WHITE, Fonts.sans(800))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_prompt_label)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _style(Color(0.1, 0.12, 0.18, 0.88), 22, 22))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 40
	_toast.visible = false
	add_child(_toast)
	_toast_label = _label("", 18, Color.WHITE, Fonts.sans(700))
	_toast.add_child(_toast_label)


func _build_button() -> void:
	_button = Button.new()
	_button.custom_minimum_size = Vector2(112, 112)
	_button.focus_mode = Control.FOCUS_NONE
	_button.text = "ОТКРЫТЬ"
	_button.add_theme_font_override("font", Fonts.sans(800))
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
	var t := _label("Добро пожаловать в мой мир", 60, Color.WHITE, Fonts.sans(800))
	var s := _label("Семь мест - семь кейсов. Подойди к любому и нажми E.", 20, Color.WHITE, Fonts.sans(600))
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
	_counter.text = "Открыто %d / %d" % [n, total]


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
