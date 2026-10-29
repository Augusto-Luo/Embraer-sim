extends Node3D

const GUN_SPEED = 700.0
const GUN_LIFETIME = 2.4

var kind = "gun"
var team = "player"
var target
var velocity = Vector3.ZERO
var max_speed = 280.0
var turn_rate = 2.4
var ttl = 1.6
var active = true
var previous_position = Vector3.ZERO
var smoke
var launch_puff
var exhaust_flame
var exhaust_light
var visual_age = 0.0


func _ready() -> void:
	previous_position = position
	if kind == "gun":
		ttl = GUN_LIFETIME
		build_gun_visual()
	else:
		ttl = 12.0
		build_missile_visual()
	point_along_velocity()


func material(color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	return result


func build_gun_visual() -> void:
	var instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.065, 0.065, 7.0)
	instance.mesh = mesh
	instance.material_override = material(Color(1.0, 0.72, 0.20, 1.0))
	instance.position.z = 3.5
	add_child(instance)


func build_missile_visual() -> void:
	var body = MeshInstance3D.new()
	var body_mesh = CylinderMesh.new()
	body_mesh.top_radius = 0.07
	body_mesh.bottom_radius = 0.12
	body_mesh.height = 1.5
	body_mesh.radial_segments = 10
	body.mesh = body_mesh
	body.rotation_degrees.x = -90.0
	body.material_override = material(Color(0.74, 0.77, 0.78, 1.0))
	add_child(body)

	var nose = MeshInstance3D.new()
	var nose_mesh = CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.07
	nose_mesh.height = 0.35
	nose_mesh.radial_segments = 10
	nose.mesh = nose_mesh
	nose.rotation_degrees.x = -90.0
	nose.position.z = -0.82
	nose.material_override = material(Color(0.24, 0.28, 0.30, 1.0))
	add_child(nose)

	for fin_size in [Vector3(0.65, 0.025, 0.38), Vector3(0.025, 0.65, 0.38)]:
		var fin = MeshInstance3D.new()
		var fin_mesh = BoxMesh.new()
		fin_mesh.size = fin_size
		fin.mesh = fin_mesh
		fin.position.z = 0.48
		fin.material_override = material(Color(0.48, 0.52, 0.54, 1.0))
		add_child(fin)

	exhaust_flame = MeshInstance3D.new()
	var flame_mesh = SphereMesh.new()
	flame_mesh.radius = 0.15
	flame_mesh.height = 0.30
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	exhaust_flame.mesh = flame_mesh
	exhaust_flame.position.z = 0.92
	exhaust_flame.scale = Vector3(1.0, 1.0, 1.8)
	exhaust_flame.material_override = material(Color(1.0, 0.36, 0.035, 1.0))
	add_child(exhaust_flame)
	exhaust_light = OmniLight3D.new()
	exhaust_light.light_color = Color(1.0, 0.40, 0.08)
	exhaust_light.light_energy = 1.0
	exhaust_light.omni_range = 5.0
	exhaust_light.shadow_enabled = false
	exhaust_light.position.z = 0.90
	add_child(exhaust_light)

	launch_puff = GPUParticles3D.new()
	launch_puff.amount = 22
	launch_puff.lifetime = 0.75
	launch_puff.one_shot = true
	launch_puff.explosiveness = 1.0
	launch_puff.local_coords = false
	var launch_process = ParticleProcessMaterial.new()
	launch_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	launch_process.direction = Vector3.BACK
	launch_process.spread = 24.0
	launch_process.initial_velocity_min = 2.0
	launch_process.initial_velocity_max = 6.0
	launch_process.gravity = Vector3(0.0, 0.5, 0.0)
	launch_process.scale_min = 0.5
	launch_process.scale_max = 1.4
	var launch_gradient = Gradient.new()
	launch_gradient.set_color(0, Color(0.82, 0.85, 0.86, 0.42))
	launch_gradient.set_color(1, Color(0.45, 0.48, 0.50, 0.0))
	var launch_ramp = GradientTexture1D.new()
	launch_ramp.gradient = launch_gradient
	launch_process.color_ramp = launch_ramp
	launch_puff.process_material = launch_process
	var launch_quad = QuadMesh.new()
	launch_quad.size = Vector2(1.6, 1.6)
	var launch_material = StandardMaterial3D.new()
	launch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	launch_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	launch_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	launch_material.vertex_color_use_as_albedo = true
	launch_material.albedo_texture = load("res://assets/effects/soft_particle.png")
	launch_quad.material = launch_material
	launch_puff.draw_pass_1 = launch_quad
	add_child(launch_puff)

	smoke = GPUParticles3D.new()
	smoke.amount = 48
	smoke.lifetime = 1.0
	smoke.local_coords = false
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = Vector3.ZERO
	process.spread = 8.0
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.35
	process.scale_max = 0.95
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.82, 0.85, 0.88, 0.34))
	gradient.set_color(1, Color(0.42, 0.46, 0.50, 0.0))
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	smoke.process_material = process
	var quad = QuadMesh.new()
	quad.size = Vector2(1.25, 1.25)
	var smoke_material = StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.albedo_texture = load("res://assets/effects/soft_particle.png")
	quad.material = smoke_material
	smoke.draw_pass_1 = quad
	add_child(smoke)


