extends Node3D

const EnemyAircraft = preload("res://scripts/enemy_aircraft.gd")
const CombatProjectile = preload("res://scripts/combat_projectile.gd")
const CombatEffect = preload("res://scripts/combat_effect.gd")
const GunFireAudio = preload("res://scripts/gun_fire_audio.gd")
const GUN_ASSIST_SECONDS = 1.25
const GUN_ASSIST_COOLDOWN_SECONDS = 5.0
const GUN_ASSIST_BREAK_SECONDS = 0.65
const GUN_ASSIST_CAPTURE_RANGE = 1600.0
const GUN_ASSIST_CAPTURE_ANGLE = 25.0
const GUN_ASSIST_HOLD_ANGLE = 35.0
const GUN_ASSIST_SNAP_ANGLE = 0.35

var player
var camera
var hold = false
var intro_pending = false
var enemies = []
var projectiles = []
var selected_enemy
var player_missile_target
var gun_ammo = 600
var missile_ammo = 6
var gun_cooldown = 0.0
var missile_cooldown = 0.0
var lock_progress = 0.0
var locked = false
var lock_loss_time = 0.0
var kills = 0
var shots = 0
var hits = 0
var comms_text = "BANDITS SPOTTED"
var comms_timer = 4.0
var warning_text = ""
var warning_timer = 0.0
var threat = false
var hit_timer = 0.0
var kill_timer = 0.0
var gun_audio
var sounds = {}
var gun_assist_target
var gun_assist_state = "idle"
var gun_assist_remaining = 0.0
var gun_assist_cooldown = 0.0
var gun_assist_manual_time = 0.0
var gun_assist_manual_direction = Vector3.ZERO
var gun_assist_manual_override = false
var gun_assist_quiet_time = 0.0
var gun_assist_pull_time = 0.0


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		sounds = {
			"gun": load("res://assets/audio/gun.mp3"),
			"missile": load("res://assets/audio/missile.mp3"),
			"lock": load("res://assets/audio/lock.mp3"),
			"explosion": load("res://assets/audio/explosion.mp3"),
		}
	restart()


func restart() -> void:
	reset_gun_assist()
	if is_instance_valid(gun_audio):
		gun_audio.stop()
	gun_audio = null
	for child in get_children():
		child.queue_free()
	enemies.clear()
	projectiles.clear()
	selected_enemy = null
	player_missile_target = null
	gun_ammo = 600
	missile_ammo = 6
	gun_cooldown = 0.0
	missile_cooldown = 0.0
	lock_progress = 0.0
	locked = false
	lock_loss_time = 0.0
	kills = 0
	shots = 0
	hits = 0
	comms_text = "BANDITS SPOTTED"
	comms_timer = 4.0
	warning_text = ""
	warning_timer = 0.0
	threat = false
	hit_timer = 0.0
	kill_timer = 0.0
	if not intro_pending:
		spawn_enemies()


func spawn_enemies() -> void:
	var spawn_position = player.position
	var forward = player.forward
	var right = player.right
	var count = clamp(int(player.settings.get("max_enemies", 3)), 1, 5)
	var configs = [
		{"name": "BANDIT-1", "role": 0, "position": spawn_position + forward * 2100.0 + Vector3.UP * 120.0},
		{"name": "BANDIT-2", "role": 1, "position": spawn_position + forward * 3000.0 - right * 1500.0 + Vector3.UP * 320.0},
		{"name": "BANDIT-3", "role": 2, "position": spawn_position + forward * 3600.0 + right * 1800.0 - Vector3.UP * 120.0},
		{"name": "BANDIT-4", "role": 0, "position": spawn_position + forward * 4300.0 - right * 2400.0 + Vector3.UP * 500.0},
		{"name": "BANDIT-5", "role": 1, "position": spawn_position + forward * 4800.0 + right * 2600.0 + Vector3.UP * 100.0},
	]
	for index in range(count):
		var config = configs[index]
		var enemy = EnemyAircraft.new()
		enemy.callsign = config.name
		enemy.role = config.role
		enemy.position = config.position
		var direction = (spawn_position - config.position).normalized()
		enemy.quaternion = Quaternion(Vector3.UP, atan2(direction.x, direction.z))
		enemy.player = player
		add_child(enemy)
		enemies.append(enemy)
	selected_enemy = enemies[0]


