extends Node3D

signal damaged(amount: float, weapon: String)
signal eliminated(target)

const MAX_HP = 120.0
const GUN_DAMAGE = 10.0
const ROCKET_DAMAGE = 100.0

const TANK_PATH = "res://assets/ground/targets/tank.glb"
const FUEL_PATH = "res://assets/ground/targets/fuel.glb"
const SHIP_PATH = "res://assets/ground/targets/ship.glb"
const MODEL_SCALES = {"tank": 1.45, "fuel": 1.35, "ship": 1.15}

var callsign = "TARGET"
var site_id = "avenue"
var variant = 0
var kind = "tank"
var hp = MAX_HP
var max_hp = MAX_HP
var destroyed = false
var death_reported = false
var dimensions = Vector3(4.5, 4.3, 10.3)
var visual_offset = Vector3.ZERO
var aim_offset = Vector3(0.0, 2.5, 0.0)
var hit_volumes: Array[AABB] = []
var model = {"position": Vector3.ZERO, "forward": Vector3.FORWARD, "speed": 0.0}
var geometry: Node3D
var smoke: GPUParticles3D
var target_materials: Array[StandardMaterial3D] = []
var model_scale = 1.0
var cruise_points: Array[Vector3] = []
var cruise_segment_lengths: Array[float] = []
var cruise_total_length = 0.0
var cruise_distance = 0.0
var cruise_speed = 10.0
var cruise_direction = Vector3.FORWARD


func _ready() -> void:
	set_notify_transform(true)
	configure_profile()
	sync_model()
	build_geometry()
	build_smoke()


func configure_profile() -> void:
	max_hp = 240.0 if kind == "ship" else MAX_HP
	hp = max_hp
	hit_volumes.clear()
	visual_offset = Vector3.ZERO
	match kind:
		"ship":
			dimensions = Vector3(17.7, 27.8, 120.0)
			visual_offset = Vector3(0.0, -5.84, 0.0)
			aim_offset = Vector3(0.0, 12.0, 5.0)
			hit_volumes.append(AABB(Vector3(-8.85, -2.0, -60.0), Vector3(17.7, 10.0, 120.0)))
			hit_volumes.append(AABB(Vector3(-6.0, 5.0, -28.0), Vector3(12.0, 17.0, 56.0)))
		"fuel":
			dimensions = Vector3(10.35, 6.54, 12.0)
			aim_offset = Vector3(0.0, 3.3, 0.0)
			hit_volumes.append(AABB(Vector3(-5.175, 0.0, -6.0), dimensions))
		_:
			kind = "tank"
			dimensions = Vector3(4.5, 4.3, 10.3)
			aim_offset = Vector3(0.0, 2.6, 0.0)
			hit_volumes.append(AABB(Vector3(-2.25, 0.0, -4.2), Vector3(4.5, 2.0, 8.4)))
			hit_volumes.append(AABB(Vector3(-1.8, 1.8, -2.5), Vector3(3.6, 2.5, 5.0)))
	model_scale = float(MODEL_SCALES.get(kind, 1.0))
	dimensions *= model_scale
	visual_offset *= model_scale
	aim_offset *= model_scale
	for index in range(hit_volumes.size()):
		hit_volumes[index] = AABB(hit_volumes[index].position * model_scale, hit_volumes[index].size * model_scale)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		sync_model()


func sync_model() -> void:
	model.position = aim_position()
	model.forward = -global_transform.basis.z.normalized() if is_inside_tree() else Vector3.FORWARD
	if destroyed or cruise_points.is_empty():
		model.speed = 0.0


func aim_position() -> Vector3:
	var origin = global_position if is_inside_tree() else position
	var orientation = global_transform.basis if is_inside_tree() else transform.basis
	return origin + orientation * aim_offset


func make_material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.85
	return result


func box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.add_child(mesh)
	return mesh


func build_geometry() -> void:
	geometry = Node3D.new()
	geometry.name = "TargetGeometry"
	geometry.scale = Vector3.ONE * model_scale
	add_child(geometry)
	# Load these resources only when level 4 creates its targets.
	var path = SHIP_PATH if kind == "ship" else (FUEL_PATH if kind == "fuel" else TANK_PATH)
	var packed = load(path) as PackedScene
	var visual = packed.instantiate()
	visual.name = kind.capitalize() + "Model"
	if kind in ["tank", "ship"]:
		visual.rotation.y = PI
	geometry.add_child(visual)
	target_materials.clear()
	configure_visuals(visual)
	var marker = make_material(Color("#d1a54d"))
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match kind:
		"ship":
			box(Vector3(1.4, 0.18, 32.0), Vector3(0, 22.15, -3.0), marker)
		"fuel":
			box(Vector3(1.4, 0.16, 7.0), Vector3(0, 6.68, 0), marker)
		# Tanks use their natural silhouette without an overhead marker.


