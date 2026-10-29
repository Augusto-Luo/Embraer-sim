extends Node3D

const GroundTarget = preload("res://scripts/ground_strike_target.gd")
const GroundProjectile = preload("res://scripts/ground_strike_projectile.gd")
const CombatEffect = preload("res://scripts/combat_effect.gd")
const GunFireAudio = preload("res://scripts/gun_fire_audio.gd")
const TARGET_HP = 120.0
const TARGET_COUNT = 8
const TOTAL_HP = TARGET_HP * TARGET_COUNT
const GUN_DAMAGE = 10.0
const ROCKET_DAMAGE = 100.0
const GUN_AMMO = 600
const ROCKET_AMMO = 6
const LOCK_RANGE = 2200.0
const LOCK_ANGLE = 16.0
const LOCK_SECONDS = 0.8

var player
var camera
var island
var hold = false
var intro_pending = false
var targets = []
var enemies = []
var sites = []
var projectiles = []
var selected_enemy
var player_missile_target
var gun_ammo = GUN_AMMO
var missile_ammo = ROCKET_AMMO
var gun_cooldown = 0.0
var missile_cooldown = 0.0
var gun_audio
var lock_progress = 0.0
var lock_loss_time = 0.0
var locked = false
var kills = 0
var shots = 0
var hits = 0
var hit_timer = 0.0
var kill_timer = 0.0
var comms_text = "DESTROY BOTH SITES"
var comms_timer = 5.0
var warning_text = ""
var warning_timer = 0.0
var completed = false
var gun_damage_total = 0.0
var rocket_damage_total = 0.0
var total_damage = 0.0
var sounds = {}
var effects = []
var sites_root: Node3D
var platform_bounds = AABB(Vector3(815, 0, 50), Vector3(120, 1.6, 120))
var map_scale = 1.0


func _ready() -> void:
	name = "GroundStrikeDirector"
	if DisplayServer.get_name() != "headless":
		for sound_name in ["gun", "missile", "lock", "explosion"]:
			sounds[sound_name] = load("res://assets/audio/" + sound_name + ".mp3")
	restart()


func restart() -> void:
	if is_instance_valid(gun_audio):
		gun_audio.stop()
	gun_audio = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	targets.clear()
	enemies.clear()
	projectiles.clear()
	effects.clear()
	map_scale = float(island.MAP_SCALE) if island != null else 1.0
	platform_bounds = AABB(scale_site_position(Vector3(815, 0, 50)), Vector3(120.0 * map_scale, 1.6, 120.0 * map_scale))
	sites = [
		{"id": "avenue", "name": "AVENUE", "center": scale_site_position(Vector3(78, 8.45, 50)), "radius": 140.0 * map_scale},
		{"id": "offshore", "name": "OFFSHORE", "center": scale_site_position(Vector3(875, 1.75, 110)), "radius": 90.0 * map_scale},
	]
	selected_enemy = null
	player_missile_target = null
	gun_ammo = GUN_AMMO
	missile_ammo = ROCKET_AMMO
	gun_cooldown = 0.0
	missile_cooldown = 0.0
	lock_progress = 0.0
	lock_loss_time = 0.0
	locked = false
	kills = 0
	shots = 0
	hits = 0
	hit_timer = 0.0
	kill_timer = 0.0
	completed = false
	total_damage = 0.0
	gun_damage_total = 0.0
	rocket_damage_total = 0.0
	comms_text = "DESTROY BOTH SITES"
	comms_timer = 5.0
	warning_text = ""
	warning_timer = 0.0
	build_sites()
	var positions = [Vector3(22, 8.45, -25), Vector3(59, 8.45, 25), Vector3(96, 8.45, 75), Vector3(133, 8.45, 125),
		Vector3(843, 1.65, 78), Vector3(907, 1.65, 78), Vector3(843, 1.65, 142), Vector3(907, 1.65, 142)]
	for index in range(TARGET_COUNT):
		var target = GroundTarget.new()
		target.name = "GroundTarget%02d" % (index + 1)
		target.callsign = ("AV-" if index < 4 else "SEA-") + str(index % 4 + 1)
		target.site_id = "avenue" if index < 4 else "offshore"
		target.variant = index % 4
		target.position = scale_site_position(positions[index])
		target.damaged.connect(record_damage)
		target.eliminated.connect(register_kill)
		add_child(target)
		targets.append(target)
	enemies = targets
	selected_enemy = targets[0]
	assert(TOTAL_HP > ROCKET_AMMO * ROCKET_DAMAGE)


