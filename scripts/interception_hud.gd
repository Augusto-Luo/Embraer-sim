extends CanvasLayer

const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const BODY_FONT = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const INK = Color("c9eddd")
const MUTED = Color("91b9aa")
const GREEN = Color("83e7b0")
const AMBER = Color("ffd083")
const BRIEFING_TEXT = "Investigue uma transmissão desconhecida entre as nuvens. Mantenha o controle do KC-390 e encontre uma rota segura de saída."

class NavigationOverlay extends Control:
	var hud
	func _draw() -> void:
		if hud != null:
			hud.draw_navigation(self)

var controller
var root_control: Control
var panel: PanelContainer
var mission_layout: VBoxContainer
var mission_caption: Label
var fictional_label: Label
var compact_mode = false
var layout_mode_initialized = false
var objective_label: Label
var detail_label: Label
var status_label: Label
var warning_label: Label
var progress: ProgressBar
var radio_panel: PanelContainer
var radio_source: Label
var radio_label: Label
var cinematic_subtitle: Label
var cinematic_active = false
var cinematic_alpha = 1.0
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var restart_button: Button
var navigation: NavigationOverlay
var snapshot: Dictionary = {}
var last_stage = ""
var last_radio = ""
var briefing_elapsed = 0.0
var motion_elapsed = 0.0
var stage_tween: Tween
var radio_tween: Tween
var result_tween: Tween
var draw_elapsed = 0.0


func _ready() -> void:
	layer = 4
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	navigation = NavigationOverlay.new()
	navigation.hud = self
	navigation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(navigation)
	build_mission_panel()
	build_radio_panel()
	build_cinematic_subtitle()
	build_result_panel()
	root_control.move_child(navigation, root_control.get_child_count() - 1)
	start_briefing_stream()


func make_label(value: String, font_size: int, color: Color = INK, instrument: bool = false) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_override("font", INSTRUMENT_FONT if instrument else BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.025, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func make_panel() -> PanelContainer:
	var result = PanelContainer.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.024, 0.032, 0.88)
	style.border_color = Color(0.48, 0.74, 0.64, 0.42)
	style.set_border_width_all(1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	result.add_theme_stylebox_override("panel", style)
	root_control.add_child(result)
	return result


func build_mission_panel() -> void:
	panel = make_panel()
	var layout = VBoxContainer.new()
	mission_layout = layout
	layout.add_theme_constant_override("separation", 3)
	panel.add_child(layout)
	var heading = HBoxContainer.new()
	layout.add_child(heading)
	mission_caption = make_label("05 / OPERAÇÃO ECO", 16, GREEN, true)
	heading.add_child(mission_caption)
	var fictional = make_label("HALLOWEEN / CENÁRIO FICCIONAL", 10, MUTED)
	fictional_label = fictional
	fictional.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fictional.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(fictional)
	objective_label = make_label("Mantenha o voo noturno", 25, INK, true)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(objective_label)
	detail_label = make_label(BRIEFING_TEXT, 13, MUTED)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size.y = 34.0
	layout.add_child(detail_label)
	status_label = make_label("KC-390 / NIGHT FLIGHT", 13, GREEN, true)
	layout.add_child(status_label)
	progress = ProgressBar.new()
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 4
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.24, 0.42, 0.38, 0.36)
	var fill = StyleBoxFlat.new()
	fill.bg_color = GREEN
	progress.add_theme_stylebox_override("background", background)
	progress.add_theme_stylebox_override("fill", fill)
	layout.add_child(progress)
	warning_label = make_label("", 13, AMBER, true)
	layout.add_child(warning_label)


func build_radio_panel() -> void:
	radio_panel = make_panel()
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 3)
	radio_panel.add_child(layout)
	radio_source = make_label("RADIO / NIGHT CONTROL", 12, GREEN, true)
	layout.add_child(radio_source)
	radio_label = make_label("Maintain your heading. The corridor is clear.", 15, INK)
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_label.custom_minimum_size.y = 36.0
	layout.add_child(radio_label)


