extends Node3D

var controller
var material: ShaderMaterial
var guide_time = 0.0


func _ready() -> void:
	name = "FlightGuide"
	var course = controller.takeoff
	var points = course.get_route()
	var vertices = PackedVector3Array()
	var uv = PackedVector2Array()
	# Two crossed ribbons remain legible in a bank and use one static mesh.
	for index in range(points.size() - 1):
		var a = points[index] + Vector3.UP * 0.35
		var b = points[index + 1] + Vector3.UP * 0.35
		var direction = (b - a).normalized()
		var right = direction.cross(Vector3.UP).normalized() * 0.9
		var d0 = course.route_distances[index]
		var d1 = course.route_distances[index + 1]
		var final = 1.0 if course.route_legs[index] in ["final", "rollout"] else 0.0
		for axis in [right, Vector3.UP * 0.65]:
			for corner in [0, 1, 2, 0, 2, 3]:
				vertices.append([a - axis, a + axis, b + axis, b - axis][corner])
				uv.append(Vector2(d0 if corner < 2 else d1, final))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/flight_guide.gdshader")
	var instance = MeshInstance3D.new()
	instance.name = "ContinuousRoute"
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _process(dt: float) -> void:
	visible = not controller.intro_active and not controller.observing and not controller.settings_open and not controller.takeoff.completed
	if not (controller.paused or controller.frozen or controller.settings_open or controller.observing or controller.observation_frozen):
		guide_time += dt
	material.set_shader_parameter("guide_time", guide_time)
	material.set_shader_parameter("progress", controller.takeoff.route_progress)
