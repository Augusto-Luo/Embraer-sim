extends Control

# Transparent, instrument-only texture for the physical KC-390 combiner.
# All coordinates scale with the SubViewport; no screen-space panel is drawn.
const FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const GREEN = Color(0.34, 0.92, 0.48, 0.64)
const DIM = Color(0.30, 0.82, 0.42, 0.50)
const BRIGHT = Color(0.42, 1.0, 0.56, 0.90)
const METRES_TO_FEET = 3.28084

var state: Dictionary = {}
# Ray slopes use the combiner shader convention: right/down on the image.
# The source glass is below and to one side of the aircraft boresight.
var field_center = Vector2(-0.23275, 0.15262)
var field_span = Vector2(0.285, 0.235)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func update_state(telemetry: Dictionary) -> void:
	state = telemetry
	queue_redraw()


func label_at(origin: Vector2, value: String, font_size: float, color: Color = GREEN, centered: bool = false) -> void:
	var point = origin
	var pixels = maxi(9, int(round(font_size * size.y / 1024.0)))
	if centered:
		point.x -= FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x * 0.5
	draw_string(FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)


func line(from: Vector2, to: Vector2, color: Color = GREEN, width: float = 2.0) -> void:
	draw_line(from, to, color, maxf(0.8, width * size.y / 1024.0), true)


func altitude_metres() -> float:
	var position = state.get("position", [0.0, 0.0, 0.0])
	if position is Vector3:
		return position.y
	if position is Array or position is PackedFloat32Array or position is PackedFloat64Array:
		return float(position[1]) if position.size() > 1 else 0.0
	return 0.0


func draw_heading() -> void:
	var heading = fposmod(float(state.get("heading", 0.0)), 360.0)
	var center = Vector2(size.x * 0.5, size.y * 0.10)
	var pixels_per_degree = size.x * 0.010
	for offset in range(-7, 8):
		var bearing = floorf(heading / 5.0) * 5.0 + offset * 5.0
		var displacement = bearing - heading
		if absf(displacement) > 30.0:
			continue
		var x = center.x + displacement * pixels_per_degree
		var major = posmod(int(round(bearing)), 10) == 0
		line(Vector2(x, center.y), Vector2(x, center.y + size.y * (0.015 if major else 0.009)), DIM)
		if major:
			label_at(Vector2(x, center.y - size.y * 0.008), "%02d" % (posmod(int(round(bearing)), 360) / 10), 25.0, DIM, true)
	line(center + Vector2(-size.x * 0.009, size.y * 0.034), center + Vector2(0.0, size.y * 0.020), GREEN)
	line(center + Vector2(0.0, size.y * 0.020), center + Vector2(size.x * 0.009, size.y * 0.034), GREEN)
	label_at(Vector2(center.x, size.y * 0.045), "%03d" % posmod(int(round(heading)), 360), 35.0, BRIGHT, true)


func slope_to_canvas(slope: Vector2) -> Vector2:
	var span = Vector2(maxf(0.001, field_span.x), maxf(0.001, field_span.y))
	return (Vector2(0.5, 0.5) + (slope - field_center) / span) * size


func clipped_segment(from: Vector2, to: Vector2, bounds: Rect2) -> PackedVector2Array:
	var delta = to - from
	var start = 0.0
	var finish = 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.00001:
			if from[axis] < bounds.position[axis] or from[axis] > bounds.end[axis]:
				return PackedVector2Array()
			continue
		var lower = (bounds.position[axis] - from[axis]) / delta[axis]
		var upper = (bounds.end[axis] - from[axis]) / delta[axis]
		start = maxf(start, minf(lower, upper))
		finish = minf(finish, maxf(lower, upper))
		if start > finish:
			return PackedVector2Array()
	return PackedVector2Array([from + delta * start, from + delta * finish])


func draw_projected_segment(from: Vector2, to: Vector2, bank: float, bounds: Rect2, color: Color) -> void:
	var points = clipped_segment(slope_to_canvas(from.rotated(-bank)), slope_to_canvas(to.rotated(-bank)), bounds)
	if points.size() == 2:
		line(points[0], points[1], color)


func draw_pitch_ladder() -> void:
	var pitch = float(state.get("pitch", 0.0))
	var bank = float(state.get("bank", 0.0))
	# Cover the actual off-axis aperture, not a ladder centered on the texture.
	# Readouts sit outside this central clear region and never mask the numbers.
	var bounds = Rect2(size * Vector2(0.26, 0.145), size * Vector2(0.48, 0.66))
	var minimum_x = INF
	var maximum_x = -INF
	for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		var slope = (field_center + (corner - Vector2(0.5, 0.5)) * field_span).rotated(bank)
		minimum_x = minf(minimum_x, slope.x)
		maximum_x = maxf(maximum_x, slope.x)
	minimum_x -= 0.02
	maximum_x += 0.02
	for angle in range(-80, 81, 5):
		var relative_pitch = pitch - deg_to_rad(float(angle))
		if absf(relative_pitch) >= deg_to_rad(85.0):
			continue
		var y = tan(relative_pitch)
		var left = Vector2(minimum_x, y)
		var right = Vector2(maximum_x, y)
		var visible = clipped_segment(slope_to_canvas(left.rotated(-bank)), slope_to_canvas(right.rotated(-bank)), bounds)
		if visible.size() != 2:
			continue
		var color = GREEN if angle == 0 else DIM
		if angle < 0:
			# Fixed angular dash lengths preserve scale as the aperture clips.
			var dash = 0.022
			var x = floorf(minimum_x / dash) * dash
			while x < maximum_x:
				draw_projected_segment(Vector2(x, y), Vector2(minf(x + dash * 0.58, maximum_x), y), bank, bounds, color)
				x += dash
		else:
			draw_projected_segment(left, right, bank, bounds, color)
		var anchor = visible[0] if visible[0].x <= visible[1].x else visible[1]
		anchor += Vector2(size.x * 0.014, -size.y * 0.006)
		if bounds.grow(-size.y * 0.012).has_point(anchor):
			label_at(anchor, "%+d" % angle if angle != 0 else "0", 23.0, color)


