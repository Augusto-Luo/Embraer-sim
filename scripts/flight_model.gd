extends RefCounted

const FlightSettings = preload("res://scripts/flight_settings.gd")
const TransportProfile = preload("res://scripts/transport_profile.gd")

var settings = {}
var position = Vector3(0, 1200, 0)
var orientation = Quaternion()
var speed = 115.0
var throttle = 0.68
var ground_height_func: Callable = func(_x, _z): return 0.0
var obstacle_height_func: Callable = func(_x, _z): return -INF
var boundary_radius = 5000.0
var spawn = {}
var inputs = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0}
var forward = Vector3(0, 0, 1)
var up = Vector3.UP
var right = Vector3.LEFT
var pitch = 0.0
var bank = 0.0
var heading = 0.0
var vertical_speed = 0.0
var stall = false
var stall_severity = 0.0
var low_altitude = false
var outside_boundary = false
var crashed = false
var airbrake = false
var time = 0.0
var ground = 0.0
var agl = 1200.0
var invincible = false
var ground_operations = false
var on_ground = false
var gear_clearance = 2.5
var rotation_speed = 60.0
var ground_thrust_scale = 0.22
var transport_profile = false
var engine_power = 0.68
var angular_rates = Vector3.ZERO
var flight_path_angle = 0.0
var touchdown_count = 0
var last_touchdown = {}
var ground_contact_time = -1.0
var gear_compression = 0.0
var gear_target_down = true
var gear_extension = 1.0
const GEAR_TRAVEL_SECONDS = 3.2


func _init(options: Dictionary = {}) -> void:
	settings = options.get("settings", null)
	if settings == null:
		settings = FlightSettings.DEFAULTS.duplicate()
	position = options.get("position", position)
	orientation = options.get("quaternion", options.get("orientation", orientation))
	speed = options.get("speed", speed)
	throttle = options.get("throttle", throttle)
	ground_height_func = options.get("ground_height", ground_height_func)
	obstacle_height_func = options.get("obstacle_height", obstacle_height_func)
	boundary_radius = options.get("boundary_radius", boundary_radius)
	invincible = bool(options.get("invincible", false))
	transport_profile = bool(options.get("transport_profile", false))
	if transport_profile and options.get("settings", null) == null:
		settings.merge(TransportProfile.SETTINGS, true)
	ground_operations = bool(options.get("ground_operations", false))
	on_ground = ground_operations and bool(options.get("on_ground", false))
	gear_clearance = max(0.1, float(options.get("gear_clearance", TransportProfile.GEAR_CLEARANCE if transport_profile else 2.5)))
	rotation_speed = max(1.0, float(options.get("rotation_speed", TransportProfile.ROTATION_SPEED if transport_profile else 60.0)))
	ground_thrust_scale = max(0.01, float(options.get("ground_thrust_scale", TransportProfile.GROUND_THRUST_SCALE if transport_profile else 0.22)))
	engine_power = throttle
	spawn = {
		"position": position,
		"quaternion": orientation,
		"speed": speed,
		"throttle": throttle,
		"on_ground": on_ground,
	}
	update_attitude()
	flight_path_angle = pitch - TransportProfile.angle_of_attack(speed) if transport_profile and not on_ground else pitch


func reset() -> void:
	position = spawn.position
	orientation = spawn.quaternion
	speed = spawn.speed
	throttle = spawn.throttle
	on_ground = spawn.on_ground
	engine_power = throttle
	angular_rates = Vector3.ZERO
	touchdown_count = 0
	last_touchdown = {}
	ground_contact_time = -1.0
	gear_compression = 0.0
	gear_target_down = true
	gear_extension = 1.0
	inputs = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0}
	vertical_speed = 0.0
	stall = false
	stall_severity = 0.0
	crashed = false
	airbrake = false
	time = 0.0
	update_attitude()
	flight_path_angle = pitch - TransportProfile.angle_of_attack(speed) if transport_profile and not on_ground else pitch


func damp_value(current: float, target: float, rate: float, dt: float) -> float:
	return lerp(current, target, 1.0 - exp(-rate * dt))


func request_landing_gear(down: bool) -> bool:
	if not transport_profile or (on_ground and not down) or gear_target_down == down:
		return false
	gear_target_down = down
	return true


func toggle_landing_gear() -> bool:
	return request_landing_gear(not gear_target_down)


func landing_gear_state() -> String:
	if gear_extension >= 0.999:
		return "DOWN"
	if gear_extension <= 0.001:
		return "UP"
	return "EXTENDING" if gear_target_down else "RETRACTING"


