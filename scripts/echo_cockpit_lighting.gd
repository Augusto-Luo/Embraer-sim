extends Node3D

# Level-five-only lighting for the existing KC-390 cockpit. The original
# painel UVs/texture come from the model credited in kc390-ATTRIBUTION.md.
const BacklightShader = preload("res://shaders/echo_cockpit_backlight.gdshader")
const COCKPIT_LIGHT_LAYER = 1 << 18
const FILL_RECEIVERS = ["KC390_010_painel_0", "KC390_007_painel_0", "KC390_011_interior_a_0"]

var backlit_surfaces: Array[String] = []
var lighting_root: Node3D
var fill_light: OmniLight3D


func setup(aircraft_visual: Node3D) -> void:
	if aircraft_visual == null or is_instance_valid(lighting_root):
		return
	lighting_root = Node3D.new()
	lighting_root.name = "EchoCockpitBacklighting"
	aircraft_visual.add_child(lighting_root)
	var materials: Dictionary = {}
	for node in aircraft_visual.find_children("*", "MeshInstance3D", true, false):
		var part = node as MeshInstance3D
		if part.mesh == null:
			continue
		if String(part.name) in FILL_RECEIVERS:
			part.layers |= COCKPIT_LIGHT_LAYER
		for surface in range(part.mesh.get_surface_count()):
			var source = part.get_active_material(surface)
			# The combiner, glass, charcoal interior and live MFD surfaces are
			# deliberately excluded. Only the original button/legend atlas is lit.
			if not source is StandardMaterial3D or source.resource_name != "painel":
				continue
			var texture = source.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
			if texture == null:
				continue
			var key = source.get_instance_id()
			if not materials.has(key):
				var backlit = source.duplicate() as StandardMaterial3D
				backlit.resource_name = "Echo_ButtonLegends"
				var glow = ShaderMaterial.new()
				glow.shader = BacklightShader
				glow.set_shader_parameter("legend_atlas", texture)
				glow.set_shader_parameter("backlight_energy", 0.72)
				backlit.next_pass = glow
				materials[key] = backlit
			part.set_surface_override_material(surface, materials[key])
			backlit_surfaces.append("%s:%d" % [part.name, surface])
	var eye = aircraft_visual.find_child("PILOT_EYE_LEFT", true, false) as Node3D
	if eye == null:
		return
	# A gentle, shadow-free instrument wash lives aft of the pilot's eye.
	# It has no visible lamp mesh and stays behind the 0.8 m forward camera move.
	fill_light = OmniLight3D.new()
	fill_light.name = "InstrumentWash"
	var eye_frame = relative_transform(eye, aircraft_visual)
	fill_light.position = eye_frame * Vector3(0.08, 0.02, 0.38)
	fill_light.light_color = Color("b5c9a4")
	fill_light.light_energy = 0.22
	fill_light.light_specular = 0.0
	fill_light.light_cull_mask = COCKPIT_LIGHT_LAYER
	fill_light.omni_range = 2.0
	fill_light.omni_attenuation = 1.2
	fill_light.shadow_enabled = false
	lighting_root.add_child(fill_light)


func relative_transform(part: Node3D, ancestor: Node3D) -> Transform3D:
	var result = Transform3D.IDENTITY
	var current: Node3D = part
	while current != null and current != ancestor:
		result = current.transform * result
		current = current.get_parent() as Node3D
	return result
