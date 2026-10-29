extends Node3D

var strength = 1.0
var lifetime = 1.1
var final_lifetime = 1.1
var age = 0.0
var pieces = []
var flash
var flash_material
var fireball
var fireball_material
var shockwave
var shockwave_material
var flash_light
var smoke


func _ready() -> void:
	final_lifetime = max(lifetime, 2.8) if strength >= 1.0 else lifetime
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	flash = MeshInstance3D.new()
	var flash_mesh = QuadMesh.new()
	flash_mesh.size = Vector2(2.0, 2.0)
	flash.mesh = flash_mesh
	flash_material = glow_material(Color(1.0, 0.96, 0.78, 0.90))
	flash.material_override = flash_material
	add_child(flash)

	fireball = MeshInstance3D.new()
	var fire_mesh = QuadMesh.new()
	fire_mesh.size = Vector2(2.0, 2.0)
	fireball.mesh = fire_mesh
	fireball_material = glow_material(Color(1.0, 0.36, 0.035, 0.52))
	fireball.material_override = fireball_material
	add_child(fireball)

	if strength >= 1.0:
		flash_light = OmniLight3D.new()
		flash_light.light_color = Color(1.0, 0.48, 0.14)
		flash_light.light_energy = 2.5
		flash_light.omni_range = 20.0 * strength
		flash_light.shadow_enabled = false
		add_child(flash_light)

		build_smoke()

	for index in range(maxi(3, int(14.0 * strength))):
		var piece = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.08, 0.08, 0.50) * strength
		piece.mesh = mesh
		var material = effect_material(Color(1.0, rng.randf_range(0.30, 0.72), 0.05, 0.95))
		piece.material_override = material
		add_child(piece)
		var direction = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		pieces.append({"node": piece, "material": material, "velocity": direction * rng.randf_range(9.0, 24.0) * strength})


func build_smoke() -> void:
	smoke = GPUParticles3D.new()
	smoke.amount = 20
	smoke.lifetime = 2.8
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.local_coords = false
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.8 * strength
	process.direction = Vector3.UP
	process.spread = 45.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 5.0
	process.gravity = Vector3(0.0, 0.6, 0.0)
	process.scale_min = 0.8 * strength
	process.scale_max = 2.2 * strength
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.12, 0.14, 0.16, 0.58))
	gradient.set_color(1, Color(0.10, 0.12, 0.14, 0.0))
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	smoke.process_material = process
	var quad = QuadMesh.new()
	quad.size = Vector2(3.0, 3.0) * strength
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load("res://assets/effects/soft_particle.png")
	quad.material = material
	smoke.draw_pass_1 = quad
	add_child(smoke)


func effect_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material


func glow_material(color: Color) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/effect_glow.gdshader")
	material.set_shader_parameter("effect_color", color)
	material.set_shader_parameter("glow_texture", load("res://assets/effects/soft_particle.png"))
	material.set_shader_parameter("billboard", true)
	material.set_shader_parameter("use_texture", true)
	return material


func _process(dt: float) -> void:
	age += dt
	var ratio = clamp(age / lifetime, 0.0, 1.0)
	var flash_ratio = clamp(age / 0.22, 0.0, 1.0)
	flash.scale = Vector3.ONE * strength * (1.0 + flash_ratio * 2.0)
	flash_material.set_shader_parameter("effect_color", Color(1.0, 0.96, 0.78, (1.0 - flash_ratio) * 0.90))
	fireball.scale = Vector3.ONE * strength * (0.8 + ratio * 3.0)
	fireball_material.set_shader_parameter("effect_color", Color(1.0, 0.12 + 0.30 * (1.0 - ratio), 0.035, (1.0 - ratio) * 0.52))
	if flash_light != null:
		flash_light.light_energy = max(0.0, 1.0 - age * 5.0) * 2.5
	if shockwave != null:
		shockwave.scale = Vector3.ONE * strength * (0.5 + ratio * 2.5)
		shockwave_material.set_shader_parameter("effect_color", Color(1.0, 0.68, 0.24, (1.0 - ratio) * 0.22))
	for piece in pieces:
		piece.velocity.y -= 8.0 * dt
		piece.node.position += piece.velocity * dt
		piece.node.rotation += Vector3(1.1, 1.7, 0.8) * dt
		piece.node.scale = Vector3.ONE * max(0.05, 1.0 - ratio)
		piece.material.albedo_color.a = 1.0 - ratio
	if age >= final_lifetime:
		queue_free()
