extends CanvasLayer

signal levels_requested
signal rejoin_requested

const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const TEXT_FONT = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const FlightLessonHud = preload("res://scripts/flight_lesson_hud.gd")

var controller
var root_control: Control
var levels_button: Button
var rejoin_button: Button
var mission_panel: PanelContainer
var title: Label
var objective: Label
var detail: Label
var progress: ProgressBar
var last_stage = ""
var flight_lesson_hud


func _ready() -> void:
	layer = 3
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	levels_button = make_button("MISSIONS", levels_requested.emit)
	root_control.add_child(levels_button)
	if controller.level_id in [3, 4, 5]:
		return
	if controller.level_id == 1:
		flight_lesson_hud = FlightLessonHud.new()
		flight_lesson_hud.controller = controller
		root_control.add_child(flight_lesson_hud)
		return
	mission_panel = PanelContainer.new()
	mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.055, 0.040, 0.80)
	style.border_color = Color(0.40, 0.95, 0.61, 0.45)
	style.set_border_width_all(1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	mission_panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(mission_panel)
	var content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 9)
	mission_panel.add_child(content)
	title = make_label("02 / PURSUIT", 20, Color("92c6a6"))
	content.add_child(title)
	objective = make_label("INTERCEPT KC-390", 29, Color("baffd0"))
	content.add_child(objective)
	detail = make_label("", 14, Color("9fceb0"))
	detail.add_theme_font_override("font", TEXT_FONT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	progress = ProgressBar.new()
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(progress)
	rejoin_button = make_button("REJOIN TAIL", rejoin_requested.emit)
	root_control.add_child(rejoin_button)


func make_label(value: String, font_size: int, color: Color) -> Label:
	var result = Label.new()
	result.text = value
	result.add_theme_font_override("font", INSTRUMENT_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func make_button(value: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", INSTRUMENT_FONT)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("baffd0"))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.065, 0.045, 0.85)
	style.border_color = Color(0.40, 0.95, 0.61, 0.5)
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color(0.06, 0.20, 0.12, 0.94)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(action)
	return button


func _process(_dt: float) -> void:
	var viewport_size = root_control.get_viewport_rect().size
	var margin = max(22.0, viewport_size.x * 0.025)
	levels_button.position = Vector2(margin, 108)
	levels_button.size = Vector2(140, 30)
	if mission_panel == null:
		return
	mission_panel.visible = not controller.observing and not controller.settings_open
	rejoin_button.visible = mission_panel.visible
	mission_panel.position = Vector2(margin, 152)
	mission_panel.size = Vector2(260, 148)
	rejoin_button.position = Vector2(margin, mission_panel.position.y + mission_panel.size.y + 10)
	rejoin_button.size = Vector2(260, 30)
	var data = controller.pursuit.training_snapshot()
	var reset_key = OS.get_keycode_string(int(controller.settings.key_bindings.reset))
	var gun_key = OS.get_keycode_string(int(controller.settings.key_bindings.gun_fire))
	var missile_key = OS.get_keycode_string(int(controller.settings.key_bindings.missile_fire))
	if data.respawning:
		objective.text = "TARGET DOWN"
		detail.text = "REPLACEMENT INBOUND"
	elif data.rejoin:
		objective.text = "REJOIN PURSUIT"
		detail.text = "REJOIN TAIL / %s RESTART" % reset_key.to_upper()
	elif data.completed:
		objective.text = "PURSUIT CLEAR"
		detail.text = "FREE PRACTICE\n%s GUN / %s MISSILE" % [gun_key.to_upper(), missile_key.to_upper()]
	elif data.stage == "track":
		objective.text = "HOLD TAIL  %.1f / 2S" % controller.pursuit.follow_time
		detail.text = "350-1100 M\nKEEP TARGET AHEAD"
	else:
		objective.text = "INTERCEPT KC-390"
		detail.text = "RANGE %.0f M\nCLOSE TO 350-1100 M" % data.distance
	progress.value = data.progress
	if last_stage != data.stage:
		last_stage = data.stage
		var tween = create_tween()
		objective.modulate.a = 0.3
		tween.tween_property(objective, "modulate:a", 1.0, 0.25)