func draw_display_reference() -> void:
	# A faint optical fiducial identifies the aperture center. It is distinct
	# from both the aircraft boresight wings and the circular flight-path marker.
	var center = size * 0.5
	var radius = size.y * 0.004
	for sign in [-1.0, 1.0]:
		line(center + Vector2(sign * radius, -radius), center + Vector2(sign * radius * 1.7, -radius * 1.7), DIM, 0.9)
		line(center + Vector2(sign * radius, radius), center + Vector2(sign * radius * 1.7, radius * 1.7), DIM, 0.9)
	var boresight = slope_to_canvas(Vector2.ZERO)
	if not Rect2(Vector2.ZERO, size).has_point(boresight):
		return
	var wing = size.x * 0.032
	var gap = size.x * 0.010
	line(boresight + Vector2(-wing, 0.0), boresight + Vector2(-gap, 0.0))
	line(boresight + Vector2(gap, 0.0), boresight + Vector2(wing, 0.0))
	line(boresight + Vector2(-gap, 0.0), boresight + Vector2(0.0, size.y * 0.006))
	line(boresight + Vector2(0.0, size.y * 0.006), boresight + Vector2(gap, 0.0))


func draw_flight_path() -> void:
	var speed = float(state.get("speed", float(state.get("speedKmh", 0.0)) / 3.6))
	if speed < 5.0 or bool(state.get("onGround", false)):
		return
	var vertical_speed = float(state.get("verticalSpeed", 0.0))
	var climb_angle = asin(clampf(vertical_speed / speed, -1.0, 1.0))
	var pitch = float(state.get("pitch", 0.0))
	var relative_pitch = pitch - climb_angle
	if absf(relative_pitch) >= deg_to_rad(85.0):
		return
	# No lateral velocity exists in the current telemetry. Zero lateral slope
	# is used unless the model supplies actual sideslip (rad) or lateral speed.
	var slip = float(state.get("sideslip", 0.0))
	if not state.has("sideslip") and state.has("lateralSpeed"):
		slip = atan2(float(state.lateralSpeed), maxf(0.1, speed))
	var slope = Vector2(tan(slip), tan(relative_pitch)).rotated(-float(state.get("bank", 0.0)))
	var point = slope_to_canvas(slope)
	# True boresight and FPV can lie beyond the original off-axis glass. Never
	# recenter or clamp them into a misleading flight-director indication.
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return
	var radius = size.y * 0.010
	draw_arc(point, radius, 0.0, TAU, 28, GREEN, maxf(0.8, size.y / 1024.0 * 1.3), true)
	line(point + Vector2(-radius * 2.1, 0.0), point + Vector2(-radius, 0.0))
	line(point + Vector2(radius, 0.0), point + Vector2(radius * 2.1, 0.0))
	line(point + Vector2(0.0, -radius * 1.9), point + Vector2(0.0, -radius))


func draw_readouts() -> void:
	var knots = float(state.get("speedKmh", float(state.get("speed", 0.0)) * 3.6)) / 1.852
	var feet = altitude_metres() * METRES_TO_FEET
	var vertical_fpm = float(state.get("verticalSpeed", 0.0)) * METRES_TO_FEET * 60.0
	label_at(Vector2(size.x * 0.14, size.y * 0.455), "IAS", 23.0, DIM, true)
	label_at(Vector2(size.x * 0.14, size.y * 0.503), "%03d" % int(round(knots)), 48.0, BRIGHT, true)
	label_at(Vector2(size.x * 0.14, size.y * 0.535), "KT", 21.0, DIM, true)
	label_at(Vector2(size.x * 0.86, size.y * 0.455), "BARO", 23.0, DIM, true)
	label_at(Vector2(size.x * 0.86, size.y * 0.503), "%05d" % int(round(feet / 10.0) * 10.0), 46.0, BRIGHT, true)
	label_at(Vector2(size.x * 0.86, size.y * 0.535), "FT", 21.0, DIM, true)
	label_at(Vector2(size.x * 0.82, size.y * 0.703), "VS %+.0f" % (round(vertical_fpm / 10.0) * 10.0), 27.0, GREEN, true)
	label_at(Vector2(size.x * 0.82, size.y * 0.733), "FT/MIN", 19.0, DIM, true)
	var cautions: Array[String] = []
	if bool(state.get("stall", false)):
		cautions.append("STALL")
	if bool(state.get("gearEnabled", false)) and float(state.get("gearExtension", 0.0)) > 0.01:
		cautions.append("GEAR" if str(state.get("gearState", "")) == "DOWN" else "GEAR TRANSIT")
	if bool(state.get("airbrake", false)):
		cautions.append("BRAKE")
	if not cautions.is_empty():
		label_at(Vector2(size.x * 0.5, size.y * 0.84), "  ".join(cautions), 29.0, BRIGHT, true)


func _draw() -> void:
	if state.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	draw_pitch_ladder()
	draw_display_reference()
	draw_flight_path()
	draw_heading()
	draw_readouts()
