extends Node3D

const GroundShader = preload("res://shaders/coastal_ground.gdshader")
const CloudShader = preload("res://shaders/cloud_veil.gdshader")
const WaterNormal = preload("res://assets/ground/water-normal-256.png")
const CloudTexture = preload("res://assets/ground/cloud-veil-512.png")
const CoreAlbedo = preload("res://assets/ground/ground-core-2k.jpg")
const CoreMask = preload("res://assets/ground/ground-mask-core-2k.png")
const ApronAlbedo = preload("res://assets/ground/ground-apron-1k.jpg")
const ApronMask = preload("res://assets/ground/ground-mask-apron-1k.png")

var cloud_root


func _ready() -> void:
	build_surface(50000.0, -2.0, ApronAlbedo, ApronMask)
	build_surface(20000.0, 0.0, CoreAlbedo, CoreMask)
	build_clouds()


func build_surface(size: float, height: float, albedo: Texture2D, mask: Texture2D) -> void:
	var ground = MeshInstance3D.new()
	ground.name = "GroundCore" if size < 25000.0 else "GroundApron"
	var plane = PlaneMesh.new()
	plane.size = Vector2(size, size)
	ground.mesh = plane
	ground.position.y = height
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = GroundShader
	material.set_shader_parameter("ground_albedo", albedo)
	material.set_shader_parameter("ground_mask", mask)
	material.set_shader_parameter("water_normal_texture", WaterNormal)
	material.set_shader_parameter("map_size", size)
	ground.material_override = material
	add_child(ground)


func build_clouds() -> void:
	cloud_root = Node3D.new()
	cloud_root.name = "CloudVeil"
	add_child(cloud_root)
	var specs = [
		[Vector3(-2600.0, 600.0, 2200.0), Vector2(1800.0, 1300.0), 0.42],
		[Vector3(1800.0, 650.0, 2800.0), Vector2(2200.0, 1400.0), 0.50],
		[Vector3(-500.0, 560.0, 4300.0), Vector2(2600.0, 1600.0), 0.46],
		[Vector3(4000.0, 700.0, 5400.0), Vector2(2300.0, 1500.0), 0.44],
		[Vector3(-4500.0, 620.0, 5700.0), Vector2(2800.0, 1800.0), 0.40],
		[Vector3(500.0, 780.0, 7200.0), Vector2(3400.0, 1900.0), 0.36],
	]
	for index in range(specs.size()):
		var spec = specs[index]
		var cloud = MeshInstance3D.new()
		cloud.name = "CloudCard%02d" % index
		var plane = PlaneMesh.new()
		plane.size = spec[1]
		cloud.mesh = plane
		cloud.position = spec[0]
		cloud.rotation.y = index * 0.63
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material = ShaderMaterial.new()
		material.shader = CloudShader
		material.set_shader_parameter("cloud_texture", CloudTexture)
		material.set_shader_parameter("opacity", spec[2])
		cloud.material_override = material
		cloud_root.add_child(cloud)


func set_clouds_visible(value: bool) -> void:
	if cloud_root != null:
		cloud_root.visible = value