func update_attitude() -> void:
	forward = (orientation * Vector3(0, 0, 1)).normalized()
	up = (orientation * Vector3.UP).normalized()
	right = forward.cross(up).normalized()
	pitch = asin(clamp(forward.y, -1.0, 1.0))
	bank = atan2(-right.y, up.y)
	heading = fposmod(rad_to_deg(atan2(-forward.x, forward.z)) + 360.0, 360.0)
	ground = ground_height_func.call(position.x, position.z)
	agl = position.y - ground
	low_altitude = agl < 180.0
	outside_boundary = Vector2(position.x, position.z).length() > boundary_radius


func step(dt: float, controls: Dictionary = {}) -> void:
	if crashed:
		return
	# Resolve transport wheel contact at a fixed small interval so a slower
	# frame cannot bury the wheels before the suspension gets its first step.
	if transport_profile and ground_operations and dt > 1.0 / 120.0 + 0.000001:
		var steps = ceili(dt * 120.0)
		for index in range(steps):
			step(dt / steps, controls)
		return
	time += dt
	if transport_profile:
		gear_extension = move_toward(gear_extension, 1.0 if gear_target_down else 0.0, dt / GEAR_TRAVEL_SECONDS)
	throttle = clamp(throttle + float(controls.get("throttleDelta", 0.0)) * float(settings.get("throttle_response", 0.65)) * dt, 0.0, 1.0)
	airbrake = bool(controls.get("airbrake", false))
	var response = max(0.1, float(settings.get("input_response", 1.0)))
	inputs.pitch = damp_value(inputs.pitch, clamp(float(controls.get("pitch", 0.0)), -1.0, 1.0), 9.0 * response, dt)
	inputs.roll = damp_value(inputs.roll, clamp(float(controls.get("roll", 0.0)), -1.0, 1.0), 12.0 * response, dt)
	inputs.yaw = damp_value(inputs.yaw, clamp(float(controls.get("yaw", 0.0)), -1.0, 1.0), 8.0 * response, dt)
	update_attitude()
	if transport_profile:
		engine_power = damp_value(engine_power, throttle, TransportProfile.ENGINE_RESPONSE, dt)
	if ground_operations and on_ground:
		step_ground(dt)
		return
	if transport_profile:
		step_transport(dt)
		return

	var authority = clamp((speed - 32.0) / 65.0, 0.18, 1.0)
	var stall_now = clamp((52.0 - speed) / 16.0, 0.0, 1.0)
	stall_severity = stall_now
	stall = speed < 55.0
	var pitch_rate = inputs.pitch * float(settings.get("pitch_rate", 0.65)) * authority
	var roll_rate = inputs.roll * float(settings.get("roll_rate", 2.0)) * authority
	var yaw_rate = inputs.yaw * float(settings.get("yaw_rate", 0.30)) * authority
	yaw_rate += sin(bank) * float(settings.get("turn_coordination", 0.38)) * clamp(105.0 / max(speed, 35.0), 0.55, 1.5)
	if stall_now > 0.0:
		pitch_rate -= stall_now * 0.42
		roll_rate += sin(time * 17.3) * stall_now * 0.24

	orientation = (orientation * Quaternion(Vector3.RIGHT, -pitch_rate * dt)).normalized()
	orientation = (orientation * Quaternion(Vector3.UP, -yaw_rate * dt)).normalized()
	orientation = (orientation * Quaternion(Vector3.BACK, roll_rate * dt)).normalized()
	update_attitude()

	var thrust = throttle * float(settings.get("thrust", 20.5))
	var drag = 0.04 + float(settings.get("drag", 0.00030)) * speed * speed
	var gravity_along_flight_path = 9.81 * forward.y
	var manoeuvre_drag = (abs(inputs.pitch) * 1.15 + abs(sin(bank)) * 0.85) * clamp(speed / 110.0, 0.6, 1.4)
	var idle_brake = max(0.0, 0.10 - throttle) / 0.10 * (1.0 + speed * 0.005) * float(settings.get("throttle_brake_strength", 1.0))
	var brake_drag = (5.5 if airbrake else 0.0) + idle_brake
	var acceleration = thrust - drag - gravity_along_flight_path - manoeuvre_drag - brake_drag
	speed = clamp(speed + acceleration * dt, float(settings.get("speed_min", 45.0)), float(settings.get("speed_max", 260.0)))

	var sink = stall_now * float(settings.get("stall_sink", 14.0))
	vertical_speed = forward.y * speed - sink
	position += forward * speed * dt
	position.y -= sink * dt

	var impact_height = max(
		ground_height_func.call(position.x, position.z),
		obstacle_height_func.call(position.x, position.z)
	) + (gear_clearance if ground_operations else 2.5)
	if position.y <= impact_height:
		if ground_operations:
			record_touchdown(impact_height)
		position.y = impact_height
		vertical_speed = 0.0
		if invincible:
			vertical_speed = max(0.0, vertical_speed)
			if ground_operations:
				on_ground = true
				level_ground_attitude(0.0)
		else:
			speed = 0.0
			crashed = true
			stall = false
			stall_severity = 0.0
	update_attitude()