func scale_site_position(source_position: Vector3) -> Vector3:
	# Move the layout with the larger streets/coast while preserving target
	# bodies, deck heights and forgiving weapon hit volumes in metres.
	return Vector3(source_position.x * map_scale, source_position.y, source_position.z * map_scale)


func build_sites() -> void:
	sites_root = Node3D.new()
	sites_root.name = "GroundTargetSites"
	add_child(sites_root)
	var platform = MeshInstance3D.new()
	platform.name = "OffshoreTargetPlatform"
	var shape = BoxMesh.new()
	shape.size = platform_bounds.size
	platform.mesh = shape
	platform.position = platform_bounds.get_center()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("#5b6664")
	material.roughness = 0.95
	platform.material_override = material
	sites_root.add_child(platform)
	for site in sites:
		var circle = MeshInstance3D.new()
		circle.name = String(site.id).capitalize() + "TargetRing"
		var mesh = ImmediateMesh.new()
		var ring_material = StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.albedo_color = Color("#d8ad58")
		ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, ring_material)
		for index in range(128):
			var a = TAU * float(index) / 128.0
			var b = TAU * float(index + 1) / 128.0
			var inner = float(site.radius) - 1.4
			var outer = float(site.radius) + 1.4
			var ia = Vector3(cos(a) * inner, 0, sin(a) * inner)
			var ib = Vector3(cos(b) * inner, 0, sin(b) * inner)
			var oa = Vector3(cos(a) * outer, 0, sin(a) * outer)
			var ob = Vector3(cos(b) * outer, 0, sin(b) * outer)
			for vertex in [ia, oa, ib, ib, oa, ob]:
				mesh.surface_add_vertex(vertex)
		mesh.surface_end()
		circle.mesh = mesh
		circle.position = site.center
		circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sites_root.add_child(circle)


func _process(_dt: float) -> void:
	var paused = is_held()
	for target in targets:
		target.set_simulation_paused(paused)
	for projectile in projectiles:
		for particle in [projectile.smoke, projectile.launch_puff]:
			if particle != null:
				particle.speed_scale = 0.0 if paused else 1.0
	for effect in effects.duplicate():
		if not is_instance_valid(effect):
			effects.erase(effect)
			continue
		effect.set_process(not paused)
		if effect.smoke != null:
			effect.smoke.speed_scale = 0.0 if paused else 1.0


func _physics_process(dt: float) -> void:
	if is_held():
		return
	gun_cooldown = maxf(0, gun_cooldown - dt)
	missile_cooldown = maxf(0, missile_cooldown - dt)
	comms_timer = maxf(0, comms_timer - dt)
	warning_timer = maxf(0, warning_timer - dt)
	hit_timer = maxf(0, hit_timer - dt)
	kill_timer = maxf(0, kill_timer - dt)
	for projectile in projectiles.duplicate():
		if not is_instance_valid(projectile) or not projectile.active:
			continue
		var result = projectile.step(dt, targets, player)
		if not result.is_empty():
			handle_projectile_result(projectile, result)
	update_targeting(dt)
	if Input.is_action_pressed("gun_fire"):
		fire_gun()
	player_missile_target = null
	for projectile in projectiles:
		if projectile.active and projectile.kind == "missile" and is_instance_valid(projectile.target) and not projectile.target.destroyed:
			player_missile_target = projectile.target
			break


func live_enemies() -> Array:
	return targets.filter(func(target): return not target.destroyed)