func _process(_dt: float) -> void:
	for enemy in enemies:
		enemy.hold = hold


func _physics_process(dt: float) -> void:
	if hold:
		for enemy in enemies:
			enemy.hold = true
			enemy.sync_idle()
		return
	update_timers(dt)
	for enemy in enemies:
		enemy.step_ai(dt, self)
	for projectile in projectiles.duplicate():
		if not is_instance_valid(projectile) or not projectile.active:
			continue
		var result = projectile.step(dt, enemies, player)
		if not result.is_empty():
			handle_projectile_result(projectile, result)
	update_targeting(dt)
	if Input.is_action_pressed("gun_fire"):
		fire_gun()
	player_missile_target = null
	for projectile in projectiles:
		if is_instance_valid(projectile) and projectile.active and projectile.team == "player" and projectile.kind == "missile" and projectile.target != null and not projectile.target.destroyed:
			player_missile_target = projectile.target
			break
	threat = false
	for projectile in projectiles:
		if is_instance_valid(projectile) and projectile.active and projectile.team == "enemy" and projectile.kind == "missile":
			threat = true
			break


func update_timers(dt: float) -> void:
	gun_cooldown = max(0.0, gun_cooldown - dt)
	missile_cooldown = max(0.0, missile_cooldown - dt)
	comms_timer = max(0.0, comms_timer - dt)
	warning_timer = max(0.0, warning_timer - dt)
	hit_timer = max(0.0, hit_timer - dt)
	kill_timer = max(0.0, kill_timer - dt)


func live_enemies() -> Array:
	return enemies.filter(func(enemy): return not enemy.destroyed)


func nearest_enemy():
	var nearest = null
	var best_distance = INF
	for enemy in enemies:
		if enemy.destroyed:
			continue
		var distance = enemy.model.position.distance_to(player.position)
		if distance < best_distance:
			best_distance = distance
			nearest = enemy
	return nearest


func cycle_target() -> void:
	reset_gun_assist(max(gun_assist_cooldown, 0.15))
	var live = live_enemies()
	if live.is_empty():
		selected_enemy = null
		set_warning("NO TARGET", 1.2)
		return
	live.sort_custom(func(a, b): return a.model.position.distance_squared_to(player.position) < b.model.position.distance_squared_to(player.position))
	var index = live.find(selected_enemy)
	selected_enemy = live[(index + 1) % live.size()]
	lock_progress = 0.0
	locked = false
	lock_loss_time = 0.0
	set_event("TARGET " + selected_enemy.callsign, 1.0)


func update_targeting(dt: float) -> void:
	if selected_enemy == null:
		lock_progress = 0.0
		locked = false
		lock_loss_time = 0.0
		return
	if selected_enemy.destroyed:
		selected_enemy = null
		lock_progress = 0.0
		locked = false
		lock_loss_time = 0.0
		return
	var direction = (selected_enemy.model.position - player.position).normalized()
	var distance = selected_enemy.model.position.distance_to(player.position)
	var angle = rad_to_deg(acos(clamp(player.forward.dot(direction), -1.0, 1.0)))
	if not locked:
		if distance <= 6000.0 and angle <= 14.0:
			lock_progress = min(1.0, lock_progress + dt / 0.8)
		else:
			lock_progress = max(0.0, lock_progress - dt * 1.4)
		if lock_progress >= 1.0:
			locked = true
			lock_loss_time = 0.0
			selected_enemy.notify_player_lock()
			set_event("LOCK " + selected_enemy.callsign, 1.2)
			play_sound("lock", -10.0)
	else:
		if distance > 7000.0 or angle > 22.0:
			lock_loss_time += dt
		else:
			lock_loss_time = max(0.0, lock_loss_time - dt * 2.0)
		if lock_loss_time > 1.0:
			locked = false
			lock_progress = 0.0
			set_event("LOCK LOST", 1.0)


