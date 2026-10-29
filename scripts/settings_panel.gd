extends Control

signal closed

const INK = Color("c2e7d0")
const MUTED = Color("80ab94")
const BRIGHT = Color("e0f7e8")
const GREEN = Color("62f69b")
const AMBER = Color("e9bb70")
const BORDER = Color("294c3c")
const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const BODY_FONT = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const PAGE_INFO = [
	["quick", "QUICK SETUP"], ["controls", "CONTROLS"],
	["camera", "CAMERA & HUD"], ["graphics", "GRAPHICS"],
	["audio", "AUDIO"], ["advanced", "ADVANCED"],
]
const BINDING_GROUPS = [
	["FLIGHT", [
		["Throttle +", "throttle_up"], ["Throttle -", "throttle_down"],
		["Roll left", "roll_left"], ["Roll right", "roll_right"],
		["Pitch up", "pitch_up"], ["Pitch down", "pitch_down"],
		["Yaw left", "yaw_left"], ["Yaw right", "yaw_right"],
		["Airbrake", "airbrake"], ["Landing gear", "gear_toggle"],
	]],
	["WEAPONS", [["Cannon", "gun_fire"], ["Rocket", "missile_fire"], ["Next target", "target_next"]]],
	["VIEW", [
		["Chase camera", "camera"], ["Observe", "observe"],
		["Cockpit", "cockpit"], ["Cockpit seat", "cockpit_seat"],
		["Recenter view", "view_recenter"],
	]],
	["SYSTEM", [
		["Pause", "pause"], ["Restart", "reset"], ["Settings", "settings"],
		["Close settings", "settings_close"], ["Help", "help"],
	]],
]
const PREVIEW_STREAMS = {
	"cannon": preload("res://assets/audio/gun.mp3"),
	"rocket": preload("res://assets/audio/missile.mp3"),
	"explosion": preload("res://assets/audio/explosion.mp3"),
}

var settings
var controller
var level_id = 3
var combat_enabled = true
var ground_attack = false
var pages = {}
var nav_buttons = {}
var current_page = "quick"
var section_keys = {}
var section_actions = {}
var slider_controls = []
var checkbox_controls = []
var option_controls = []
var preset_buttons = {}
var binding_buttons = {}
var binding_action = ""
var refreshing = false
var dirty = false
var save_state = "saved"
var last_save_error = OK
var restart_values = {}
var panel: PanelContainer
var close_button: Button
var reset_button: Button
var save_label: Label
var retry_button: Button
var restart_indicator: Label
var binding_prompt: Label
var save_timer: Timer
var preview_player: AudioStreamPlayer
var preview_buttons = {}
var preview_kind = ""
var open_tween: Tween
var page_tween: Tween
var active_page = ""


func _ready() -> void:
	visible = false
	z_index = 50
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_theme()
	var dim = ColorRect.new()
	dim.color = Color(0.005, 0.018, 0.013, 0.18)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.039, 0.106, 0.082, 0.72), BORDER, 1, 28, 18))
	center.add_child(panel)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	panel.add_child(layout)
	_build_header(layout)
	_separator(layout)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	layout.add_child(body)
	_build_navigation(body)
	var divider = VSeparator.new()
	divider.add_theme_stylebox_override("separator", _line())
	body.add_child(divider)
	var page_margin = MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_left", 28)
	page_margin.add_theme_constant_override("margin_top", 20)
	page_margin.add_theme_constant_override("margin_bottom", 20)
	body.add_child(page_margin)
	var page_stack = Control.new()
	page_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_margin.add_child(page_stack)
	for info in PAGE_INFO:
		var page = VBoxContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 14)
		page_stack.add_child(page)
		pages[info[0]] = page
		section_keys[info[0]] = []
		section_actions[info[0]] = []
		page.add_child(_label(info[1], 36, BRIGHT, true))
		var scroll = ScrollContainer.new()
		scroll.follow_focus = true
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_child(scroll)
		var row_margin = MarginContainer.new()
		row_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_margin.add_theme_constant_override("margin_right", 12)
		scroll.add_child(row_margin)
		var rows = VBoxContainer.new()
		rows.name = "Rows"
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation", 8)
		row_margin.add_child(rows)
	_build_quick(_rows("quick"))
	_build_controls(_rows("controls"))
	_build_camera(_rows("camera"))
	_build_graphics(_rows("graphics"))
	_build_audio(_rows("audio"))
	_build_advanced(_rows("advanced"))
	_separator(layout)
	_build_footer(layout)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.3
	save_timer.timeout.connect(save_pending)
	add_child(save_timer)
	preview_player = AudioStreamPlayer.new()
	preview_player.process_mode = Node.PROCESS_MODE_ALWAYS
	preview_player.finished.connect(stop_preview)
	add_child(preview_player)
	if level_id == 3:
		restart_values.max_enemies = settings.values.max_enemies
	refresh_controls()
	show_page("quick", false)
	_layout_panel()
	get_viewport().size_changed.connect(_layout_panel)


