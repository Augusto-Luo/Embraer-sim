extends Node3D

const AirportScene = preload("res://assets/aerodrome-training.glb")
const RUNWAY_LENGTH = 2200.0
const RUNWAY_WIDTH = 45.0
const DECK_HEIGHT = 0.40
const SITE = Vector3(2500.0, 0.0, -2000.0)
const SPAWN_OFFSET = Vector3(0.0, DECK_HEIGHT + 1.2, -1000.0)


func _ready() -> void:
	position = SITE
	name = "TrainingAirport"
	var airport = AirportScene.instantiate()
	airport.name = "AerodromeBuildings"
	airport.position.y = 0.15
	add_child(airport)
	# Extend pavement, not the entire source model: buildings and parked aircraft
	# retain their original scale while the runway can later accommodate a KC-390.
	add_surface("RunwayShoulder", Vector2(63, RUNWAY_LENGTH + 40), 0.26, Color("777a65"))
	add_surface("Runway", Vector2(RUNWAY_WIDTH, RUNWAY_LENGTH), DECK_HEIGHT, Color("343a3b"))
	build_markings()
	build_edge_lights()


func add_surface(node_name: String, size: Vector2, height: float, color: Color) -> void:
	var node = MeshInstance3D.new()
	node.name = node_name
	var mesh = PlaneMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position.y = height
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	material.metallic_specular = 0.1
	node.material_override = material
	add_child(node)


func build_markings() -> void:
	var strips: Array[Rect2] = []
	# A single mesh holds all paint, avoiding a node/draw call per stripe.
	for z in range(-900, 901, 60):
		strips.append(Rect2(-0.45, z - 15.0, 0.9, 30.0))
	for side in [-1.0, 1.0]:
		strips.append(Rect2(side * (RUNWAY_WIDTH * 0.5 - 1.1) - 0.15, -1100, 0.3, RUNWAY_LENGTH))
	for end in [-1.0, 1.0]:
		for x in [-17.0, -13.0, -9.0, -5.0, 5.0, 9.0, 13.0, 17.0]:
			strips.append(Rect2(x - 1.2, end * 1040.0 - 18, 2.4, 36))
		for x in [-13.0, 9.0]:
			strips.append(Rect2(x, end * 780.0 - 22, 4, 44))
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	for strip in strips:
		var a = Vector3(strip.position.x, DECK_HEIGHT + 0.015, strip.position.y)
		var b = a + Vector3(strip.size.x, 0, 0)
		var c = a + Vector3(strip.size.x, 0, strip.size.y)
		var d = a + Vector3(0, 0, strip.size.y)
		for point in [a, c, b, a, d, c]:
			vertices.append(point)
			normals.append(Vector3.UP)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var paint = StandardMaterial3D.new()
	paint.albedo_color = Color("e1e4d9")
	paint.roughness = 1.0
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, paint)
	var instance = MeshInstance3D.new()
	instance.name = "RunwayPaint"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	for spec in [["36", -975.0, PI], ["18", 975.0, 0.0]]:
		var number = MeshInstance3D.new()
		number.name = "Runway" + spec[0]
		var text = TextMesh.new()
		text.text = spec[0]
		text.font = preload("res://assets/fonts/VT323-Regular.ttf")
		text.font_size = 128
		text.pixel_size = 0.075
		text.depth = 0.0
		number.mesh = text
		number.material_override = paint
		number.rotation = Vector3(-PI * 0.5, spec[2], 0.0)
		number.position = Vector3(0, DECK_HEIGHT + 0.02, spec[1])
		number.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(number)


func build_edge_lights() -> void:
	var lights = MultiMeshInstance3D.new()
	lights.name = "RunwayEdgeMarkers"
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.35, 0.35, 0.35)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("e1deb9")
	mesh.material = material
	multimesh.mesh = mesh
	multimesh.instance_count = 76
	var index = 0
	for side in [-1.0, 1.0]:
		for z in range(38):
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(side * 24.5, 0.5, -1110.0 + z * 60.0)))
			index += 1
	lights.multimesh = multimesh
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)


func ground_height(x: float, z: float) -> float:
	var local = Vector2(x - SITE.x, z - SITE.z)
	return DECK_HEIGHT if abs(local.x) <= 31.5 and abs(local.y) <= RUNWAY_LENGTH * 0.5 + 20.0 else 0.0


func on_runway(world_position: Vector3) -> bool:
	return abs(world_position.x - SITE.x) <= RUNWAY_WIDTH * 0.5 and abs(world_position.z - SITE.z) <= RUNWAY_LENGTH * 0.5


func spawn_position() -> Vector3:
	return SITE + SPAWN_OFFSET


func runway_remaining(world_position: Vector3) -> float:
	return max(0.0, SITE.z + RUNWAY_LENGTH * 0.5 - world_position.z)