func build_cinematic_subtitle() -> void:
	cinematic_subtitle = make_label("", 15, INK)
	cinematic_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cinematic_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	cinematic_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cinematic_subtitle.visible = false
	root_control.add_child(cinematic_subtitle)


func make_button(value: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(220, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", INSTRUMENT_FONT)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", INK)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.12, 0.10, 0.96)
	normal.border_color = Color(0.51, 0.79, 0.65, 0.7)
	normal.set_border_width_all(1)
	var hover = normal.duplicate()
	hover.bg_color = Color(0.08, 0.23, 0.17, 1.0)
	hover.border_color = GREEN
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.12, 0.30, 0.21, 1.0)
	var focus = normal.duplicate()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = INK
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button


func build_result_panel() -> void:
	result_panel = make_panel()
	var result_style = result_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	result_style.bg_color = Color("07121a")
	result_panel.add_theme_stylebox_override("panel", result_style)
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_panel.visible = false
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	result_panel.add_child(layout)
	layout.add_child(make_label("OPERAÇÃO ECO / CENÁRIO FICCIONAL", 12, MUTED))
	result_title = make_label("CORREDOR SEGURO", 40, GREEN, true)
	layout.add_child(result_title)
	result_detail = make_label("O voo foi concluído. A origem do sinal permanece desconhecida.", 16, INK)
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(result_detail)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)
	restart_button = make_button("VOAR NOVAMENTE", restart_mission)
	actions.add_child(restart_button)
	actions.add_child(make_button("MISSÕES", return_to_missions))


func restart_mission() -> void:
	if controller != null:
		controller.reset_flight()


func return_to_missions() -> void:
	if controller != null:
		controller.return_to_level_select()


