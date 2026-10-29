extends Control

signal camera_requested
signal pause_requested
signal reset_requested
signal settings_requested

const INK = Color(0.66, 0.90, 0.76, 0.88)
const MUTED = Color(0.66, 0.90, 0.76, 0.62)
const BRIGHT = Color(0.82, 0.96, 0.87, 0.95)
const AMBER = Color(1.0, 0.78, 0.46, 0.95)
var state = {}
var contrast = 0.65
var paused = false
var wide = false
var camera_button
var pause_button
var reset_button
var settings_button
var help_label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_button = make_button("CHASE [C]", "camera")
	pause_button = make_button("PAUSE [P]", "pause")
	reset_button = make_button("RESET [R]", "reset")
	settings_button = make_button("SETTINGS [TAB]", "settings")
	help_label = Label.new()
	help_label.text = "W/S THROTTLE    A/D ROLL    UP/DOWN PITCH    Q/E YAW    SHIFT AIRBRAKE"
	help_label.add_theme_font_size_override("font_size", 10)
	help_label.add_theme_color_override("font_color", MUTED)
	help_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.055, 0.035, 0.85))
	help_label.add_theme_constant_override("shadow_offset_x", 1)
	help_label.add_theme_constant_override("shadow_offset_y", 1)
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help_label)


