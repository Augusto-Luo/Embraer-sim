extends RefCounted

const PATTERN_ALTITUDE = 350.0
const CIRCUIT_SPEED = 80.0
const FINAL_SPEED = 70.0
const TURN_RADIUS = 1200.0
const SAMPLE_SPACING = 80.0
const LOOK_AHEAD = 380.0
const TOAST_SECONDS = 4.0
const CORRECTION_INTERVAL = 12.0

var player
var airport
var stage = "ready"
var completed = false
# Kept for callers that inspect the original takeoff exercise timer.
var climb_time = 0.0
var route_points: Array[Vector3] = []
var route_distances: Array[float] = []
var route_legs: Array[String] = []
var total_route_length = 0.0
var route_progress = 0.0
var route_index = 0
var navigation_target = Vector3.ZERO
var desired_altitude = 0.0
var speed_target = CIRCUIT_SPEED * 3.6
var distance_to_route = 0.0
var toast = ""
var toast_remaining = 0.0
var toast_queue: Array[String] = []
var airborne_time = 0.0
var landing_armed = false
var landed_safely = false
var _was_on_ground = true
var _last_touchdown_count = 0
var _last_stage = ""
var _correction_cooldown = 0.0
var _stop_time = 0.0
var _go_around_active = false
var _route_ready = false
var _gear_up_prompted = false
var _gear_down_prompted = false


func restart() -> void:
	stage = "ready"
	completed = false
	climb_time = 0.0
	route_progress = 0.0
	route_index = 0
	distance_to_route = 0.0
	airborne_time = 0.0
	landing_armed = false
	landed_safely = false
	_was_on_ground = true
	_last_touchdown_count = int(player.get("touchdown_count")) if player.get("touchdown_count") != null else 0
	_last_stage = ""
	_correction_cooldown = 0.0
	_stop_time = 0.0
	_go_around_active = false
	_gear_up_prompted = false
	_gear_down_prompted = false
	toast = ""
	toast_remaining = 0.0
	toast_queue.clear()
	build_route()
	update_navigation()


func _world(point: Vector3) -> Vector3:
	return airport.SITE + point


func _height(agl: float) -> float:
	return airport.DECK_HEIGHT + player.gear_clearance + agl


func add_route_point(local: Vector3, leg: String) -> void:
	var point = _world(local)
	if not route_points.is_empty():
		total_route_length += route_points[-1].distance_to(point)
	route_points.append(point)
	route_distances.append(total_route_length)
	route_legs.append(leg)


func add_line(start: Vector3, finish: Vector3, leg: String) -> void:
	var count = max(1, int(ceil(start.distance_to(finish) / SAMPLE_SPACING)))
	for index in range(1, count + 1):
		add_route_point(start.lerp(finish, float(index) / count), leg)


func build_route() -> void:
	route_points.clear()
	route_distances.clear()
	route_legs.clear()
	total_route_length = 0.0
	var start = Vector3(0.0, _height(0.0), -1000.0)
	add_route_point(start, "roll")
	var rotation = Vector3(0.0, _height(0.0), -300.0)
	add_line(start, rotation, "roll")
	var initial_climb = Vector3(0.0, _height(100.0), 500.0)
	add_line(rotation, initial_climb, "climb")
	var outbound = Vector3(0.0, _height(PATTERN_ALTITUDE), 2300.0)
	add_line(initial_climb, outbound, "climb")
	var arc_count = int(ceil(PI * TURN_RADIUS / SAMPLE_SPACING))
	for index in range(1, arc_count + 1):
		var angle = PI * float(index) / arc_count
		add_route_point(Vector3(TURN_RADIUS * (1.0 - cos(angle)), _height(PATTERN_ALTITUDE), 2300.0 + TURN_RADIUS * sin(angle)), "crosswind")
	var downwind_start = Vector3(2.0 * TURN_RADIUS, _height(PATTERN_ALTITUDE), 2300.0)
	var downwind_end = Vector3(2.0 * TURN_RADIUS, _height(250.0), -2500.0)
	add_line(downwind_start, downwind_end, "downwind")
	for index in range(1, arc_count + 1):
		var fraction = float(index) / arc_count
		var angle = PI * fraction
		# Smooth altitude easing avoids a kink in the base-turn vertical guide.
		var blend = fraction * fraction * (3.0 - 2.0 * fraction)
		add_route_point(Vector3(TURN_RADIUS * (1.0 + cos(angle)), _height(lerp(250.0, 75.0, blend)), -2500.0 - TURN_RADIUS * sin(angle)), "base")
	var final_start = Vector3(0.0, _height(75.0), -2500.0)
	var touchdown = Vector3(0.0, _height(0.0), -1000.0)
	add_line(final_start, touchdown, "final")
	add_line(touchdown, Vector3(0.0, _height(0.0), 800.0), "rollout")
	_route_ready = true