func level_ground_attitude(ground_pitch: float) -> void:
	var yaw = atan2(forward.x, forward.z)
	orientation = (Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, -ground_pitch)).normalized()
	update_attitude()


func step_ground(dt: float) -> void:
	# Virtual landing gear supports the aircraft without a wheel mesh or rigid bodies.
	# Ground thrust is deliberately slower than airborne thrust for a useful runway roll.
	stall = false
	stall_severity = 0.0
	var thrust = (engine_power if transport_profile else throttle) * float(settings.get("thrust", 20.5)) * ground_thrust_scale
	var rolling_drag = 0.35 + float(settings.get("drag", 0.00030)) * speed * speed
	var idle_brake = max(0.0, 0.35 - throttle) * (4.0 + speed * 0.01) * float(settings.get("throttle_brake_strength", 1.0))
	var brake_drag = (TransportProfile.WHEEL_BRAKE_DRAG if transport_profile else 7.5) if airbrake else 0.0
	speed = clamp(speed + (thrust - rolling_drag - idle_brake - brake_drag) * dt, 0.0, float(settings.get("speed_max", 260.0)))
	var steering_authority = clamp(speed / 20.0, 0.0, 1.0) * clamp(45.0 / max(speed, 1.0), 0.35, 1.0)
	var yaw_rate = inputs.yaw * float(settings.get("yaw_rate", 0.30)) * steering_authority
	if transport_profile:
		angular_rates.z = TransportProfile.angular_rate(angular_rates.z, yaw_rate, inputs.yaw, dt)
		yaw_rate = angular_rates.z
	orientation = (Quaternion(Vector3.UP, -yaw_rate * dt) * orientation).normalized()
	update_attitude()
	if transport_profile:
		step_transport_ground(dt)
		return
	var ground_pitch = 0.0
	if speed >= rotation_speed:
		var pitch_rate = inputs.pitch * float(settings.get("pitch_rate", 0.65)) * 0.45
		if transport_profile:
			angular_rates.x = TransportProfile.angular_rate(angular_rates.x, pitch_rate, inputs.pitch, dt)
			pitch_rate = angular_rates.x
		ground_pitch = clamp(pitch + pitch_rate * dt, 0.0, deg_to_rad(10.0))
	elif transport_profile:
		angular_rates.x = 0.0
	if transport_profile:
		angular_rates.y = 0.0
	level_ground_attitude(ground_pitch)
	var ground_direction = Vector3(forward.x, 0.0, forward.z).normalized()
	position += ground_direction * speed * dt
	position.y = max(ground_height_func.call(position.x, position.z), obstacle_height_func.call(position.x, position.z)) + gear_clearance
	vertical_speed = 0.0
	if speed >= rotation_speed and ground_pitch >= deg_to_rad(3.0) and inputs.pitch > 0.1:
		on_ground = false
		flight_path_angle = max(0.0, pitch - TransportProfile.angle_of_attack(speed)) if transport_profile else pitch
		vertical_speed = sin(flight_path_angle) * speed
		position.y += vertical_speed * dt
	update_attitude()


func transport_support_height() -> float:
	var surface = max(ground_height_func.call(position.x, position.z), obstacle_height_func.call(position.x, position.z))
	# The main wheels meet first in a flare; the nose can then lower around them.
	# Project the three wheel contact points instead of pinning the aircraft origin.
	var support = gear_clearance
	if gear_extension >= 0.999:
		support = -INF
		for wheel in [
			Vector3(0.0, -gear_clearance, TransportProfile.NOSE_GEAR_FORWARD),
			Vector3(TransportProfile.MAIN_GEAR_HALF_TRACK, -gear_clearance, -TransportProfile.MAIN_GEAR_AFT),
			Vector3(-TransportProfile.MAIN_GEAR_HALF_TRACK, -gear_clearance, -TransportProfile.MAIN_GEAR_AFT),
		]:
			support = max(support, -(orientation * wheel).y)
	return surface + support