func _process(dt: float) -> void:
	visual_age += dt
	if exhaust_flame != null:
		var flicker = 1.0 + sin(visual_age * 75.0) * 0.14
		exhaust_flame.scale = Vector3(flicker, flicker, 1.8 + sin(visual_age * 53.0) * 0.25)
	if exhaust_light != null:
		exhaust_light.light_energy = 0.30 + 0.70 * exp(-visual_age * 4.0)


func point_along_velocity() -> void:
	if velocity.length_squared() < 0.001:
		return
	var direction = velocity.normalized()
	if abs(direction.dot(Vector3.UP)) < 0.99:
		look_at(position + direction, Vector3.UP)


func step(dt: float, enemies: Array, player) -> Dictionary:
	if not active:
		return {}
	previous_position = position
	if kind == "missile":
		velocity = velocity.normalized() * min(max_speed, velocity.length() + 75.0 * dt)
		var target_alive = target != null and (team == "enemy" or not target.destroyed)
		if target_alive:
			var target_position
			var target_forward
			var target_speed
			if team == "player":
				target_position = target.model.position
				target_forward = target.model.forward
				target_speed = target.model.speed
			else:
				target_position = target.position
				target_forward = target.forward
				target_speed = target.speed
			var to_target = target_position - position
			var lead_time = clamp(to_target.length() / max(velocity.length(), 1.0) * 0.35, 0.0, 1.2)
			var aim_point = target_position + target_forward * target_speed * lead_time
			var desired = (aim_point - position).normalized()
			velocity = velocity.normalized().lerp(desired, clamp(turn_rate * dt, 0.0, 1.0)).normalized() * velocity.length()
	position += velocity * dt
	point_along_velocity()

	if team == "player":
		for enemy in enemies:
			if enemy.destroyed:
				continue
			var closest = Geometry3D.get_closest_point_to_segment(enemy.model.position, previous_position, position)
			var radius = float(enemy.get_meta("gun_hit_radius", 8.0)) if kind == "gun" else float(enemy.get_meta("missile_hit_radius", 14.0))
			if closest.distance_to(enemy.model.position) <= radius:
				enemy.apply_hit(kind)
				active = false
				return {"finished": true, "hit": true, "enemy": enemy, "kind": kind, "position": position}
	else:
		if position.distance_to(player.position) < 14.0:
			active = false
			return {"finished": true, "near_player": true, "kind": kind, "position": position}

	ttl -= dt
	if ttl <= 0.0 or position.y < 0.0:
		active = false
		return {"finished": true, "expired": true, "kind": kind, "position": position}
	return {}
