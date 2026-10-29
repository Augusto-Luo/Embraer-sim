extends RefCounted

# Training handling for the KC-390, applied only by an explicit model option.
# These settings are intended for the first-level configuration, not global defaults.
const SETTINGS = {
	"roll_rate": 0.42,
	"pitch_rate": 0.16,
	"yaw_rate": 0.09,
	"turn_coordination": 1.0,
	"input_response": 0.65,
	"thrust": 4.6,
	"drag": 0.0004,
	"speed_min": 48.0,
	"speed_max": 150.0,
	"throttle_response": 0.25,
	"throttle_brake_strength": 0.5,
	"stall_sink": 8.0,
}

const ROTATION_SPEED = 64.0
const GROUND_THRUST_SCALE = 1.0
const GEAR_CLEARANCE = 1.2
const ENGINE_RESPONSE = 1.0
const ANGULAR_ACCEL_RESPONSE = 1.8
const ANGULAR_RELEASE_RESPONSE = 3.8
const ANGULAR_COUNTER_RESPONSE = 5.5
const FLIGHT_PATH_RESPONSE = 1.1
const AIRBRAKE_DRAG = 2.0
const WHEEL_BRAKE_DRAG = 3.8
# A short, damped undercarriage stroke, scoped to the training transport.
const GEAR_SPRING_FREQUENCY = 12.0
const GEAR_DAMPING_RATIO = 0.76
const GEAR_COMPRESSION_LIMIT = 0.28
const MAIN_GEAR_AFT = 4.22
const MAIN_GEAR_HALF_TRACK = 2.48
const NOSE_GEAR_FORWARD = 6.85
const TOUCHDOWN_ROTATION_DELAY = 0.35


static func angular_rate(current: float, target: float, input_value: float, dt: float) -> float:
	var response = ANGULAR_ACCEL_RESPONSE
	if abs(input_value) < 0.03:
		response = ANGULAR_RELEASE_RESPONSE
	elif current * target < 0.0:
		response = ANGULAR_COUNTER_RESPONSE
	return lerp(current, target, 1.0 - exp(-response * dt))


static func angle_of_attack(speed: float) -> float:
	# A small attitude/path separation makes shallow approach and progressive flare
	# possible without claiming a full aerodynamic lift or flap simulation.
	return deg_to_rad(clamp(2.0 * pow(65.0 / max(speed, 35.0), 2.0), 0.8, 4.0))
