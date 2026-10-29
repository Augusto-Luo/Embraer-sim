extends RefCounted

const AILERON_LIMIT = deg_to_rad(16.0)

# Measured from the leading boundary of the supplied aileron vertex strips, in
# TRAINING_ROOT coordinates before its 180-degree heading correction. The span
# follows both sweep and dihedral; neither strip is hinged along a pure X axis.
const AILERON_HINGES = [
	{"name": "AILERON_L_PIVOT", "side": "right", "start": Vector3(5.86341, 4.0, 1.15739), "end": Vector3(16.4154, 2.8828, 6.48424)},
	{"name": "AILERON_R_PIVOT", "side": "left", "start": Vector3(-5.86604, 4.0, 1.15084), "end": Vector3(-16.42465, 2.8828, 6.46589)},
]

var ailerons: Array[Dictionary] = []


func setup(visual: Node) -> void:
	ailerons.clear()
	for spec in AILERON_HINGES:
		var pivot = find_pivot(visual, spec.name)
		if pivot == null:
			continue
		var authored_transforms = {}
		for child in pivot.get_children():
			if child is MeshInstance3D:
				authored_transforms[child] = pivot.transform * child.transform
		pivot.position = (spec.start + spec.end) * 0.5
		pivot.quaternion = Quaternion.IDENTITY
		var axis = (spec.end - spec.start).normalized()
		var aft = axis.cross(Vector3.UP).normalized()
		if aft.z < 0.0:
			aft = -aft
		var probe_mesh
		var probe_vertex = Vector3.ZERO
		var probe_parent = Vector3.ZERO
		var aft_projection = -INF
		for mesh in authored_transforms:
			mesh.transform = pivot.transform.affine_inverse() * authored_transforms[mesh]
			for surface in range(mesh.mesh.get_surface_count()):
				var vertices = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var parent_point = authored_transforms[mesh] * vertex
					var projection = parent_point.dot(aft)
					if projection > aft_projection:
						aft_projection = projection
						probe_mesh = mesh
						probe_vertex = vertex
						probe_parent = parent_point
		pivot.set_meta("geometry_hinge_start", spec.start)
		pivot.set_meta("geometry_hinge_end", spec.end)
		pivot.set_meta("geometry_hinge_axis", axis)
		ailerons.append({
			"pivot": pivot, "axis": axis, "start": spec.start, "end": spec.end,
			"side": spec.side, "angle": 0.0, "probe_mesh": probe_mesh,
			"probe_vertex": probe_vertex, "probe_parent": probe_parent,
		})


func find_pivot(node: Node, suffix: String):
	if String(node.name).ends_with(suffix):
		return node
	for child in node.get_children():
		var found = find_pivot(child, suffix)
		if found != null:
			return found
	return null


func apply_inputs(dt: float, inputs: Dictionary) -> void:
	var blend = 1.0 - exp(-12.0 * dt)
	for item in ailerons:
		# The source's *_L mesh becomes the aircraft's right side after the root
		# rotation. Around outward span axes, negative angles lift the right
		# trailing edge and lower the left for a positive/right roll command.
		item.angle = lerp(float(item.angle), -float(inputs.get("roll", 0.0)) * AILERON_LIMIT, blend)
		item.pivot.quaternion = Quaternion(item.axis, item.angle)


func trailing_edge_motion() -> Dictionary:
	var motion = {}
	for item in ailerons:
		var current = item.pivot.transform * item.probe_mesh.transform * item.probe_vertex
		motion[item.side] = current.y - item.probe_parent.y
	return motion
