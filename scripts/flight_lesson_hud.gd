extends Control

const FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const TEXT_FONT = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const GREEN = Color("baffd0")
const MUTED = Color("8cbaa0")
const AMBER = Color("f0d46b")

var controller
var data = {}
var toast_text = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func expand_keys(value: String) -> String:
	var pitch_action = "pitch_down" if controller.settings.values.invert_pitch else "pitch_up"
	var actions = {
		"THROTTLE_UP": "throttle_up", "THROTTLE_DOWN": "throttle_down",
		"PULL_UP": pitch_action, "STEER_LEFT": "yaw_left",
		"STEER_RIGHT": "yaw_right", "BRAKE": "airbrake",
		"GEAR": "gear_toggle",
	}
	for token in actions:
		var key = int(controller.settings.key_bindings[actions[token]])
		value = value.replace("{" + token + "}", OS.get_keycode_string(key).to_upper())
	return value


func _process(_dt: float) -> void:
	visible = not controller.observing and not controller.settings_open
	data = controller.takeoff.training_snapshot()
	toast_text = expand_keys(str(data.toast))
	queue_redraw()


func text_at(point: Vector2, value: String, font_size: int, color: Color, font: Font = FONT) -> void:
	draw_string(font, point + Vector2.ONE, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.03, 0.02, color.a))
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if data.is_empty():
		return
	var margin = max(22.0, size.x * 0.025)
	var stage = str(data.stage)
	var color = AMBER if stage in ["base", "final", "flare", "rollout", "go_around"] else GREEN
	# Small reference strip; the route itself carries the navigation instruction.
	draw_line(Vector2(margin, 158), Vector2(margin + 235, 158), Color(color, 0.45), 1.0)
	text_at(Vector2(margin, 182), "01 / " + stage.replace("_", " ").to_upper(), 25, color)
	var target = "%.0f M  /  %.0f KM/H" % [float(data.desired_altitude), float(data.speed_target)]
	if stage in ["ready", "roll", "rotate"]:
		target = "ROTATE / %.0f KM/H" % float(data.rotation_speed)
	elif stage == "rollout":
		target = "BRAKE / KEEP STRAIGHT"
	elif stage == "clear":
		target = "FREE FLIGHT"
	text_at(Vector2(margin, 207), target, 16, MUTED, TEXT_FONT)
	var gear = controller.model.landing_gear_state()
	var gear_key = OS.get_keycode_string(int(controller.settings.key_bindings.gear_toggle)).to_upper()
	text_at(Vector2(margin, 231), "%s GEAR / %s" % [gear_key, gear], 18, GREEN if gear == "DOWN" else AMBER)
	if not bool(data.completed):
		draw_route_pointer(color)
	if toast_text.is_empty():
		return
	var remaining = float(data.toast_remaining)
	var alpha = min(1.0, remaining / 0.4, (4.0 - remaining) / 0.18)
	alpha = clamp(alpha, 0.0, 1.0)
	var font_size = 29
	var width = FONT.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var toast_origin = Vector2((size.x - width) * 0.5, 84.0 if controller.cockpit_mode else size.y - 119)
	var rect = Rect2(toast_origin + Vector2(-20, -29), Vector2(width + 40, 44))
	draw_rect(rect, Color(0.01, 0.04, 0.03, 0.83 * alpha))
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(color, 0.6 * alpha), 1.0)
	text_at(toast_origin, toast_text, font_size, Color(color, alpha))


func draw_route_pointer(color: Color) -> void:
	if controller.model.on_ground:
		return
	var camera: Camera3D = controller.camera
	var target: Vector3 = data.navigation_target
	var camera_point = camera.global_transform.affine_inverse() * target
	var bounds = Rect2(Vector2(size.x * 0.20, size.y * 0.18), Vector2(size.x * 0.60, size.y * 0.57))
	var point = camera.unproject_position(target)
	if camera_point.z < 0.0 and bounds.has_point(point):
		# Open chevron, never a gate that the player has to pass through.
		draw_polyline(PackedVector2Array([point + Vector2(-9, 6), point + Vector2(0, -4), point + Vector2(9, 6)]), color, 1.6, true)
		return
	var direction = Vector2(camera_point.x, -camera_point.y)
	if camera_point.z >= 0.0:
		direction.y = max(abs(direction.y), 0.7 * direction.length())
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var center = bounds.get_center()
	var reach = min(bounds.size.x * 0.5 / max(abs(direction.x), 0.01), bounds.size.y * 0.5 / max(abs(direction.y), 0.01))
	point = center + direction * reach
	var side = Vector2(-direction.y, direction.x)
	draw_polyline(PackedVector2Array([point - direction * 10 + side * 6, point, point - direction * 10 - side * 6]), color, 2.0, true)
	text_at(point + Vector2(12, 5), "ROUTE", 17, color)