func make_button(label: String, action: String) -> Button:
	var button = Button.new()
	button.text = label
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", BRIGHT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.08, 0.055, 0.72)
	style.border_color = Color(0.66, 0.90, 0.76, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.pressed.connect(_on_button_pressed.bind(action))
	add_child(button)
	return button


func _on_button_pressed(action: String) -> void:
	match action:
		"camera": camera_requested.emit()
		"pause": pause_requested.emit()
		"reset": reset_requested.emit()
		"settings": settings_requested.emit()


func set_settings_open(value: bool) -> void:
	settings_button.text = "CLOSE [ESC]" if value else "SETTINGS [TAB]"


func set_camera_mode(value: bool) -> void:
	wide = value
	camera_button.text = "WIDE [C]" if wide else "CHASE [C]"


func set_paused(value: bool) -> void:
	paused = value
	pause_button.text = "RESUME [P]" if paused else "PAUSE [P]"


func update_contrast(value: float) -> void:
	contrast = clamp(value, 0.0, 1.0)


func update_state(value: Dictionary) -> void:
	state = value
	queue_redraw()


func _process(_dt: float) -> void:
	camera_button.position = Vector2(size.x - 456, 22)
	camera_button.size = Vector2(100, 30)
	pause_button.position = Vector2(size.x - 348, 22)
	pause_button.size = Vector2(100, 30)
	reset_button.position = Vector2(size.x - 240, 22)
	reset_button.size = Vector2(100, 30)
	settings_button.position = Vector2(size.x - 132, 22)
	settings_button.size = Vector2(120, 30)
	var help_width = help_label.get_minimum_size().x
	help_label.position = Vector2((size.x - help_width) * 0.5, size.y - 38)
	queue_redraw()


func text(position: Vector2, value: String, font_size: int = 12, color: Color = INK) -> void:
	var shadow = Color(0.0, 0.055, 0.035, color.a * 0.9)
	draw_string(ThemeDB.fallback_font, position + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func format_time(seconds: float) -> String:
	var total = max(0, int(seconds))
	return "%02d:%02d" % [int(total / 60), total % 60]


func _draw() -> void:
	if state.is_empty():
		return
	var panel_color = Color(0.005, 0.035, 0.025, contrast * 0.45)
	text(Vector2(34, 36), "TIME " + format_time(state.get("time", 0.0)), 11, MUTED)
	text(Vector2(34, 56), "FLIGHT TEST 01", 11, MUTED)
	text(Vector2(34, 76), "FLIGHT TEST RANGE / EMB-314", 9, MUTED)

	var speed_position = Vector2(size.x * 0.32, size.y * 0.33)
	draw_rect(Rect2(speed_position + Vector2(-7, 1), Vector2(78, 48)), panel_color, true)
	text(speed_position, "SPEED", 10, MUTED)
	draw_rect(Rect2(speed_position + Vector2(0, 5), Vector2(64, 23)), MUTED, false, 1.0)
	text(speed_position + Vector2(6, 22), str(int(state.get("speedKmh", 0.0))), 13, BRIGHT)
	text(speed_position + Vector2(0, 42), "KM/H", 8, MUTED)

	var alt_position = Vector2(size.x * 0.68, size.y * 0.33)
	draw_rect(Rect2(alt_position + Vector2(-7, 1), Vector2(78, 48)), panel_color, true)
	text(alt_position, "ALT", 10, MUTED)
	draw_rect(Rect2(alt_position + Vector2(0, 5), Vector2(64, 23)), MUTED, false, 1.0)
	text(alt_position + Vector2(6, 22), str(int(state.get("position", [0, 0, 0])[1])), 13, BRIGHT)
	text(alt_position + Vector2(0, 42), "MSL / M", 8, MUTED)

	var center = Vector2(size.x * 0.5, size.y * 0.49)
	var pitch_deg = rad_to_deg(state.get("pitch", 0.0))
	var bank_deg = rad_to_deg(state.get("bank", 0.0))
	draw_set_transform(center, -state.get("bank", 0.0), Vector2.ONE)
	for offset in [-34, 0, 34]:
		var y = offset + pitch_deg * 2.0
		draw_line(Vector2(-22, y), Vector2(22, y), MUTED, 1.0, true)
		draw_line(Vector2(-22, y - 3), Vector2(-22, y + 3), MUTED, 1.0, true)
		draw_line(Vector2(22, y - 3), Vector2(22, y + 3), MUTED, 1.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_circle(center, 5.0, Color(0.0, 0.03, 0.02, contrast * 0.7))
	draw_line(center + Vector2(0, -17), center + Vector2(0, 17), BRIGHT, 1.0, true)
	draw_line(center + Vector2(-17, 0), center + Vector2(17, 0), BRIGHT, 1.0, true)
	draw_circle(center, 2.0, BRIGHT)
	text(center + Vector2(-42, 48), "P %d°  B %d°" % [int(pitch_deg), int(bank_deg)], 9, MUTED)

	var nav = Vector2(104, size.y - 112)
	draw_rect(Rect2(nav - Vector2(70, 70), Vector2(140, 140)), panel_color, true)
	draw_rect(Rect2(nav - Vector2(70, 70), Vector2(140, 140)), MUTED, false, 1.0)
	for radius in [55, 36, 17]:
		draw_arc(nav, radius, 0.0, TAU, 64, MUTED, 1.0, true)
	draw_line(nav + Vector2(-66, 0), nav + Vector2(66, 0), MUTED, 1.0, true)
	draw_line(nav + Vector2(0, -66), nav + Vector2(0, 66), MUTED, 1.0, true)
	draw_set_transform(nav, -deg_to_rad(state.get("heading", 0.0)), Vector2.ONE)
	text(Vector2(-5, -46), "N", 10, BRIGHT)
	text(Vector2(45, 3), "E", 8, MUTED)
	text(Vector2(-4, 52), "S", 8, MUTED)
	text(Vector2(-51, 3), "W", 8, MUTED)
	draw_set_transform(Vector2.ZERO)
	draw_polygon(PackedVector2Array([nav + Vector2(0, -13), nav + Vector2(-6, 9), nav + Vector2(0, 5), nav + Vector2(6, 9)]), PackedColorArray([BRIGHT]))
	text(nav + Vector2(-48, 84), "NAV 5 KM / %03d°" % int(state.get("heading", 0.0)), 9, MUTED)

	var right = Vector2(size.x - 166, size.y - 142)
	draw_rect(Rect2(right - Vector2(8, 10), Vector2(150, 78)), panel_color, true)
	text(right, "THR", 10, MUTED)
	text(right + Vector2(78, 0), "%d%%" % int(state.get("throttle", 0.0) * 100.0), 10, BRIGHT)
	text(right + Vector2(0, 22), "VS", 10, MUTED)
	text(right + Vector2(78, 22), "%+.1f M/S" % state.get("verticalSpeed", 0.0), 10, BRIGHT)
	text(right + Vector2(0, 44), "AGL", 10, MUTED)
	text(right + Vector2(78, 44), "%d M" % int(max(0.0, state.get("agl", 0.0))), 10, BRIGHT)
	if state.get("airbrake", false):
		text(right + Vector2(0, 68), "AIRBRAKE", 9, AMBER)

	if state.get("stall", false):
		text(Vector2(size.x * 0.5 - 92, 84), "STALL · NOSE DOWN", 11, AMBER)
	elif state.get("lowAltitude", false):
		text(Vector2(size.x * 0.5 - 118, 84), "LOW ALTITUDE · PULL UP", 11, AMBER)
	elif state.get("outsideBoundary", false):
		text(Vector2(size.x * 0.5 - 104, 84), "LEAVING TEST RANGE", 11, AMBER)

	if paused or state.get("crashed", false):
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.035, 0.02, 0.66))
		var panel = Rect2(Vector2(size.x * 0.5 - 135, size.y * 0.5 - 62), Vector2(270, 124))
		draw_rect(panel, Color(0.025, 0.09, 0.065, 0.94))
		draw_rect(panel, MUTED, false, 1.0)
		var title = "PAUSED" if paused else "CRASHED"
		var subtitle = "Flight state frozen" if paused else "Reset to test airspace"
		text(panel.position + Vector2(92, 38), title, 18, BRIGHT)
		text(panel.position + Vector2(45, 72), subtitle, 11, MUTED)
		text(panel.position + Vector2(63, 102), "P / R TO CONTINUE", 10, INK)
