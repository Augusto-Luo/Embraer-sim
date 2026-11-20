extends Node3D

# A staged visual encounter, not an enemy: no hit boxes, damage or flight forces.
const MODEL = preload("res://assets/mothman/eclipsis-mothman.glb")
const WING_SHADER = preload("res://shaders/echo_mothman.gdshader")
const CLOUD_SHADER = preload("res://shaders/near_cloud.gdshader")
const CLOUD_TEXTURE = preload("res://assets/ground/near-cloud-512.png")
const SOURCE_CENTER = Vector3(-555.1769, 20.40401, 394.92926)
const SOURCE_WINGSPAN = 42.26965
const WINGSPAN = 1000.0
const GLIDE_SPEED = 65.0
const FREE_GLIDE_SPEED = 32.0
const ORBIT_RADIUS = 1500.0
const ORBIT_SETTLE_SECONDS = 10.0
# Barycentric UV projection of the large ring center onto each original wing.
const SOURCE_EYES = [Vector3(-540.893835, 25.209051, 394.977190), Vector3(-569.472481, 25.208860, 394.807721)]
const SOURCE_LOWER_EYES = [Vector3(-549.145696, 14.927504, 392.709909), Vector3(-561.193597, 14.927329, 392.638095)]

var flash_strength = 0.0
var heading = Vector3.BACK
var lateral = Vector3.RIGHT
var spawn_position = Vector3.ZERO
var elapsed = 0.0
var reveal_time = 0.0
var visual: Node3D
var motion: Node3D
var wing_materials: Array[ShaderMaterial] = []
var body_materials: Array[StandardMaterial3D] = []
var body_base_colors: Array[Color] = []
var cloud_materials: Array[ShaderMaterial] = []
var cloud_nodes: Array[MeshInstance3D] = []
var eye_anchors: Array[Node3D] = []
var initialized = false
var free_flight = false
var free_elapsed = 0.0
var free_entry_time = 14.0
var orbit_radius = ORBIT_RADIUS
var orbit_origin = Vector3.ZERO
var orbit_center = Vector3.ZERO
var orbit_tangent = Vector3.BACK
var orbit_right = Vector3.RIGHT
var orbit_initial_speed = GLIDE_SPEED
var orbit_velocity = Vector3.ZERO
var free_yaw_start = 0.0
var body_opacity = 0.0
var upper_eye_energy = 0.0
var lower_eye_energy = 0.0
var body_surface_fill = 0.0
var lower_eye_anchors: Array[Node3D] = []


func _ready() -> void:
	build_model()
	build_cloud_veils()
	initialized = true
	visible = false


func build_model() -> void:
	motion = Node3D.new()
	motion.name = "ContinuousGlide"
	add_child(motion)
	visual = MODEL.instantiate()
	visual.name = "MothmanSource"
	var factor = WINGSPAN / SOURCE_WINGSPAN
	visual.scale = Vector3.ONE * factor
	visual.position = -SOURCE_CENTER * factor
	motion.add_child(visual)
	prepare_materials(visual, {})
	for point in SOURCE_EYES:
		var anchor = Node3D.new()
		anchor.name = "WingEye%d" % eye_anchors.size()
		anchor.position = (point - SOURCE_CENTER) * factor
		motion.add_child(anchor)
		eye_anchors.append(anchor)
	for point in SOURCE_LOWER_EYES:
		var anchor = Node3D.new()
		anchor.name = "LowerWingEye%d" % lower_eye_anchors.size()
		anchor.position = (point - SOURCE_CENTER) * factor
		motion.add_child(anchor)
		lower_eye_anchors.append(anchor)


func prepare_materials(node: Node, shared: Dictionary) -> void:
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(node.mesh.get_surface_count()):
			var original = node.get_active_material(surface)
			if original is not StandardMaterial3D:
				continue
			var key = original.get_instance_id()
			if not shared.has(key):
				if "wing" in original.resource_name.to_lower():
					var wing = ShaderMaterial.new()
					wing.shader = WING_SHADER
					wing.set_shader_parameter("wing_texture", original.albedo_texture)
					wing.set_shader_parameter("wing_normal", original.normal_texture)
					wing.set_shader_parameter("eye_energy", 0.0)
					shared[key] = wing
					wing_materials.append(wing)
				else:
					var material: StandardMaterial3D = original.duplicate()
					material.emission_enabled = false
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
					material.roughness = 0.96
					material.metallic = 0.0
					material.disable_ambient_light = false
					shared[key] = material
					body_materials.append(material)
					body_base_colors.append(material.albedo_color)
			node.set_surface_override_material(surface, shared[key])
	for child in node.get_children():
		prepare_materials(child, shared)


