extends Node

const MfdDisplay = preload("res://scripts/mfd_display.gd")
const MfdScreenShader = preload("res://shaders/mfd_screen.gdshader")
const MfdRearScreenShader = preload("res://shaders/mfd_screen_rear.gdshader")
const MfdRearCenterShader = preload("res://shaders/mfd_screen_raw.gdshader")

var flight
var viewports = {}
var screens = {}
var shared_modes = {}
var screen_shader = MfdScreenShader
var elapsed = 0.0


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	create_screen("DYNAMIC_MFD_LEFT", "navigation", Vector2i(512, 512))
	create_screen("DYNAMIC_MFD_RIGHT", "engine", Vector2i(512, 512))
	create_screen("DYNAMIC_MFD_CENTER", "system", Vector2i(512, 512))
	create_screen("DYNAMIC_MFD_REAR_LEFT", "navigation", Vector2i(512, 512))
	create_screen("DYNAMIC_MFD_REAR_RIGHT", "engine", Vector2i(512, 512))
	create_screen("DYNAMIC_MFD_REAR_CENTER", "system", Vector2i(512, 512))


func create_screen(node_name: String, mode: String, resolution: Vector2i) -> void:
	var viewport
	var display
	if shared_modes.has(mode):
		viewport = shared_modes[mode].viewport
		display = shared_modes[mode].display
	else:
		viewport = SubViewport.new()
		viewport.size = resolution
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.gui_disable_input = true
		viewport.transparent_bg = false
		add_child(viewport)
		display = MfdDisplay.new()
		display.mode = mode
		viewport.add_child(display)
		shared_modes[mode] = {"viewport": viewport, "display": display}
	viewports[node_name] = {"viewport": viewport, "display": display}
	var mesh = flight.find_part(flight.aircraft_root, node_name)
	if mesh == null:
		push_warning("Dynamic screen mesh missing: " + node_name)
		return
	var material = ShaderMaterial.new()
	var active_shader = screen_shader
	if node_name == "DYNAMIC_MFD_REAR_CENTER":
		active_shader = MfdRearCenterShader
	elif node_name.contains("_REAR_"):
		active_shader = MfdRearScreenShader
	material.shader = active_shader
	material.set_shader_parameter("screen_texture", viewport.get_texture())
	mesh.material_override = material
	mesh.set_meta("dynamic_ready", true)
	screens[node_name] = mesh


func _process(dt: float) -> void:
	elapsed += dt
	var interval = 1.0 / 15.0 if flight.cockpit_mode else 1.0 / 8.0
	if elapsed < interval:
		return
	elapsed = 0.0
	var state = flight.model.telemetry()
	if flight.level_id == 4:
		state.groundAttack = true
	if flight.level_id == 1:
		state.lowAltitude = false
		state.aircraftType = "KC-390"
		if flight.takeoff != null:
			state.training = flight.takeoff.training_snapshot()
	var combat = flight.cockpit_hud.combat
	for item in viewports.values():
		item.display.update_state(state)
		item.display.update_combat(combat)
		item.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func is_ready(node_name: String) -> bool:
	return screens.has(node_name) and screens[node_name].get_meta("dynamic_ready", false)
