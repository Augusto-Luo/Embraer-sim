extends Node3D

# A visual contact only: it cannot attack, take damage or affect the flight model.
const AIRCRAFT = preload("res://assets/kc390-training.glb")
const CRUISE_SPEED = 88.0
const TURN_RADIUS = 4200.0

var forward = Vector3.BACK
var route_origin = Vector3.ZERO
var route_orientation = Quaternion()
var straight_distance = 0.0
var arc_angle = 0.0
var in_arc = false
var opacity = 1.0
var elapsed = 0.0
var aircraft: Node3D
var surface_materials: Array[StandardMaterial3D] = []
var navigation_lights: Array[MeshInstance3D] = []
var cloud_veil: MeshInstance3D
var cloud_material: StandardMaterial3D


func _ready() -> void:
	route_origin = position
	route_orientation = quaternion
	forward = route_orientation * Vector3.BACK
	aircraft = AIRCRAFT.instantiate()
	add_child(aircraft)
	prepare_materials(aircraft, {})
	add_navigation_light(Vector3(-16.8, 1.4, -1.0), Color("f36368"))
	add_navigation_light(Vector3(16.8, 1.4, -1.0), Color("87e7b4"))
	add_navigation_light(Vector3(0.0, 7.2, -14.0), Color("d5e5e7"))
	cloud_veil = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1550.0, 950.0)
	cloud_veil.mesh = quad
	cloud_veil.position.z = -190.0
	cloud_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_material = StandardMaterial3D.new()
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cloud_material.albedo_texture = preload("res://assets/ground/near-cloud-512.png")
	cloud_material.albedo_color = Color(0.13, 0.21, 0.24, 0.0)
	cloud_veil.material_override = cloud_material
	add_child(cloud_veil)


func prepare_materials(node: Node, shared: Dictionary) -> void:
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(node.mesh.get_surface_count()):
			var original = node.get_active_material(surface)
			if original is not StandardMaterial3D:
				continue
			var key = original.get_instance_id()
			if not shared.has(key):
				var material: StandardMaterial3D = original.duplicate()
				material.albedo_color *= Color(0.48, 0.58, 0.64, 1.0)
				material.roughness = 0.88
				material.metallic = 0.02
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				shared[key] = material
				surface_materials.append(material)
			node.set_surface_override_material(surface, shared[key])
	for child in node.get_children():
		prepare_materials(child, shared)


func add_navigation_light(at: Vector3, color: Color) -> void:
	var light = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	sphere.radial_segments = 8
	sphere.rings = 4
	light.mesh = sphere
	light.position = at
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	light.material_override = material
	add_child(light)
	navigation_lights.append(light)


func begin_arc() -> void:
	if in_arc:
		return
	in_arc = true
	route_origin = position
	route_orientation = quaternion
	arc_angle = 0.0


func step(dt: float) -> void:
	elapsed += dt
	if in_arc:
		arc_angle += CRUISE_SPEED / TURN_RADIUS * dt
		position = route_origin + route_orientation * Vector3(TURN_RADIUS * (1.0 - cos(arc_angle)), 0.0, TURN_RADIUS * sin(arc_angle))
		quaternion = (route_orientation * Quaternion(Vector3.UP, arc_angle) * Quaternion(Vector3.BACK, deg_to_rad(-10.0))).normalized()
	else:
		straight_distance += CRUISE_SPEED * dt
		position = route_origin + route_orientation * Vector3(0.0, 0.0, straight_distance)
	forward = (quaternion * Vector3.BACK).normalized()
	# Small navigation lamps give the dark silhouette a stable point of reference.
	var pulse = fposmod(elapsed, 1.8) < 0.14
	for index in range(navigation_lights.size()):
		navigation_lights[index].visible = opacity > 0.15 and (index < 2 or pulse)


func set_opacity(value: float) -> void:
	opacity = clamp(value, 0.0, 1.0)
	for material in surface_materials:
		var color = material.albedo_color
		color.a = opacity
		material.albedo_color = color
	aircraft.visible = opacity > 0.015
	if cloud_material != null:
		cloud_material.albedo_color = Color(0.13, 0.21, 0.24, (1.0 - opacity) * 0.65)