func get_gun_assist_target():
	if not is_instance_valid(selected_enemy) or selected_enemy.destroyed:
		return null
	if float(player.settings.get("gun_assist_strength", 0.65)) <= 0.0:
		return null
	var distance = selected_enemy.model.position.distance_to(player.position)
	var solution = gun_intercept_solution(selected_enemy)
	if not solution.valid:
		return null
	var direction = (solution.point - player.position).normalized()
	var angle = rad_to_deg(acos(clamp(player.forward.dot(direction), -1.0, 1.0)))
	if distance <= GUN_ASSIST_CAPTURE_RANGE and angle <= GUN_ASSIST_CAPTURE_ANGLE:
		return selected_enemy
	return null


func gun_aim_point(enemy) -> Vector3:
	return gun_intercept_solution(enemy).point


func gun_intercept_solution(enemy) -> Dictionary:
	# Gun velocity is in world space and does not inherit the player's speed.
	# Solve |relative_position + target_velocity * t| = gun_speed * t.
	var origin = player.position + player.forward * 3.2 - player.up * 0.35
	var relative = enemy.model.position - origin
	var velocity = enemy.model.forward * enemy.model.speed
	var a = velocity.length_squared() - CombatProjectile.GUN_SPEED * CombatProjectile.GUN_SPEED
	var b = 2.0 * relative.dot(velocity)
	var c = relative.length_squared()
	var intercept_time = -1.0
	if abs(a) < 0.0001:
		if abs(b) > 0.0001:
			intercept_time = -c / b
	else:
		var discriminant = b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var first = (-b - sqrt(discriminant)) / (2.0 * a)
			var second = (-b + sqrt(discriminant)) / (2.0 * a)
			if first > 0.0:
				intercept_time = first
			if second > 0.0 and (intercept_time < 0.0 or second < intercept_time):
				intercept_time = second
	var valid = intercept_time > 0.0 and intercept_time <= CombatProjectile.GUN_LIFETIME
	var display_time = clamp(intercept_time, 0.0, CombatProjectile.GUN_LIFETIME)
	return {"point": enemy.model.position + velocity * display_time, "time": intercept_time, "valid": valid}


func reset_gun_assist(cooldown: float = 0.0) -> void:
	gun_assist_target = null
	gun_assist_state = "idle"
	gun_assist_remaining = 0.0
	gun_assist_cooldown = cooldown
	gun_assist_manual_time = 0.0
	gun_assist_manual_direction = Vector3.ZERO
	gun_assist_manual_override = false
	gun_assist_quiet_time = 0.0
	gun_assist_pull_time = 0.0


func gun_assist_active() -> bool:
	return gun_assist_state != "idle" and is_instance_valid(gun_assist_target) and gun_assist_target == selected_enemy and not gun_assist_target.destroyed and float(player.settings.get("gun_assist_strength", 0.65)) > 0.0


func gun_assist_target_valid() -> bool:
	if not gun_assist_active():
		return false
	if gun_assist_target.model.position.distance_to(player.position) > GUN_ASSIST_CAPTURE_RANGE + 100.0:
		return false
	var solution = gun_intercept_solution(gun_assist_target)
	if not solution.valid:
		return false
	var direction = (solution.point - player.position).normalized()
	return rad_to_deg(acos(clamp(player.forward.dot(direction), -1.0, 1.0))) <= GUN_ASSIST_HOLD_ANGLE