func get_route() -> PackedVector3Array:
	if not _route_ready:
		build_route()
	return PackedVector3Array(route_points)


func queue_toast(message: String) -> void:
	if message == toast or message in toast_queue:
		return
	if toast_remaining <= 0.0:
		toast = message
		toast_remaining = TOAST_SECONDS
	else:
		# Only the next short cue is retained; stale instruction backlogs confuse pilots.
		toast_queue.assign([message])


func tick_toasts(dt: float) -> void:
	toast_remaining = max(0.0, toast_remaining - dt)
	_correction_cooldown = max(0.0, _correction_cooldown - dt)
	if toast_remaining <= 0.0:
		toast = ""
		if not toast_queue.is_empty():
			toast = toast_queue.pop_front()
			toast_remaining = TOAST_SECONDS


func stage_toast(value: String) -> String:
	match value:
		"ready": return "{THROTTLE_UP} THR + / {THROTTLE_DOWN} THR -"
		"roll": return "{STEER_LEFT} {STEER_RIGHT} / KEEP CENTERLINE"
		"rotate": return "ROTATE / {PULL_UP} GENTLE PULL"
		"climb": return "CLIMB / FOLLOW THE LINE"
		"crosswind": return "LEFT TURN / HOLD 350 M"
		"downwind": return "DOWNWIND / EASE TO 250 M"
		"base": return "LEFT BASE / DESCEND"
		"final": return "FINAL / 250 KM/H"
		"flare": return "{THROTTLE_DOWN} IDLE / GENTLE FLARE"
		"rollout": return "{BRAKE} BRAKE / KEEP STRAIGHT"
		"off_runway": return "OFF RUNWAY / REJOIN WHEN READY"
		"go_around": return "GO AROUND / POWER AND CLIMB"
		"clear": return "CIRCUIT COMPLETE"
	return ""


func set_stage(value: String) -> void:
	stage = value
	if _last_stage == value:
		return
	_last_stage = value
	queue_toast(stage_toast(value))


func project_route() -> void:
	# Horizontal projection keeps altitude deviations from jumping to another leg.
	# Progress advances continuously; broad turns and skipped samples are permitted.
	var best_distance = INF
	var best_progress = route_progress
	var best_index = route_index
	var first = max(0, route_index - 5)
	var last = min(route_points.size() - 2, route_index + 35)
	for index in range(first, last + 1):
		var a = Vector2(route_points[index].x, route_points[index].z)
		var b = Vector2(route_points[index + 1].x, route_points[index + 1].z)
		var point = Vector2(player.position.x, player.position.z)
		var offset = b - a
		var fraction = clamp((point - a).dot(offset) / max(offset.length_squared(), 0.001), 0.0, 1.0)
		var candidate = a.lerp(b, fraction)
		var separation = point.distance_to(candidate)
		var progress = lerp(route_distances[index], route_distances[index + 1], fraction)
		# Prefer proximity; negligible ties retain the earlier, stable route segment.
		if separation < best_distance - 0.01:
			best_distance = separation
			best_progress = progress
			best_index = index
	if best_distance > 1800.0:
		# A wide rejoin can skip ahead to any suitable remaining section, never rewind.
		for index in range(last + 1, route_points.size() - 1):
			var a = Vector2(route_points[index].x, route_points[index].z)
			var b = Vector2(route_points[index + 1].x, route_points[index + 1].z)
			var point = Vector2(player.position.x, player.position.z)
			var offset = b - a
			var fraction = clamp((point - a).dot(offset) / max(offset.length_squared(), 0.001), 0.0, 1.0)
			var separation = point.distance_to(a.lerp(b, fraction))
			if separation < best_distance - 150.0:
				best_distance = separation
				best_progress = lerp(route_distances[index], route_distances[index + 1], fraction)
				best_index = index
	if best_progress > route_progress:
		route_progress = best_progress
		route_index = best_index
	distance_to_route = best_distance