func build_cloud_veils() -> void:
	# These actual scene quads sit in front of and behind the creature. Sky clouds
	# alone cannot occlude a mesh, and no overlay is used to fake the glowing eyes.
	var specs = [
		[Vector3(-510, 150, 130), Vector2(900, 540), 0.43],
		[Vector3(530, 40, 105), Vector2(920, 620), 0.40],
		[Vector3(0, -160, 165), Vector2(1150, 470), 0.54],
		[Vector3(-360, -25, -145), Vector2(1000, 680), 0.62],
		[Vector3(400, 190, -170), Vector2(1100, 650), 0.58],
	]
	for index in range(specs.size()):
		var spec = specs[index]
		var cloud = MeshInstance3D.new()
		cloud.name = "EncounterCloud%02d" % index
		var quad = QuadMesh.new()
		quad.size = spec[1]
		cloud.mesh = quad
		cloud.position = spec[0]
		cloud.set_meta("origin", spec[0])
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.extra_cull_margin = 300.0
		cloud.sorting_offset = 5.0 if index < 3 else -5.0
		var material = ShaderMaterial.new()
		material.shader = CLOUD_SHADER
		material.set_shader_parameter("cloud_texture", CLOUD_TEXTURE)
		material.set_shader_parameter("cloud_tint", Color(0.018, 0.024, 0.040, 1))
		material.set_shader_parameter("opacity", spec[2])
		material.set_shader_parameter("uv_rotation", 0.5 + index * 0.79)
		material.set_shader_parameter("depth_softness", 20.0)
		material.set_shader_parameter("night_factor", 1.0)
		cloud.set_meta("opacity", spec[2])
		cloud.material_override = material
		add_child(cloud)
		cloud_nodes.append(cloud)
		cloud_materials.append(material)


func begin(player_position: Vector3, forward: Vector3) -> void:
	heading = Vector3(forward.x, 0.0, forward.z).normalized()
	if heading.length_squared() < 0.1:
		heading = Vector3.BACK
	lateral = Vector3(heading.z, 0, -heading.x)
	var eye_height = (SOURCE_EYES[0].y - SOURCE_CENTER.y) * WINGSPAN / SOURCE_WINGSPAN
	spawn_position = player_position + heading * 1700.0 + Vector3.UP * (65.0 - eye_height)
	position = spawn_position
	# The imported creature faces +Z. Face back down the flight corridor.
	rotation.y = atan2(-heading.x, -heading.z)
	elapsed = 0.0
	reveal_time = 0.0
	free_flight = false
	free_elapsed = 0.0
	free_entry_time = 14.0
	orbit_velocity = heading * GLIDE_SPEED
	orbit_center = Vector3.ZERO
	flash_strength = 0.0
	visible = true
	apply_visuals(0.0)


func enter_free_flight() -> void:
	if free_flight or not initialized:
		return
	# Capture the current tangent, not the player. The same world-space point
	# and velocity start the circular path, so control hand-back has no jump.
	var departure = max(0.0, reveal_time - 9.0)
	orbit_velocity = heading * GLIDE_SPEED + lateral * departure * 2.2
	orbit_initial_speed = orbit_velocity.length()
	orbit_tangent = orbit_velocity.normalized()
	orbit_right = Vector3(orbit_tangent.z, 0.0, -orbit_tangent.x)
	orbit_origin = position
	orbit_center = orbit_origin + orbit_right * orbit_radius
	free_yaw_start = rotation.y
	free_entry_time = reveal_time
	free_elapsed = 0.0
	free_flight = true
	visible = true
	apply_visuals(max(14.0, reveal_time))


func step(dt: float, time: float) -> void:
	if not initialized or not visible:
		return
	elapsed += dt
	if free_flight:
		free_elapsed += dt
		reveal_time = 14.0 + free_elapsed
		# Integrating the exponential speed analytically makes the orbit stable
		# across frame rates and bounded for an arbitrarily long free flight.
		var decay = exp(-free_elapsed / ORBIT_SETTLE_SECONDS)
		var distance = FREE_GLIDE_SPEED * free_elapsed + (orbit_initial_speed - FREE_GLIDE_SPEED) * ORBIT_SETTLE_SECONDS * (1.0 - decay)
		var angle = distance / orbit_radius
		position = orbit_origin + orbit_tangent * orbit_radius * sin(angle) + orbit_right * orbit_radius * (1.0 - cos(angle))
		var tangent = orbit_tangent * cos(angle) + orbit_right * sin(angle)
		orbit_velocity = tangent * (FREE_GLIDE_SPEED + (orbit_initial_speed - FREE_GLIDE_SPEED) * decay)
		var facing_yaw = atan2(-tangent.x, -tangent.z)
		rotation.y = lerp_angle(free_yaw_start, facing_yaw, smoothstep(0.0, 8.0, free_elapsed))
	else:
		reveal_time = time
		var departure = max(0.0, time - 9.0)
		position = spawn_position + heading * GLIDE_SPEED * elapsed + lateral * departure * departure * 1.1
		orbit_velocity = heading * GLIDE_SPEED + lateral * departure * 2.2
	motion.rotation_degrees = Vector3(sin(elapsed * 0.20) * 0.55, sin(elapsed * 0.13) * 0.65, sin(elapsed * 0.17) * 0.55)
	motion.position.y = sin(elapsed * 0.28) * 3.0
	apply_visuals(reveal_time)


