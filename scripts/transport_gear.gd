extends RefCounted

# Pivots use the imported visual wrapper's frame: +Y up, +Z forward, metres.
# TRAINING_ROOT's 180-degree conversion remains part of each mesh transform.
const NOSE_PIVOT = Vector3(0.0, 1.05, 6.85)
const MAIN_POSITIVE_X_PIVOT = Vector3(2.48, 0.75, -4.22)
const MAIN_NEGATIVE_X_PIVOT = Vector3(-2.48, 0.75, -4.22)

var visual_root: Node3D
var nose_hinge: Node3D
var main_positive_x_hinge: Node3D
var main_negative_x_hinge: Node3D
var nose_positive_x_door: Node3D
var nose_negative_x_door: Node3D
var main_positive_x_door: Node3D
var main_negative_x_door: Node3D
var extension = 1.0


func setup(visual: Node3D) -> void:
	if is_instance_valid(visual_root):
		return
	visual_root = visual
	nose_hinge = make_hinge("GearNoseHinge", NOSE_PIVOT)
	main_positive_x_hinge = make_hinge("GearMainPositiveXHinge", MAIN_POSITIVE_X_PIVOT)
	main_negative_x_hinge = make_hinge("GearMainNegativeXHinge", MAIN_NEGATIVE_X_PIVOT)
	nose_positive_x_door = make_hinge("GearNosePositiveXDoor", Vector3(0.60, 0.55, 6.82))
	nose_negative_x_door = make_hinge("GearNoseNegativeXDoor", Vector3(-0.60, 0.55, 6.82))
	main_positive_x_door = make_hinge("GearMainPositiveXDoor", Vector3(3.30, 0.75, -4.14))
	main_negative_x_door = make_hinge("GearMainNegativeXDoor", Vector3(-3.30, 0.75, -4.14))

	move_mesh("KC3901_fuzelagem_003_0", nose_hinge)
	# This shared mesh also contains cargo-ramp hinges. Only extract the nose
	# linkage; moving the entire mesh would pull the rear cargo hardware away.
	var shared_nose = find_mesh(visual, "KC390_001_fuzelagem_gear_0")
	if shared_nose != null:
		extract_parts(shared_nose, [{
			"name": "NoseGearLinkage", "hinge": nose_hinge,
			"bounds": box(Vector3(-2.0, -1.0, 5.0), Vector3(2.0, 2.0, 9.0)),
		}])

	for part in [
		"KC3902_fuzelagem_gear_0", "KC3902_fuzelagem_0",
		"KC3902_001_fuzelagem_003_0", "KC3902_002_fuzelagem_003_0",
	]:
		move_mesh(part, main_positive_x_hinge)
	for part in [
		"KC3903_fuzelagem_gear_0", "KC3902_003_fuzelagem_003_0",
		"KC3902_004_fuzelagem_003_0",
	]:
		move_mesh(part, main_negative_x_hinge)
	# Door panels share meshes with the fuselage/fairings. These measured boxes
	# contain complete disconnected panels, rather than broad body-name matches.
	var fuselage = find_mesh(visual, "KC390_fuzelagem__0")
	if fuselage != null:
		extract_parts(fuselage, [
			{"name": "NosePositiveXPanel", "hinge": nose_positive_x_door, "bounds": box(Vector3(0.55700, -0.02053, 6.22814), Vector3(0.93372, 0.56042, 7.40842))},
			{"name": "NoseNegativeXPanel", "hinge": nose_negative_x_door, "bounds": box(Vector3(-0.93082, -0.02044, 6.22745), Vector3(-0.56355, 0.56142, 7.40783))},
		])
	var fairings = find_mesh(visual, "KC390_019_fuzelagem__0")
	if fairings != null:
		extract_parts(fairings, [
			{"name": "MainPositiveXPanel", "hinge": main_positive_x_door, "bounds": box(Vector3(3.29356, -0.69999, -5.79702), Vector3(4.18316, 0.82753, -2.47739))},
			{"name": "MainNegativeXPanel", "hinge": main_negative_x_door, "bounds": box(Vector3(-4.17801, -0.70087, -5.79977), Vector3(-3.28865, 0.82922, -2.47947))},
		])
	var actuators = find_mesh(visual, "KC390_013_fuzelagem_gear_parts_0")
	if actuators != null:
		extract_parts(actuators, [
			{"name": "MainPositiveXActuators", "hinge": main_positive_x_door, "bounds": box(Vector3(2.80, -0.70, -5.90), Vector3(4.20, 0.80, -2.40))},
			{"name": "MainNegativeXActuators", "hinge": main_negative_x_door, "bounds": box(Vector3(-4.20, -0.70, -5.90), Vector3(-2.80, 0.80, -2.40))},
			{"name": "NosePositiveXActuators", "hinge": nose_positive_x_door, "bounds": box(Vector3(0.53, 0.04, 6.20), Vector3(0.90, 0.58, 7.50))},
			{"name": "NoseNegativeXActuators", "hinge": nose_negative_x_door, "bounds": box(Vector3(-0.90, 0.04, 6.20), Vector3(-0.53, 0.58, 7.50))},
		])
	apply_extension(1.0)