func cycle_target() -> void:
	if is_held():
		return
	var live = live_enemies()
	if live.is_empty():
		selected_enemy = null
		return
	var current = live.find(selected_enemy)
	selected_enemy = live[(current + 1) % live.size()]
	locked = false
	lock_progress = 0.0
	lock_loss_time = 0.0
	set_event("TARGET " + selected_enemy.callsign, 1.4)


func select_next_target() -> void:
	cycle_target()


func update_targeting(dt: float) -> void:
	if not is_instance_valid(selected_enemy) or selected_enemy.destroyed:
		selected_enemy = null
		locked = false
		lock_progress = 0.0
		return
	selected_enemy.sync_model()
	var direction = selected_enemy.aim_position() - player.position
	var distance = direction.length()
	var angle = rad_to_deg(acos(clampf(player.forward.dot(direction.normalized()), -1, 1)))
	var visible = world_segment_block(player.position, selected_enemy.aim_position()).is_empty()
	if not locked:
		if distance <= LOCK_RANGE and angle <= LOCK_ANGLE and visible:
			lock_progress = minf(1, lock_progress + dt / LOCK_SECONDS)
		else:
			lock_progress = maxf(0, lock_progress - dt * 1.4)
		if lock_progress >= 1.0:
			locked = true
			lock_loss_time = 0.0
			play_sound("lock", -10)
	else:
		lock_loss_time = lock_loss_time + dt if distance > LOCK_RANGE + 400 or angle > 24 or not visible else 0.0
		if lock_loss_time > 0.6:
			locked = false
			lock_progress = 0.0
			lock_loss_time = 0.0


func fire_gun() -> void:
	if is_held() or completed or gun_cooldown > 0 or gun_ammo <= 0:
		return
	gun_cooldown = 0.085
	gun_ammo -= 1
	shots += 1
	var side = -1.0 if shots % 2 == 0 else 1.0
	var origin = player.position + player.forward * 3.2 + player.right * side * 1.3 - player.up * 0.35
	var spread = player.right * sin(float(shots) * 7.13) * 0.0015 + player.up * cos(float(shots) * 5.17) * 0.0012
	spawn_projectile("gun", "player", origin, (player.forward + spread).normalized() * 700.0, null)
	play_sound("gun", -13)
	if gun_ammo == 0:
		set_warning("GUN EMPTY · R RESTART", 4)


func fire_missile() -> void:
	if is_held() or completed or missile_cooldown > 0 or missile_ammo <= 0:
		return
	if not locked or not is_instance_valid(selected_enemy) or selected_enemy.destroyed:
		set_warning("NO LOCK", 1.2)
		return
	missile_cooldown = 0.9
	missile_ammo -= 1
	shots += 1
	var origin = player.position + player.forward * 2.2 - player.up * 0.8
	spawn_projectile("missile", "player", origin, player.forward * maxf(150, player.speed + 55), selected_enemy)
	set_event("ROCKET AWAY" if missile_ammo > 0 else "ROCKETS EMPTY · USE GUNS", 3)
	play_sound("missile", -8)


func spawn_projectile(kind: String, team: String, origin: Vector3, velocity: Vector3, target):
	var projectile = GroundProjectile.new()
	projectile.director = self
	projectile.kind = kind
	projectile.team = team
	projectile.position = origin
	projectile.velocity = velocity
	projectile.target = target
	add_child(projectile)
	projectiles.append(projectile)
	return projectile


func segment_box_fraction(start: Vector3, finish: Vector3, bounds: AABB) -> float:
	var delta = finish - start
	var near = 0.0
	var far = 1.0
	for axis in range(3):
		if absf(delta[axis]) < 0.000001:
			if start[axis] < bounds.position[axis] or start[axis] > bounds.end[axis]:
				return INF
		else:
			var a = (bounds.position[axis] - start[axis]) / delta[axis]
			var b = (bounds.end[axis] - start[axis]) / delta[axis]
			near = maxf(near, minf(a, b))
			far = minf(far, maxf(a, b))
			if near > far:
				return INF
	return near


