extends Node3D

signal damaged(amount: float, weapon: String)
signal eliminated(target)

const MAX_HP = 120.0
const GUN_DAMAGE = 10.0
const ROCKET_DAMAGE = 100.0

var callsign = "TARGET"
var site_id = "avenue"
var variant = 0
var hp = MAX_HP
var max_hp = MAX_HP
var destroyed = false
var death_reported = false
var dimensions = Vector3(18.0, 8.0, 24.0)
var model = {"position": Vector3.ZERO, "forward": Vector3.FORWARD, "speed": 0.0}
var geometry: Node3D
var smoke: GPUParticles3D
var body_material: StandardMaterial3D


func _ready() -> void:
	set_notify_transform(true)
	sync_model()
	build_geometry()
	build_smoke()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		sync_model()


func sync_model() -> void:
	model.position = aim_position()


func aim_position() -> Vector3:
	return (global_position if is_inside_tree() else position) + Vector3.UP * dimensions.y * 0.55


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
	geometry.add_child(mesh)
	return mesh


func cylinder(radius: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 12
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = mat
	geometry.add_child(mesh)
	return mesh


func build_geometry() -> void:
	geometry = Node3D.new()
	geometry.name = "TargetGeometry"
	add_child(geometry)
	body_material = make_material(Color("#555e4b"), 0.12)
	var dark = make_material(Color("#242c2c"))
	var marker = make_material(Color("#d1a54d"))
	if variant % 4 == 0:
		box(Vector3(16, 6, 20), Vector3(0, 4, 0), body_material)
		box(Vector3(14, 4, 7), Vector3(0, 3.5, 10), body_material)
		box(Vector3(12, 1.5, 1), Vector3(0, 5.5, 13.6), dark)
		for z in [-7.0, 6.0]:
			for x in [-8.0, 8.0]:
				box(Vector3(2, 3, 4), Vector3(x, 1.5, z), dark)
	elif variant % 4 == 1:
		box(Vector3(18, 8, 22), Vector3(0, 4, 0), body_material)
		for z in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			box(Vector3(18.3, 7, 0.35), Vector3(0, 4, z), dark)
	elif variant % 4 == 2:
		box(Vector3(20, 1.2, 23), Vector3(0, 0.6, 0), dark)
		cylinder(7.5, 7.0, Vector3(0, 4.7, 0), body_material)
		cylinder(7.7, 0.6, Vector3(0, 8.2, 0), marker)
	else:
		box(Vector3(19, 6, 22), Vector3(0, 3, 0), body_material)
		box(Vector3(13, 2, 15), Vector3(0, 7, 0), dark)
		box(Vector3(2, 2, 19), Vector3(0, 9, 0), marker)
	# The broad amber top stripe identifies actual targets from the city's roofs.
	box(Vector3(4.0, 0.25, 17.0), Vector3(0, 8.6, 0), marker)


func build_smoke() -> void:
	smoke = GPUParticles3D.new()
	smoke.name = "DamageSmoke"
	smoke.amount = 12
	smoke.lifetime = 3.0
	smoke.emitting = false
	smoke.position.y = 5.0
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


func get_visual_bounds() -> AABB:
	var origin = global_position if is_inside_tree() else position
	return AABB(origin - Vector3(dimensions.x * 0.5, 0, dimensions.z * 0.5), dimensions)


func get_hit_bounds(weapon: String = "gun") -> AABB:
	sync_model()
	var visual = get_visual_bounds()
	var tolerance = 5.0 if weapon == "gun" else 6.0
	# Keep the lower face at the surface: shooting through ground is never a hit.
	return AABB(visual.position - Vector3(tolerance, 0, tolerance), visual.size + Vector3(tolerance * 2, tolerance, tolerance * 2))


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
			geometry.scale.y = 0.42
			geometry.rotation.z = 0.08
		if body_material != null:
			body_material.albedo_color = Color("#252b28")
	damaged.emit(actual, weapon)
	if destroyed:
		eliminated.emit(self)
	return actual


func set_simulation_paused(value: bool) -> void:
	if smoke != null:
		smoke.speed_scale = 0.0 if value else 1.0
