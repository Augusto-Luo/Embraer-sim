extends Control

const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const SKY = Color(0.16, 0.34, 0.43, 1.0)
const GROUND = Color(0.31, 0.27, 0.17, 1.0)
const INK = Color(0.55, 0.95, 0.72, 1.0)
const BRIGHT = Color(0.82, 1.0, 0.88, 1.0)
const PIXELS_PER_DEGREE = 4.0

var pitch = 0.0
var bank = 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_attitude(pitch_value: float, bank_value: float) -> void:
	pitch = pitch_value
	bank = bank_value
	queue_redraw()


func ladder_text(position: Vector2, value: String) -> void:
	draw_string(INSTRUMENT_FONT, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)


func _draw() -> void:
	var center = size * 0.5
	# Flight telemetry uses radians; ladder marks are labelled in degrees.
	var horizon_y = rad_to_deg(pitch) * PIXELS_PER_DEGREE
	var extent = size.length() * 2.0
	draw_set_transform(center, -bank, Vector2.ONE)
	draw_rect(Rect2(Vector2(-extent, horizon_y - extent), Vector2(extent * 2.0, extent)), SKY)
	draw_rect(Rect2(Vector2(-extent, horizon_y), Vector2(extent * 2.0, extent)), GROUND)
	draw_line(Vector2(-extent, horizon_y), Vector2(extent, horizon_y), BRIGHT, 2.0, true)
	for ladder_angle in range(-90, 91, 5):
		if ladder_angle == 0:
			continue
		var y = horizon_y - float(ladder_angle) * PIXELS_PER_DEGREE
		if abs(y) > size.length() * 0.5:
			continue
		var major = ladder_angle % 10 == 0
		var outer = 105.0 if major else 72.0
		draw_line(Vector2(-outer, y), Vector2(-40, y), INK, 1.5, true)
		draw_line(Vector2(40, y), Vector2(outer, y), INK, 1.5, true)
		if major:
			ladder_text(Vector2(-132, y + 5), "%+d" % ladder_angle)
			ladder_text(Vector2(112, y + 5), "%+d" % ladder_angle)
	draw_set_transform(Vector2.ZERO)
	draw_arc(center, 118.0, -PI * 0.85, -PI * 0.15, 36, INK, 1.5, true)
	draw_line(center + Vector2(-82, 0), center + Vector2(-22, 0), BRIGHT, 3.0, true)
	draw_line(center + Vector2(22, 0), center + Vector2(82, 0), BRIGHT, 3.0, true)
	draw_line(center + Vector2(-22, 0), center + Vector2(0, 14), BRIGHT, 3.0, true)
	draw_line(center + Vector2(0, 14), center + Vector2(22, 0), BRIGHT, 3.0, true)
	draw_circle(center, 3.0, BRIGHT)
