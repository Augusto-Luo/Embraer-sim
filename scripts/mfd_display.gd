extends Control

const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const AttitudeGauge = preload("res://scripts/mfd_attitude.gd")
const BACKGROUND = Color(0.008, 0.025, 0.022, 1.0)
const PANEL = Color(0.025, 0.065, 0.052, 1.0)
const INK = Color(0.42, 0.90, 0.62, 1.0)
const MUTED = Color(0.30, 0.64, 0.45, 1.0)
const BRIGHT = Color(0.78, 1.0, 0.85, 1.0)
const CYAN = Color(0.36, 0.82, 0.88, 1.0)
const AMBER = Color(1.0, 0.70, 0.30, 1.0)

var mode = "navigation"
var state = {}
var combat = {}
var attitude


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mode == "navigation":
		attitude = AttitudeGauge.new()
		attitude.position = Vector2(72, 76)
		attitude.size = Vector2(368, 260)
		add_child(attitude)


func update_state(value: Dictionary) -> void:
	state = value
	if attitude != null:
		attitude.update_attitude(state.get("pitch", 0.0), state.get("bank", 0.0))
	queue_redraw()


func update_combat(value: Dictionary) -> void:
	combat = value


func text(position: Vector2, value: String, font_size: int = 18, color: Color = INK) -> void:
	draw_string(INSTRUMENT_FONT, position + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.02, 0.015, 0.9))
	draw_string(INSTRUMENT_FONT, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func frame(title: String, page: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), MUTED, false, 2.0)
	draw_rect(Rect2(Vector2(12, 42), Vector2(size.x - 24, 1)), MUTED, true)
	for corner in [Vector2(13, 13), Vector2(size.x - 13, 13), Vector2(13, size.y - 13), Vector2(size.x - 13, size.y - 13)]:
		draw_circle(corner, 3.0, PANEL)
		draw_arc(corner, 3.0, 0.0, TAU, 12, MUTED, 1.0, true)
	text(Vector2(20, 31), title, 24, BRIGHT)
	text(Vector2(size.x - 72, 30), page, 18, MUTED)


func bar(rect: Rect2, value: float, color: Color = INK) -> void:
	draw_rect(rect, PANEL, true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamp(value, 0.0, 1.0), rect.size.y)), color, true)
	draw_rect(rect, MUTED, false, 1.0)


func gauge(center: Vector2, radius: float, value: float, label: String, value_text: String, unit: String) -> void:
	var start = deg_to_rad(135.0)
	var sweep = deg_to_rad(270.0)
	draw_arc(center, radius, start, start + sweep, 72, PANEL, 9.0, true)
	draw_arc(center, radius, start, start + sweep, 72, MUTED, 2.0, true)
	draw_arc(center, radius, start, start + sweep * clamp(value, 0.0, 1.0), 72, INK, 5.0, true)
	for index in range(10):
		var angle = start + sweep * index / 9.0
		var direction = Vector2(cos(angle), sin(angle))
		draw_line(center + direction * (radius - 13), center + direction * (radius - 5), MUTED, 2.0, true)
	text(center + Vector2(-radius * 0.55, -radius * 0.22), label, 24, MUTED)
	text(center + Vector2(-radius * 0.58, radius * 0.35), value_text, 40, BRIGHT)
	text(center + Vector2(-radius * 0.32, radius * 0.65), unit, 18, MUTED)


func draw_navigation() -> void:
	frame("PFD / NAV", "01")
	text(Vector2(16, 76), "IAS", 18, MUTED)
	text(Vector2(14, 108), str(int(state.get("speedKmh", 0.0))), 30, CYAN)
	text(Vector2(14, 132), "KM/H", 14, MUTED)
	text(Vector2(448, 76), "ALT", 18, MUTED)
	text(Vector2(444, 108), str(int(state.get("position", [0, 0, 0])[1])), 30, CYAN)
	text(Vector2(446, 132), "M", 14, MUTED)
	var heading = int(round(state.get("heading", 0.0))) % 360
	text(Vector2(188, 366), "HDG %03d°" % heading, 24, BRIGHT)
	text(Vector2(16, 366), "VS %+.1f" % state.get("verticalSpeed", 0.0), 18, INK)
	text(Vector2(408, 366), "AGL %d" % int(max(0.0, state.get("agl", 0.0))), 18, INK)
	text(Vector2(18, 402), "ATT / FD", 16, MUTED)
	var transport = state.get("aircraftType", "") == "KC-390"
	text(Vector2(18, 478), "KC-390 / FLIGHT DIRECTOR" if transport else "EMB-314  /  FLIGHT DIRECTOR", 16, MUTED)
	text(Vector2(338, 478), "MANUAL" if state.get("groundAttack", false) else ("RWY 36" if transport else "TGT " + str(combat.get("target_id", "---"))), 18, INK)
	if state.get("stall", false):
		text(Vector2(168, 410), "STALL", 26, AMBER)
	elif state.get("lowAltitude", false):
		text(Vector2(132, 410), "PULL UP", 26, AMBER)