func apply_extension(value: float) -> void:
	extension = clampf(value, 0.0, 1.0)
	if not is_instance_valid(visual_root):
		return
	# Smooth the endpoint motion without changing the model's physical gear time.
	var retracting = 1.0 - extension
	var folded = smoothstep(0.0, 0.72, retracting)
	var doors_closed = smoothstep(0.72, 1.0, retracting)
	nose_hinge.position = NOSE_PIVOT + Vector3.UP * folded * 0.30
	nose_hinge.rotation.x = deg_to_rad(96.0) * folded
	main_positive_x_hinge.position = MAIN_POSITIVE_X_PIVOT + Vector3.UP * folded * 0.50
	main_positive_x_hinge.rotation.z = deg_to_rad(-95.0) * folded
	main_negative_x_hinge.position = MAIN_NEGATIVE_X_PIVOT + Vector3.UP * folded * 0.50
	main_negative_x_hinge.rotation.z = deg_to_rad(95.0) * folded
	# Wheels are inside the opaque bays at the end of the travel. Hiding their
	# enclosed meshes also avoids small links clipping through the simplified bay.
	nose_positive_x_door.rotation.z = deg_to_rad(-116.0) * doors_closed
	nose_negative_x_door.rotation.z = deg_to_rad(116.0) * doors_closed
	main_positive_x_door.rotation.z = deg_to_rad(-90.0) * doors_closed
	main_negative_x_door.rotation.z = deg_to_rad(90.0) * doors_closed
	var exposed = folded < 0.999
	nose_hinge.visible = exposed
	main_positive_x_hinge.visible = exposed
	main_negative_x_hinge.visible = exposed


func make_hinge(part_name: String, pivot: Vector3) -> Node3D:
	var hinge = Node3D.new()
	hinge.name = part_name
	visual_root.add_child(hinge)
	hinge.position = pivot
	return hinge


func apply_suspension(strokes: Vector3) -> void:
	if not is_instance_valid(visual_root) or extension < 0.999:
		return
	# Shorten the loaded legs as the fuselage settles; unloaded wheels remain
	# extended until the nose and opposite main gear meet the runway.
	nose_hinge.position.y += strokes.x
	main_positive_x_hinge.position.y += strokes.y
	main_negative_x_hinge.position.y += strokes.z


func move_mesh(part_name: String, hinge: Node3D) -> void:
	var part = find_mesh(visual_root, part_name)
	if part == null:
		return
	# Preserve the imported wheel-centre offsets and the root-axis conversion.
	var relative = hinge.transform.affine_inverse() * transform_in_visual(part)
	part.get_parent().remove_child(part)
	hinge.add_child(part)
	part.transform = relative


func find_mesh(node: Node, part_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name) == part_name:
		return node
	for child in node.get_children():
		var found = find_mesh(child, part_name)
		if found != null:
			return found
	return null


func transform_in_visual(part: Node3D) -> Transform3D:
	var relative = part.transform
	var ancestor = part.get_parent()
	while ancestor != visual_root and ancestor != null:
		if ancestor is Node3D:
			relative = ancestor.transform * relative
		ancestor = ancestor.get_parent()
	return relative


func box(minimum: Vector3, maximum: Vector3) -> AABB:
	# Imported mesh position compression can shift authored bounds by a millimetre.
	return AABB(minimum, maximum - minimum).grow(0.002)