func point_at_distance(distance: float) -> Vector3:
	var index = route_index
	while index < route_points.size() - 2 and route_distances[index + 1] < distance:
		index += 1
	var fraction = clamp((distance - route_distances[index]) / max(0.001, route_distances[index + 1] - route_distances[index]), 0.0, 1.0)
	return route_points[index].lerp(route_points[index + 1], fraction)


func update_navigation() -> void:
	if route_points.is_empty():
		return
	var look_ahead = 220.0 if stage in ["final", "flare"] else LOOK_AHEAD
	navigation_target = point_at_distance(min(total_route_length, route_progress + look_ahead))
	desired_altitude = point_at_distance(route_progress).y
	speed_target = (FINAL_SPEED if stage in ["base", "final", "flare"] else CIRCUIT_SPEED) * 3.6
	if stage in ["ready", "roll", "rotate"]:
		speed_target = player.rotation_speed * 3.6
	elif stage in ["rollout", "clear"]:
		speed_target = 0.0
	elif stage == "go_around":
		navigation_target = _world(Vector3(0.0, _height(220.0), max(700.0, player.position.z - airport.SITE.z + 800.0)))
		desired_altitude = _height(220.0)
		speed_target = CIRCUIT_SPEED * 3.6


func begin_go_around() -> void:
	_go_around_active = true
	landed_safely = false
	_stop_time = 0.0
	set_stage("go_around")
	# Safety feedback takes priority over a queued routine leg announcement.
	toast_queue.clear()
	toast = stage_toast("go_around")
	toast_remaining = TOAST_SECONDS
	_correction_cooldown = CORRECTION_INTERVAL


func touchdown_is_safe() -> bool:
	if not airport.on_runway(player.position):
		return false
	var contact = player.get("last_touchdown")
	if contact is Dictionary and not contact.is_empty():
		if not bool(contact.get("gear_down", true)):
			return false
		return abs(float(contact.get("vertical_speed", player.vertical_speed))) <= 6.0 and abs(float(contact.get("bank", player.bank))) <= deg_to_rad(20.0) and float(contact.get("speed", player.speed)) <= 95.0 and Vector3(contact.get("forward", player.forward)).z >= 0.85 and abs(float(contact.get("pitch", player.pitch))) <= deg_to_rad(18.0)
	return player.speed <= 95.0 and abs(player.bank) <= deg_to_rad(20.0) and player.forward.z >= 0.85