func engine_readings() -> Dictionary:
	var power = float(state.get("enginePower", state.get("throttle", 0.0)))
	return {"n1": 32.0 + power * 66.0, "itt": 430.0 + power * 380.0}


func draw_engine() -> void:
	frame("ENG / POWER", "02")
	var throttle = state.get("throttle", 0.0)
	var readings = engine_readings()
	gauge(Vector2(140, 188), 92.0, readings.n1 / 100.0, "N1", "%02d" % int(readings.n1), "% RPM")
	gauge(Vector2(372, 188), 92.0, readings.itt / 900.0, "ITT", str(int(readings.itt)), "°C")
	text(Vector2(22, 330), "OIL", 18, MUTED)
	bar(Rect2(Vector2(84, 316), Vector2(150, 14)), 0.82)
	text(Vector2(254, 330), "OK", 18, INK)
	text(Vector2(22, 362), "HYD", 18, MUTED)
	bar(Rect2(Vector2(84, 348), Vector2(150, 14)), 0.76)
	text(Vector2(254, 362), "OK", 18, INK)
	text(Vector2(22, 394), "FUEL", 18, MUTED)
	var fuel = clamp(1.0 - state.get("time", 0.0) / 7200.0, 0.0, 1.0)
	bar(Rect2(Vector2(84, 380), Vector2(304, 14)), fuel, CYAN)
	text(Vector2(408, 394), "%d%%" % int(fuel * 100.0), 18, CYAN)
	text(Vector2(22, 448), "LEVER" if state.get("aircraftType", "") == "KC-390" else "THR", 20, MUTED)
	bar(Rect2(Vector2(84, 432), Vector2(304, 20)), throttle, BRIGHT)
	text(Vector2(408, 448), "%d%%" % int(throttle * 100.0), 24, BRIGHT)
	text(Vector2(22, 486), "KC-390 / TWIN ENGINE / SIM" if state.get("aircraftType", "") == "KC-390" else "ENG 1  /  TPE-331  /  SIM RATING", 16, MUTED)


func draw_system() -> void:
	if state.get("groundAttack", false):
		draw_ground_system()
		return
	frame("SYS / STATUS", "03")
	text(Vector2(24, 84), "GEAR", 18, MUTED)
	text(Vector2(160, 84), str(state.get("gearState", "UP")), 28, BRIGHT)
	text(Vector2(24, 124), "FLAP", 18, MUTED)
	text(Vector2(160, 124), "0°", 28, BRIGHT)
	text(Vector2(24, 164), "BRAKE", 18, MUTED)
	text(Vector2(160, 164), "ON" if state.get("airbrake", false) else "OFF", 28, AMBER if state.get("airbrake", false) else BRIGHT)
	text(Vector2(24, 204), "ARM", 18, MUTED)
	text(Vector2(160, 204), "INV", 28, BRIGHT)
	var center = Vector2(116, 324)
	draw_arc(center, 72, 0.0, TAU, 48, MUTED, 1.5, true)
	draw_arc(center, 44, 0.0, TAU, 48, MUTED, 1.0, true)
	draw_line(center + Vector2(-72, 0), center + Vector2(72, 0), MUTED, 1.0, true)
	draw_line(center + Vector2(0, -72), center + Vector2(0, 72), MUTED, 1.0, true)
	for contact in combat.get("contacts", []):
		var point = center + contact.radar * 1.1
		draw_circle(point, 3.0, AMBER if contact.selected else INK)
	text(Vector2(224, 286), "RWR", 20, MUTED)
	text(Vector2(224, 320), "MISSILE" if combat.get("threat", false) else "CLEAR", 26, AMBER if combat.get("threat", false) else INK)
	var warning = str(combat.get("warning", ""))
	if state.get("stall", false):
		warning = "STALL"
	elif state.get("lowAltitude", false):
		warning = "LOW ALT"
	elif combat.get("threat", false):
		warning = "INBOUND"
	text(Vector2(224, 366), warning if not warning.is_empty() else "NOMINAL", 22, AMBER if not warning.is_empty() else INK)
	text(Vector2(22, 486), "KC-390 / SYSTEMS" if state.get("aircraftType", "") == "KC-390" else "A-29  /  SYSTEMS", 16, MUTED)


