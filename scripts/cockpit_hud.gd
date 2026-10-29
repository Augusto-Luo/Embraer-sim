extends Control

const INK = Color(0.32, 1.0, 0.55, 0.96)
const MUTED = Color(0.40, 0.92, 0.60, 0.82)
const BRIGHT = Color(0.66, 1.0, 0.80, 1.0)
const AMBER = Color(1.0, 0.78, 0.43, 0.98)
const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")

var state = {}
var combat = {}
var combat_enabled = true
var map_preview = false
var ground_attack = false
var paused = false
var seat_name = "FRONT"
var redraw_elapsed = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_state(value: Dictionary) -> void:
	state = value


func update_combat(value: Dictionary) -> void:
	combat = value


func set_seat(value: String) -> void:
	seat_name = value
	queue_redraw()


func set_paused(value: bool) -> void:
	paused = value
	queue_redraw()


func _process(dt: float) -> void:
	redraw_elapsed += dt
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()


func text(position: Vector2, value: String, font_size: int = 12, color: Color = INK) -> void:
	var scaled_size = int(round(font_size * (1.18 if font_size >= 18 else 1.10)))
	var glow = Color(0.18, 1.0, 0.42, color.a * 0.16)
	var shadow = Color(0.0, 0.04, 0.025, 0.86)
	draw_string(INSTRUMENT_FONT, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, glow)
	draw_string(INSTRUMENT_FONT, position + Vector2(1.0, 1.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, shadow)
	draw_string(INSTRUMENT_FONT, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, color)


func glow_line(from: Vector2, to: Vector2, color: Color = INK, width: float = 1.0) -> void:
	draw_line(from, to, Color(0.18, 1.0, 0.42, color.a * 0.16), width + 1.5, true)
	draw_line(from, to, color, width, true)


func panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.005, 0.035, 0.022, 0.16), true)
	draw_rect(rect, Color(0.30, 1.0, 0.55, 0.40), false, 1.0)


func format_time(seconds: float) -> String:
	var total = max(0, int(seconds))
	return "%02d:%02d" % [int(total / 60), total % 60]


func draw_tape(center: Vector2, value: float, step_value: float, side: int) -> void:
	var x = center.x + side * 118.0
	glow_line(Vector2(x, center.y - 112.0), Vector2(x, center.y + 112.0), MUTED, 1.0)
	var base = round(value / step_value) * step_value
	for index in range(-4, 5):
		var tick_value = base + index * step_value
		if tick_value < 0.0:
			continue
		var y = center.y - (tick_value - value) / step_value * 27.0
		if abs(y - center.y) > 110.0:
			continue
		glow_line(Vector2(x, y), Vector2(x - side * 10.0, y), MUTED, 1.0)
		var label_position = Vector2(x - 48.0 if side < 0 else x + 14.0, y + 3.0)
		text(label_position, str(int(tick_value)), 8, MUTED)


func draw_attitude(center: Vector2) -> void:
	var pitch_deg = rad_to_deg(state.get("pitch", 0.0))
	var bank_deg = rad_to_deg(state.get("bank", 0.0))
	draw_arc(center, 54.0, -deg_to_rad(30.0 + bank_deg), deg_to_rad(30.0 - bank_deg), 20, MUTED, 1.0, true)
	draw_set_transform(center, -state.get("bank", 0.0), Vector2.ONE)
	for ladder_angle in [-20, -10, 0, 10, 20]:
		var y = (pitch_deg - ladder_angle) * 2.2
		var label = "%+d" % ladder_angle if ladder_angle != 0 else "0"
		glow_line(Vector2(-98, y), Vector2(-42, y), MUTED, 1.0)
		glow_line(Vector2(42, y), Vector2(98, y), MUTED, 1.0)
		glow_line(Vector2(-98, y), Vector2(-98, y + 5), MUTED, 1.0)
		glow_line(Vector2(98, y), Vector2(98, y + 5), MUTED, 1.0)
		text(Vector2(-122, y + 4), label, 8, MUTED)
		text(Vector2(104, y + 4), label, 8, MUTED)
	draw_set_transform(Vector2.ZERO)
	if combat_enabled:
		var gun_center: Vector2 = combat.get("gun_reticle_screen", center)
		var snapped = combat.get("reticle_snapped", false)
		var gun_color = AMBER if snapped else BRIGHT
		if combat.get("gun_reticle_visible", true):
			draw_arc(gun_center, 10.0 if snapped else 7.0, 0.0, TAU, 28, gun_color, 1.6, true)
			glow_line(gun_center + Vector2(-23, 0), gun_center + Vector2(-13, 0), gun_color, 1.1)
			glow_line(gun_center + Vector2(13, 0), gun_center + Vector2(23, 0), gun_color, 1.1)
			draw_circle(gun_center, 1.4, gun_color)
			if snapped:
				text(gun_center + Vector2(-38, 38), "AIM HOLD %.1f" % float(combat.get("gun_assist_remaining", 0.0)), 12, AMBER)
			elif combat.get("gun_assist", false):
				text(gun_center + Vector2(-28, 35), "AIM PULL", 11, BRIGHT)