func _build_theme() -> void:
	var ui_theme = Theme.new()
	ui_theme.default_font = BODY_FONT
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_shadow_color", "Label", Color(0.0, 0.015, 0.008, 0.85))
	ui_theme.set_constant("shadow_offset_x", "Label", 1)
	ui_theme.set_constant("shadow_offset_y", "Label", 1)
	for type in ["Button", "CheckButton"]:
		ui_theme.set_color("font_color", type, INK)
		ui_theme.set_color("font_hover_color", type, BRIGHT)
		ui_theme.set_color("font_pressed_color", type, GREEN)
		ui_theme.set_color("font_focus_color", type, BRIGHT)
		ui_theme.set_color("font_disabled_color", type, MUTED)
		ui_theme.set_stylebox("normal", type, _box(Color("10271d"), BORDER))
		ui_theme.set_stylebox("hover", type, _box(Color("193a29"), Color("4b8061")))
		ui_theme.set_stylebox("pressed", type, _box(Color("173e29"), GREEN))
		ui_theme.set_stylebox("disabled", type, _box(Color("0d2118"), BORDER))
		ui_theme.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), Color("a0edb5")))
	ui_theme.set_stylebox("slider", "HSlider", _box(Color("203d2d"), Color(0, 0, 0, 0), 0, 0, 2))
	ui_theme.set_stylebox("grabber_area", "HSlider", _box(Color("4c9a69"), Color(0, 0, 0, 0), 0, 0, 2))
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", _box(GREEN, Color(0, 0, 0, 0), 0, 0, 2))
	ui_theme.set_stylebox("focus", "HSlider", _box(Color(0, 0, 0, 0), Color("699d78")))
	ui_theme.set_icon("grabber", "HSlider", _slider_grabber(INK))
	ui_theme.set_icon("grabber_highlight", "HSlider", _slider_grabber(GREEN))
	ui_theme.set_icon("grabber_disabled", "HSlider", _slider_grabber(MUTED))
	ui_theme.set_stylebox("scroll", "VScrollBar", _box(Color("132a1f"), Color(0, 0, 0, 0), 0, 3, 0))
	ui_theme.set_stylebox("grabber", "VScrollBar", _box(Color("41634e"), Color(0, 0, 0, 0), 0, 3, 12))
	ui_theme.set_stylebox("grabber_highlight", "VScrollBar", _box(Color("679f79"), Color(0, 0, 0, 0), 0, 3, 12))
	theme = ui_theme


