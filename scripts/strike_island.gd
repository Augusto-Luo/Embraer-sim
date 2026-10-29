extends Node3D

const CITY_PATH = "res://assets/jamsil/jamsil-city.glb"
const MANIFEST_PATH = "res://assets/jamsil/city-manifest.json"
const OceanShader = preload("res://shaders/strike_ocean.gdshader")
const LandShader = preload("res://shaders/strike_land.gdshader")
const NearCloudShader = preload("res://shaders/near_cloud.gdshader")
const VeilShader = preload("res://shaders/cloud_veil.gdshader")
const NearCloudTexture = preload("res://assets/ground/near-cloud-512.png")
const VeilTexture = preload("res://assets/ground/cloud-veil-512.png")
const WaterNormal = preload("res://assets/ground/water-normal-256.png")
# The source GLB remains at its authored scale. Apply the same transform to
# rendered geometry and all geographic metadata around the 8 m city base.
const MAP_SCALE = 1.5
const LAND_HEIGHT = 8.0
const LAKE_FLOOR = LAND_HEIGHT + (3.0 - LAND_HEIGHT) * MAP_SCALE
const SEA_LEVEL = 0.0
const COAST_SEGMENTS = 128
const GRID_SIZE = 100.0
const PAUSE_FLAGS = ["paused", "observing", "observation_frozen", "settings_open", "frozen"]

var city_path = CITY_PATH
var manifest_path = MANIFEST_PATH
var manifest: Dictionary = {}
var city_bounds = AABB(Vector3(-578.604 * MAP_SCALE, 8.0, -512.378 * MAP_SCALE), Vector3(1157.208, 555.0, 1024.756) * MAP_SCALE)
var city_footprint = Rect2(Vector2(-578.604, -512.378) * MAP_SCALE, Vector2(1157.208, 1024.756) * MAP_SCALE)
var city_footprint_area = 0.0
var land_area = 0.0
var noncity_land_area = 0.0
var grass_area = 0.0
var sand_area = 0.0
var coast_polygon = PackedVector2Array()
var island_bounds = AABB()
var landmark_position = Vector3(0.0, LAND_HEIGHT + 555.0 * MAP_SCALE, 0.0)
var city_root: Node3D
var ocean: MeshInstance3D
var coast_mesh: MeshInstance3D
var cloud_root: Node3D
var ocean_material: ShaderMaterial
var collision_boxes: Array[AABB] = []
var collision_grid: Dictionary = {}
var lake_triangles: Array[PackedVector2Array] = []
var lake_grid: Dictionary = {}
var cloud_specs: Array = []
var cloud_elapsed = 0.0
var simulation_paused = false
var clouds_visible = true
var controller_flags: Array[String] = []
var ring_polygons: Array[PackedVector2Array] = []


func _init() -> void:
	configure()