func landing_gear_strokes() -> Vector3:
	if not transport_profile or not on_ground or gear_extension < 0.999:
		return Vector3.ZERO
	var strokes = Vector3.ZERO
	var contacts = [
		Vector3(0.0, -gear_clearance, TransportProfile.NOSE_GEAR_FORWARD),
		Vector3(TransportProfile.MAIN_GEAR_HALF_TRACK, -gear_clearance, -TransportProfile.MAIN_GEAR_AFT),
		Vector3(-TransportProfile.MAIN_GEAR_HALF_TRACK, -gear_clearance, -TransportProfile.MAIN_GEAR_AFT),
	]
	for index in range(contacts.size()):
		var wheel = position + orientation * contacts[index]
		var surface = max(ground_height_func.call(wheel.x, wheel.z), obstacle_height_func.call(wheel.x, wheel.z))
		strokes[index] = clamp((surface - wheel.y) / max(up.y, 0.5), 0.0, TransportProfile.GEAR_COMPRESSION_LIMIT)
	return strokes


func step_transport_ground(dt: float) -> void:
	if ground_contact_time >= 0.0:
		ground_contact_time += dt
	# Keep contact attitude and angular momentum. Wheel loads gently lower the
	# nose, level the wings, and add a restrained braking dip during the rollout.
	var braking_pitch = deg_to_rad(-0.35) if airbrake and speed > 12.0 else 0.0
	var pitch_rate = (braking_pitch - pitch) * 2.2
	var rotation_allowed = ground_contact_time < 0.0 or ground_contact_time >= TransportProfile.TOUCHDOWN_ROTATION_DELAY
	if rotation_allowed and speed >= rotation_speed and abs(inputs.pitch) > 0.1:
		pitch_rate = inputs.pitch * float(settings.get("pitch_rate", 0.16)) * 0.45
		angular_rates.x = TransportProfile.angular_rate(angular_rates.x, pitch_rate, inputs.pitch, dt)
	else:
		angular_rates.x = damp_value(angular_rates.x, pitch_rate, 4.2, dt)
	angular_rates.y = damp_value(angular_rates.y, -bank * 3.2, 4.8, dt)
	orientation = (orientation * Quaternion(Vector3.RIGHT, -angular_rates.x * dt)).normalized()
	orientation = (orientation * Quaternion(Vector3.BACK, angular_rates.y * dt)).normalized()
	update_attitude()
	var ground_direction = Vector3(forward.x, 0.0, forward.z).normalized()
	position += ground_direction * speed * dt
	var support_height = transport_support_height()
	# Substeps keep the mass-normalized spring stable across frame rates. The
	# incoming descent rate drives the stroke rather than an imposed animation.
	var steps = max(1, ceili(dt / (1.0 / 120.0)))
	var sub_dt = dt / steps
	var frequency = TransportProfile.GEAR_SPRING_FREQUENCY
	var damping = 2.0 * TransportProfile.GEAR_DAMPING_RATIO * frequency
	if gear_extension < 0.999:
		damping = 2.0 * frequency
	for index in range(steps):
		var displacement = position.y - support_height
		var acceleration = -frequency * frequency * displacement - damping * vertical_speed
		vertical_speed += acceleration * sub_dt
		position.y += vertical_speed * sub_dt
		# A physical bump stop only engages on an excessive impact. Normal
		# touchdowns never set height or discard the incoming vertical velocity.
		if position.y < support_height - TransportProfile.GEAR_COMPRESSION_LIMIT:
			position.y = support_height - TransportProfile.GEAR_COMPRESSION_LIMIT
			vertical_speed = max(0.0, -vertical_speed * 0.08)
	gear_compression = clamp(support_height - position.y, 0.0, TransportProfile.GEAR_COMPRESSION_LIMIT)
	if rotation_allowed and speed >= rotation_speed and pitch >= deg_to_rad(3.0) and inputs.pitch > 0.1:
		on_ground = false
		ground_contact_time = -1.0
		gear_compression = 0.0
		flight_path_angle = max(0.0, pitch - TransportProfile.angle_of_attack(speed))
		vertical_speed = max(0.0, sin(flight_path_angle) * speed)
	update_attitude()