func apply_nose_assist(dt: float, controls: Dictionary) -> Dictionary:
	if dt <= 0.0 or hold or player.crashed:
		return controls
	gun_assist_cooldown = max(0.0, gun_assist_cooldown - dt)
	var manual = Vector3(float(controls.get("pitch", 0.0)), float(controls.get("roll", 0.0)), float(controls.get("yaw", 0.0)))
	var magnitude = max(abs(manual.x), max(abs(manual.y), abs(manual.z)))
	if gun_assist_manual_override:
		gun_assist_quiet_time = gun_assist_quiet_time + dt if magnitude < 0.25 else 0.0
		if gun_assist_quiet_time < 0.2:
			return controls
		gun_assist_manual_override = false
		gun_assist_quiet_time = 0.0
	if gun_assist_state != "idle" and not gun_assist_target_valid():
		reset_gun_assist(0.2)
	if gun_assist_state == "idle":
		if gun_assist_cooldown > 0.0:
			return controls
		var candidate = get_gun_assist_target()
		if candidate == null:
			return controls
		gun_assist_target = candidate
		gun_assist_state = "pull"
		gun_assist_pull_time = 0.0
		player.inputs = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0}
	# Deliberate sustained input breaks the hold. Taps, a small stick deflection
	# and alternating directions cannot build up time towards a breakout.
	if magnitude >= 0.85:
		var direction = manual.normalized()
		if gun_assist_manual_direction.dot(direction) < 0.90:
			gun_assist_manual_time = 0.0
		gun_assist_manual_direction = direction
		gun_assist_manual_time += dt
	else:
		gun_assist_manual_time = 0.0
		gun_assist_manual_direction = Vector3.ZERO
	if gun_assist_manual_time >= GUN_ASSIST_BREAK_SECONDS:
		reset_gun_assist(0.8)
		gun_assist_manual_override = true
		return controls
	var assisted = controls.duplicate()
	assisted.pitch = 0.0
	assisted.roll = 0.0
	assisted.yaw = 0.0
	return assisted


func apply_gun_assist(dt: float) -> void:
	if dt <= 0.0 or hold or not gun_assist_active():
		return
	if not gun_assist_target_valid():
		reset_gun_assist(0.2)
		return
	var strength = clamp(float(player.settings.get("gun_assist_strength", 0.65)), 0.0, 1.0)
	var direction = (gun_aim_point(gun_assist_target) - player.position).normalized()
	var angle = acos(clamp(player.forward.dot(direction), -1.0, 1.0))
	var max_rate = deg_to_rad(45.0 + 75.0 * strength)
	var weight = min(1.0 - exp(-(8.0 + 14.0 * strength) * dt), max_rate * dt / max(angle, 0.00001))
	if rad_to_deg(angle) <= GUN_ASSIST_SNAP_ANGLE:
		weight = 1.0
	var correction = Quaternion(player.forward, direction)
	player.orientation = (Quaternion.IDENTITY.slerp(correction, weight) * player.orientation).normalized()
	player.update_attitude()
	var remaining_angle = rad_to_deg(acos(clamp(player.forward.dot(direction), -1.0, 1.0)))
	# Finish the correction on the entry frame too, before the HUD snaps its reticle.
	if remaining_angle <= GUN_ASSIST_SNAP_ANGLE and weight < 1.0:
		player.orientation = (Quaternion(player.forward, direction) * player.orientation).normalized()
		player.update_attitude()
	if gun_assist_state == "pull":
		gun_assist_pull_time += dt
		if remaining_angle <= GUN_ASSIST_SNAP_ANGLE:
			gun_assist_state = "hold"
			gun_assist_remaining = GUN_ASSIST_SECONDS
		elif gun_assist_pull_time > 1.0:
			reset_gun_assist(0.3)
	elif gun_assist_state == "hold":
		gun_assist_remaining = max(0.0, gun_assist_remaining - dt)
		if gun_assist_remaining <= 0.0:
			reset_gun_assist(GUN_ASSIST_COOLDOWN_SECONDS)


func fire_gun() -> void:
	if hold or gun_cooldown > 0.0 or gun_ammo <= 0:
		return
	gun_cooldown = 0.085
	gun_ammo -= 1
	shots += 1
	var side = -1.0 if shots % 2 == 0 else 1.0
	var origin = player.position + player.forward * 3.2 + player.right * side * 1.3 + player.up * -0.35
	var spread = player.right * sin(float(shots) * 7.13) * 0.0015 + player.up * cos(float(shots) * 5.17) * 0.0012
	spawn_projectile("gun", "player", origin, (player.forward + spread).normalized() * CombatProjectile.GUN_SPEED, null)
	play_sound("gun", -13.0)


func fire_missile() -> void:
	if hold or missile_cooldown > 0.0 or missile_ammo <= 0:
		return
	if not locked or selected_enemy == null or selected_enemy.destroyed:
		set_warning("NO LOCK", 1.2)
		return
	missile_cooldown = 0.9
	missile_ammo -= 1
	shots += 1
	var origin = player.position + player.forward * 2.2 + player.up * -0.8
	var velocity = player.forward * max(150.0, player.speed + 55.0)
	spawn_projectile("missile", "player", origin, velocity, selected_enemy)
	selected_enemy.notify_missile()
	player_missile_target = selected_enemy
	set_event("FOX TWO", 1.5)
	play_sound("missile", -8.0)