func start_briefing_stream() -> void:
	briefing_elapsed = 0.0
	motion_elapsed = 0.0
	last_stage = ""
	last_radio = ""
	cinematic_active = false
	cinematic_alpha = 1.0
	snapshot = {}
	for tween in [stage_tween, radio_tween, result_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	if panel != null:
		panel.modulate.a = 0.0
		stage_tween = create_tween()
		stage_tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	if result_panel != null:
		result_panel.visible = false
	if radio_panel != null:
		radio_panel.modulate.a = 1.0
	if navigation != null:
		navigation.modulate.a = 1.0
	if cinematic_subtitle != null:
		cinematic_subtitle.visible = false


func _process(dt: float) -> void:
	if controller == null or controller.interception == null:
		visible = false
		return
	visible = not controller.intro_active and not controller.observing and not controller.settings_open and not controller.paused
	if not visible:
		return
	if not controller.frozen and not controller.observation_frozen:
		briefing_elapsed += dt
		motion_elapsed += dt
	snapshot = controller.interception.interception_snapshot()
	var stage = str(snapshot.get("stage", "night_flight"))
	var finished = stage in ["complete", "failed"]
	apply_layout_mode(controller.cockpit_mode)
	objective_label.text = str(snapshot.get("objective", "Mantenha o voo noturno"))
	detail_label.text = BRIEFING_TEXT if stage == "night_flight" and briefing_elapsed < 12.0 else str(snapshot.get("detail", "Siga o marcador de navegação."))
	var distance = float(snapshot.get("distance", 0.0))
	var nav_label = str(snapshot.get("nav_label", "NAV"))
	if stage == "contact":
		status_label.text = "ECO-13 / %.0f M  ·  IDENTIFICAÇÃO %.1f / %.0f S" % [distance, float(snapshot.get("follow_time", 0.0)), float(snapshot.get("follow_required", 6.0))]
	elif stage == "escort":
		status_label.text = "ECO-13 / %.0f M  ·  MANTENHA 400–2200 M" % distance
	elif stage == "free_flight":
		status_label.text = "CONTROLE MANUAL  ·  SEM ROTA OBRIGATÓRIA"
	elif stage == "return_route":
		status_label.text = "%s / %.1f KM  ·  ROTA %d / %d" % [nav_label, float(snapshot.get("waypoint_distance", distance)) / 1000.0, int(snapshot.get("waypoint_index", 1)), int(snapshot.get("waypoint_count", 2))]
	else:
		status_label.text = "%s  ·  %.1f KM" % [nav_label, distance / 1000.0]
	progress.visible = stage in ["contact", "escort"]
	progress.value = clamp(float(snapshot.get("progress", 0.0)), 0.0, 1.0)
	warning_label.text = str(snapshot.get("warning", ""))
	warning_label.visible = not compact_mode and not warning_label.text.is_empty()
	if compact_mode and not warning_label.text.is_empty():
		status_label.text = "%s  ·  %.1f KM" % [warning_label.text, distance / 1000.0]
	status_label.add_theme_color_override("font_color", AMBER if compact_mode and not warning_label.text.is_empty() else GREEN)
	var interference = float(snapshot.get("radio_interference", 0.0))
	radio_source.text = "RADIO / " + str(snapshot.get("radio_source", "NIGHT CONTROL"))
	radio_source.add_theme_color_override("font_color", AMBER if interference > 0.25 else GREEN)
	var radio = str(snapshot.get("radio_text", ""))
	radio_label.text = radio
	radio_panel.visible = not radio.is_empty()
	if radio != last_radio:
		last_radio = radio
		if radio_tween != null and radio_tween.is_valid():
			radio_tween.kill()
		radio_label.modulate.a = 0.45
		radio_tween = create_tween()
		radio_tween.tween_property(radio_label, "modulate:a", 1.0, 0.22)
	if stage != last_stage:
		last_stage = stage
		if stage_tween != null and stage_tween.is_valid():
			stage_tween.kill()
		objective_label.modulate.a = 0.55
		stage_tween = create_tween()
		stage_tween.tween_property(objective_label, "modulate:a", 1.0, 0.24)
		panel.modulate.a = 1.0
		if finished:
			show_result(stage == "complete")
	panel.visible = not finished and (stage != "free_flight" or float(snapshot.get("stage_elapsed", 0.0)) < 12.0)
	result_panel.visible = finished
	update_cinematic_overlay(stage, radio)
	layout_panels()
	draw_elapsed += dt
	if draw_elapsed >= 1.0 / 30.0:
		draw_elapsed = 0.0
		navigation.queue_redraw()


func update_cinematic_overlay(stage: String, radio: String) -> void:
	var active = bool(snapshot.get("cinematic", stage == "monster_reveal"))
	var was_active = cinematic_active
	cinematic_active = active
	if active:
		var time = float(snapshot.get("cinematic_time", 0.0))
		# Overlay fades follow the mission clock, so pause/resume never races
		# independent tweens or covers the windscreen with a letterbox.
		cinematic_alpha = maxf(1.0 - smoothstep(0.0, 0.85, time), smoothstep(12.8, 14.0, time))
		panel.modulate.a = cinematic_alpha
		radio_panel.modulate.a = cinematic_alpha
		navigation.modulate.a = cinematic_alpha
		cinematic_subtitle.text = radio
		cinematic_subtitle.visible = not radio.is_empty()
		cinematic_subtitle.modulate.a = smoothstep(1.0, 1.8, time) * (1.0 - smoothstep(12.3, 13.2, time))
	elif was_active:
		cinematic_alpha = 1.0
		panel.modulate.a = 1.0
		radio_panel.modulate.a = 1.0
		navigation.modulate.a = 1.0
		cinematic_subtitle.visible = false
	else:
		cinematic_subtitle.visible = false


func apply_layout_mode(cockpit: bool) -> void:
	if layout_mode_initialized and compact_mode == cockpit:
		return
	layout_mode_initialized = true
	compact_mode = cockpit
	detail_label.visible = not cockpit
	mission_layout.add_theme_constant_override("separation", 2 if cockpit else 3)
	mission_caption.add_theme_font_size_override("font_size", 14 if cockpit else 16)
	fictional_label.add_theme_font_size_override("font_size", 9 if cockpit else 10)
	objective_label.add_theme_font_size_override("font_size", 22 if cockpit else 25)
	status_label.add_theme_font_size_override("font_size", 12 if cockpit else 13)
	radio_label.add_theme_font_size_override("font_size", 14 if cockpit else 15)
	radio_label.custom_minimum_size.y = 0.0 if cockpit else 36.0
	var mission_style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	mission_style.content_margin_top = 6 if cockpit else 10
	mission_style.content_margin_bottom = 6 if cockpit else 10
	var radio_style = radio_panel.get_theme_stylebox("panel") as StyleBoxFlat
	radio_style.content_margin_top = 8 if cockpit else 10
	radio_style.content_margin_bottom = 8 if cockpit else 10
	panel.minimum_size_changed.emit()
	radio_panel.minimum_size_changed.emit()


func layout_panels() -> void:
	var viewport = root_control.get_viewport_rect().size
	var width = maxf(520.0, minf(760.0, viewport.x - 480.0))
	panel.position = Vector2((viewport.x - width) * 0.5, 48 if compact_mode else 62)
	# Recompute the minimum after wrapping or switching views; do not carry a
	# larger chase-panel height into the compact cockpit layout.
	panel.size = Vector2(width, 0.0)
	var radio_width = minf(440.0, viewport.x * 0.31) if compact_mode else width
	radio_panel.position = Vector2(viewport.x - radio_width - 32.0, 180.0) if compact_mode else Vector2((viewport.x - width) * 0.5, viewport.y - 148.0)
	radio_panel.size = Vector2(radio_width, 0.0)
	result_panel.size = Vector2(minf(620.0, viewport.x - 100.0), 0.0)
	result_panel.position = Vector2((viewport.x - result_panel.size.x) * 0.5, viewport.y * 0.28)
	var subtitle_width = minf(850.0, viewport.x - 180.0)
	cinematic_subtitle.position = Vector2((viewport.x - subtitle_width) * 0.5, viewport.y * 0.70)
	cinematic_subtitle.size = Vector2(subtitle_width, 24.0)


func show_result(success: bool) -> void:
	result_title.text = "CORREDOR SEGURO" if success else "SINAL PERDIDO"
	result_title.add_theme_color_override("font_color", GREEN if success else AMBER)
	result_detail.text = "O voo foi concluído. A origem do sinal permanece desconhecida." if success else "Você deixou o corredor por tempo demais. Retorne à rota na próxima tentativa."
	restart_button.text = "VOAR NOVAMENTE" if success else "TENTAR NOVAMENTE"
	result_panel.modulate.a = 0.0
	if result_tween != null and result_tween.is_valid():
		result_tween.kill()
	result_tween = create_tween()
	result_tween.tween_property(result_panel, "modulate:a", 1.0, 0.4)
	restart_button.grab_focus()


func draw_navigation(canvas: Control) -> void:
	if snapshot.is_empty() or controller == null or not is_instance_valid(controller.camera):
		return
	var stage = str(snapshot.get("stage", "night_flight"))
	if not bool(snapshot.get("navigation_active", true)):
		return
	if stage in ["complete", "failed"] or cinematic_active and cinematic_alpha <= 0.01:
		return
	var viewport = root_control.get_viewport_rect().size
	var world_position: Vector3 = snapshot.get("navigation_position", controller.interception.navigation_position())
	var camera: Camera3D = controller.camera
	var point = camera.unproject_position(world_position)
	var safe_top = 280.0 if compact_mode else 220.0
	var safe = Rect2(Vector2(210, safe_top), Vector2(viewport.x - 420.0, viewport.y - safe_top - 200.0))
	var color = AMBER if bool(snapshot.get("signal_lost", false)) else GREEN
	var is_contact = bool(snapshot.get("target_valid", false)) and stage in ["contact", "escort"]
	var distance = float(snapshot.get("distance", 0.0))
	var label = str(snapshot.get("nav_label", "NAV"))
	if not camera.is_position_behind(world_position) and safe.has_point(point):
		if is_contact:
			for sign_x in [-1, 1]:
				for sign_y in [-1, 1]:
					var corner = point + Vector2(sign_x * 22.0, sign_y * 22.0)
					canvas.draw_line(corner, corner - Vector2(sign_x * 9.0, 0), color, 1.2, true)
					canvas.draw_line(corner, corner - Vector2(0, sign_y * 9.0), color, 1.2, true)
			if stage == "contact":
				var amount = maxf(0.001, float(snapshot.get("progress", 0.0)))
				canvas.draw_arc(point, 29.0, -PI * 0.5, -PI * 0.5 + TAU * amount, 36, color, 1.5, true)
		else:
			var diamond = PackedVector2Array([point + Vector2(0, -12), point + Vector2(12, 0), point + Vector2(0, 12), point + Vector2(-12, 0), point + Vector2(0, -12)])
			canvas.draw_polyline(diamond, color, 1.3, true)
		var text_origin = point + Vector2(39, -7)
		text_origin.x = minf(text_origin.x, viewport.x - 250.0)
		canvas.draw_line(point + Vector2(26, 0), text_origin - Vector2(5, 0), Color(color, 0.6), 1.0, true)
		canvas.draw_string(INSTRUMENT_FONT, text_origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
		canvas.draw_string(INSTRUMENT_FONT, text_origin + Vector2(0, 18), "%.1f KM" % (distance / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	else:
		var local = camera.global_transform.basis.inverse() * (world_position - camera.global_position)
		var direction = Vector2(local.x, -local.y)
		if direction.length_squared() < 0.001:
			direction = Vector2.DOWN
		direction = direction.normalized()
		var half = safe.size * 0.5
		var extent = minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		var edge = safe.get_center() + direction * extent
		var tangent = Vector2(-direction.y, direction.x)
		var arrow = PackedVector2Array([edge + direction * 10.0, edge - direction * 7.0 + tangent * 6.0, edge - direction * 7.0 - tangent * 6.0])
		canvas.draw_colored_polygon(arrow, color)
		var text_origin = edge - direction * 31.0 + Vector2(-42, 28)
		canvas.draw_string(INSTRUMENT_FONT, text_origin, "%s / %.1f KM" % [label, distance / 1000.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
	# Add the same navigation fix to the existing heading instrument.
	if not controller.cockpit_mode:
		var radar_center = Vector2(maxf(22.0, viewport.x * 0.025) + 72.0, viewport.y - 112.0)
		var relative = world_position - controller.model.position
		var radar = Vector2(relative.dot(controller.model.right), -relative.dot(controller.model.forward)) * (58.0 / 5000.0)
		if radar.length() > 58.0:
			radar = radar.normalized() * 58.0
		canvas.draw_circle(radar_center + radar, 3.0, color)
	var interference = float(snapshot.get("radio_interference", 0.0))
	if interference > 0.0 and radio_panel.visible:
		var radio_rect = Rect2(radio_panel.position, radio_panel.size)
		for index in range(5):
			var y = radio_rect.position.y + fposmod(motion_elapsed * 19.0 + index * 13.0, maxf(1.0, radio_rect.size.y))
			var offset = sin(motion_elapsed * 3.0 + index * 2.2) * 12.0
			canvas.draw_line(Vector2(radio_rect.position.x + 8.0 + absf(offset), y), Vector2(radio_rect.end.x - 8.0, y), Color(AMBER, interference * 0.09), 1.0)
