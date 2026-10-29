extends Control

const INK = Color("baffd0")
const MUTED = Color("77a58b")
const GREEN = Color("62f69b")
const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const BODY_FONT = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const SELECTED_LEVEL_META = "selected_level"
const FLIGHT_SCENE = "res://scenes/flight_test.tscn"

var selected_level = 1
var level_buttons: Dictionary = {}
var mission_number: Label
var mission_title: Label
var mission_body: Label
var mission_route: Label
var start_button: Button
var launching = false
var selection_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_interface()
	select_level(1, false)
	level_buttons[1].grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("06120f"))
	for x in range(0, int(size.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.35, 0.75, 0.53, 0.035))
	for y in range(0, int(size.y), 64):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.35, 0.75, 0.53, 0.035))
	var radar_center = Vector2(size.x * 0.84, size.y * 0.33)
	for radius in [180.0, 300.0, 420.0]:
		draw_arc(radar_center, radius, 0.0, TAU, 100, Color(0.35, 0.90, 0.56, 0.045), 1.0, true)
	draw_line(Vector2(64, 0), Vector2(64, size.y), Color(0.35, 0.90, 0.56, 0.08))


func label(value: String, font_size: int, color: Color = INK, instrument: bool = false) -> Label:
	var result = Label.new()
	result.text = value
	result.add_theme_font_override("font", INSTRUMENT_FONT if instrument else BODY_FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func box_style(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style


func build_interface() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_top", 52)
	margin.add_theme_constant_override("margin_bottom", 42)
	add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	layout.add_child(label("FLIGHT / TRAINING", 20, GREEN))
	layout.add_child(label("MISSION SELECT", 60, INK, true))

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 16
	layout.add_child(spacer)

	var content = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 28)
	layout.add_child(content)

	var mission_list = VBoxContainer.new()
	mission_list.custom_minimum_size.x = 440
	mission_list.add_theme_constant_override("separation", 14)
	content.add_child(mission_list)
	mission_list.add_child(make_level_button(1, "AIRFIELD", "KC-390 CIRCUIT", true))
	mission_list.add_child(make_level_button(2, "PURSUIT", "KC-390", true))
	mission_list.add_child(make_level_button(3, "FREE COMBAT", "COASTAL RANGE", true))
	mission_list.add_child(make_level_button(4, "GROUND ATTACK", "CITY + OFFSHORE / MANUAL AIM", true))
	mission_list.add_child(make_level_button(5, "INTERCEPT", "FLASH EVENT / FLÁVIO", true))

	var details = PanelContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_stylebox_override("panel", box_style(Color("0b2019"), Color(0.40, 0.80, 0.56, 0.25)))
	content.add_child(details)
	var detail_layout = VBoxContainer.new()
	detail_layout.add_theme_constant_override("separation", 16)
	details.add_child(detail_layout)
	mission_number = label("", 18, GREEN)
	detail_layout.add_child(mission_number)
	mission_title = label("", 44, INK, true)
	detail_layout.add_child(mission_title)
	var separator = HSeparator.new()
	separator.modulate = Color(0.40, 0.80, 0.56, 0.28)
	detail_layout.add_child(separator)
	mission_body = label("", 26, Color("9dc6ae"))
	mission_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_layout.add_child(mission_body)
	mission_route = label("", 18, GREEN)
	detail_layout.add_child(mission_route)

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	layout.add_child(footer)
	var keyboard_hint = label("UP/DOWN SELECT    ENTER LAUNCH\nPLAYER INVINCIBLE", 18, MUTED)
	keyboard_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(keyboard_hint)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(300, 62)
	start_button.add_theme_font_override("font", INSTRUMENT_FONT)
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.add_theme_color_override("font_color", Color("06120f"))
	start_button.add_theme_color_override("font_disabled_color", Color("06120f"))
	start_button.add_theme_stylebox_override("normal", box_style(GREEN, GREEN))
	start_button.add_theme_stylebox_override("hover", box_style(Color("9bffbd"), Color("9bffbd")))
	start_button.add_theme_stylebox_override("pressed", box_style(Color("3fbd73"), Color("3fbd73")))
	start_button.add_theme_stylebox_override("disabled", box_style(Color("3fbd73"), Color("3fbd73")))
	start_button.add_theme_stylebox_override("focus", box_style(Color.TRANSPARENT, Color.WHITE, 2))
	start_button.pressed.connect(start_selected_level)
	footer.add_child(start_button)


func make_level_button(level: int, title: String, subtitle: String, available: bool) -> Button:
	var button = Button.new()
	button.custom_minimum_size.y = 94
	button.disabled = not available
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	button.add_theme_stylebox_override("normal", box_style(Color("0a1a15"), Color(0.40, 0.80, 0.56, 0.18)))
	button.add_theme_stylebox_override("hover", box_style(Color("112b20"), Color(0.40, 0.90, 0.56, 0.60)))
	button.add_theme_stylebox_override("pressed", box_style(Color("183d2a"), GREEN))
	button.add_theme_stylebox_override("disabled", box_style(Color("08150f"), Color(0.40, 0.80, 0.56, 0.08)))
	button.add_theme_stylebox_override("focus", box_style(Color.TRANSPARENT, GREEN, 2))
	var inner = HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 24
	inner.offset_right = -24
	inner.add_theme_constant_override("separation", 24)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inner)
	var number = label("%02d" % level, 46, GREEN if available else Color("365343"), true)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(number)
	var captions = VBoxContainer.new()
	captions.alignment = BoxContainer.ALIGNMENT_CENTER
	captions.add_theme_constant_override("separation", 6)
	captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(captions)
	captions.add_child(label(title, 32, INK if available else Color("4c6958"), true))
	captions.add_child(label(subtitle, 18, MUTED if available else Color("365343")))
	if available:
		button.pressed.connect(select_level.bind(level))
		level_buttons[level] = button
	return button