func configure(new_city_path: String = CITY_PATH, new_manifest_path: String = MANIFEST_PATH) -> void:
	city_path = new_city_path
	manifest_path = new_manifest_path
	manifest = {}
	if FileAccess.file_exists(manifest_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary:
			manifest = parsed
	var source_bounds = manifest.get("bounds", {})
	if source_bounds is Dictionary and source_bounds.has("min") and source_bounds.has("max"):
		var minimum = vector3_from(source_bounds.min)
		var maximum = vector3_from(source_bounds.max)
		city_bounds = AABB(city_to_world(minimum), (maximum - minimum) * MAP_SCALE)
	city_footprint = Rect2(Vector2(city_bounds.position.x, city_bounds.position.z), Vector2(city_bounds.size.x, city_bounds.size.z))
	var footprint = manifest.get("city_footprint", {})
	if footprint is Dictionary and footprint.has("min") and footprint.has("max"):
		var minimum = Vector2(float(footprint.min[0]), float(footprint.min[1]))
		var maximum = Vector2(float(footprint.max[0]), float(footprint.max[1]))
		city_footprint = Rect2(minimum * MAP_SCALE, (maximum - minimum) * MAP_SCALE)
	city_footprint_area = city_footprint.size.x * city_footprint.size.y
	landmark_position = Vector3(city_footprint.get_center().x, city_bounds.end.y, city_footprint.get_center().y)
	build_collision_metadata()
	build_coast_metadata()
	build_cloud_metadata()


func vector3_from(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func city_to_world(source_position: Vector3) -> Vector3:
	return source_position * MAP_SCALE + Vector3.UP * LAND_HEIGHT


func lake_water_height() -> float:
	return LAND_HEIGHT + float(manifest.get("lake_water_height", -3.96)) * MAP_SCALE


func build_collision_metadata() -> void:
	collision_boxes.clear()
	collision_grid.clear()
	lake_triangles.clear()
	lake_grid.clear()
	for entry in manifest.get("building_aabbs", []):
		if entry is not Dictionary or not entry.has("min") or not entry.has("max"):
			continue
		var minimum = city_to_world(vector3_from(entry.min))
		var maximum = city_to_world(vector3_from(entry.max))
		var bounds = AABB(minimum, maximum - minimum)
		var index = collision_boxes.size()
		collision_boxes.append(bounds)
		index_bounds(collision_grid, Rect2(Vector2(minimum.x, minimum.z), Vector2(bounds.size.x, bounds.size.z)), index)
		if String(entry.get("name", "")).to_lower().contains("tower"):
			landmark_position = Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)
	for entry in manifest.get("lake_triangles_xz", []):
		if entry is not Array or entry.size() != 3:
			continue
		var triangle = PackedVector2Array()
		for point in entry:
			triangle.append(Vector2(float(point[0]), float(point[1])) * MAP_SCALE)
		var index = lake_triangles.size()
		lake_triangles.append(triangle)
		var bounds = Rect2(triangle[0], Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
		index_bounds(lake_grid, bounds, index)


func index_bounds(grid: Dictionary, bounds: Rect2, index: int) -> void:
	for x in range(floori(bounds.position.x / GRID_SIZE), floori(bounds.end.x / GRID_SIZE) + 1):
		for z in range(floori(bounds.position.y / GRID_SIZE), floori(bounds.end.y / GRID_SIZE) + 1):
			var key = Vector2i(x, z)
			if not grid.has(key):
				grid[key] = PackedInt32Array()
			grid[key].append(index)


func rectangular_distance(point: Vector2) -> float:
	var outside = (point - city_footprint.get_center()).abs() - city_footprint.size * 0.5
	return Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length()


func margin_at(angle: float) -> float:
	return 62.0 * MAP_SCALE * (0.94 + 0.26 * sin(angle * 3.0 + 0.4) + 0.17 * sin(angle * 7.0 - 1.1) + 0.08 * cos(angle * 11.0))


func coast_point(angle: float, margin: float) -> Vector2:
	var direction = Vector2(cos(angle), sin(angle))
	var half = city_footprint.size * 0.5
	var inner = minf(half.x / maxf(absf(direction.x), 0.00001), half.y / maxf(absf(direction.y), 0.00001))
	var outer = inner + margin * 1.5 + 1.0
	var center = city_footprint.get_center()
	# Offset the rectangle by a rounded, uneven margin. This supports its corners
	# while avoiding both a rectangular sea edge and a large empty island apron.
	for iteration in range(20):
		var middle = (inner + outer) * 0.5
		if rectangular_distance(center + direction * middle) < margin:
			inner = middle
		else:
			outer = middle
	return center + direction * ((inner + outer) * 0.5)


func polygon_area(polygon: PackedVector2Array) -> float:
	var area = 0.0
	for index in range(polygon.size()):
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(area) * 0.5


func build_coast_metadata() -> void:
	ring_polygons.clear()
	for ring in range(6):
		var polygon = PackedVector2Array()
		for index in range(COAST_SEGMENTS):
			var angle = TAU * float(index) / float(COAST_SEGMENTS)
			var margin = margin_at(angle)
			var offsets = [0.0, 0.0, margin * 0.68, margin * 0.90, margin + 10.0 * MAP_SCALE, margin + 30.0 * MAP_SCALE]
			polygon.append(coast_point(angle, offsets[ring]))
		ring_polygons.append(polygon)
	coast_polygon = ring_polygons[4]
	land_area = polygon_area(coast_polygon)
	noncity_land_area = land_area - city_footprint_area
	grass_area = polygon_area(ring_polygons[2]) - city_footprint_area
	sand_area = noncity_land_area - grass_area
	var minimum = Vector2(INF, INF)
	var maximum = Vector2(-INF, -INF)
	for point in ring_polygons[5]:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	island_bounds = AABB(Vector3(minimum.x, -4.0, minimum.y), Vector3(maximum.x - minimum.x, LAND_HEIGHT + 4.0, maximum.y - minimum.y))


func build_cloud_metadata() -> void:
	cloud_specs = []
	var half = city_footprint.size * (0.5 / MAP_SCALE)
	var center = city_footprint.get_center()
	var specs = [
		[Vector3(-180.0, 145.0, -240.0), Vector2(300.0, 120.0), 0.22],
		[Vector3(270.0, 235.0, -110.0), Vector2(330.0, 130.0), 0.23],
		[Vector3(-155.0, 335.0, -175.0), Vector2(280.0, 110.0), 0.20],
		[Vector3(half.x + 110.0, 385.0, half.y + 210.0), Vector2(450.0, 180.0), 0.17],
		[Vector3(-half.x - 420.0, 240.0, -half.y - 280.0), Vector2(580.0, 220.0), 0.18],
		[Vector3(half.x + 350.0, 310.0, -half.y - 340.0), Vector2(510.0, 195.0), 0.16],
		[Vector3(80.0, 335.0, half.y + 560.0), Vector2(600.0, 200.0), 0.14],
		[Vector3(-300.0, 180.0, half.y + 490.0), Vector2(420.0, 170.0), 0.16],
		# Extra shallow banks frame the attack lanes rather than hiding their
		# targets. The central avenue and nearshore working area stay open.
		[Vector3(-425.0, 190.0, -10.0), Vector2(270.0, 105.0), 0.20],
		[Vector3(-390.0, 280.0, 270.0), Vector2(310.0, 120.0), 0.19],
		[Vector3(-half.x - 90.0, 405.0, 80.0), Vector2(390.0, 155.0), 0.18],
		[Vector3(435.0, 260.0, 250.0), Vector2(300.0, 115.0), 0.18],
		[Vector3(half.x + 80.0, 390.0, -260.0), Vector2(400.0, 150.0), 0.18],
		[Vector3(-340.0, 435.0, -430.0), Vector2(360.0, 130.0), 0.17],
		[Vector3(360.0, 420.0, -420.0), Vector2(330.0, 125.0), 0.16],
		[Vector3(-half.x - 280.0, 165.0, 370.0), Vector2(440.0, 170.0), 0.17],
	]
	for index in range(specs.size()):
		var spec = specs[index]
		cloud_specs.append({"position": scaled_cloud_position(spec[0]) + Vector3(center.x, 0.0, center.y), "size": spec[1] * MAP_SCALE, "opacity": spec[2], "veil": false})
	cloud_specs.append({"position": scaled_cloud_position(Vector3(-half.x - 450.0, 260.0, half.y + 230.0)) + Vector3(center.x, 0.0, center.y), "size": Vector2(800.0, 520.0) * MAP_SCALE, "opacity": 0.12, "veil": true})
	cloud_specs.append({"position": scaled_cloud_position(Vector3(half.x + 380.0, 340.0, half.y + 480.0)) + Vector3(center.x, 0.0, center.y), "size": Vector2(900.0, 590.0) * MAP_SCALE, "opacity": 0.12, "veil": true})


func scaled_cloud_position(previous_position: Vector3) -> Vector3:
	return city_to_world(previous_position - Vector3.UP * LAND_HEIGHT)


func _ready() -> void:
	name = "StrikeIsland"
	for property in get_parent().get_property_list():
		if String(property.name) in PAUSE_FLAGS:
			controller_flags.append(String(property.name))
	build_ocean()
	build_land()
	build_city()
	build_clouds()


func build_city() -> void:
	city_root = Node3D.new()
	city_root.name = "City"
	city_root.position.y = LAND_HEIGHT
	city_root.scale = Vector3.ONE * MAP_SCALE
	add_child(city_root)
	if ResourceLoader.exists(city_path):
		var scene = load(city_path)
		if scene is PackedScene:
			city_root.add_child(scene.instantiate())


func build_ocean() -> void:
	ocean = MeshInstance3D.new()
	ocean.name = "Ocean"
	var plane = PlaneMesh.new()
	plane.size = Vector2(240000.0, 240000.0)
	ocean.mesh = plane
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = OceanShader
	ocean_material.set_shader_parameter("water_normal_texture", WaterNormal)
	ocean_material.set_shader_parameter("city_half_size", city_footprint.size * 0.5)
	ocean_material.set_shader_parameter("city_center", city_footprint.get_center())
	ocean_material.set_shader_parameter("map_scale", MAP_SCALE)
	ocean.material_override = ocean_material
	add_child(ocean)


func build_land() -> void:
	coast_mesh = MeshInstance3D.new()
	coast_mesh.name = "IslandLand"
	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var center = city_footprint.get_center()
	vertices.append(Vector3(center.x, LAKE_FLOOR, center.y))
	colors.append(Color("#8b8765").srgb_to_linear())
	normals.append(Vector3.UP)
	var heights = [LAKE_FLOOR, LAND_HEIGHT - 0.08, 5.8, 2.6, SEA_LEVEL, -4.0]
	var palette = [Color("#8b8765"), Color("#61734c"), Color("#687c50"), Color("#b6b18c"), Color("#c7b991"), Color("#9baf9d")]
	for ring in range(ring_polygons.size()):
		for point in ring_polygons[ring]:
			vertices.append(Vector3(point.x, heights[ring], point.y))
			colors.append(palette[ring].srgb_to_linear())
			normals.append(Vector3.UP)
	for index in range(COAST_SEGMENTS):
		var next = (index + 1) % COAST_SEGMENTS
		indices.append_array(PackedInt32Array([0, 1 + index, 1 + next]))
	for ring in range(ring_polygons.size() - 1):
		for index in range(COAST_SEGMENTS):
			var next = (index + 1) % COAST_SEGMENTS
			var a = 1 + ring * COAST_SEGMENTS + index
			var b = 1 + ring * COAST_SEGMENTS + next
			var c = a + COAST_SEGMENTS
			var d = b + COAST_SEGMENTS
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	coast_mesh.mesh = mesh
	var material = ShaderMaterial.new()
	material.shader = LandShader
	coast_mesh.material_override = material
	coast_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coast_mesh)


func build_clouds() -> void:
	cloud_root = Node3D.new()
	cloud_root.name = "CityCloudBanks"
	cloud_root.visible = clouds_visible
	add_child(cloud_root)
	for index in range(cloud_specs.size()):
		var spec = cloud_specs[index]
		var cloud = MeshInstance3D.new()
		cloud.name = "CityCloud%02d" % index
		var material = ShaderMaterial.new()
		if spec.veil:
			var plane = PlaneMesh.new()
			plane.size = spec.size
			cloud.mesh = plane
			material.shader = VeilShader
			material.set_shader_parameter("cloud_texture", VeilTexture)
			cloud.rotation.y = float(index) * 0.71
		else:
			var quad = QuadMesh.new()
			quad.size = spec.size
			cloud.mesh = quad
			material.shader = NearCloudShader
			material.set_shader_parameter("cloud_texture", NearCloudTexture)
			material.set_shader_parameter("uv_rotation", float(index) * 0.71)
		material.set_shader_parameter("opacity", spec.opacity)
		cloud.position = spec.position
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.material_override = material
		cloud_root.add_child(cloud)


func _process(dt: float) -> void:
	if simulation_paused:
		return
	for flag in controller_flags:
		if bool(get_parent().get(flag)):
			return
	cloud_elapsed += dt
	if ocean_material != null:
		ocean_material.set_shader_parameter("ocean_time", cloud_elapsed)
	if cloud_root != null:
		for index in range(cloud_root.get_child_count()):
			var offset = Vector3(sin(cloud_elapsed * 0.006 + index) * 18.0, sin(cloud_elapsed * 0.003 + index) * 2.0, cos(cloud_elapsed * 0.004 + index) * 15.0)
			cloud_root.get_child(index).position = cloud_specs[index].position + offset * MAP_SCALE


func is_lake(point: Vector2) -> bool:
	var key = Vector2i(floori(point.x / GRID_SIZE), floori(point.y / GRID_SIZE))
	for index in lake_grid.get(key, PackedInt32Array()):
		if Geometry2D.is_point_in_polygon(point, lake_triangles[index]):
			return true
	return false


func ground_height(x: float, z: float) -> float:
	var point = Vector2(x, z)
	if city_footprint.has_point(point):
		return LAKE_FLOOR if is_lake(point) else LAND_HEIGHT
	if not Geometry2D.is_point_in_polygon(point, coast_polygon):
		return SEA_LEVEL
	var angle = (point - city_footprint.get_center()).angle()
	var margin = margin_at(angle)
	var distance = rectangular_distance(point)
	if distance < margin * 0.68:
		return lerpf(LAND_HEIGHT - 0.08, 5.8, distance / (margin * 0.68))
	if distance < margin * 0.90:
		return lerpf(5.8, 2.6, inverse_lerp(margin * 0.68, margin * 0.90, distance))
	return maxf(0.0, lerpf(2.6, 0.0, inverse_lerp(margin * 0.90, margin + 10.0 * MAP_SCALE, distance)))


func obstacle_height(x: float, z: float) -> float:
	var highest = -INF
	var key = Vector2i(floori(x / GRID_SIZE), floori(z / GRID_SIZE))
	for index in collision_grid.get(key, PackedInt32Array()):
		var bounds = collision_boxes[index]
		if x >= bounds.position.x and x <= bounds.end.x and z >= bounds.position.z and z <= bounds.end.z:
			highest = maxf(highest, bounds.end.y)
	return highest


func spawn_position() -> Vector3:
	var center = city_footprint.get_center()
	# Keep the approach about 1.7 km outside the enlarged city, with clearance
	# above the taller skyline rather than scaling the whole flight envelope.
	return Vector3(center.x - 520.0 * MAP_SCALE, maxf(1000.0, landmark_position.y + 180.0), center.y - city_footprint.size.y * 0.5 - 1700.0)


func spawn_orientation() -> Quaternion:
	var target = Vector3(landmark_position.x, spawn_position().y, landmark_position.z)
	return Basis.looking_at((target - spawn_position()).normalized(), Vector3.UP, true).get_rotation_quaternion()


func set_clouds_visible(value: bool) -> void:
	clouds_visible = value
	if cloud_root != null:
		cloud_root.visible = value


func set_simulation_paused(value: bool) -> void:
	simulation_paused = value


func diagnostic_snapshot() -> Dictionary:
	return {
		"city_path": city_path, "manifest_path": manifest_path, "map_scale": MAP_SCALE, "lake_water_height": lake_water_height(),
		"city_bounds": city_bounds, "city_footprint": city_footprint,
		"city_footprint_area": city_footprint_area, "city_area": city_footprint_area,
		"land_area": land_area, "land_total_area": land_area,
		"noncity_land_area": noncity_land_area, "grass_area": grass_area, "sand_area": sand_area,
		"cloud_count": cloud_specs.size(), "cloud_elapsed": cloud_elapsed,
		"collision_boxes": collision_boxes.size(), "collision_grid_cells": collision_grid.size(),
		"lake_triangles": lake_triangles.size(), "landmark_position": landmark_position,
		"coast_segments": coast_polygon.size(), "island_bounds": island_bounds,
		"spawn_position": spawn_position(), "spawn_orientation": spawn_orientation(),
	}
