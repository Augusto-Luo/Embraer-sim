extends Node3D

const TIP_POSITIONS = [Vector3(5.88, -0.56, -0.65), Vector3(-4.74, -0.56, -0.65)]
const LIFETIME = 0.85
const SAMPLE_INTERVAL = 0.0166667
const MAX_POINTS = 56

var aircraft
var strength = 0.0
var histories = [[], []]
var sample_timers = [0.0, 0.0]
var mesh_instances = []
var trail_material


func _ready() -> void:
	trail_material = StandardMaterial3D.new()
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.vertex_color_use_as_albedo = true
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_material.albedo_color = Color.WHITE
	for side in range(2):
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "WingtipTrail%d" % side
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var immediate = ImmediateMesh.new()
		mesh_instance.mesh = immediate
		mesh_instance.material_override = trail_material
		add_child(mesh_instance)
		mesh_instances.append(mesh_instance)


func update_trail(delta: float, model, hold: bool) -> void:
	if aircraft == null or hold:
		return
	var speed_factor = clamp((model.speed - 55.0) / 65.0, 0.0, 1.0)
	var manoeuvre = 0.07 + abs(model.inputs.pitch) * 0.70 + abs(model.inputs.roll) * 0.28 + abs(sin(model.bank)) * 0.40
	var target = speed_factor * clamp(manoeuvre, 0.0, 1.0)
	strength = lerp(strength, target, 1.0 - exp(-delta * 5.0))
	for side in range(2):
		_update_side(side, delta)


func _update_side(side: int, delta: float) -> void:
	var history = histories[side]
	var emitter = aircraft.to_global(TIP_POSITIONS[side])
	if not history.is_empty() and history[0].position.distance_squared_to(emitter) > 900.0:
		history.clear()
	for point in history:
		point.age += delta
	while not history.is_empty() and history[-1].age > LIFETIME:
		history.pop_back()
	sample_timers[side] += delta
	if sample_timers[side] >= SAMPLE_INTERVAL:
		history.push_front({
			"position": emitter,
			"axis": aircraft.global_transform.basis.x.normalized(),
			"age": 0.0,
		})
		sample_timers[side] = 0.0
		if history.size() > MAX_POINTS:
			history.pop_back()
	_redraw(side)


func _redraw(side: int) -> void:
	var immediate = mesh_instances[side].mesh as ImmediateMesh
	immediate.clear_surfaces()
	var history = histories[side]
	var camera = get_viewport().get_camera_3d()
	if camera == null or history.size() < 2 or strength < 0.008:
		return
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, trail_material)
	for index in range(history.size() - 1):
		var a = history[index]
		var b = history[index + 1]
		var midpoint = (a.position + b.position) * 0.5
		var view_direction = (camera.global_position - midpoint).normalized()
		var axis_a = _projected_axis(a.axis, view_direction)
		var axis_b = _projected_axis(b.axis, view_direction)
		var width_a = _point_width(a.age)
		var width_b = _point_width(b.age)
		var color_a = _point_color(a.age)
		var color_b = _point_color(b.age)
		var a0 = a.position - axis_a * width_a
		var a1 = a.position + axis_a * width_a
		var b0 = b.position - axis_b * width_b
		var b1 = b.position + axis_b * width_b
		_add_vertex(immediate, a0, color_a)
		_add_vertex(immediate, b0, color_b)
		_add_vertex(immediate, a1, color_a)
		_add_vertex(immediate, a1, color_a)
		_add_vertex(immediate, b0, color_b)
		_add_vertex(immediate, b1, color_b)
	immediate.surface_end()


func _projected_axis(axis: Vector3, view_direction: Vector3) -> Vector3:
	var projected = axis - view_direction * axis.dot(view_direction)
	if projected.length_squared() < 0.001:
		projected = Vector3.UP - view_direction * view_direction.y
	return projected.normalized()


func _point_width(age: float) -> float:
	return (0.025 + age * 0.12) * (0.75 + strength * 0.25)


func _point_color(age: float) -> Color:
	var life = clamp(age / LIFETIME, 0.0, 1.0)
	var fade_in = clamp(age / 0.05, 0.0, 1.0)
	var alpha = 0.28 * strength * pow(1.0 - life, 1.6) * fade_in
	return Color(0.91, 0.96, 1.0, alpha)


func _add_vertex(mesh: ImmediateMesh, point: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(point)


func clear_trails() -> void:
	strength = 0.0
	for side in range(2):
		histories[side].clear()
		sample_timers[side] = 0.0
		if not mesh_instances.is_empty():
			var immediate = mesh_instances[side].mesh as ImmediateMesh
			immediate.clear_surfaces()
