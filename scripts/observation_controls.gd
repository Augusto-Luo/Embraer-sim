extends CanvasLayer

signal chase_requested
signal freeze_requested
signal reset_requested
signal settings_requested

var status_label
var freeze_button


func _ready() -> void:
	visible = false
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var status_panel = PanelContainer.new()
	status_panel.position = Vector2(20, 20)
	status_panel.custom_minimum_size = Vector2(210, 44)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.055, 0.043, 0.88)
	style.border_color = Color(0.66, 0.90, 0.76, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	status_panel.add_theme_stylebox_override("panel", style)
	root.add_child(status_panel)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.84, 0.97, 0.89))
	status_panel.add_child(status_label)

	var buttons = HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	buttons.offset_left = -510.0
	buttons.offset_right = -20.0
	buttons.offset_top = 20.0
	buttons.offset_bottom = 64.0
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)
	freeze_button = make_button("FREEZE [P]", freeze_requested.emit, 122.0)
	buttons.add_child(freeze_button)
	buttons.add_child(make_button("RESET [R]", reset_requested.emit, 112.0))
	buttons.add_child(make_button("SETTINGS [TAB]", settings_requested.emit, 138.0))
	buttons.add_child(make_button("CHASE [V]", chase_requested.emit, 110.0))

	var help = Label.new()
	help.text = "LMB ORBIT  ·  WHEEL ZOOM  ·  R RESET VIEW"
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -300.0
	help.offset_right = 300.0
	help.offset_top = -52.0
	help.offset_bottom = -20.0
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.76, 0.92, 0.82))
	help.add_theme_color_override("font_shadow_color", Color(0.0, 0.04, 0.03, 0.9))
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help)
	set_frozen(false)


func make_button(text: String, action: Callable, width: float) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 36)
	button.pressed.connect(action)
	return button


func set_frozen(value: bool) -> void:
	status_label.text = "OBSERVE  ·  FROZEN" if value else "OBSERVE  ·  LIVE"
	freeze_button.text = "RESUME [P]" if value else "FREEZE [P]"


func is_pointer_over_ui() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered is Button or hovered is PanelContainer or hovered is HBoxContainer:
			return true
		hovered = hovered.get_parent()
	return false