func select_level(level: int, animate: bool = true) -> void:
	if launching or not level_buttons.has(level):
		return
	var changed = selected_level != level or mission_title.text.is_empty()
	selected_level = level
	for number in level_buttons:
		var selected = number == level
		level_buttons[number].add_theme_stylebox_override("normal", box_style(Color("123325") if selected else Color("0a1a15"), GREEN if selected else Color(0.40, 0.80, 0.56, 0.18)))
	mission_number.text = "MISSION %02d" % level
	if level == 1:
		mission_title.text = "KC-390 CIRCUIT"
		mission_body.text = "TAKEOFF. CIRCUIT. LAND.\nFOLLOW THE LINE."
		mission_route.text = "RWY 36 / 2200 M / PATTERN 350 M"
	elif level == 2:
		mission_title.text = "KC-390 PURSUIT"
		mission_body.text = "CLOSE IN.\nHOLD TAIL FOR 2 SEC."
		mission_route.text = "5200 M / STRAIGHT + WIDE TURNS"
	elif level == 3:
		mission_title.text = "FREE COMBAT"
		mission_body.text = "GUNS. MISSILES. FREE FLIGHT."
		mission_route.text = "COASTAL RANGE / ORIGINAL CONFIG"
	elif level == 4:
		mission_title.text = "ISLAND STRIKE"
		mission_body.text = "DESTROY BOTH SITES.\nGUNS + GUIDED ROCKETS."
		mission_route.text = "8 TARGETS / MANUAL AIM / NO TIME LIMIT"
	else:
		mission_title.text = "INTERCEPT"
		mission_body.text = "CENÁRIO FICCIONAL.\nPERSIGA. MANTENHA. INTERCEPTE."
		mission_route.text = "ALVO: FLÁVIO / FRONTEIRA AÉREA"
	start_button.text = "LAUNCH %02d >" % level
	if changed and animate:
		animate_selection()


func animate_selection() -> void:
	if selection_tween != null and selection_tween.is_valid():
		selection_tween.kill()
	selection_tween = create_tween().set_parallel(true)
	for text_node in [mission_number, mission_title, mission_body, mission_route]:
		text_node.modulate.a = 0.4
		selection_tween.tween_property(text_node, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or launching:
		return
	if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
		var direction = 1 if event.keycode == KEY_DOWN else -1
		select_level(wrapi(selected_level - 1 + direction, 0, 5) + 1)
		level_buttons[selected_level].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
		select_level(event.keycode - KEY_1 + 1)
		level_buttons[selected_level].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		start_selected_level()


func start_selected_level() -> void:
	if launching:
		return
	launching = true
	start_button.disabled = true
	start_button.text = "LOADING..."
	get_tree().root.set_meta(SELECTED_LEVEL_META, selected_level)
	get_tree().root.set_meta("play_intro", selected_level in [1, 2, 3, 5])
	var result = get_tree().change_scene_to_file(FLIGHT_SCENE)
	if result != OK:
		launching = false
		start_button.disabled = false
		start_button.text = "RETRY LAUNCH"
		push_error("Unable to open flight scene: %s" % result)