func _slider_grabber(color: Color) -> ImageTexture:
	var image = Image.create(8, 18, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _label(text: String, font_size: int = 16, color: Color = INK, instrument: bool = false) -> Label:
	var result = Label.new()
	result.text = text
	result.add_theme_font_override("font", INSTRUMENT_FONT if instrument else BODY_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _box(bg: Color, border: Color, width: int = 1, horizontal: int = 12, vertical: int = 7) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _line() -> StyleBoxLine:
	var style = StyleBoxLine.new()
	style.color = BORDER
	style.thickness = 1
	return style


func _separator(parent: Node) -> void:
	var separator = HSeparator.new()
	separator.add_theme_stylebox_override("separator", _line())
	parent.add_child(separator)


func _build_header(parent: Node) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 66
	row.add_theme_constant_override("separation", 24)
	parent.add_child(row)
	var title = _label("SETTINGS", 44, BRIGHT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var missions = {1: "AIRFIELD", 2: "PURSUIT", 3: "FREE COMBAT", 4: "ISLAND STRIKE", 5: "INTERCEPT"}
	var context = _label("MISSION %02d / %s\n%s" % [level_id, missions.get(level_id, "FREE FLIGHT"), "KC-390" if _transport() else "EMB-314"], 15, MUTED)
	context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(context)
	var live = _label("LIVE", 16, GREEN)
	live.tooltip_text = "Changes apply immediately. Each mission saves its own settings."
	live.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(live)


func _build_navigation(parent: Node) -> void:
	var margin = MarginContainer.new()
	margin.custom_minimum_size.x = 188
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	parent.add_child(margin)
	var nav = VBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	margin.add_child(nav)
	for info in PAGE_INFO:
		var button = Button.new()
		button.text = info[1]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 44
		button.toggle_mode = true
		button.pressed.connect(show_page.bind(info[0]))
		button.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
		nav.add_child(button)
		nav_buttons[info[0]] = button
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)


func _build_footer(parent: Node) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 64
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	reset_button = Button.new()
	reset_button.text = "RESET SECTION"
	reset_button.add_theme_font_size_override("font_size", 14)
	reset_button.add_theme_color_override("font_color", INK)
	reset_button.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	reset_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset_button.pressed.connect(reset_current_section)
	row.add_child(reset_button)
	var status = HBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_theme_constant_override("separation", 12)
	row.add_child(status)
	save_label = _label("AUTOSAVE ON", 14, INK)
	status.add_child(save_label)
	retry_button = Button.new()
	retry_button.text = "RETRY"
	retry_button.add_theme_font_size_override("font_size", 14)
	retry_button.pressed.connect(save_pending)
	retry_button.visible = false
	status.add_child(retry_button)
	restart_indicator = _label("RESTART REQUIRED", 14, AMBER)
	restart_indicator.visible = false
	status.add_child(restart_indicator)
	close_button = Button.new()
	close_button.text = "RESUME [ESC]"
	close_button.custom_minimum_size = Vector2(186, 40)
	close_button.add_theme_color_override("font_color", GREEN)
	close_button.add_theme_stylebox_override("normal", _box(Color("173c27"), Color("59926a")))
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	row.add_child(close_button)


func _rows(page: String) -> VBoxContainer:
	return pages[page].get_child(1).get_child(0).get_child(0)


func _transport() -> bool:
	return not settings.profile_defaults.is_empty()


func _build_quick(rows: Node) -> void:
	add_section(rows, "FLIGHT FEEL")
	var presets = HBoxContainer.new()
	presets.add_theme_constant_override("separation", 0)
	rows.add_child(presets)
	for id in ["stable", "balanced", "agile", "custom"]:
		var button = Button.new()
		button.text = id.to_upper()
		button.toggle_mode = true
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = id == "custom"
		button.tooltip_text = "Flight handling only." if id != "custom" else "Your handling adjustments."
		if id != "custom":
			button.pressed.connect(apply_preset.bind(id))
		presets.add_child(button)
		preset_buttons[id] = button
	for key in settings.FLIGHT_PRESET_KEYS:
		section_keys.quick.append(key)
	var gap = Control.new()
	gap.custom_minimum_size.y = 8
	rows.add_child(gap)
	add_slider(rows, "Input response", "input_response", 0.5, 2.0, 0.05, "", 1.0, "quick")
	add_checkbox(rows, "Invert pitch", "invert_pitch", "quick")
	_add_distance(rows, "quick")
	add_slider(rows, "HUD contrast", "hud_contrast", 0.0, 1.0, 0.05, "", 1.0, "quick")
	add_slider(rows, "Master volume", "audio_volume", 0.0, 1.0, 0.01, "", 1.0, "quick")


func _build_camera(rows: Node) -> void:
	_add_distance(rows, "camera")
	add_slider(rows, "Roll follow", "camera_roll_follow", 0.0, 0.5, 0.01, "", 1.0, "camera")
	add_slider(rows, "Smoothing", "camera_smoothing", 3.0, 15.0, 0.5, "", 1.0, "camera")
	add_slider(rows, "Speed FOV boost", "camera_fov_boost", 0.0, 16.0, 0.5, "", 1.0, "camera")
	add_slider(rows, "Free-look sensitivity", "view_sensitivity", 0.3, 2.0, 0.05, "", 1.0, "camera")
	add_slider(rows, "HUD contrast", "hud_contrast", 0.0, 1.0, 0.05, "", 1.0, "camera")


func _add_distance(rows: Node, page: String) -> void:
	var scale = 3.0 if _transport() else 1.0
	add_slider(rows, "Chase distance", "camera_distance", 8.0 * scale, 32.0 * scale, 0.5 * scale, "", scale, page)
	slider_controls[-1].slider.tooltip_text = "Distance in normal chase view. Wide view uses 1.5x."


func _build_graphics(rows: Node) -> void:
	add_section(rows, "PERFORMANCE")
	add_option(rows, "Frame limit", "fps_cap", [
		{"label": "UNLIMITED", "value": 0},
		{"label": "120 FPS", "value": 120},
		{"label": "60 FPS", "value": 60},
		{"label": "45 FPS", "value": 45},
	], "graphics")
	add_option(rows, "3D scale", "render_scale", [
		{"label": "100%", "value": 1.0},
		{"label": "85%", "value": 0.85},
		{"label": "75%", "value": 0.75},
		{"label": "65%", "value": 0.65},
	], "graphics")
	if level_id != 4:
		add_option(rows, "Cloud mode", "volume_clouds", [
			{"label": "VOLUMETRIC", "value": true},
			{"label": "SIMPLIFIED", "value": false},
		], "graphics")
	if level_id != 4:
		var low = 0.8 if level_id in [2, 5] else 0.2
		var high = 0.4 if level_id == 1 else 0.85
		add_slider(rows, "Cloud coverage", "cloud_coverage", low, high, 0.01, "", 1.0, "graphics")
		if level_id in [1, 3]:
			add_slider(rows, "Cloud top", "cloud_top", 2200.0, 6000.0, 100.0, "", 1.0, "graphics")
		add_slider(rows, "Cloud quality", "cloud_quality", 0.0, 2.0, 1.0, "", 1.0, "graphics")
	add_slider(rows, "Sun elevation", "sun_elevation", 10.0, 55.0, 1.0, "", 1.0, "graphics")
	if level_id == 4:
		add_section(rows, "ISLAND CLOUDS / FIXED")
	elif level_id in [2, 5]:
		add_section(rows, "CLOUD CEILING / 7800 M")


func _build_audio(rows: Node) -> void:
	add_slider(rows, "Master volume", "audio_volume", 0.0, 1.0, 0.01, "", 1.0, "audio")
	var gap = Control.new()
	gap.custom_minimum_size.y = 16
	rows.add_child(gap)
	add_section(rows, "SOUND CHECK")
	for id in ["cannon", "rocket", "explosion"]:
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 52
		rows.add_child(row)
		var title = _label(id.capitalize(), 18)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(title)
		var button = Button.new()
		button.text = "PLAY"
		button.custom_minimum_size = Vector2(128, 36)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(play_preview.bind(id))
		row.add_child(button)
		preview_buttons[id] = button


func _build_controls(rows: Node) -> void:
	if ground_attack:
		add_section(rows, "MANUAL AIM / ASSIST OFF", AMBER)
	elif combat_enabled:
		add_slider(rows, "Aim assist", "gun_assist_strength", 0.0, 1.0, 0.05, "", 1.0, "controls")
		if level_id in [2, 5]:
			var note = _label("AVAILABLE AFTER TAIL HOLD" if level_id == 2 else "AVAILABLE AT WEAPON RELEASE", 13, MUTED)
			rows.add_child(note)
	binding_prompt = _label("CLICK A KEY TO REBIND", 13, MUTED)
	rows.add_child(binding_prompt)
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	rows.add_child(columns)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	columns.add_child(left)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	columns.add_child(right)
	for group in BINDING_GROUPS:
		if group[0] == "WEAPONS" and not combat_enabled:
			continue
		var column = left if group[0] in ["FLIGHT", "WEAPONS"] else right
		add_section(column, group[0])
		for entry in group[1]:
			if entry[1] == "gear_toggle" and not _transport():
				continue
			_add_binding(column, entry[0], entry[1])


func _add_binding(parent: Node, title: String, action: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var name_label = _label(("Rocket" if ground_attack else "Missile") if action == "missile_fire" else title, 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var button = Button.new()
	button.custom_minimum_size = Vector2(94, 26)
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style = theme.get_stylebox(state, "Button").duplicate()
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(begin_binding.bind(action))
	row.add_child(button)
	binding_buttons[action] = button
	section_actions.controls.append(action)


func _build_advanced(rows: Node) -> void:
	var transport = _transport()
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	rows.add_child(columns)
	var handling = VBoxContainer.new()
	handling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	handling.add_theme_constant_override("separation", 12)
	columns.add_child(handling)
	var power = VBoxContainer.new()
	power.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power.add_theme_constant_override("separation", 12)
	columns.add_child(power)
	add_section(handling, "HANDLING")
	add_slider(handling, "Roll rate", "roll_rate", 0.1 if transport else 0.5, 0.9 if transport else 3.5, 0.01 if transport else 0.05, "", 1.0, "advanced", true)
	add_slider(handling, "Pitch rate", "pitch_rate", 0.05 if transport else 0.2, 0.4 if transport else 1.2, 0.01, "", 1.0, "advanced", true)
	add_slider(handling, "Yaw rate", "yaw_rate", 0.05, 0.8, 0.01, "", 1.0, "advanced", true)
	add_slider(handling, "Turn coordination", "turn_coordination", 0.0, 1.5 if transport else 0.8, 0.01, "", 1.0, "advanced", true)
	if level_id == 3:
		add_section(handling, "MISSION")
		add_slider(handling, "Enemy count", "max_enemies", 1.0, 5.0, 1.0, "", 1.0, "advanced", true)
		var note = _label("RESTART REQUIRED", 13, AMBER)
		handling.add_child(note)
	add_section(power, "POWER & AIRFRAME")
	add_slider(power, "Engine thrust", "thrust", 2.0 if transport else 6.0, 10.0 if transport else 30.0, 0.1, "", 1.0, "advanced", true)
	add_slider(power, "Aerodynamic drag", "drag", 0.0002, 0.0009, 0.00001, "", 10000.0, "advanced", true)
	add_slider(power, "Min speed", "speed_min", 20.0, 100.0, 1.0, "", 1.0, "advanced", true)
	add_slider(power, "Max speed", "speed_max", 100.0 if transport else 160.0, 200.0 if transport else 320.0, 5.0, "", 1.0, "advanced", true)
	add_slider(power, "Throttle response", "throttle_response", 0.2, 1.2, 0.05, "", 1.0, "advanced", true)
	add_slider(power, "Idle brake", "throttle_brake_strength", 0.0, 2.0, 0.05, "", 1.0, "advanced", true)
	add_slider(power, "Stall sink", "stall_sink", 4.0, 24.0, 0.5, "", 1.0, "advanced", true)


func add_section(parent: Node, title: String, color: Color = MUTED) -> void:
	var heading = _label(title, 14, color)
	heading.custom_minimum_size.y = 24
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(heading)


func add_slider(parent: Node, title: String, key: String, minimum: float, maximum: float, step: float, _unit: String = "", scale_factor: float = 1.0, page: String = "quick", compact: bool = false) -> void:
	var row = VBoxContainer.new() if compact else HBoxContainer.new()
	row.add_theme_constant_override("separation", 4 if compact else 18)
	row.custom_minimum_size.y = 48 if not compact else 46
	parent.add_child(row)
	var header = HBoxContainer.new()
	if not compact:
		header.custom_minimum_size.x = 236
		header.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(header)
	var title_label = _label(title, 16 if compact else 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var value_label = _label("", 22, GREEN, true)
	value_label.custom_minimum_size.x = 84 if not compact else 64
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider = HSlider.new()
	slider.min_value = minimum * (scale_factor if key == "drag" else 1.0)
	slider.max_value = maximum * (scale_factor if key == "drag" else 1.0)
	slider.step = step * (scale_factor if key == "drag" else 1.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(88, 24)
	if compact:
		header.add_child(value_label)
		row.add_child(slider)
	else:
		row.add_child(slider)
		row.add_child(value_label)
	var entry = {"slider": slider, "key": key, "scale": scale_factor, "label": value_label, "page": page}
	slider_controls.append(entry)
	if not section_keys[page].has(key):
		section_keys[page].append(key)
	slider.value_changed.connect(func(value: float) -> void:
		if refreshing:
			return
		settings.values[key] = value / scale_factor
		_mark_dirty()
		refresh_controls()
	)


func add_checkbox(parent: Node, title: String, key: String, page: String = "quick") -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 48
	parent.add_child(row)
	var name_label = _label(title, 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var checkbox = CheckButton.new()
	checkbox.custom_minimum_size = Vector2(116, 34)
	checkbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	checkbox.toggled.connect(func(value: bool) -> void:
		if refreshing:
			return
		settings.values[key] = value
		_mark_dirty()
		refresh_controls()
	)
	row.add_child(checkbox)
	checkbox_controls.append({"checkbox": checkbox, "key": key, "page": page})
	if not section_keys[page].has(key):
		section_keys[page].append(key)


func add_option(parent: Node, title: String, key: String, choices: Array, page: String) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var title_label = _label(title, 18)
	title_label.custom_minimum_size.x = 236
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title_label)
	var option_button = OptionButton.new()
	option_button.custom_minimum_size = Vector2(190, 34)
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	option_button.add_theme_font_size_override("font_size", 14)
	option_button.tooltip_text = "Apply immediately and save with this mission."
	for index in range(choices.size()):
		option_button.add_item(choices[index].label, index)
		option_button.set_item_metadata(index, choices[index].value)
	option_button.item_selected.connect(func(index: int) -> void:
		if refreshing:
			return
		settings.values[key] = option_button.get_item_metadata(index)
		_mark_dirty()
		refresh_controls()
	)
	row.add_child(option_button)
	option_controls.append({"option": option_button, "key": key, "choices": choices, "page": page})
	if not section_keys[page].has(key):
		section_keys[page].append(key)


func _layout_panel() -> void:
	panel.custom_minimum_size = Vector2(min(1080.0, get_viewport_rect().size.x - 64.0), min(722.0, get_viewport_rect().size.y - 48.0))


func show_page(id: String, animate: bool = true) -> void:
	if not pages.has(id):
		return
	if current_page != id:
		stop_preview()
		binding_action = ""
		refresh_binding_buttons()
	current_page = id
	for page in pages:
		pages[page].visible = page == id
		nav_buttons[page].set_pressed_no_signal(page == id)
	if visible:
		nav_buttons[id].grab_focus()
	if animate and active_page != id and visible:
		if page_tween != null:
			page_tween.kill()
		pages[id].modulate.a = 0.5
		page_tween = create_tween()
		page_tween.tween_property(pages[id], "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		pages[id].modulate.a = 1.0
	active_page = id


func _mark_dirty() -> void:
	dirty = true
	save_state = "pending"
	save_label.text = "SAVING..."
	save_label.add_theme_color_override("font_color", INK)
	retry_button.visible = false
	save_timer.start()


func save_pending() -> Error:
	save_timer.stop()
	var result = settings.save_to_disk()
	_accept_save_result(result)
	return result


func _accept_save_result(result: Error) -> void:
	last_save_error = result
	dirty = result != OK
	save_state = "saved" if result == OK else "error"
	save_label.text = "SAVED" if result == OK else "SAVE FAILED"
	save_label.add_theme_color_override("font_color", INK if result == OK else AMBER)
	save_label.tooltip_text = "" if result == OK else "Current values are active. Unable to write settings (%s). Retry to save." % error_string(result)
	retry_button.visible = result != OK


func apply_preset(id: String) -> void:
	save_timer.stop()
	var result = settings.apply_preset(id)
	_accept_save_result(result)
	refresh_controls()
	if preset_buttons.has(id):
		preset_buttons[id].modulate.a = 0.65
		create_tween().tween_property(preset_buttons[id], "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func reset_current_section() -> Error:
	save_timer.stop()
	binding_action = ""
	stop_preview()
	var result = settings.reset_section(section_keys[current_page], section_actions[current_page])
	if not section_actions[current_page].is_empty():
		get_tree().call_group("flight_controllers", "setup_input")
	_accept_save_result(result)
	refresh_controls()
	return result


func refresh_controls() -> void:
	refreshing = true
	for entry in slider_controls:
		var value = clamp(float(settings.values[entry.key]) * entry.scale, entry.slider.min_value, entry.slider.max_value)
		entry.slider.set_value_no_signal(value)
		entry.label.text = format_value(entry.key, value)
	for entry in checkbox_controls:
		entry.checkbox.set_pressed_no_signal(bool(settings.values[entry.key]))
		entry.checkbox.text = "ON" if settings.values[entry.key] else "OFF"
	for entry in option_controls:
		var selected_index = 0
		var best_distance = INF
		for index in range(entry.choices.size()):
			var distance = abs(float(entry.choices[index].value) - float(settings.values[entry.key]))
			if distance < best_distance:
				selected_index = index
				best_distance = distance
		entry.option.select(selected_index)
	var selected = settings.current_preset()
	for id in preset_buttons:
		preset_buttons[id].set_pressed_no_signal(id == selected)
		if id == "custom":
			preset_buttons[id].add_theme_stylebox_override("disabled", _box(Color("173e29") if selected == id else Color("0d2118"), GREEN if selected == id else BORDER))
			preset_buttons[id].add_theme_color_override("font_disabled_color", GREEN if selected == id else MUTED)
	refreshing = false
	refresh_binding_buttons()
	if restart_indicator != null:
		restart_indicator.visible = restart_values.has("max_enemies") and not is_equal_approx(float(restart_values.max_enemies), float(settings.values.max_enemies))


func begin_binding(action: String) -> void:
	binding_action = action
	refresh_binding_buttons()


func capture_binding_event(event: InputEvent) -> void:
	if binding_action.is_empty() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_ESCAPE and code != 0:
		settings.key_bindings[binding_action] = code
		get_tree().call_group("flight_controllers", "setup_input")
		_mark_dirty()
	binding_action = ""
	refresh_binding_buttons()


func refresh_binding_buttons() -> void:
	for action in binding_buttons:
		binding_buttons[action].text = "..." if binding_action == action else "[%s]" % OS.get_keycode_string(settings.key_bindings[action])
		binding_buttons[action].add_theme_color_override("font_color", GREEN if binding_action == action else INK)
	if binding_prompt != null:
		binding_prompt.text = "PRESS A KEY / ESC TO CANCEL" if not binding_action.is_empty() else "CLICK A KEY TO REBIND"
		binding_prompt.add_theme_color_override("font_color", GREEN if not binding_action.is_empty() else MUTED)


func format_value(key: String, value: float) -> String:
	match key:
		"drag": return "%.1f x10-4" % value
		"roll_rate", "pitch_rate", "yaw_rate": return "%.2f rad/s" % value
		"camera_roll_follow", "audio_volume", "cloud_coverage", "hud_contrast", "gun_assist_strength": return "%d%%" % roundi(value * 100.0)
		"camera_distance": return "%.1f m" % value
		"turn_coordination", "input_response": return "%.2f" % value
		"thrust", "camera_smoothing": return "%.1f" % value
		"speed_min", "speed_max", "stall_sink": return "%d m/s" % roundi(value)
		"throttle_response", "throttle_brake_strength", "view_sensitivity": return "%.2f x" % value
		"camera_fov_boost", "sun_elevation": return "%d°" % roundi(value)
		"max_enemies": return "%d" % roundi(value)
		"cloud_top": return "%d m" % roundi(value)
		"cloud_quality": return ["LOW", "MEDIUM", "HIGH"][clampi(roundi(value), 0, 2)]
	return str(value)


func play_preview(id: String) -> void:
	if preview_kind == id:
		stop_preview()
		return
	stop_preview()
	preview_kind = id
	# A private stream keeps the cannon's gameplay loop setting out of previews.
	preview_player.stream = PREVIEW_STREAMS[id].duplicate()
	preview_player.stream.loop = false
	preview_player.volume_db = -13.0 if id == "cannon" else -8.0
	preview_player.play()
	preview_buttons[id].text = "STOP"


func stop_preview() -> void:
	if preview_player != null:
		preview_player.stop()
	preview_kind = ""
	for id in preview_buttons:
		preview_buttons[id].text = "PLAY"


func open() -> void:
	refresh_controls()
	show_page("quick", false)
	visible = true
	if open_tween != null:
		open_tween.kill()
	modulate.a = 0.0
	open_tween = create_tween()
	open_tween.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	nav_buttons.quick.grab_focus()


func close() -> void:
	binding_action = ""
	refresh_binding_buttons()
	if save_pending() != OK:
		return
	stop_preview()
	visible = false
	closed.emit()
