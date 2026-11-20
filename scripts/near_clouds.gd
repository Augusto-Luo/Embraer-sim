extends Node3D

const NearCloudShader = preload("res://shaders/near_cloud.gdshader")
const CloudTexture = preload("res://assets/ground/near-cloud-512.png")

var aircraft: Node3D
var high_altitude = false
# Set before adding this node to the scene tree. Day missions keep white clouds.
var night_mode = false
var night_tint = Color(0.085, 0.115, 0.17)
var clouds = []
var applied_clearance = -1.0
var applied_moonlight = -1.0
var applied_lightning = -1.0
var applied_lightning_direction = Vector3.ZERO
const DEFAULT_LIGHTNING_DIRECTION = Vector3(-0.55, 0.35, 0.76)
var recycle_index = 0
var wind = Vector3(1.2, 0.0, -0.5)


func _ready() -> void:
	var origin = aircraft.global_position if is_instance_valid(aircraft) else Vector3(0.0, 1200.0, 0.0)
	var specs = [
		[Vector3(-160.0, -30.0, 380.0), Vector2(170.0, 110.0), 0.32],
		[Vector3(220.0, 60.0, 620.0), Vector2(230.0, 150.0), 0.30],
		[Vector3(-420.0, -100.0, 850.0), Vector2(300.0, 190.0), 0.27],
		[Vector3(430.0, 120.0, 1180.0), Vector2(340.0, 210.0), 0.26],
		[Vector3(0.0, 0.0, 560.0), Vector2(140.0, 90.0), 0.40],
		[Vector3(-650.0, 180.0, 1500.0), Vector2(420.0, 260.0), 0.22],
		[Vector3(600.0, -180.0, 1550.0), Vector2(300.0, 200.0), 0.24],
		[Vector3(-80.0, 100.0, 1850.0), Vector2(380.0, 220.0), 0.21],
		[Vector3(800.0, 40.0, 2100.0), Vector2(400.0, 250.0), 0.20],
		[Vector3(-900.0, -120.0, 2300.0), Vector2(500.0, 300.0), 0.18],
	]
	if high_altitude:
		# Thick banks above, below and beside a clear pursuit corridor.
		# Reuse the existing 512px texture, not additional volumetric passes.
		specs.clear()
		for index in range(24):
			var side = -1.0 if index % 2 == 0 else 1.0
			var lateral = side * (450.0 + random_unit(index * 7 + 1) * 1000.0)
			var ahead = 180.0 + random_unit(index * 7 + 2) * 2300.0
			var vertical = (random_unit(index * 7 + 3) - 0.5) * 1400.0
			var width = 450.0 + random_unit(index * 7 + 4) * 500.0
			specs.append([Vector3(lateral, vertical, ahead), Vector2(width, width * 0.56), 0.35 + random_unit(index * 7 + 5) * 0.12])
	for index in range(specs.size()):
		var spec = specs[index]
		var cloud = MeshInstance3D.new()
		cloud.name = "NearCloud%02d" % index
		var quad = QuadMesh.new()
		quad.size = spec[1]
		cloud.mesh = quad
		cloud.position = origin + spec[0]
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material = ShaderMaterial.new()
		material.shader = NearCloudShader
		material.set_shader_parameter("cloud_texture", CloudTexture)
		material.set_shader_parameter("opacity", spec[2] * (0.7 if night_mode else 1.0))
		material.set_shader_parameter("uv_rotation", index * 0.71)
		if night_mode:
			material.set_shader_parameter("cloud_tint", night_tint)
			material.set_shader_parameter("night_factor", 1.0)
			material.set_shader_parameter("lightning_direction", DEFAULT_LIGHTNING_DIRECTION)
		cloud.set_meta("base_opacity", spec[2] * (0.7 if night_mode else 1.0))
		cloud.material_override = material
		add_child(cloud)
		clouds.append(cloud)


func _process(dt: float) -> void:
	if not is_instance_valid(aircraft):
		visible = false
		return
	var controller = get_parent()
	visible = not bool(controller.get("observing"))
	if not visible:
		return
	var animate = not bool(controller.get("paused")) and not bool(controller.get("observation_frozen")) and not bool(controller.get("settings_open")) and not bool(controller.get("frozen"))
	if night_mode:
		# Use the director/controller's frozen envelope; no separate clock can
		# continue flashing while the mission is paused or settings are open.
		var flash_value = controller.get("echo_lightning")
		var lightning = clamp(float(flash_value), 0.0, 1.0) if flash_value != null else 0.0
		var direction_value = controller.get("echo_lightning_direction")
		var direction = direction_value if direction_value is Vector3 else DEFAULT_LIGHTNING_DIRECTION
		if direction.length_squared() < 0.01:
			direction = DEFAULT_LIGHTNING_DIRECTION
		if abs(lightning - applied_lightning) >= 0.001 or direction != applied_lightning_direction:
			for cloud in clouds:
				cloud.material_override.set_shader_parameter("lightning_strength", lightning)
				cloud.material_override.set_shader_parameter("lightning_direction", direction)
			applied_lightning = lightning
			applied_lightning_direction = direction
		var moonlight = float(controller.get("echo_moonlight"))
		if abs(moonlight - applied_moonlight) >= 0.01:
			for cloud in clouds:
				cloud.material_override.set_shader_parameter("cloud_tint", night_tint * lerp(1.0, 1.6, moonlight))
			applied_moonlight = moonlight
		var clearance = float(controller.get("echo_clearance"))
		if abs(clearance - applied_clearance) >= 0.01 or clearance == 0.0 and applied_clearance != 0.0:
			for cloud in clouds:
				cloud.material_override.set_shader_parameter("opacity", float(cloud.get_meta("base_opacity")) * (1.0 - clearance))
			applied_clearance = clearance
	var inverse = aircraft.global_transform.affine_inverse()
	for cloud in clouds:
		if animate:
			cloud.position += wind * dt
		var local = inverse * cloud.global_position
		var max_ahead = 3400.0 if high_altitude else 2800.0
		var max_side = 2300.0 if high_altitude else 1700.0
		var max_height = 1100.0 if high_altitude else 750.0
		if local.z < -350.0 or local.z > max_ahead or abs(local.x) > max_side or abs(local.y) > max_height:
			recycle_cloud(cloud)


func random_unit(index: int) -> float:
	return fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0)


func recycle_cloud(cloud: MeshInstance3D) -> void:
	recycle_index += 1
	var forward = aircraft.global_transform.basis.z.normalized()
	var right = aircraft.global_transform.basis.x.normalized()
	var ahead = 1500.0 + random_unit(recycle_index * 3 + 1) * 700.0
	var lateral = (random_unit(recycle_index * 3 + 2) - 0.5) * 1600.0
	var vertical = (random_unit(recycle_index * 3 + 3) - 0.5) * 500.0
	if high_altitude:
		ahead = 1800.0 + random_unit(recycle_index * 3 + 1) * 900.0
		var side = -1.0 if recycle_index % 2 == 0 else 1.0
		lateral = side * (400.0 + random_unit(recycle_index * 3 + 2) * 1300.0)
		vertical = (random_unit(recycle_index * 3 + 3) - 0.5) * 1500.0
	cloud.global_position = aircraft.global_position + forward * ahead + right * lateral + Vector3.UP * vertical
