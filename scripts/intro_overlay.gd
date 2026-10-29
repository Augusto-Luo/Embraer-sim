extends CanvasLayer

const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const BODY_FONT = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const INK = Color("baffd0")
const MUTED = Color("8dbca1")

var root_control: Control
var top_bar: ColorRect
var bottom_bar: ColorRect
var aircraft_label: Label
var intro_label: Label
var mission_label: Label
var shot_label: Label
var skip_label: Label


func _ready() -> void:
	layer = 8
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	top_bar = make_bar()
	bottom_bar = make_bar()
	aircraft_label = make_label("EMB-314  /  SUPER TUCANO", 24, INK, true)
	intro_label = make_label("LIVERY INSPECTION", 16, MUTED)
	mission_label = make_label("", 18, MUTED)
	shot_label = make_label("OVERVIEW", 22, INK, true)
	skip_label = make_label("ENTER  SKIP", 16, MUTED)


func make_bar() -> ColorRect:
	var bar = ColorRect.new()
	bar.color = Color(0.002, 0.012, 0.009, 0.88)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(bar)
	return bar


func make_label(value: String, font_size: int, color: Color, instrument: bool = false) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_override("font", INSTRUMENT_FONT if instrument else BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0.03, 0.02, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(label)
	return label


func set_mission(level_id: int) -> void:
	aircraft_label.text = "KC-390 / MILLENNIUM" if level_id == 1 else "EMB-314 / SUPER TUCANO"
	if level_id == 1:
		mission_label.text = "01  /  AIRFIELD CIRCUIT"
	elif level_id == 2:
		mission_label.text = "02  /  HIGH-ALTITUDE PURSUIT"
	elif level_id == 5:
		mission_label.text = "05  /  INTERCEPT"
	else:
		mission_label.text = "03  /  COASTAL FREE COMBAT"


func set_shot(value: String) -> void:
	shot_label.text = value


func _process(_dt: float) -> void:
	var viewport_size = root_control.size
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(viewport_size.x, 54)
	bottom_bar.position = Vector2(0, viewport_size.y - 54)
	bottom_bar.size = Vector2(viewport_size.x, 54)
	aircraft_label.position = Vector2(32, 11)
	intro_label.position = Vector2(viewport_size.x - intro_label.get_minimum_size().x - 32, 18)
	mission_label.position = Vector2(32, viewport_size.y - 39)
	shot_label.position = Vector2(viewport_size.x * 0.5 - shot_label.get_minimum_size().x * 0.5, viewport_size.y - 42)
	skip_label.position = Vector2(viewport_size.x - skip_label.get_minimum_size().x - 32, viewport_size.y - 39)
