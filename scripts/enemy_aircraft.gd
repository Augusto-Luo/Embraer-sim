extends Node3D

const FlightModel = preload("res://scripts/flight_model.gd")
const FlightSettings = preload("res://scripts/flight_settings.gd")
const EnemyScene = preload("res://assets/emb314-enemy-lod2.glb")
const MIN_ALTITUDE = 700.0
const MAX_ALTITUDE = 2600.0
const MAX_RANGE = 5200.0
const RECOVERY_RANGE = 4500.0

var model
var visual
var prop
var player
var callsign = "BANDIT"
var role = 0
var state = "patrol"
var state_time = 0.0
var hold = false
var destroyed = false
var death_reported = false
var gun_hits = 0
var gun_cooldown = 0.0
var missile_cooldown = 0.0
var evade_sign = 1.0
var cruise_direction = Vector3(0, 0, 1)
var cruise_center = Vector3.ZERO
var cruise_radial = Vector3.ZERO
var cruise_altitude = 1500.0
var cruise_radius = 2400.0
var cruise_arc_sign = 1.0
var cruise_arc = false
var cruise_duration = 8.0
var cruise_cycle = 0
var death_time = 0.0
var wreck_velocity = Vector3.ZERO
var previous_position = Vector3.ZERO
var previous_orientation = Quaternion()
var wreck_smoke


func _ready() -> void:
	model = FlightModel.new({
		"position": position,
		"orientation": quaternion,
		"speed": 76.0 + role * 4.0,
		"invincible": true,
		"settings": FlightSettings.DEFAULTS.duplicate(),
	})
	previous_position = model.position
	previous_orientation = model.orientation
	missile_cooldown = 4.0 + role * 2.0
	evade_sign = -1.0 if role == 1 else 1.0
	visual = EnemyScene.instantiate()
	add_child(visual)
	apply_placeholder_materials(visual)
	prop = find_part(visual, "PROP")


func apply_placeholder_materials(node: Node) -> void:
	if node is MeshInstance3D:
		if String(node.name).to_upper().contains("DECAL"):
			node.visible = false
		else:
			var material = StandardMaterial3D.new()
			if String(node.name).to_upper().contains("CANOPY"):
				material.albedo_color = Color(0.045, 0.065, 0.085, 0.92)
				material.metallic = 0.25
				material.roughness = 0.22
			else:
				material.albedo_color = Color(0.58, 0.49, 0.35)
				material.metallic = 0.38
				material.roughness = 0.52
			node.material_override = material
	for child in node.get_children():
		apply_placeholder_materials(child)


func find_part(node: Node, needle: String) -> Node:
	if String(node.name).to_upper().contains(needle):
		return node
	for child in node.get_children():
		var found = find_part(child, needle)
		if found != null:
			return found
	return null


func sync_idle() -> void:
	if model != null:
		previous_position = model.position
		previous_orientation = model.orientation


func _process(dt: float) -> void:
	if model == null:
		return
	var fraction = 1.0 if hold else Engine.get_physics_interpolation_fraction()
	position = previous_position.lerp(model.position, fraction)
	quaternion = previous_orientation.slerp(model.orientation, fraction).normalized()
	if prop != null and not hold and not destroyed:
		prop.rotation.x += dt * 28.0


func set_state(next_state: String) -> void:
	if destroyed:
		return
	state = next_state
	state_time = 0.0
	if next_state == "evade":
		evade_sign = -1.0 if role == 1 else 1.0
	elif next_state == "cruise":
		setup_cruise()
	elif next_state == "extend":
		setup_extend()


func setup_cruise() -> void:
	cruise_cycle += 1
	cruise_arc = (cruise_cycle + role) % 2 == 0
	cruise_duration = 7.5 + float((cruise_cycle + role) % 3) * 1.5
	cruise_altitude = clamp(model.position.y, 950.0, 2150.0)
	cruise_direction = Vector3(model.forward.x, 0.0, model.forward.z)
	cruise_direction = cruise_direction.normalized() if cruise_direction.length_squared() > 0.01 else Vector3(0, 0, 1)
	cruise_arc_sign = -1.0 if (role + cruise_cycle) % 2 == 0 else 1.0
	cruise_radius = 2400.0 + role * 250.0
	var flat_right = Vector3(model.right.x, 0.0, model.right.z)
	flat_right = flat_right.normalized() if flat_right.length_squared() > 0.01 else Vector3(1, 0, 0)
	cruise_center = model.position + flat_right * cruise_arc_sign * cruise_radius
	cruise_center.y = cruise_altitude
	cruise_radial = model.position - cruise_center
	cruise_radial.y = 0.0