func draw_target() -> void:
	for contact in combat.get("contacts", []):
		if not contact.selected:
			continue
		if contact.on_screen:
			var point = contact.screen
			var rect = Rect2(point - Vector2(34, 26), Vector2(68, 52))
			draw_rect(rect, Color(0.36, 1.0, 0.58, 0.82), false, 1.1)
			draw_circle(point, 1.8, BRIGHT)
			text(point + Vector2(40, -15), contact.id, 15, INK)
			text(point + Vector2(40, 5), "%.1f KM" % (contact.distance / 1000.0), 12, MUTED)
			if ground_attack:
				text(point + Vector2(40, 23), "HP %d" % int(combat.get("target_hp", 0)), 12, AMBER)
			if combat.get("locked", false):
				text(point + Vector2(-28, -34), "LOCK", 10, AMBER)
			else:
				draw_arc(point, 40.0, -PI * 0.5, -PI * 0.5 + TAU * float(combat.get("lock_progress", 0.0)), 36, MUTED, 1.1, true)
		else:
			var margin = max(24.0, size.x * 0.025)
			var point = contact.screen
			var edge = Vector2(clamp(point.x, margin + 60.0, size.x - margin - 60.0), clamp(point.y, 120.0, size.y - 180.0))
			draw_circle(edge, 4.0, AMBER)
			text(edge + Vector2(8, 4), contact.id + " / OFFSCREEN", 12, AMBER)
	if combat.get("lead_visible", false) and not combat.get("reticle_snapped", false):
		var lead = combat.lead_screen
		if Rect2(Vector2.ZERO, size).has_point(lead):
			draw_arc(lead, 6.0, 0.0, TAU, 20, AMBER, 1.0, true)
			glow_line(lead + Vector2(-9, 0), lead + Vector2(9, 0), AMBER, 1.0)
			glow_line(lead + Vector2(0, -9), lead + Vector2(0, 9), AMBER, 1.0)


func draw_radar() -> void:
	var margin = max(24.0, size.x * 0.025)
	var center = Vector2(margin + 64.0, size.y - 96.0)
	panel(Rect2(center - Vector2(64, 64), Vector2(128, 128)))
	for radius in [50.0, 30.0, 10.0]:
		draw_arc(center, radius, 0.0, TAU, 48, MUTED, 0.8, true)
	glow_line(center + Vector2(-54, 0), center + Vector2(54, 0), MUTED, 0.8)
	glow_line(center + Vector2(0, -54), center + Vector2(0, 54), MUTED, 0.8)
	draw_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(-4, 6), center + Vector2(0, 3), center + Vector2(4, 6)]), PackedColorArray([BRIGHT]))
	for contact in combat.get("contacts", []):
		var point = center + contact.radar * (50.0 / 58.0)
		var color = AMBER if contact.selected else MUTED
		draw_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(4, 0), point + Vector2(0, 4), point + Vector2(-4, 0)]), PackedColorArray([color]))
	text(center + Vector2(-42, 80), "SITES / 5 KM" if ground_attack else ("RWR / 5 KM" if combat_enabled else "HEADING"), 9, MUTED)


func draw_weapon_status() -> void:
	var margin = max(24.0, size.x * 0.025)
	var right = Vector2(size.x - margin - 142.0, size.y - 132.0)
	panel(Rect2(right - Vector2(0, 4), Vector2(142, 94)))
	text(right, "GUN", 11, MUTED)
	text(right + Vector2(66, 0), str(combat.get("gun_ammo", 0)), 12, BRIGHT)
	text(right + Vector2(0, 24), "RKT" if ground_attack else "MSL", 11, MUTED)
	text(right + Vector2(66, 24), str(combat.get("missile_ammo", 0)), 12, BRIGHT)
	text(right + Vector2(0, 48), "DEST" if ground_attack else "DMG", 11, MUTED)
	text(right + Vector2(66, 48), "%d%%" % int(round(float(combat.get("destruction", 0.0)) * 100.0)) if ground_attack else "0%", 12, BRIGHT)
	text(right + Vector2(0, 70), "MANUAL / INV" if ground_attack else "INV MODE", 9, MUTED)