func spawn_projectile(kind: String, team: String, origin: Vector3, velocity: Vector3, target):
	var projectile = CombatProjectile.new()
	projectile.kind = kind
	projectile.team = team
	projectile.position = origin
	projectile.velocity = velocity
	projectile.target = target
	if kind == "missile":
		spawn_effect(origin, 0.42, 0.24)
	add_child(projectile)
	projectiles.append(projectile)
	return projectile


func target_angle(enemy) -> float:
	return enemy.target_angle_to_player()


func enemy_fire_gun(enemy) -> void:
	if enemy.destroyed or enemy.gun_cooldown > 0.0:
		return
	var distance = enemy.model.position.distance_to(player.position)
	if distance > 1450.0 or enemy.target_angle_to_player() > 18.0:
		return
	enemy.record_gun_fire()
	var aim = player.position + player.forward * 80.0
	var jitter = player.right * sin(enemy.state_time * 8.0 + enemy.role) * 14.0 + player.up * cos(enemy.state_time * 6.0) * 8.0
	var direction = (aim + jitter - enemy.model.position).normalized()
	spawn_projectile("gun", "enemy", enemy.model.position + enemy.model.forward * 3.0, direction * 640.0, null)


func enemy_fire_missile(enemy) -> void:
	if enemy.destroyed or enemy.missile_cooldown > 0.0 or threat:
		return
	var distance = enemy.model.position.distance_to(player.position)
	if distance < 1100.0 or distance > 5000.0 or enemy.target_angle_to_player() > 28.0:
		return
	enemy.record_missile_fire()
	spawn_projectile("missile", "enemy", enemy.model.position + enemy.model.forward * 2.0, enemy.model.forward * 155.0, player)
	set_warning("MISSILE INBOUND", 2.5)
	play_sound("missile", -13.0)


func handle_projectile_result(projectile, result: Dictionary) -> void:
	if not is_instance_valid(projectile):
		return
	projectiles.erase(projectile)
	if result.has("hit"):
		hits += 1
		hit_timer = 0.16
		var enemy = result.enemy
		if enemy.destroyed:
			register_kill(enemy)
		else:
			spawn_effect(result.position, 0.28, 0.22)
			set_event("HIT", 0.35)
	elif result.has("near_player"):
		spawn_effect(result.position, 0.55, 0.45)
	elif result.has("expired") and result.kind == "missile":
		spawn_effect(result.position, 0.35, 0.35)
	projectile.queue_free()


func register_kill(enemy) -> void:
	if enemy.death_reported:
		return
	enemy.death_reported = true
	kills += 1
	kill_timer = 1.4
	spawn_effect(enemy.model.position, 2.2, 1.5)
	set_event(enemy.callsign + (" DOWN · T NEXT TARGET" if not live_enemies().is_empty() else " DOWN"), 2.4)
	play_sound("explosion", -6.0)
	if selected_enemy == enemy:
		reset_gun_assist(max(gun_assist_cooldown, 0.2))
		selected_enemy = null
		locked = false
		lock_progress = 0.0


func spawn_effect(at_position: Vector3, strength: float, lifetime: float) -> void:
	var effect = CombatEffect.new()
	effect.position = at_position
	effect.strength = strength
	effect.lifetime = lifetime
	add_child(effect)


func set_event(text: String, duration: float) -> void:
	comms_text = text
	comms_timer = duration


func set_warning(text: String, duration: float) -> void:
	warning_text = text
	warning_timer = duration
	comms_text = text
	comms_timer = duration


func play_sound(key: String, volume_db: float) -> void:
	if DisplayServer.get_name() == "headless" or not sounds.has(key):
		return
	if key == "gun":
		if not is_instance_valid(gun_audio):
			gun_audio = GunFireAudio.new()
			gun_audio.configure(sounds[key])
			add_child(gun_audio)
		gun_audio.pulse(volume_db)
		return
	var player_audio = AudioStreamPlayer.new()
	player_audio.stream = sounds[key]
	player_audio.volume_db = volume_db
	add_child(player_audio)
	player_audio.finished.connect(player_audio.queue_free)
	player_audio.play()