func component_root(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index


func connected_parts(vertices: PackedVector3Array, indices: PackedInt32Array, transform: Transform3D) -> Array:
	var parents: Array[int] = []
	var welded = {}
	for index in range(vertices.size()):
		var point = vertices[index]
		var key = Vector3i(roundi(point.x * 100000.0), roundi(point.y * 100000.0), roundi(point.z * 100000.0))
		if not welded.has(key):
			welded[key] = index
		parents.append(welded[key])
	for index in range(0, indices.size(), 3):
		var first = component_root(parents, indices[index])
		for corner in range(1, 3):
			var other = component_root(parents, indices[index + corner])
			parents[other] = first
	var groups = {}
	for index in range(0, indices.size(), 3):
		var component = component_root(parents, indices[index])
		if not groups.has(component):
			groups[component] = {"indices": PackedInt32Array(), "minimum": Vector3(INF, INF, INF), "maximum": Vector3(-INF, -INF, -INF)}
		var group = groups[component]
		for corner in range(3):
			var vertex_index = indices[index + corner]
			group.indices.append(vertex_index)
			var point = transform * vertices[vertex_index]
			group.minimum = group.minimum.min(point)
			group.maximum = group.maximum.max(point)
	return groups.values()


func extract_parts(source: MeshInstance3D, parts: Array) -> void:
	var fixed_mesh = ArrayMesh.new()
	for part in parts:
		part["mesh"] = ArrayMesh.new()
	var model_transform = transform_in_visual(source)
	for surface in range(source.mesh.get_surface_count()):
		var arrays = source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for index in range(vertices.size()):
				indices[index] = index
		var fixed_indices = PackedInt32Array()
		var moving_indices = []
		for part in parts:
			moving_indices.append(PackedInt32Array())
		# Select whole welded components. A bounding box touching the fuselage
		# cannot accidentally clip out a few body triangles beside a door hinge.
		for component in connected_parts(vertices, indices, model_transform):
			var selected = -1
			for part_index in range(parts.size()):
				if parts[part_index].bounds.has_point(component.minimum) and parts[part_index].bounds.has_point(component.maximum):
					selected = part_index
					break
			if selected >= 0:
				moving_indices[selected].append_array(component.indices)
			else:
				fixed_indices.append_array(component.indices)
		var material = source.get_active_material(surface)
		append_surface(fixed_mesh, arrays, fixed_indices, material)
		for part_index in range(parts.size()):
			append_surface(parts[part_index].mesh, arrays, moving_indices[part_index], material)
	for part in parts:
		if part.mesh.get_surface_count() == 0:
			continue
		var moving = MeshInstance3D.new()
		moving.name = part.name
		moving.mesh = part.mesh
		moving.material_override = source.material_override
		moving.cast_shadow = source.cast_shadow
		moving.set_meta("gear_source_mesh", String(source.name))
		part.hinge.add_child(moving)
		moving.transform = part.hinge.transform.affine_inverse() * model_transform
	# Split ArrayMeshes are new resources; imported/shared meshes stay unchanged.
	source.mesh = fixed_mesh
	for surface in range(fixed_mesh.get_surface_count()):
		source.set_surface_override_material(surface, null)


func append_surface(mesh: ArrayMesh, arrays: Array, indices: PackedInt32Array, material: Material) -> void:
	if indices.is_empty():
		return
	var split_arrays = arrays.duplicate()
	var vertex_order: Array[int] = []
	var remapped_indices = PackedInt32Array()
	var remap = {}
	for original in indices:
		if not remap.has(original):
			remap[original] = vertex_order.size()
			vertex_order.append(original)
		remapped_indices.append(remap[original])
	var vertex_count = arrays[Mesh.ARRAY_VERTEX].size()
	for channel in range(Mesh.ARRAY_INDEX):
		var original_values = arrays[channel]
		if original_values == null or original_values.is_empty():
			continue
		var compact_values = original_values.duplicate()
		compact_values.clear()
		var components_per_vertex = int(original_values.size() / vertex_count)
		for original in vertex_order:
			for component in range(components_per_vertex):
				compact_values.append(original_values[original * components_per_vertex + component])
		split_arrays[channel] = compact_values
	split_arrays[Mesh.ARRAY_INDEX] = remapped_indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, split_arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