func apply_visuals(time: float) -> void:
	var wake = smoothstep(2.0, 2.20, time)
	upper_eye_energy = wake * (3.2 + sin(time * 1.10) * 0.12)
	# The lower pair awakens after the main lightning reveal. The upper eyes
	# never extinguish when the continuous shot returns to the driver's seat.
	lower_eye_energy = upper_eye_energy * smoothstep(9.5, 12.5, time)
	body_surface_fill = smoothstep(10.5, 16.0, time)
	var body_visibility = lerp(0.055, 0.90, smoothstep(7.0, 12.0, time)) + flash_strength * 0.35
	# Alpha prevents only the premature black cutout. The fully revealed body
	# stays solid, lit by the mission's moon/ambient light, with real 3D clouds.
	body_opacity = max(smoothstep(7.0, 9.5, time), flash_strength * 0.5)
	for material in wing_materials:
		material.set_shader_parameter("eye_energy", upper_eye_energy)
		material.set_shader_parameter("lower_eye_energy", lower_eye_energy)
		material.set_shader_parameter("body_visibility", min(1.0, body_visibility))
		material.set_shader_parameter("surface_fill", body_surface_fill)
		material.set_shader_parameter("opacity", 1.0)
		material.set_shader_parameter("body_opacity", body_opacity)
	for index in range(body_materials.size()):
		var source = body_base_colors[index]
		var color = source * Color(body_visibility, body_visibility, body_visibility, 1.0)
		# A restrained charcoal-blue diffuse lift preserves the original surface
		# variation while allowing the very dark source asset to read at night.
		color += Color(0.025, 0.030, 0.045, 0.0) * body_surface_fill
		color.a = body_opacity
		body_materials[index].albedo_color = color
	var cloud_time = time
	if free_flight:
		# Bound the cloud drift as well as the creature. The first derivative at
		# the handover matches the original moving cloud layer.
		cloud_time = free_entry_time + sin(free_elapsed * 0.05) / 0.05
	for index in range(cloud_nodes.size()):
		var cloud = cloud_nodes[index]
		var base: Vector3 = cloud.get_meta("origin")
		cloud.position = base + Vector3(cloud_time * (5.0 if index % 2 == 0 else -7.0), sin(time * 0.16 + index) * 10.0, 0.0)
		var veil = float(cloud.get_meta("opacity"))
		var thin_veil = smoothstep(10.5, 17.0, time)
		veil *= lerp(0.82 if index < 3 else 1.0, 0.23 if index < 3 else 0.18, thin_veil)
		cloud_materials[index].set_shader_parameter("opacity", min(0.95, veil))
		cloud_materials[index].set_shader_parameter("lightning_strength", clamp(flash_strength, 0.0, 1.0))
		cloud_materials[index].set_shader_parameter("lightning_direction", (heading + Vector3.UP * 0.35 - lateral * 0.55).normalized())


func eye_positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for anchor in eye_anchors:
		points.append(anchor.global_position)
	return points


func all_eye_positions() -> Array[Vector3]:
	var points = eye_positions()
	for anchor in lower_eye_anchors:
		points.append(anchor.global_position)
	return points


func eyes_center() -> Vector3:
	if eye_anchors.size() == 2:
		return (eye_anchors[0].global_position + eye_anchors[1].global_position) * 0.5
	return global_position


func body_position() -> Vector3:
	return motion.global_position


func clear() -> void:
	visible = false
	free_flight = false
	free_elapsed = 0.0
	orbit_velocity = Vector3.ZERO
	orbit_center = Vector3.ZERO
	flash_strength = 0.0
	elapsed = 0.0
	reveal_time = 0.0
	if initialized:
		apply_visuals(0.0)
