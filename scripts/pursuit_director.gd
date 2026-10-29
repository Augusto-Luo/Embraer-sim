extends "res://scripts/combat_director.gd"

const TransportAircraft = preload("res://scripts/transport_aircraft.gd")
const FOLLOW_SECONDS = 2.0

var stage = "approach"
var follow_time = 0.0
var target
var target_respawn_time = -1.0
var completed = false
var distance_to_target = 1100.0
var nose_angle = 0.0
var tail_aligned = false
var rejoin_recommended = false


func restart() -> void:
	stage = "approach"
	follow_time = 0.0
	completed = false
	target_respawn_time = -1.0
	rejoin_recommended = false
	super.restart()
	set_event("INTERCEPT KC-390", 4.0)


func spawn_enemies() -> void:
	target = TransportAircraft.new()
	target.callsign = "KC-390"
	var forward = Vector3(player.forward.x, 0.0, player.forward.z).normalized()
	if forward.length_squared() < 0.1:
		forward = Vector3.BACK
	var lateral = Vector3(forward.z, 0.0, -forward.x)
	target.position = player.position + forward * 1100.0 + lateral * 350.0
	target.quaternion = Quaternion(Vector3.UP, atan2(forward.x, forward.z))
	target.player = player
	add_child(target)
	enemies.append(target)
	selected_enemy = target


func _physics_process(dt: float) -> void:
	# Read pause causes at the point of use, including event-driven weapon input.
	var controller = get_parent()
	hold = controller.intro_active or controller.enemy_spawn_pending or controller.paused or controller.frozen or controller.settings_open or controller.observing or controller.observation_frozen
	super._physics_process(dt)
	if hold:
		return
	if target_respawn_time >= 0.0:
		target_respawn_time -= dt
		if target_respawn_time <= 0.0:
			respawn_target()
	training_step(dt)


func training_step(dt: float) -> void:
	var controller = get_parent()
	hold = controller.intro_active or controller.enemy_spawn_pending or controller.paused or controller.frozen or controller.settings_open or controller.observing or controller.observation_frozen
	if hold or dt <= 0.0 or not is_instance_valid(target) or target.destroyed:
		return
	var offset = target.model.position - player.position
	distance_to_target = offset.length()
	nose_angle = rad_to_deg(acos(clamp(player.forward.dot(offset.normalized()), -1.0, 1.0)))
	tail_aligned = player.forward.dot(target.model.forward) > 0.5 and (player.position - target.model.position).dot(target.model.forward) < -100.0
	rejoin_recommended = distance_to_target > 5000.0 or player.position.y < 2500.0 or player.position.y > 8500.0 or player.outside_boundary
	if completed:
		return
	if stage == "approach":
		if distance_to_target <= 1100.0 and distance_to_target >= 350.0 and nose_angle <= 20.0 and tail_aligned:
			stage = "track"
			set_event("HOLD TAIL / 2 SEC", 3.0)
		return
	var in_window = distance_to_target >= 350.0 and distance_to_target <= 1100.0 and nose_angle <= 14.0 and tail_aligned
	if in_window:
		follow_time = min(FOLLOW_SECONDS, follow_time + dt)
	else:
		follow_time = max(0.0, follow_time - dt * 0.65)
	if follow_time >= FOLLOW_SECONDS:
		completed = true
		stage = "complete"
		set_event("PURSUIT CLEAR", 5.0)


func apply_nose_assist(dt: float, controls: Dictionary) -> Dictionary:
	# Keep the short pursuit exercise manual; free weapons practice uses assist.
	if not completed:
		reset_gun_assist()
		return controls
	return super.apply_nose_assist(dt, controls)


func get_gun_assist_target():
	return super.get_gun_assist_target() if completed else null


func register_kill(enemy) -> void:
	super.register_kill(enemy)
	if enemy == target and target_respawn_time < 0.0:
		target_respawn_time = 3.0
		set_event("TARGET DOWN / REPLACING", 3.0)


func respawn_target() -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	selected_enemy = null
	player_missile_target = null
	locked = false
	lock_progress = 0.0
	lock_loss_time = 0.0
	spawn_enemies()
	target_respawn_time = -1.0
	gun_ammo = 600
	missile_ammo = 6
	set_event("NEW TARGET", 3.0)


func fire_missile() -> void:
	var controller = get_parent()
	if controller.paused or controller.frozen or controller.settings_open or controller.observing:
		return
	super.fire_missile()


func training_snapshot() -> Dictionary:
	return {
		"stage": stage,
		"progress": follow_time / FOLLOW_SECONDS,
		"distance": distance_to_target,
		"angle": nose_angle,
		"tail_aligned": tail_aligned,
		"completed": completed,
		"rejoin": rejoin_recommended,
		"respawning": target_respawn_time >= 0.0,
		"turning": is_instance_valid(target) and target.turning,
	}