func setup_extend() -> void:
	cruise_arc = false
	cruise_duration = 4.0 + role * 0.4
	cruise_direction = Vector3(model.position.x - player.position.x, 0.0, model.position.z - player.position.z)
	if cruise_direction.length_squared() <= 0.01:
		cruise_direction = Vector3(model.forward.x, 0.0, model.forward.z)
	cruise_direction = cruise_direction.normalized() if cruise_direction.length_squared() > 0.01 else Vector3(0, 0, 1)
	cruise_altitude = clamp(model.position.y + 120.0, 950.0, 2200.0)


func notify_player_lock() -> void:
	if (role == 1 or role == 2) and state == "engage":
		set_state("evade")


func notify_missile() -> void:
	set_state("evade")


func step_ai(dt: float, director) -> void:
	if destroyed:
		step_wreck(dt)
		return
	previous_position = model.position
	previous_orientation = model.orientation
	state_time += dt
	gun_cooldown = max(0.0, gun_cooldown - dt)
	missile_cooldown = max(0.0, missile_cooldown - dt)
	var offset = model.position - player.position
	var distance = offset.length()
	var desired_point = model.position + model.forward * 500.0
	var outside = model.position.y < 750.0 or model.position.y > 2400.0 or Vector2(model.position.x, model.position.z).length() > RECOVERY_RANGE
	if outside:
		if state != "recover":
			set_state("recover")
		desired_point = Vector3(clamp(model.position.x * 0.25, -1500.0, 1500.0), 1500.0, clamp(model.position.z * 0.25, -1500.0, 1500.0))
		fly_toward(desired_point, dt)
		return

	if director.player_missile_target == self and state != "evade":
		set_state("evade")

	match state:
		"patrol":
			desired_point = model.position + model.forward * 500.0 + Vector3.UP * 80.0
			if state_time > 2.0:
				set_state("cruise")
		"engage":
			if distance < 800.0:
				set_state("extend")
			else:
				if role == 0:
					desired_point = player.position + player.forward * 900.0 + Vector3.UP * 100.0
				elif role == 1:
					desired_point = player.position + player.right * 1300.0 + player.forward * 500.0 + Vector3.UP * 220.0
				else:
					desired_point = player.position - player.right * 1400.0 + player.forward * 700.0 - Vector3.UP * 80.0
				if distance < 1700.0 and director.target_angle(self) < 35.0 and state_time > 0.8:
					set_state("attack")
				elif state_time > 4.5:
					set_state("cruise")
				elif distance > 4800.0:
					set_state("recover")
		"attack":
			if distance < 900.0 or state_time > 2.4:
				set_state("extend")
			else:
				desired_point = player.position + player.forward * 420.0
				director.enemy_fire_gun(self)
				if state_time > 1.0:
					director.enemy_fire_missile(self)
		"evade":
			var away = offset.normalized()
			desired_point = model.position + away * 700.0 + Vector3(evade_sign * 500.0, 260.0, 0.0)
			if state_time > 2.2:
				set_state("extend")
		"recover":
			desired_point = model.position + offset.normalized() * 650.0 + Vector3.UP * 350.0
			if state_time > 2.5:
				set_state("cruise")
		"cruise", "extend":
			var extending = state == "extend"
			if state_time > cruise_duration:
				if extending:
					set_state("cruise")
				else:
					set_state("engage")

	if state == "cruise" or state == "extend":
		fly_cruise(dt)
		return
	if model.position.y < 850.0:
		desired_point.y = 1100.0
	elif model.position.y > 2300.0:
		desired_point.y = 1800.0
	if Vector2(model.position.x, model.position.z).length() > 4800.0:
		desired_point = Vector3(0, 1500, 0)
	fly_toward(desired_point, dt)