func world_segment_block(start: Vector3, finish: Vector3) -> Dictionary:
	var best = segment_box_fraction(start, finish, platform_bounds)
	if island != null:
		for bounds in island.collision_boxes:
			best = minf(best, segment_box_fraction(start, finish, bounds))
		var steps = maxi(1, ceili(start.distance_to(finish) / 6.0))
		for index in range(steps + 1):
			var fraction = float(index) / float(steps)
			if fraction >= best:
				break
			var point = start.lerp(finish, fraction)
			var surface = float(island.ground_height(point.x, point.z))
			if island.is_lake(Vector2(point.x, point.z)):
				surface = float(island.lake_water_height())
			if point.y <= surface + 0.03:
				best = fraction
				break
	if best <= 1.0:
		return {"blocked": true, "fraction": best, "position": start.lerp(finish, best)}
	return {}


func trace_segment(start: Vector3, finish: Vector3, weapon: String = "gun") -> Dictionary:
	var best = world_segment_block(start, finish)
	var fraction = float(best.get("fraction", INF))
	for target in targets:
		if target.destroyed:
			continue
		var hit_fraction = segment_box_fraction(start, finish, target.get_hit_bounds(weapon))
		if hit_fraction < fraction:
			fraction = hit_fraction
			best = {"hit": true, "target": target, "enemy": target, "fraction": fraction, "position": start.lerp(finish, fraction)}
	return best


func handle_projectile_result(projectile, result: Dictionary) -> void:
	projectiles.erase(projectile)
	if result.get("hit", false):
		hits += 1
		hit_timer = 0.16
		if not result.target.destroyed:
			spawn_effect(result.position, 0.35 if result.kind == "gun" else 1.2, 0.4)
			if missile_ammo > 0:
				set_event("HIT", 0.4)
	elif result.kind == "missile":
		spawn_effect(result.position, 0.7, 0.5)
	if is_instance_valid(projectile):
		projectile.queue_free()


func record_damage(amount: float, weapon: String) -> void:
	total_damage += amount
	if weapon in ["missile", "rocket"]:
		rocket_damage_total += amount
	else:
		gun_damage_total += amount


func register_kill(target) -> void:
	if target.death_reported:
		return
	target.death_reported = true
	kills += 1
	kill_timer = 1.3
	spawn_effect(target.aim_position(), 2.0, 1.2)
	play_sound("explosion", -7)
	if selected_enemy == target:
		selected_enemy = null
		locked = false
		lock_progress = 0.0
	completed = live_enemies().is_empty()
	set_event("ALL TARGETS DESTROYED" if completed else target.callsign + " DESTROYED · T NEXT", 5 if completed else 2)


func spawn_effect(at_position: Vector3, strength: float, lifetime: float) -> void:
	# A target can die once; short hit flashes are bounded even during bursts.
	if effects.size() >= 14:
		return
	var effect = CombatEffect.new()
	effect.position = at_position
	effect.strength = strength
	effect.lifetime = lifetime
	add_child(effect)
	effects.append(effect)


func set_event(text: String, duration: float) -> void:
	comms_text = text
	comms_timer = duration


func set_warning(text: String, duration: float) -> void:
	warning_text = text
	warning_timer = duration
	set_event(text, duration)


func play_sound(key: String, volume: float) -> void:
	if not sounds.has(key):
		return
	if key == "gun":
		if not is_instance_valid(gun_audio):
			gun_audio = GunFireAudio.new()
			gun_audio.configure(sounds[key])
			add_child(gun_audio)
		gun_audio.pulse(volume)
		return
	var audio = AudioStreamPlayer.new()
	audio.stream = sounds[key]
	audio.volume_db = volume
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()


func apply_nose_assist(_dt: float, controls: Dictionary) -> Dictionary:
	return controls


