extends Node

# A compact, collimated approximation for the two original KC-390 combiners.
# The model's small glass apertures remain the only surfaces showing symbols.
const Symbology = preload("res://scripts/echo_hud_symbology.gd")
const ProjectionShader = preload("res://shaders/echo_hud_combiner.gdshader")
const LEFT_EYE = Vector3(0.35, 3.20, 7.0)
const RIGHT_EYE = Vector3(-0.35, 3.20, 7.0)
const LEFT_CENTER = Vector3(0.51953, 3.08883, 7.72837)
const RIGHT_CENTER = Vector3(-0.52793, 3.08883, 7.72777)
# Tangent-space field calibrated to the source glass, without moving the camera.
const FIELD_SPAN = Vector2(0.285, 0.235)

var flight
var viewport: SubViewport
var display: Control
var glass: MeshInstance3D
var projection: ShaderMaterial
var elapsed = 0.0
var active = false
var visibility_weight = 0.0


func setup(controller, aircraft_visual: Node3D) -> void:
	if flight != null or controller.level_id not in [1, 5]:
		return
	flight = controller
	glass = aircraft_visual.find_child("KC390_006_hud_0", true, false) as MeshInstance3D
	if glass == null or glass.mesh == null:
		push_warning("KC-390 HUD combiner is missing")
		return
	viewport = SubViewport.new()
	viewport.name = "EchoHudOptics"
	viewport.size = Vector2i(1024, 1024)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	display = Symbology.new()
	viewport.add_child(display)
	projection = ShaderMaterial.new()
	projection.shader = ProjectionShader
	projection.set_shader_parameter("symbol_texture", viewport.get_texture())
	projection.set_shader_parameter("mesh_to_aircraft", relative_transform(glass, flight.aircraft_root))
	projection.set_shader_parameter("left_field_center", field_center(LEFT_EYE, LEFT_CENTER))
	projection.set_shader_parameter("right_field_center", field_center(RIGHT_EYE, RIGHT_CENTER))
	projection.set_shader_parameter("field_span", FIELD_SPAN)
	for surface in range(glass.mesh.get_surface_count()):
		var source = glass.get_active_material(surface)
		if source is not StandardMaterial3D or source.resource_name != "material_13":
			continue
		# Duplicate per instance so both missions leave the imported asset intact.
		var clear_glass = source.duplicate() as StandardMaterial3D
		clear_glass.resource_name = "Echo_ClearCombiner"
		clear_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		clear_glass.albedo_color = Color(0.08, 0.24, 0.14, 0.055)
		clear_glass.metallic = 0.0
		clear_glass.roughness = 0.38
		clear_glass.metallic_specular = 0.12
		clear_glass.emission_enabled = false
		clear_glass.cull_mode = BaseMaterial3D.CULL_BACK
		clear_glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		clear_glass.set_flag(BaseMaterial3D.FLAG_DONT_RECEIVE_SHADOWS, true)
		clear_glass.next_pass = projection
		glass.set_surface_override_material(surface, clear_glass)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update_projection(0.0)


func relative_transform(part: Node3D, ancestor: Node3D) -> Transform3D:
	var result = Transform3D.IDENTITY
	var current: Node3D = part
	while current != null and current != ancestor:
		result = current.transform * result
		current = current.get_parent() as Node3D
	return result


func field_center(eye: Vector3, center: Vector3) -> Vector2:
	var ray = center - eye
	return Vector2(-ray.x / ray.z, -ray.y / ray.z)


func _process(dt: float) -> void:
	update_projection(dt)


func update_projection(dt: float) -> void:
	if projection == null or flight.camera == null:
		return
	var camera_local: Vector3 = flight.aircraft_root.to_local(flight.camera.global_position)
	projection.set_shader_parameter("camera_local", camera_local)
	var cinematic = 0.0
	if flight.interception != null and flight.interception.cinematic_active():
		var t: float = flight.interception.stage_elapsed
		cinematic = smoothstep(0.0, 0.85, t) * (1.0 - smoothstep(12.8, 14.0, t))
	# Eye-box suppression also prevents an instructor/chase view from seeing
	# mirrored symbols, and fades before the one-take camera passes the glass.
	var eye = LEFT_EYE if flight.cockpit_seat == "front" else RIGHT_EYE
	var eye_distance = camera_local.distance_to(eye)
	var eye_box = 1.0 - smoothstep(0.20, 0.55, eye_distance)
	active = flight.cockpit_mode and flight.cockpit_seat != "instructor" and not flight.intro_active and not flight.observing
	visibility_weight = (1.0 - cinematic) * eye_box if active else 0.0
	projection.set_shader_parameter("visibility_weight", visibility_weight)
	projection.set_shader_parameter("active_side", 1.0 if flight.cockpit_seat == "front" else -1.0)
	elapsed += dt
	if elapsed >= 1.0 / 30.0 or display.state.is_empty():
		elapsed = 0.0
		display.field_center = field_center(LEFT_EYE, LEFT_CENTER) if flight.cockpit_seat == "front" else field_center(RIGHT_EYE, RIGHT_CENTER)
		display.field_span = FIELD_SPAN
		display.update_state(flight.model.telemetry())
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