func draw_ground_system() -> void:
	frame("GND / STRIKE", "03")
	text(Vector2(24, 92), "TARGETS  %d/8" % int(combat.get("destroyed_targets", 0)), 30, BRIGHT)
	text(Vector2(24, 140), "DESTRUCTION  %d%%" % int(round(float(combat.get("destruction", 0.0)) * 100.0)), 24, CYAN)
	bar(Rect2(Vector2(24, 162), Vector2(464, 10)), float(combat.get("destruction", 0.0)), CYAN)
	text(Vector2(24, 226), "GUN  %d" % int(combat.get("gun_ammo", 0)), 28, INK)
	text(Vector2(24, 270), "RKT  %d" % int(combat.get("missile_ammo", 0)), 28, INK)
	text(Vector2(24, 334), str(combat.get("target_id", "---")), 28, BRIGHT)
	text(Vector2(24, 378), "HP %d / %d" % [int(combat.get("target_hp", 0)), int(combat.get("target_max_hp", 120))], 24, CYAN)
	text(Vector2(24, 440), "ALL TARGETS DESTROYED" if combat.get("completed", false) else "MANUAL AIM / GUIDED RKT", 22, AMBER)
	text(Vector2(24, 486), "EMB-314 / ISLAND STRIKE", 16, MUTED)


func draw_nd() -> void:
	frame("NAV / ROUTE", "02")
	var center = Vector2(176, 250)
	for radius in [120.0, 80.0, 40.0]:
		draw_arc(center, radius, 0.0, TAU, 64, MUTED, 1.2, true)
	draw_line(center + Vector2(-120, 0), center + Vector2(120, 0), MUTED, 1.0, true)
	draw_line(center + Vector2(0, -120), center + Vector2(0, 120), MUTED, 1.0, true)
	for contact in combat.get("contacts", []):
		var point = center + contact.radar * 1.8
		draw_circle(point, 4.0, AMBER if contact.selected else INK)
	text(center + Vector2(-42, 148), "5 KM", 16, MUTED)
	text(Vector2(344, 92), "HDG", 18, MUTED)
	text(Vector2(344, 124), "%03d°" % int(round(state.get("heading", 0.0))), 30, BRIGHT)
	text(Vector2(344, 178), "IAS", 18, MUTED)
	text(Vector2(344, 210), str(int(state.get("speedKmh", 0.0))), 30, CYAN)
	text(Vector2(344, 264), "ALT", 18, MUTED)
	text(Vector2(344, 296), str(int(state.get("position", [0, 0, 0])[1])), 30, CYAN)
	text(Vector2(344, 352), "VS", 18, MUTED)
	text(Vector2(344, 384), "%+.1f" % state.get("verticalSpeed", 0.0), 26, INK)
	text(Vector2(344, 448), "AGL", 18, MUTED)
	text(Vector2(344, 480), "%d M" % int(max(0.0, state.get("agl", 0.0))), 26, INK)
	text(Vector2(20, 486), "RWY 36  /  LOCAL TRAINING", 16, MUTED)