func is_held() -> bool:
	if hold:
		return true
	var controller = get_parent()
	if controller != null and controller.is_in_group("flight_controllers"):
		for flag in ["paused", "frozen", "settings_open", "observing", "observation_frozen", "intro_active"]:
			if bool(controller.get(flag)):
				return true
	return false


func update_gun_assist(_dt: float, _controls: Dictionary = {}) -> void:
	pass


func apply_gun_assist(_dt: float) -> void:
	pass


func reset_gun_assist(_cooldown: float = 0.0) -> void:
	pass


func gun_assist_active() -> bool:
	return false


func active_player_missiles() -> int:
	return projectiles.filter(func(projectile): return is_instance_valid(projectile) and projectile.active and projectile.kind == "missile").size()


func snapshot() -> Dictionary:
	var contacts = []
	var viewport_size = camera.get_viewport().get_visible_rect().size if camera != null else Vector2(1440, 810)
	for target in targets:
		if target.destroyed:
			continue
		target.sync_model()
		var world_position = target.aim_position()
		var screen = camera.unproject_position(world_position) if camera != null else Vector2.ZERO
		var behind = camera.is_position_behind(world_position) if camera != null else false
		var relative = world_position - player.position
		var radar = Vector2(relative.dot(player.right), -relative.dot(player.forward)) * (58.0 / 5000.0)
		if radar.length() > 58:
			radar = radar.normalized() * 58
		var camera_point = camera.global_transform.affine_inverse() * world_position if camera != null else relative
		var indicator = Vector2(camera_point.x, -camera_point.y)
		indicator = indicator.normalized() if indicator.length_squared() > 0.0001 else Vector2.DOWN
		contacts.append({"id": target.callsign, "selected": target == selected_enemy, "screen": screen,
			"on_screen": not behind and Rect2(Vector2.ZERO, viewport_size).has_point(screen), "behind": behind,
			"indicator_direction": indicator, "attacking": false, "radar": radar, "distance": relative.length(),
			"hp": target.hp, "max_hp": target.max_hp, "site": target.site_id})
	var site_states = []
	for site in sites:
		var remaining = 0.0
		var destroyed = 0
		for target in targets:
			if target.site_id == site.id:
				remaining += target.hp
				destroyed += int(target.destroyed)
		var state = site.duplicate()
		state.total = 4
		state.destroyed = destroyed
		state.destruction = 1.0 - remaining / (TARGET_HP * 4)
		site_states.append(state)
	var reticle_world = player.position + player.forward * 1000
	return {"ground_attack": true, "contacts": contacts, "sites": site_states, "completed": completed,
		"total_targets": TARGET_COUNT, "destroyed_targets": kills, "destruction": clampf(total_damage / TOTAL_HP, 0, 1),
		"total_hp": TOTAL_HP, "remaining_hp": TOTAL_HP - total_damage,
		"gun_damage_total": gun_damage_total, "rocket_damage_total": rocket_damage_total,
		"target_id": selected_enemy.callsign if is_instance_valid(selected_enemy) else "---",
		"target_hp": selected_enemy.hp if is_instance_valid(selected_enemy) else 0,
		"target_max_hp": TARGET_HP, "lock_progress": lock_progress, "locked": locked,
		"gun_assist": false, "gun_assist_state": "idle", "gun_assist_remaining": 0.0, "reticle_snapped": false,
		"gun_reticle_screen": camera.unproject_position(reticle_world) if camera != null else viewport_size * 0.5,
		"gun_reticle_visible": not camera.is_position_behind(reticle_world) if camera != null else true,
		"gun_solution_valid": false, "lead_visible": false, "lead_screen": Vector2.ZERO,
		"gun_ammo": gun_ammo, "missile_ammo": missile_ammo, "active_missiles": active_player_missiles(),
		"kills": kills, "shots": shots, "hits": hits, "hit_marker": hit_timer > 0, "kill_marker": kill_timer > 0,
		"comms_name": "STRIKE CONTROL", "comms_text": comms_text if comms_timer > 0 else "",
		"warning": warning_text if warning_timer > 0 else "", "threat": false}