func step(dt: float) -> void:
	if dt <= 0.0:
		return
	if not _route_ready:
		restart()
	tick_toasts(dt)
	if completed:
		return
	var grounded = bool(player.on_ground)
	var touchdown_count = int(player.get("touchdown_count")) if player.get("touchdown_count") != null else 0
	var new_touchdown = grounded and (not _was_on_ground or touchdown_count > _last_touchdown_count)
	_last_touchdown_count = touchdown_count
	if grounded:
		climb_time = 0.0
		if new_touchdown and landing_armed:
			landed_safely = touchdown_is_safe()
			if not landed_safely:
				begin_go_around()
		if landed_safely:
			if not airport.on_runway(player.position):
				landed_safely = false
				_stop_time = 0.0
				set_stage("off_runway")
			else:
				set_stage("rollout")
				_stop_time = _stop_time + dt if player.speed < 1.0 else 0.0
				if _stop_time >= 1.0:
					completed = true
					set_stage("clear")
		elif not airport.on_runway(player.position):
			set_stage("off_runway")
		elif _go_around_active:
			set_stage("go_around")
		elif player.speed >= player.rotation_speed:
			set_stage("rotate")
		elif player.speed > 1.0 or player.throttle > 0.05:
			set_stage("roll")
		else:
			set_stage("ready")
		# The visible line should move down the runway during the ground roll too.
		project_route()
	else:
		airborne_time += dt
		climb_time = climb_time + dt if player.agl >= 80.0 and player.vertical_speed > 0.0 else 0.0
		if airborne_time >= 8.0 and player.agl >= 60.0:
			landing_armed = true
		if _go_around_active:
			set_stage("go_around")
			if player.agl >= 150.0 and player.vertical_speed >= 0.0:
				_go_around_active = false
				# Begin a new circuit from the outbound climb; no aircraft state changes.
				route_index = 0
				route_progress = 0.0
				project_route()
		else:
			project_route()
			var leg = route_legs[min(route_index + 1, route_legs.size() - 1)]
			# Rollout is a contact state; passing its route samples in the air is
			# still an approach and must never ask the pilot to target zero airspeed.
			var next_stage = "final" if leg == "rollout" else (leg if leg != "roll" else "climb")
			var local = player.position - airport.SITE
			if landing_armed and local.z < -700.0 and abs(local.x) < 300.0 and next_stage in ["base", "final", "rollout"]:
				next_stage = "flare" if player.agl < 18.0 else "final"
			set_stage(next_stage)
			if next_stage in ["final", "flare"]:
				var missed_runway = landing_armed and local.z > airport.RUNWAY_LENGTH * 0.5 and player.agl < 150.0
				var unstable = player.agl < 45.0 and (abs(local.x) > 100.0 or abs(player.bank) > deg_to_rad(35.0) or player.vertical_speed < -6.0 or player.speed < 50.0 or player.speed > 110.0)
				if missed_runway or (unstable and _correction_cooldown <= 0.0):
					begin_go_around()
			if distance_to_route > 700.0 and _correction_cooldown <= 0.0:
				queue_toast("REJOIN THE LINE / NO RUSH")
				_correction_cooldown = CORRECTION_INTERVAL
	_was_on_ground = grounded
	if not grounded and bool(player.transport_profile):
		if stage == "climb" and player.agl > 35.0 and not _gear_up_prompted:
			_gear_up_prompted = true
			if player.gear_target_down:
				queue_toast("{GEAR} / GEAR UP")
		if stage in ["base", "final", "flare"] and not _gear_down_prompted:
			_gear_down_prompted = true
			if not player.gear_target_down:
				queue_toast("{GEAR} / GEAR DOWN")
		if stage in ["final", "flare"] and player.agl < 70.0 and player.gear_extension < 0.999 and _correction_cooldown <= 0.0:
			toast = "{GEAR} / GEAR DOWN"
			toast_remaining = TOAST_SECONDS
			toast_queue.clear()
			_correction_cooldown = CORRECTION_INTERVAL
	update_navigation()


func training_snapshot() -> Dictionary:
	if not _route_ready:
		restart()
	return {
		"stage": stage,
		"leg": stage,
		"completed": completed,
		"progress": 1.0 if completed else clamp(route_progress / max(total_route_length, 1.0), 0.0, 1.0),
		"runway_remaining": airport.runway_remaining(player.position),
		"rotation_speed": player.rotation_speed * 3.6,
		"navigation_target": navigation_target,
		"desired_altitude": desired_altitude,
		"speed_target": speed_target,
		"distance_to_route": distance_to_route,
		"route_progress": route_progress,
		"route_length": total_route_length,
		"route_index": route_index,
		"toast": toast,
		"toast_remaining": toast_remaining,
		"landed_safely": landed_safely,
	}