func configure_visuals(node: Node) -> void:
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "ship" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.visibility_range_end = 5000.0
		if node.mesh != null:
			for surface in range(node.mesh.get_surface_count()):
				var source = node.get_active_material(surface)
				if source is StandardMaterial3D:
					var material = source.duplicate() as StandardMaterial3D
					material.resource_name = kind.capitalize() + " / " + str(surface + 1)
					if kind == "ship":
						material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					node.set_surface_override_material(surface, material)
					target_materials.append(material)
	for child in node.get_children():
		configure_visuals(child)


func build_smoke() -> void:
	smoke = GPUParticles3D.new()
	smoke.name = "DamageSmoke"
	smoke.amount = 12
	smoke.lifetime = 3.0
	smoke.emitting = false
	smoke.position = aim_offset
	var process = ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 18.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 7.0
	process.gravity = Vector3(0, 1.0, 0)
	process.scale_min = 1.5
	process.scale_max = 3.2
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.13, 0.16, 0.17, 0.50))
	gradient.set_color(1, Color(0.13, 0.16, 0.17, 0.0))
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	smoke.process_material = process
	var quad = QuadMesh.new()
	quad.size = Vector2(4, 4)
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://assets/effects/soft_particle.png")
	quad.material = mat
	smoke.draw_pass_1 = quad
	add_child(smoke)


func configure_cruise(points: Array[Vector3], start_distance: float = 0.0) -> void:
	cruise_points = points
	cruise_segment_lengths.clear()
	cruise_total_length = 0.0
	for index in range(cruise_points.size()):
		var length = cruise_points[index].distance_to(cruise_points[(index + 1) % cruise_points.size()])
		cruise_segment_lengths.append(length)
		cruise_total_length += length
	cruise_distance = fposmod(start_distance, cruise_total_length)
	update_cruise_pose()
	rotation.y = atan2(-cruise_direction.x, -cruise_direction.z)
	sync_model()


func update_cruise_pose() -> void:
	var remaining = cruise_distance
	for index in range(cruise_points.size()):
		var length = cruise_segment_lengths[index]
		if remaining <= length or index == cruise_points.size() - 1:
			var start = cruise_points[index]
			var finish = cruise_points[(index + 1) % cruise_points.size()]
			position = start.lerp(finish, clampf(remaining / maxf(length, 0.001), 0.0, 1.0))
			cruise_direction = (finish - start).normalized()
			return
		remaining -= length


func step_cruise(dt: float) -> void:
	if destroyed or cruise_total_length <= 0.0:
		return
	cruise_distance = fposmod(cruise_distance + cruise_speed * dt, cruise_total_length)
	update_cruise_pose()
	var desired_yaw = atan2(-cruise_direction.x, -cruise_direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, minf(1.0, dt * 1.8))
	model.speed = cruise_speed
	sync_model()


func get_visual_bounds() -> AABB:
	var world = global_transform if is_inside_tree() else transform
	var local = AABB(visual_offset - Vector3(dimensions.x * 0.5, 0, dimensions.z * 0.5), dimensions)
	return world * local


func get_local_hit_volumes(weapon: String = "gun") -> Array[AABB]:
	var volumes: Array[AABB] = []
	var tolerance = 5.0 if weapon == "gun" else 6.0
	for box in hit_volumes:
		# Preserve the original ground-level forgiveness in target-local space.
		volumes.append(AABB(box.position - Vector3(tolerance, 0, tolerance), box.size + Vector3(tolerance * 2, tolerance, tolerance * 2)))
	return volumes


func get_hit_volumes(weapon: String = "gun") -> Array[AABB]:
	sync_model()
	var volumes: Array[AABB] = []
	var world = global_transform if is_inside_tree() else transform
	for box in get_local_hit_volumes(weapon):
		volumes.append(world * box)
	return volumes


func get_hit_bounds(weapon: String = "gun") -> AABB:
	var volumes = get_hit_volumes(weapon)
	if volumes.is_empty():
		return AABB()
	var result = volumes[0]
	for index in range(1, volumes.size()):
		result = result.merge(volumes[index])
	return result


func apply_hit(weapon: String) -> float:
	return apply_damage(ROCKET_DAMAGE if weapon in ["missile", "rocket"] else GUN_DAMAGE, weapon)


func apply_damage(amount: float, weapon: String = "gun") -> float:
	if destroyed or amount <= 0.0:
		return 0.0
	var actual = minf(hp, amount)
	hp -= actual
	if smoke != null:
		smoke.emitting = hp < max_hp
	if hp <= 0.0:
		destroyed = true
		if geometry != null:
			geometry.rotation.z = 0.035 if kind == "ship" else 0.06
		for material in target_materials:
			var color = material.albedo_color
			material.albedo_color = Color(color.r * 0.28, color.g * 0.30, color.b * 0.28, color.a)
	damaged.emit(actual, weapon)
	if destroyed:
		eliminated.emit(self)
	return actual


func set_simulation_paused(value: bool) -> void:
	if smoke != null:
		smoke.speed_scale = 0.0 if value else 1.0