func _draw() -> void:
	if state.is_empty():
		return
	var margin = max(24.0, size.x * 0.025)
	var center = Vector2(size.x * 0.5, size.y * 0.42)
	text(Vector2(margin, 30), "TARGETS %d/8" % int(combat.get("destroyed_targets", 0)) if ground_attack else ("KILLS %d" % int(combat.get("kills", 0)) if combat_enabled else ("ISLAND RECON / MAP PREVIEW" if map_preview else "AIRFIELD / RWY 36")), 11, MUTED)
	if ground_attack:
		text(Vector2(margin, 50), "DESTRUCTION %d%%" % int(round(float(combat.get("destruction", 0.0)) * 100.0)), 11, INK)
		var message = str(combat.get("comms_text", ""))
		if combat.get("completed", false):
			message = "ALL TARGETS DESTROYED"
		if not message.is_empty():
			text(Vector2(size.x * 0.5 - float(message.length()) * 4.0, 52), message, 13, AMBER)
	text(Vector2(size.x - margin - 130, 30), "TIME " + format_time(state.get("time", 0.0)), 11, MUTED)
	text(Vector2(size.x - margin - 218, 52), seat_name + " · 1 CHASE · 2 SEAT", 10, MUTED)

	var heading = int(round(state.get("heading", 0.0))) % 360
	var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var cardinal = directions[int(round(heading / 45.0)) % 8]
	var heading_position = Vector2(center.x - 52.0, size.y * 0.17)
	panel(Rect2(heading_position, Vector2(104, 34)))
	text(heading_position + Vector2(12, 22), "%s %03d°" % [cardinal, heading], 13, BRIGHT)

	draw_tape(center, state.get("speedKmh", 0.0), 20.0, -1)
	draw_tape(center, state.get("position", [0, 0, 0])[1], 50.0, 1)
	draw_attitude(center)
	draw_target()

	var speed_position = center + Vector2(-300, -18)
	panel(Rect2(speed_position + Vector2(-8, -5), Vector2(104, 62)))
	text(speed_position, "IAS", 10, MUTED)
	text(speed_position + Vector2(0, 24), str(int(state.get("speedKmh", 0.0))), 21, BRIGHT)
	text(speed_position + Vector2(0, 46), "KM/H", 8, MUTED)

	var alt_position = center + Vector2(220, -18)
	panel(Rect2(alt_position + Vector2(-8, -5), Vector2(104, 62)))
	text(alt_position, "ALT", 10, MUTED)
	text(alt_position + Vector2(0, 24), str(int(state.get("position", [0, 0, 0])[1])), 21, BRIGHT)
	text(alt_position + Vector2(0, 46), "MSL / M", 8, MUTED)

	text(center + Vector2(-292, 98), "THR %d%%" % int(state.get("throttle", 0.0) * 100.0), 11, INK)
	if state.get("gearEnabled", false):
		text(center + Vector2(-292, 117), "PWR %d%%" % int(state.get("enginePower", 0.0) * 100.0), 11, MUTED)
	text(center + Vector2(222, 98), "AGL %d M" % int(max(0.0, state.get("agl", 0.0))), 11, INK)
	draw_radar()
	if combat_enabled:
		draw_weapon_status()

	var warning = str(combat.get("warning", ""))
	if combat.get("threat", false):
		warning = "MISSILE INBOUND"
	elif warning.is_empty() and state.get("stall", false):
		warning = "STALL · NOSE DOWN"
	elif warning.is_empty() and state.get("lowAltitude", false) and combat_enabled:
		warning = "LOW ALTITUDE · PULL UP"
	elif warning.is_empty() and state.get("outsideBoundary", false):
		warning = "LEAVING TEST RANGE"
	if paused:
		warning = "PAUSED"
	elif state.get("crashed", false):
		warning = "IMPACT"
	if not warning.is_empty():
		var warning_width = 16 * warning.length() * 0.62
		text(Vector2(size.x * 0.5 - warning_width * 0.5, size.y * 0.12), warning, 16, AMBER)