func draw_fms() -> void:
	if state.has("training"):
		draw_flight_lesson()
		return
	frame("FMS / TRAINING", "03")
	text(Vector2(24, 86), "GEAR", 18, MUTED)
	text(Vector2(174, 86), "DOWN" if state.get("onGround", false) else "UP", 28, BRIGHT)
	text(Vector2(24, 126), "FLAP", 18, MUTED)
	text(Vector2(174, 126), "0°", 28, BRIGHT)
	text(Vector2(24, 166), "BRAKE", 18, MUTED)
	text(Vector2(174, 166), "ON" if state.get("airbrake", false) else "OFF", 28, AMBER if state.get("airbrake", false) else BRIGHT)
	text(Vector2(24, 214), "ROT", 18, MUTED)
	text(Vector2(174, 214), "%d KM/H" % int(state.get("rotationSpeed", 60.0) * 3.6), 26, CYAN)
	text(Vector2(24, 260), "IAS", 18, MUTED)
	text(Vector2(174, 260), "%d" % int(state.get("speedKmh", 0.0)), 30, CYAN)
	text(Vector2(24, 306), "ALT", 18, MUTED)
	text(Vector2(174, 306), "%d M" % int(state.get("position", [0, 0, 0])[1]), 30, CYAN)
	text(Vector2(24, 352), "VS", 18, MUTED)
	text(Vector2(174, 352), "%+.1f" % state.get("verticalSpeed", 0.0), 26, INK)
	text(Vector2(24, 398), "HDG", 18, MUTED)
	text(Vector2(174, 398), "%03d°" % int(round(state.get("heading", 0.0))), 30, BRIGHT)
	var status = "GROUND" if state.get("onGround", false) else "CLIMB"
	if state.get("stall", false):
		status = "STALL"
	elif state.get("lowAltitude", false):
		status = "PULL UP"
	text(Vector2(24, 458), status, 26, AMBER if status != "GROUND" and status != "CLIMB" else INK)
	text(Vector2(24, 486), "A-29  /  BASIC FLIGHT", 16, MUTED)


func draw_flight_lesson() -> void:
	frame("FMS / FLIGHT LESSON", "03")
	var lesson = state.training
	var leg = str(lesson.get("leg", lesson.get("stage", "ready")))
	var leg_names = {
		"ready": "READY FOR TAKEOFF", "roll": "TAKEOFF ROLL", "rotate": "ROTATE",
		"climb": "CLIMB", "crosswind": "LEFT CROSSWIND", "downwind": "DOWNWIND",
		"base": "LEFT BASE", "final": "FINAL", "flare": "FLARE",
		"rollout": "LANDING ROLL", "off_runway": "REJOIN RUNWAY",
		"go_around": "GO AROUND", "clear": "CIRCUIT COMPLETE",
	}
	text(Vector2(24, 78), "LEG", 18, MUTED)
	text(Vector2(24, 114), leg_names.get(leg, leg.to_upper()), 28, AMBER if leg == "go_around" else CYAN)
	text(Vector2(24, 162), "ALT TGT", 18, MUTED)
	text(Vector2(202, 162), "%d M" % int(round(lesson.get("desired_altitude", 0.0))), 28, CYAN)
	text(Vector2(24, 208), "IAS TGT", 18, MUTED)
	text(Vector2(202, 208), "%d KM/H" % int(round(lesson.get("speed_target", 0.0))), 28, CYAN)
	draw_line(Vector2(24, 230), Vector2(488, 230), MUTED, 1.0)
	text(Vector2(24, 272), "IAS %d" % int(state.get("speedKmh", 0.0)), 26, BRIGHT)
	text(Vector2(270, 272), "ALT %d" % int(state.get("position", [0, 0, 0])[1]), 26, BRIGHT)
	text(Vector2(24, 316), "VS %+.1f" % state.get("verticalSpeed", 0.0), 24, INK)
	text(Vector2(270, 316), "HDG %03d°" % (int(round(state.get("heading", 0.0))) % 360), 24, INK)
	var gear = str(state.get("gearState", "DOWN"))
	text(Vector2(24, 368), "GEAR " + gear, 22 if gear in ["UP", "DOWN"] else 17, BRIGHT if gear == "DOWN" else AMBER)
	text(Vector2(270, 368), "BRAKE " + ("ON" if state.get("airbrake", false) else "OFF"), 22, AMBER if state.get("airbrake", false) else INK)
	text(Vector2(24, 418), "ROT %d KM/H" % int(round(state.get("rotationSpeed", 64.0) * 3.6)), 22, MUTED)
	if state.get("stall", false):
		text(Vector2(24, 456), "STALL", 26, AMBER)
	else:
		text(Vector2(24, 456), "RWY 36", 22, INK)
	text(Vector2(24, 486), "KC-390 / LOCAL TRAINING", 16, MUTED)


func _draw() -> void:
	if state.is_empty():
		return
	match mode:
		"navigation": draw_navigation()
		"engine": draw_engine()
		"system": draw_system()
		"nd": draw_nd()
		"fms": draw_fms()