func step_transport(dt: float) -> void:
	# Rates carry inertia, while reversing input damps them promptly. Releasing a
	# control stops the rate rather than automatically leveling the aircraft.
	var authority = clamp(speed / 75.0, 0.45, 1.0)
	var targets = Vector3(
		inputs.pitch * float(settings.get("pitch_rate", 0.16)) * authority,
		inputs.roll * float(settings.get("roll_rate", 0.42)) * authority,
		inputs.yaw * float(settings.get("yaw_rate", 0.09)) * authority
	)
	angular_rates.x = TransportProfile.angular_rate(angular_rates.x, targets.x, inputs.pitch, dt)
	angular_rates.y = TransportProfile.angular_rate(angular_rates.y, targets.y, inputs.roll, dt)
	angular_rates.z = TransportProfile.angular_rate(angular_rates.z, targets.z, inputs.yaw, dt)
	orientation = (orientation * Quaternion(Vector3.RIGHT, -angular_rates.x * dt)).normalized()
	orientation = (orientation * Quaternion(Vector3.BACK, angular_rates.y * dt)).normalized()
	update_attitude()
	var turn_bank = clamp(bank, deg_to_rad(-70.0), deg_to_rad(70.0))
	var coordinated_turn = 9.81 * tan(turn_bank) / max(speed, 35.0) * float(settings.get("turn_coordination", 1.0))
	orientation = (Quaternion(Vector3.UP, -(coordinated_turn + angular_rates.z) * dt) * orientation).normalized()
	update_attitude()

	stall_severity = clamp((52.0 - speed) / 16.0, 0.0, 1.0)
	stall = speed < 52.0
	var target_path = pitch - TransportProfile.angle_of_attack(speed)
	flight_path_angle = damp_value(flight_path_angle, target_path, TransportProfile.FLIGHT_PATH_RESPONSE, dt)
	var thrust = engine_power * float(settings.get("thrust", 4.6))
	var drag = 0.04 + float(settings.get("drag", 0.0004)) * speed * speed
	var manoeuvre_drag = abs(sin(bank)) * 0.35 + abs(inputs.pitch) * 0.20
	var idle_brake = max(0.0, 0.25 - throttle) * (1.2 + speed * 0.008) * float(settings.get("throttle_brake_strength", 0.5))
	var brake_drag = TransportProfile.AIRBRAKE_DRAG if airbrake else 0.0
	var acceleration = thrust - drag - 9.81 * sin(flight_path_angle) - manoeuvre_drag - idle_brake - brake_drag
	speed = clamp(speed + acceleration * dt, float(settings.get("speed_min", 48.0)), float(settings.get("speed_max", 150.0)))
	var sink = stall_severity * float(settings.get("stall_sink", 8.0))
	vertical_speed = sin(flight_path_angle) * speed - sink
	var horizontal_direction = Vector3(forward.x, 0.0, forward.z).normalized()
	position += horizontal_direction * cos(flight_path_angle) * speed * dt
	position.y += vertical_speed * dt
	var impact_height = transport_support_height() if ground_operations else max(ground_height_func.call(position.x, position.z), obstacle_height_func.call(position.x, position.z)) + gear_clearance
	if position.y <= impact_height and (not ground_operations or vertical_speed <= 0.0):
		record_touchdown(impact_height)
		if invincible and ground_operations:
			on_ground = true
			ground_contact_time = 0.0
			gear_compression = clamp(impact_height - position.y, 0.0, TransportProfile.GEAR_COMPRESSION_LIMIT)
			flight_path_angle = 0.0
		else:
			position.y = impact_height
			vertical_speed = 0.0
			if not invincible:
				speed = 0.0
				crashed = true
				stall = false
				stall_severity = 0.0
	update_attitude()


func record_touchdown(surface_height: float) -> void:
	touchdown_count += 1
	last_touchdown = {
		"position": Vector3(position.x, surface_height, position.z),
		"speed": speed,
		"vertical_speed": vertical_speed,
		"bank": bank,
		"pitch": pitch,
		"forward": forward,
		"gear_down": not transport_profile or gear_extension >= 0.999,
	}


func telemetry() -> Dictionary:
	return {
		"position": [position.x, position.y, position.z],
		"speed": speed,
		"speedKmh": speed * 3.6,
		"throttle": throttle,
		"pitch": pitch,
		"bank": bank,
		"heading": heading,
		"verticalSpeed": vertical_speed,
		"stall": stall,
		"stallSeverity": stall_severity,
		"lowAltitude": low_altitude,
		"outsideBoundary": outside_boundary,
		"crashed": crashed,
		"airbrake": airbrake,
		"groundHeight": ground,
		"agl": agl,
		"onGround": on_ground,
		"rotationSpeed": rotation_speed,
		"enginePower": engine_power if transport_profile else throttle,
		"flightPathAngle": flight_path_angle if transport_profile else pitch,
		"touchdownCount": touchdown_count,
		"gearCompression": gear_compression if transport_profile else 0.0,
		"gearEnabled": transport_profile,
		"gearExtension": gear_extension,
		"gearTargetDown": gear_target_down,
		"gearDown": transport_profile and gear_extension >= 0.999,
		"gearState": landing_gear_state() if transport_profile else "UP",
		"inputs": inputs.duplicate(),
		"time": time,
	}