func fly_cruise(dt: float) -> void:
	var desired_point = model.position + cruise_direction * 900.0
	if state != "extend" and cruise_arc:
		var angle = -cruise_arc_sign * (state_time * 82.0 / cruise_radius + 0.22)
		desired_point = cruise_center + Quaternion(Vector3.UP, angle) * cruise_radial
	desired_point.y = cruise_altitude
	fly_toward(desired_point, dt)


func fly_toward(target_point: Vector3, dt: float) -> void:
	var direction = (target_point - model.position).normalized()
	var local = model.orientation.inverse() * direction
	var turn = clamp(atan2(local.x, local.z) / 0.75, -1.0, 1.0)
	var pitch = clamp(asin(clamp(local.y, -1.0, 1.0)) * 1.9, -1.0, 1.0)
	var roll = -turn
	var yaw = -turn * 0.42
	if state == "evade":
		roll = evade_sign * 0.92
		yaw = evade_sign * 0.38
		pitch = clamp(pitch + sin(state_time * 4.0) * 0.30, -1.0, 1.0)
	if model.position.y < 850.0:
		pitch = max(pitch, 0.72)
	elif model.position.y > 2300.0:
		pitch = min(pitch, -0.38)
	model.step(dt, {
		"pitch": pitch,
		"roll": roll,
		"yaw": yaw,
		"throttleDelta": clamp((82.0 - model.speed) * 0.035, -1.0, 1.0),
	})
	enforce_safety_bounds()


func enforce_safety_bounds() -> void:
	if model.position.y < MIN_ALTITUDE:
		model.position.y = MIN_ALTITUDE
		model.vertical_speed = max(0.0, model.vertical_speed)
	elif model.position.y > MAX_ALTITUDE:
		model.position.y = MAX_ALTITUDE
		model.vertical_speed = min(0.0, model.vertical_speed)
	var horizontal = Vector2(model.position.x, model.position.z)
	if horizontal.length() > MAX_RANGE:
		var correction = MAX_RANGE / horizontal.length()
		model.position.x *= correction
		model.position.z *= correction


func target_angle_to_player() -> float:
	var direction = (player.position - model.position).normalized()
	return rad_to_deg(acos(clamp(model.forward.dot(direction), -1.0, 1.0)))


func record_gun_fire() -> void:
	gun_cooldown = 0.12


func record_missile_fire() -> void:
	missile_cooldown = 12.0 + role * 2.0


func apply_hit(kind: String) -> void:
	if destroyed:
		return
	if kind == "missile":
		gun_hits = 10
	else:
		gun_hits += 1
	if gun_hits >= 10:
		destroyed = true
		state = "destroyed"
		death_time = 0.0
		wreck_velocity = model.forward * model.speed * 0.25
		start_wreck_smoke()


func start_wreck_smoke() -> void:
	if wreck_smoke != null:
		return
	wreck_smoke = GPUParticles3D.new()
	wreck_smoke.amount = 56
	wreck_smoke.lifetime = 1.5
	wreck_smoke.local_coords = false
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = Vector3.UP
	process.spread = 30.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 3.0
	process.gravity = Vector3(0.0, 0.4, 0.0)
	process.scale_min = 1.0
	process.scale_max = 2.6
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.10, 0.12, 0.14, 0.58))
	gradient.set_color(1, Color(0.08, 0.10, 0.12, 0.0))
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	wreck_smoke.process_material = process
	var quad = QuadMesh.new()
	quad.size = Vector2(2.2, 2.2)
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load("res://assets/effects/soft_particle.png")
	quad.material = material
	wreck_smoke.draw_pass_1 = quad
	add_child(wreck_smoke)


func step_wreck(dt: float) -> void:
	death_time += dt
	previous_position = model.position
	previous_orientation = model.orientation
	wreck_velocity.y -= 9.81 * dt
	model.position += wreck_velocity * dt
	model.orientation = (model.orientation * Quaternion(Vector3.FORWARD, dt * 1.2) * Quaternion(Vector3.RIGHT, dt * 0.65)).normalized()
	if death_time > 4.0:
		visual.visible = false
		if wreck_smoke != null:
			wreck_smoke.emitting = false
