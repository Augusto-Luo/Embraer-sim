extends "res://scripts/pursuit_director.gd"

const TAIL_HOLD_SECONDS = 3.0
const CHASE_CINEMATIC_SECONDS = 4.0
const ESCAPE_DISTANCE = 8000.0
const TAIL_MIN_DISTANCE = 350.0
const TAIL_MAX_DISTANCE = 1400.0

var cinematic_time = 0.0
var weapons_released = false
var escape_axis = Vector3(0, 0, 1)
var escape_origin = Vector3.ZERO
var border_distance = ESCAPE_DISTANCE


func restart() -> void:
	super.restart()
	stage = "chase_cinematic"
	cinematic_time = 0.0
	weapons_released = false
	border_distance = ESCAPE_DISTANCE
	completed = false
	set_event("INTERCEPT FLÁVIO", 4.0)


func spawn_enemies() -> void:
	target = TransportAircraft.new()
	target.callsign = "Flávio"
	var forward = Vector3(player.forward.x, 0.0, player.forward.z).normalized()
	if forward.length_squared() < 0.1:
		forward = Vector3(0, 0, 1)
	var lateral = Vector3(forward.z, 0.0, -forward.x)
	target.position = player.position + forward * 1600.0 + lateral * 250.0
	target.quaternion = Quaternion(Vector3.UP, atan2(forward.x, forward.z))
	target.player = player
	add_child(target)
	enemies.append(target)
	selected_enemy = target
	escape_axis = forward
	escape_origin = player.position
	border_distance = ESCAPE_DISTANCE - 1600.0
	distance_to_target = 1600.0


func cinematic_active() -> bool:
	return stage == "chase_cinematic"


func cinematic_controls(dt: float, controls: Dictionary) -> Dictionary:
	if not cinematic_active():
		return controls
	cinematic_time = min(CHASE_CINEMATIC_SECONDS, cinematic_time + dt)
	var guided = controls.duplicate()
	guided.throttleDelta = 1.0
	guided.airbrake = false
	if is_instance_valid(target) and not target.destroyed:
		var direction = (target.model.position - player.position).normalized()
		var local = player.orientation.inverse() * direction
		var turn = clamp(atan2(local.x, local.z) / 0.75, -0.65, 0.65)
		guided.roll = clamp(-turn * 0.60, -0.35, 0.35)
		guided.yaw = clamp(-turn * 0.25, -0.15, 0.15)
		guided.pitch = clamp(asin(clamp(local.y, -1.0, 1.0)) * 0.8, -0.25, 0.25)
	if cinematic_time >= CHASE_CINEMATIC_SECONDS:
		stage = "intercept"
		set_event("CLOSE IN / HOLD TAIL", 2.5)
	return guided


func training_step(dt: float) -> void:
	var controller = get_parent()
	hold = controller.intro_active or controller.enemy_spawn_pending or controller.paused or controller.frozen or controller.settings_open or controller.observing or controller.observation_frozen
	if hold or dt <= 0.0 or not is_instance_valid(target) or target.destroyed or stage in ["complete", "failed"]:
		return
	var offset = target.model.position - player.position
	distance_to_target = offset.length()
	nose_angle = rad_to_deg(acos(clamp(player.forward.dot(offset.normalized()), -1.0, 1.0)))
	tail_aligned = player.forward.dot(target.model.forward) > 0.35 and (player.position - target.model.position).dot(target.model.forward) < -100.0
	border_distance = max(0.0, ESCAPE_DISTANCE - (target.model.position - escape_origin).dot(escape_axis))
	if border_distance <= 0.0:
		stage = "failed"
		completed = false
		weapons_released = false
		locked = false
		lock_progress = 0.0
		reset_gun_assist()
		set_event("TARGET ESCAPED", 8.0)
		return
	if cinematic_active() or stage == "weapons_free":
		return
	var in_window = distance_to_target >= TAIL_MIN_DISTANCE and distance_to_target <= TAIL_MAX_DISTANCE and nose_angle <= 16.0 and tail_aligned
	if in_window:
		if stage != "tail_hold":
			stage = "tail_hold"
			set_event("HOLD TAIL / 3 SEC", 2.0)
		follow_time = min(TAIL_HOLD_SECONDS, follow_time + dt)
	else:
		if stage == "tail_hold":
			stage = "intercept"
		follow_time = max(0.0, follow_time - dt * 0.75)
	if follow_time >= TAIL_HOLD_SECONDS - 0.0001:
		stage = "weapons_free"
		weapons_released = true
		completed = true
		set_event("WEAPONS FREE", 3.0)


func fire_gun() -> void:
	if not weapons_released:
		if stage not in ["complete", "failed"]:
			set_event("WEAPONS HOLD", 0.6)
		return
	super.fire_gun()


func fire_missile() -> void:
	if not weapons_released:
		if stage not in ["complete", "failed"]:
			set_event("WEAPONS HOLD", 0.6)
		return
	super.fire_missile()


func register_kill(enemy) -> void:
	super.register_kill(enemy)
	if enemy == target:
		target_respawn_time = -1.0
		stage = "complete"
		completed = true
		weapons_released = false
		set_event("INTERCEPT COMPLETE", 8.0)


func interception_snapshot() -> Dictionary:
	return {
		"stage": stage,
		"target_id": "Flávio",
		"target_valid": is_instance_valid(target),
		"target_destroyed": is_instance_valid(target) and target.destroyed,
		"distance": distance_to_target,
		"border_distance": border_distance,
		"angle": nose_angle,
		"tail_aligned": tail_aligned,
		"follow_time": follow_time,
		"follow_required": TAIL_HOLD_SECONDS,
		"progress": clamp(follow_time / TAIL_HOLD_SECONDS, 0.0, 1.0),
		"weapons_released": weapons_released,
		"cinematic": cinematic_active(),
		"cinematic_progress": clamp(cinematic_time / CHASE_CINEMATIC_SECONDS, 0.0, 1.0),
	}