func active_player_missiles() -> int:
	var count = 0
	for projectile in projectiles:
		if is_instance_valid(projectile) and projectile.active and projectile.team == "player" and projectile.kind == "missile":
			count += 1
	return count


func snapshot() -> Dictionary:
	var contacts = []
	var viewport_size = camera.get_viewport().get_visible_rect().size
	for enemy in enemies:
		if enemy.destroyed:
			continue
		var world_position = enemy.model.position
		var behind = camera.is_position_behind(world_position)
		var screen = camera.unproject_position(world_position)
		var on_screen = not behind and screen.x >= 0.0 and screen.y >= 0.0 and screen.x <= viewport_size.x and screen.y <= viewport_size.y
		var relative = player.orientation.inverse() * (world_position - player.position)
		var radar = Vector2(relative.dot(player.right), -relative.dot(player.forward)) * (58.0 / 5000.0)
		if radar.length() > 58.0:
			radar = radar.normalized() * 58.0
		var camera_point = camera.global_transform.affine_inverse() * world_position
		var indicator_direction = Vector2(camera_point.x, -camera_point.y)
		if indicator_direction.length_squared() < 0.0001:
			indicator_direction = Vector2(0.0, 1.0 if behind else -1.0)
		else:
			indicator_direction = indicator_direction.normalized()
		contacts.append({
			"id": enemy.callsign,
			"selected": enemy == selected_enemy,
			"screen": screen,
			"on_screen": on_screen,
			"behind": behind,
			"indicator_direction": indicator_direction,
			"attacking": enemy.get("state") == "attack",
			"radar": radar,
			"distance": world_position.distance_to(player.position),
		})
	var lead_screen = Vector2.ZERO
	var lead_visible = false
	var gun_solution_valid = false
	var reticle_snapped = false
	var aim_distance = 1000.0
	if selected_enemy != null and not selected_enemy.destroyed:
		var solution = gun_intercept_solution(selected_enemy)
		var lead_position = solution.point
		gun_solution_valid = solution.valid
		lead_visible = not camera.is_position_behind(lead_position)
		lead_screen = camera.unproject_position(lead_position)
		aim_distance = lead_position.distance_to(player.position)
		var aim_direction = (lead_position - player.position).normalized()
		var aim_error = rad_to_deg(acos(clamp(player.forward.dot(aim_direction), -1.0, 1.0)))
		reticle_snapped = gun_assist_active() and gun_assist_state == "hold" and aim_error <= GUN_ASSIST_SNAP_ANGLE and lead_visible
	var reticle_world = player.position + player.forward * aim_distance
	var gun_reticle_screen = camera.unproject_position(reticle_world)
	var gun_reticle_visible = not camera.is_position_behind(reticle_world)
	if reticle_snapped:
		gun_reticle_screen = lead_screen
	return {
		"contacts": contacts,
		"target_id": selected_enemy.callsign if selected_enemy != null else "---",
		"lock_progress": lock_progress,
		"locked": locked,
		"gun_assist": gun_assist_active(),
		"gun_assist_state": gun_assist_state,
		"gun_assist_remaining": gun_assist_remaining,
		"gun_reticle_screen": gun_reticle_screen,
		"gun_reticle_visible": gun_reticle_visible,
		"reticle_snapped": reticle_snapped,
		"gun_solution_valid": gun_solution_valid,
		"lead_screen": lead_screen,
		"lead_visible": lead_visible,
		"gun_ammo": gun_ammo,
		"missile_ammo": missile_ammo,
		"active_missiles": active_player_missiles(),
		"kills": kills,
		"shots": shots,
		"hits": hits,
		"hit_marker": hit_timer > 0.0,
		"kill_marker": kill_timer > 0.0,
		"comms_name": "RANGE CONTROL",
		"comms_text": comms_text if comms_timer > 0.0 else "TRAINING AIRSPACE",
		"warning": warning_text if warning_timer > 0.0 else ("BANDIT DOWN" if kill_timer > 0.0 else ""),
		"threat": threat,
	}
