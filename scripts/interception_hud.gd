extends CanvasLayer

const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const BODY_FONT = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const INK = Color("baffd0")
const MUTED = Color("91bba3")
const AMBER = Color("ffd083")
const DIALOGUE_LEFT_FRACTION = 0.26
const BRIEFING_TEXT = "Após a derrota eleitoral, Flávio Bolsonaro embarca em um avião de transporte e tenta deixar o país. Intercepte a aeronave antes que ela cruze a fronteira aérea."
const BRIEFING_WORD_RATE = 5.0

var controller
var root_control: Control
var panel: PanelContainer
var dialogue_pointer: Polygon2D
var briefing_label: Label
var target_label: Label
var status_label: Label
var distance_label: Label
var border_label: Label
var guidance_label: Label
var weapon_label: Label
var progress: ProgressBar
var stream_elapsed = 0.0
var stream_character_rate = 30.0
var visible_character_count = 0
var stream_complete = false


func _ready() -> void:
	layer = 4
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.045, 0.031, 0.91)
	style.border_color = Color(0.40, 0.95, 0.61, 0.52)
	style.set_border_width_all(1)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(panel)
	dialogue_pointer = Polygon2D.new()
	dialogue_pointer.polygon = PackedVector2Array([Vector2(0, 0), Vector2(12, 9), Vector2(0, 18)])
	dialogue_pointer.color = Color(0.40, 0.95, 0.61, 0.72)
	root_control.add_child(dialogue_pointer)

	var content = HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var left_column = VBoxContainer.new()
	left_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_stretch_ratio = 1.20
	left_column.add_theme_constant_override("separation", 4)
	content.add_child(left_column)
	left_column.add_child(make_label("INTERCEPT  /  CENÁRIO FICCIONAL", 12, MUTED, true))
	briefing_label = make_label(BRIEFING_TEXT, 12, INK)
	briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	briefing_label.custom_minimum_size.y = 48.0
	left_column.add_child(briefing_label)
	content.add_child(VSeparator.new())

	var right_column = VBoxContainer.new()
	right_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 3)
	content.add_child(right_column)
	var target_row = HBoxContainer.new()
	target_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_row.add_theme_constant_override("separation", 10)
	right_column.add_child(target_row)
	target_label = make_label("ALVO: Flávio", 17, INK, true)
	target_row.add_child(target_label)
	status_label = make_label("STATUS: AGUARDANDO CONTATO", 10, MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	target_row.add_child(status_label)

	var distance_row = HBoxContainer.new()
	distance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_row.add_theme_constant_override("separation", 12)
	right_column.add_child(distance_row)
	distance_label = make_label("DISTÂNCIA: --", 11, INK)
	distance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distance_row.add_child(distance_label)
	border_label = make_label("FRONTEIRA: --", 11, INK)
	distance_row.add_child(border_label)
	guidance_label = make_label("Prepare-se para acelerar.", 12, INK)
	guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_child(guidance_label)

	var weapon_row = HBoxContainer.new()
	weapon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_row.add_theme_constant_override("separation", 10)
	right_column.add_child(weapon_row)
	progress = ProgressBar.new()
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(70, 5)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_row.add_child(progress)
	weapon_label = make_label("ARMAMENTO: BLOQUEADO", 12, AMBER, true)
	weapon_row.add_child(weapon_label)
	start_briefing_stream()


func start_briefing_stream() -> void:
	var word_count = max(1, BRIEFING_TEXT.split(" ", false).size())
	stream_character_rate = float(BRIEFING_TEXT.length()) / float(word_count) * BRIEFING_WORD_RATE
	stream_elapsed = 0.0
	visible_character_count = 0
	stream_complete = false
	briefing_label.text = ""


func advance_briefing_stream(dt: float) -> void:
	if stream_complete:
		return
	stream_elapsed += dt
	var next_count = int(min(BRIEFING_TEXT.length(), floor(stream_elapsed * stream_character_rate)))
	if next_count == visible_character_count:
		return
	visible_character_count = next_count
	briefing_label.text = BRIEFING_TEXT.left(visible_character_count)
	stream_complete = visible_character_count >= BRIEFING_TEXT.length()


func make_label(value: String, font_size: int, color: Color, instrument: bool = false) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_override("font", INSTRUMENT_FONT if instrument else BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0.03, 0.02, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(dt: float) -> void:
	if controller == null or controller.interception == null:
		visible = false
		return
	visible = not controller.intro_active and not controller.observing
	if visible and not controller.paused and not controller.frozen and not controller.settings_open:
		advance_briefing_stream(dt)
	var viewport_size = root_control.get_viewport_rect().size
	var margin = max(22.0, viewport_size.x * 0.025)
	var left = viewport_size.x * DIALOGUE_LEFT_FRACTION
	var right = viewport_size.x - margin - 142.0 - 12.0
	panel.size = Vector2(max(600.0, right - left), panel.get_minimum_size().y)
	panel.position = Vector2(left, 58)
	dialogue_pointer.position = panel.position + Vector2(panel.size.x, 26)
	var data = controller.interception.interception_snapshot()
	var stage = data.stage
	var has_target = data.target_valid
	distance_label.text = "DISTÂNCIA: %.1f KM" % (float(data.distance) / 1000.0) if has_target else "DISTÂNCIA: --"
	border_label.text = "FRONTEIRA: %.1f KM" % (float(data.border_distance) / 1000.0) if has_target else "FRONTEIRA: --"
	match stage:
		"chase_cinematic":
			status_label.text = "STATUS: FUGA EM ANDAMENTO"
			guidance_label.text = "Acelere e feche a distância. O alvo tenta escapar."
		"intercept":
			status_label.text = "STATUS: EM PERSEGUIÇÃO"
			guidance_label.text = "Aproxime-se pela cauda e mantenha o alvo à sua frente."
		"tail_hold":
			status_label.text = "STATUS: ALVO ACOMPANHADO"
			guidance_label.text = "Sustente a perseguição: %.1f / 3.0 s" % float(data.follow_time)
		"weapons_free":
			status_label.text = "STATUS: INTERCEPTAÇÃO AUTORIZADA"
			guidance_label.text = "Armamento liberado. Derrube a aeronave antes da fronteira."
		"complete":
			status_label.text = "STATUS: FUGA IMPEDIDA"
			guidance_label.text = "Interceptação concluída. A fuga foi impedida."
		"failed":
			status_label.text = "STATUS: O ALVO ESCAPOU"
			guidance_label.text = "O alvo cruzou a fronteira. Pressione R para reiniciar."
		_:
			status_label.text = "STATUS: AGUARDANDO CONTATO"
			guidance_label.text = "Prepare-se para acelerar."
	progress.visible = stage in ["intercept", "tail_hold"]
	progress.value = float(data.progress)
	weapon_label.text = "ARMAMENTO: LIBERADO" if data.weapons_released else "ARMAMENTO: BLOQUEADO"
	weapon_label.add_theme_color_override("font_color", INK if data.weapons_released else AMBER)
