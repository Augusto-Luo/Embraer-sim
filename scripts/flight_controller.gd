extends Node3D

const FlightModel = preload("res://scripts/flight_model.gd")
const FlightHud = preload("res://scripts/flight_hud_v2.gd")
const FlightSettings = preload("res://scripts/flight_settings.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const AircraftScene = preload("res://assets/emb314-flight.glb")
const TransportScene = preload("res://assets/kc390-training-ready.glb")
const WingtipTrails = preload("res://scripts/wingtip_trails.gd")
const ObservationControls = preload("res://scripts/observation_controls.gd")
const CoastalGround = preload("res://scripts/coastal_ground.gd")
const NearClouds = preload("res://scripts/near_clouds.gd")
const CombatDirector = preload("res://scripts/combat_director.gd")
const CockpitHud = preload("res://scripts/cockpit_hud.gd")
const CockpitDisplays = preload("res://scripts/cockpit_displays.gd")
const TransportDisplays = preload("res://scripts/transport_displays.gd")
const PursuitDirector = preload("res://scripts/pursuit_director.gd")
const MissionHud = preload("res://scripts/mission_hud.gd")
const TrainingAirport = preload("res://scripts/training_airport.gd")
const TakeoffDirector = preload("res://scripts/takeoff_director.gd")
const TransportProfile = preload("res://scripts/transport_profile.gd")
const TransportSurfaces = preload("res://scripts/transport_surfaces.gd")
const TransportGear = preload("res://scripts/transport_gear.gd")
const FlightGuide = preload("res://scripts/flight_guide.gd")
const IntroOverlay = preload("res://scripts/intro_overlay.gd")
const StrikeIsland = preload("res://scripts/strike_island.gd")
const GroundStrikeDirector = preload("res://scripts/ground_strike_director.gd")
const InterceptionDirector = preload("res://scripts/interception_director.gd")
const InterceptionHud = preload("res://scripts/interception_hud.gd")
const FREE_LOOK_SENSITIVITY = 0.0042
const INTRO_DURATION = 5.8
const INTRO_SHOTS = [
	{"end": 3.40, "title": "OVERVIEW / LIVERY ORBIT", "target": Vector3(0.57, 0.10, -0.50), "distance": Vector2(24.0, 22.0), "yaw": Vector2(-1.15, 1.05), "pitch": Vector2(0.32, 0.24), "fov": 48.0, "ease": "linear"},
	{"end": 5.80, "title": "CLOSE / LIVERY & CANOPY", "target": Vector3(0.57, 0.45, 0.65), "distance": Vector2(10.0, 7.8), "yaw": Vector2(1.45, 0.65), "pitch": Vector2(0.28, 0.18), "fov": 44.0, "ease": "linear"},
]
const INTRO_SHOTS_KC390 = [
	{"end": 3.40, "title": "OVERVIEW / KC-390", "target": Vector3(0.0, 2.2, 0.0), "distance": Vector2(56.0, 50.0), "yaw": Vector2(-1.15, 1.05), "pitch": Vector2(0.30, 0.22), "fov": 48.0, "ease": "linear"},
	{"end": 5.80, "title": "CLOSE / KC-390 LIVERY", "target": Vector3(0.0, 3.0, 5.5), "distance": Vector2(22.0, 18.0), "yaw": Vector2(1.45, 0.65), "pitch": Vector2(0.22, 0.16), "fov": 44.0, "ease": "linear"},
]

var level_id = 3
var pursuit
var interception
var interception_hud
var mission_hud
var airport
var takeoff
var flight_guide
var intro_overlay
var intro_active = false
var intro_elapsed = 0.0
var intro_shot_index = -1
var enemy_spawn_pending = false
var enemy_spawn_countdown = 3.5

var model
var settings
var settings_panel
var settings_open = false
var settings_background_visibility = {}
var aircraft_root
var prop
var aileron_l
var aileron_r
var elevator_l
var elevator_r
var rudder
var transport_surfaces
var transport_gear
var strike_island
var ground_strike
var camera
var hud
var world_environment
var sun_light
var cloud_material
var fallback_sky_material
var applied_render_scale = -1.0
var applied_fps_cap = -1
var applied_volume_clouds = true
var engine_player
var wind_player
var wingtip_trails
var paused = false
var frozen = false
var wide_camera = false
var snap_camera = true
var camera_look = Vector3.ZERO
var free_look_active = false
var free_look_yaw = 0.0
var free_look_pitch = 0.0
var free_look_focus = 0.0
var previous_pad_buttons = {}
var perf_elapsed = 0.0
var perf_enabled = false
var previous_model_position = Vector3(0, 1200, 0)
var previous_model_orientation = Quaternion()
var previous_model_speed = 115.0
var visual_position = Vector3(0, 1200, 0)
var visual_orientation = Quaternion()
var visual_speed = 115.0
var observation_controls
var observing = false
var observation_frozen = false
var orbiting = false
var observation_target = Vector3.ZERO
var observation_yaw = 0.65
var observation_pitch = 0.35
var observation_distance = 16.0
var cloud_time = 0.0
var combat
var cockpit_hud
var cockpit_mode = false
var cockpit_seat = "front"
var cockpit_eye_front
var cockpit_eye_rear
var cockpit_eye_instructor
var cockpit_displays


func _ready() -> void:
	add_to_group("flight_controllers")
	perf_enabled = OS.get_cmdline_args().has("--qa-perf")
	level_id = int(get_tree().root.get_meta("selected_level", 3))
	if level_id not in [1, 2, 3, 4, 5]:
		level_id = 3
	settings = FlightSettings.new("res://settings-level%d.cfg" % level_id, TransportProfile.SETTINGS if level_id == 1 else {})
	setup_input()
	if level_id == 1:
		airport = TrainingAirport.new()
	elif level_id == 4:
		strike_island = StrikeIsland.new()
	model = FlightModel.new({
		"position": strike_island.spawn_position() if level_id == 4 else (airport.spawn_position() if level_id == 1 else (Vector3(-3500, 5200, -2000) if level_id in [2, 5] else Vector3(0, 1200, 0))),
		"quaternion": strike_island.spawn_orientation() if level_id == 4 else Quaternion(),
		"speed": 0.0 if level_id == 1 else (145.0 if level_id in [2, 5] else 115.0),
		"throttle": 0.0 if level_id == 1 else 0.68,
		"ground_operations": level_id == 1,
		"transport_profile": level_id == 1,
		"on_ground": level_id == 1,
		"gear_clearance": 1.2 if level_id == 1 else 2.5,
		"ground_height": strike_island.ground_height if level_id == 4 else (airport.ground_height if level_id == 1 else func(_x, _z): return 0.0),
		"obstacle_height": strike_island.obstacle_height if level_id == 4 else func(_x, _z): return -INF,
		"boundary_radius": 15000.0 if level_id in [2, 5] else (9000.0 if level_id in [1, 4] else 5000.0),
		"settings": settings.values,
		"invincible": true,
	})
	previous_model_position = model.position
	previous_model_orientation = model.orientation
	previous_model_speed = model.speed
	visual_position = model.position
	visual_orientation = model.orientation
	visual_speed = model.speed
	build_environment()
	build_aircraft()
	build_camera()
	build_hud()
	intro_active = level_id in [1, 2, 3, 5] and bool(get_tree().root.get_meta("play_intro", false))
	if level_id == 1:
		takeoff = TakeoffDirector.new()
		takeoff.player = model
		takeoff.airport = airport
		takeoff.restart()
		flight_guide = FlightGuide.new()
		flight_guide.controller = self
		add_child(flight_guide)
	elif level_id == 4:
		ground_strike = GroundStrikeDirector.new()
		ground_strike.player = model
		ground_strike.camera = camera
		ground_strike.island = strike_island
		combat = ground_strike
		add_child(ground_strike)
	elif level_id in [2, 3, 5]:
		if level_id == 2:
			combat = PursuitDirector.new()
			pursuit = combat
		elif level_id == 5:
			combat = InterceptionDirector.new()
			interception = combat
		else:
			combat = CombatDirector.new()
		combat.player = model
		combat.camera = camera
		combat.intro_pending = intro_active
		add_child(combat)
	mission_hud = MissionHud.new()
	mission_hud.controller = self
	mission_hud.levels_requested.connect(return_to_level_select)
	mission_hud.rejoin_requested.connect(rejoin_pursuit)
	add_child(mission_hud)
	if level_id == 5:
		interception_hud = InterceptionHud.new()
		interception_hud.controller = self
		add_child(interception_hud)
		interception_hud.visible = not intro_active
	intro_overlay = IntroOverlay.new()
	add_child(intro_overlay)
	intro_overlay.set_mission(level_id)
	if intro_active:
		start_intro()
	else:
		intro_overlay.visible = false
	build_audio()


func bind_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event = InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func setup_input() -> void:
	for action in settings.key_bindings:
		bind_key(action, int(settings.key_bindings[action]))
	if hud != null and level_id == 1:
		hud.update_training_keys(settings.key_bindings)


func build_environment() -> void:
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	if level_id == 4:
		# Low coastal cloud banks belong to the island. A clear sky avoids paying
		# for a second volumetric cloud field while preserving a readable skyline.
		var coastal_sky = ProceduralSkyMaterial.new()
		coastal_sky.sky_top_color = Color("#326b9f")
		coastal_sky.sky_horizon_color = Color("#a3c1d0")
		coastal_sky.ground_bottom_color = Color("#294953")
		coastal_sky.ground_horizon_color = Color("#a3c1d0")
		coastal_sky.sky_curve = 0.18
		coastal_sky.sun_angle_max = 5.0
		coastal_sky.sun_curve = 0.08
		sky.sky_material = coastal_sky
	else:
		cloud_material = ShaderMaterial.new()
		var use_quarter_clouds = DisplayServer.window_get_size().x >= 2200
		var cloud_shader = "res://shaders/cloud_sky_quarter.gdshader" if use_quarter_clouds else "res://shaders/cloud_sky.gdshader"
		cloud_material.shader = load(cloud_shader)
		if perf_enabled:
			print("RENDER: window=", DisplayServer.window_get_size(), " cloud_pass=", "quarter" if use_quarter_clouds else "half")
		sky.sky_material = cloud_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#A9BBC4")
	environment.ambient_light_energy = 0.45
	environment.background_energy_multiplier = 0.80
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.90
	environment.fog_enabled = false
	environment.fog_light_color = Color("#A5B6BC")
	environment.fog_light_energy = 0.7
	environment.fog_density = float(settings.values.fog_density)
	environment.fog_sky_affect = 0.35
	world_environment = environment
	world.environment = environment
	add_child(world)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-float(settings.values.sun_elevation), -135.0, 0)
	sun_light.light_energy = 1.2
	sun_light.shadow_enabled = true
	add_child(sun_light)

	if level_id in [1, 3]:
		var coastal_ground = CoastalGround.new()
		coastal_ground.name = "CoastalGround"
		add_child(coastal_ground)
	if airport != null:
		add_child(airport)
	if strike_island != null:
		strike_island.name = "StrikeIsland"
		add_child(strike_island)
	apply_performance_settings(true)


func build_aircraft() -> void:
	aircraft_root = Node3D.new()
	aircraft_root.name = "KC390_Aircraft" if level_id == 1 else "EMB314_Aircraft"
	add_child(aircraft_root)
	var scene = TransportScene if level_id == 1 else AircraftScene
	var visual = scene.instantiate()
	aircraft_root.add_child(visual)
	if level_id == 1:
		rebase_transport_hinge_meshes(visual)
		transport_surfaces = TransportSurfaces.new()
		transport_surfaces.setup(visual)
		transport_gear = TransportGear.new()
		transport_gear.setup(visual)
		var glass = find_part(visual, "GLASS")
		if glass is MeshInstance3D:
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in range(glass.mesh.get_surface_count()):
				var source_material = glass.get_active_material(surface)
				if source_material is StandardMaterial3D:
					var clear_glass = source_material.duplicate()
					clear_glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
					clear_glass.metallic_specular = 0.18
					clear_glass.set_flag(BaseMaterial3D.FLAG_DONT_RECEIVE_SHADOWS, true)
					glass.set_surface_override_material(surface, clear_glass)
			glass.set_meta("clear_cockpit_finish", true)
		var matte_names = ["interior_a", "interior_b", "interior_pla", "interior_pla_1", "interior_pla_2", "Cockpit_Frame_Inner_Black"]
		for node in visual.find_children("*", "MeshInstance3D", true, false):
			for surface in range(node.mesh.get_surface_count()):
				var source_material = node.get_active_material(surface)
				if source_material is StandardMaterial3D and source_material.resource_name in matte_names:
					var matte = source_material.duplicate()
					matte.metallic = 0.0
					matte.roughness = 0.88
					matte.metallic_specular = 0.12 if source_material.resource_name == "Cockpit_Frame_Inner_Black" else 0.22
					node.set_surface_override_material(surface, matte)
		prop = null
		aileron_l = find_part(visual, "AILERON_L_PIVOT")
		aileron_r = find_part(visual, "AILERON_R_PIVOT")
		elevator_l = find_part(visual, "ELEVATOR_L_PIVOT")
		elevator_r = find_part(visual, "ELEVATOR_R_PIVOT")
		rudder = find_part(visual, "RUDDER_PIVOT")
		cockpit_eye_front = find_part(visual, "PILOT_EYE_LEFT")
		cockpit_eye_rear = find_part(visual, "PILOT_EYE_RIGHT")
		cockpit_eye_instructor = find_part(visual, "PILOT_EYE_INSTRUCTOR")
		cockpit_displays = TransportDisplays.new()
	else:
		prop = find_part(visual, "PROP")
		aileron_l = find_part(visual, "AILERON_L")
		aileron_r = find_part(visual, "AILERON_R")
		elevator_l = find_part(visual, "ELEVATOR_L")
		elevator_r = find_part(visual, "ELEVATOR_R")
		rudder = find_part(visual, "RUDDER")
		cockpit_eye_front = find_part(visual, "PILOT_EYE_FRONT")
		cockpit_eye_rear = find_part(visual, "PILOT_EYE_REAR")
		cockpit_eye_instructor = null
		cockpit_displays = CockpitDisplays.new()
	aircraft_root.position = model.position
	aircraft_root.quaternion = model.orientation
	cockpit_displays.flight = self
	add_child(cockpit_displays)
	if level_id in [2, 3, 5]:
		var near_clouds = NearClouds.new()
		near_clouds.name = "NearClouds"
		near_clouds.aircraft = aircraft_root
		near_clouds.high_altitude = level_id in [2, 5]
		add_child(near_clouds)


func rebase_transport_hinge_meshes(node: Node) -> void:
	# The KC-390 export stores these mesh vertices in aircraft coordinates while
	# also parenting them to translated hinge nodes. Cancel that rest transform
	# on the mesh, so the hinge can animate without displacing neutral geometry.
	if node is Node3D and String(node.name).ends_with("_PIVOT") and not node.get_meta("hinge_meshes_rebased", false):
		for child in node.get_children():
			if child is MeshInstance3D:
				child.transform = node.transform.affine_inverse() * child.transform
		node.set_meta("hinge_meshes_rebased", true)
	for child in node.get_children():
		rebase_transport_hinge_meshes(child)


func find_part(node: Node, needle: String) -> Node:
	if String(node.name).to_upper().contains(needle):
		return node
	for child in node.get_children():
		var found = find_part(child, needle)
		if found != null:
			return found
	return null


func build_camera() -> void:
	camera = Camera3D.new()
	camera.near = 0.2
	camera.far = 60000.0
	camera.fov = 52.0
	add_child(camera)
	camera.current = true
	if level_id != 1:
		wingtip_trails = WingtipTrails.new()
		wingtip_trails.aircraft = aircraft_root
		add_child(wingtip_trails)
	update_camera(1.0)


func build_hud() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = FlightHud.new()
	hud.pursuit_mode = level_id in [2, 5]
	hud.combat_enabled = level_id in [2, 3, 4, 5]
	hud.ground_attack = level_id == 4
	layer.add_child(hud)
	if level_id == 1:
		hud.update_training_keys(settings.key_bindings)
	hud.camera_requested.connect(toggle_camera)
	hud.pause_requested.connect(toggle_pause)
	hud.reset_requested.connect(reset_flight)
	hud.settings_requested.connect(toggle_settings)
	hud.set_camera_mode(wide_camera)
	hud.update_state(model.telemetry())
	var settings_layer = CanvasLayer.new()
	settings_layer.layer = 10
	add_child(settings_layer)
	settings_panel = SettingsPanel.new()
	settings_panel.settings = settings
	settings_panel.combat_enabled = level_id in [2, 3, 4, 5]
	settings_panel.ground_attack = level_id == 4
	settings_panel.level_id = level_id
	settings_panel.controller = self
	settings_layer.add_child(settings_panel)
	settings_panel.closed.connect(close_settings)
	cockpit_hud = CockpitHud.new()
	cockpit_hud.combat_enabled = level_id in [2, 3, 4, 5]
	cockpit_hud.ground_attack = level_id == 4
	layer.add_child(cockpit_hud)
	cockpit_hud.visible = false
	cockpit_hud.set_seat(cockpit_seat.to_upper())
	cockpit_hud.update_state(model.telemetry())
	observation_controls = ObservationControls.new()
	add_child(observation_controls)
	observation_controls.chase_requested.connect(exit_observation)
	observation_controls.freeze_requested.connect(toggle_pause)
	observation_controls.reset_requested.connect(reset_flight)
	observation_controls.settings_requested.connect(toggle_settings)


func build_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	engine_player = AudioStreamPlayer.new()
	engine_player.stream = looped_audio("res://assets/engine-loop.wav")
	engine_player.volume_db = -50.0
	add_child(engine_player)
	engine_player.play()
	wind_player = AudioStreamPlayer.new()
	wind_player.stream = looped_audio("res://assets/wind-loop.wav")
	wind_player.volume_db = -50.0
	add_child(wind_player)
	wind_player.play()


func looped_audio(path: String) -> AudioStreamWAV:
	var stream = load(path) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func start_intro() -> void:
	intro_active = true
	intro_elapsed = 0.0
	intro_shot_index = -1
	enemy_spawn_pending = false
	hud.visible = false
	cockpit_hud.visible = false
	mission_hud.visible = false
	observation_controls.visible = false
	settings_panel.visible = false
	if flight_guide != null:
		flight_guide.visible = false
	if wingtip_trails != null:
		wingtip_trails.visible = false
	if combat != null:
		combat.intro_pending = true
		combat.hold = true
	intro_overlay.set_mission(level_id)
	intro_overlay.visible = true
	update_intro_camera(0.0)


func finish_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	get_tree().root.set_meta("play_intro", false)
	intro_overlay.visible = false
	hud.visible = not cockpit_mode
	cockpit_hud.visible = cockpit_mode
	mission_hud.visible = true
	if flight_guide != null:
		flight_guide.visible = true
	if wingtip_trails != null:
		wingtip_trails.visible = true
		wingtip_trails.clear_trails()
	reset_free_look()
	enemy_spawn_pending = level_id in [2, 3, 5] and combat != null
	enemy_spawn_countdown = 3.5
	if combat != null:
		combat.hold = enemy_spawn_pending
	update_camera(1.0)


func spawn_pending_enemies() -> void:
	if not enemy_spawn_pending or combat == null:
		return
	enemy_spawn_pending = false
	enemy_spawn_countdown = 0.0
	combat.intro_pending = false
	combat.restart()
	combat.hold = false


func update_intro_camera(dt: float) -> void:
	if not intro_active:
		return
	intro_elapsed = min(INTRO_DURATION, intro_elapsed + dt)
	var shots = INTRO_SHOTS_KC390 if level_id == 1 else INTRO_SHOTS
	var current_index = shots.size() - 1
	for index in range(shots.size()):
		if intro_elapsed <= float(shots[index].end):
			current_index = index
			break
	var shot = shots[current_index]
	var shot_start = 0.0 if current_index == 0 else float(shots[current_index - 1].end)
	if current_index != intro_shot_index:
		intro_shot_index = current_index
		intro_overlay.set_shot(shot.title)
	var weight = clamp((intro_elapsed - shot_start) / max(0.001, float(shot.end) - shot_start), 0.0, 1.0)
	if shot.ease == "smooth":
		weight = weight * weight * (3.0 - 2.0 * weight)
	elif shot.ease == "ease_in":
		weight = weight * weight
	var yaw = lerp(shot.yaw.x, shot.yaw.y, weight)
	var pitch = lerp(shot.pitch.x, shot.pitch.y, weight)
	var distance = lerp(shot.distance.x, shot.distance.y, weight)
	var target = visual_position + visual_orientation * shot.target
	var horizontal = cos(pitch)
	var offset = Vector3(sin(yaw) * horizontal, sin(pitch), cos(yaw) * horizontal) * distance
	camera.position = target + offset
	camera_look = target
	camera.look_at(target, Vector3.UP)
	camera.fov = float(shot.fov)
	if intro_elapsed >= INTRO_DURATION:
		finish_intro()


func _input(event: InputEvent) -> void:
	if intro_active:
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]):
			finish_intro()
		get_viewport().set_input_as_handled()
		return
	if settings_open and settings_panel.binding_action != "":
		settings_panel.capture_binding_event(event)
		get_viewport().set_input_as_handled()
		return
	var close_with_escape = settings_open and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)
	if close_with_escape or event.is_action_pressed("settings") or event.is_action_pressed("settings_close"):
		toggle_settings()
		get_viewport().set_input_as_handled()
		return
	if settings_open:
		return
	if event.is_action_pressed("observe"):
		toggle_observation()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("view_recenter"):
		reset_free_look()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("target_next") and combat != null and not observing:
		combat.cycle_target()
	elif event.is_action_pressed("missile_fire") and combat != null and not observing:
		combat.fire_missile()
	elif event.is_action_pressed("cockpit"):
		set_cockpit_mode(not cockpit_mode)
	elif event.is_action_pressed("cockpit_seat") and cockpit_mode:
		switch_cockpit_seat()
	elif event.is_action_pressed("camera"):
		toggle_camera()
	elif event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("reset"):
		reset_flight()
	elif event.is_action_pressed("gear_toggle") and level_id == 1:
		toggle_landing_gear()
	elif event.is_action_pressed("help") and not observing:
		hud.toggle_help()
	if observing:
		handle_observation_input(event)
	else:
		handle_free_look_input(event)


func handle_observation_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			orbiting = event.pressed and not observation_controls.is_pointer_over_ui()
		elif not observation_controls.is_pointer_over_ui() and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			observation_distance = max(5.0, observation_distance * 0.90)
		elif not observation_controls.is_pointer_over_ui() and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			observation_distance = min(45.0, observation_distance * 1.10)
	elif event is InputEventMouseMotion and orbiting:
		observation_yaw -= event.relative.x * 0.005
		observation_pitch = clamp(observation_pitch - event.relative.y * 0.005, -1.35, 1.35)


func handle_free_look_input(event: InputEvent) -> void:
	if cockpit_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if not observing and not settings_open and not mouse_over_flight_ui():
				free_look_active = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
		elif free_look_active:
			free_look_active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and free_look_active:
		var sensitivity = FREE_LOOK_SENSITIVITY * float(settings.values.get("view_sensitivity", 1.0))
		free_look_yaw = wrapf(free_look_yaw - event.relative.x * sensitivity, -PI, PI)
		free_look_pitch = clamp(free_look_pitch - event.relative.y * sensitivity, -0.35, 0.90)
		get_viewport().set_input_as_handled()


func reset_free_look() -> void:
	free_look_active = false
	free_look_yaw = 0.0
	free_look_pitch = 0.0
	free_look_focus = 0.0
	snap_camera = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func toggle_settings() -> void:
	reset_free_look()
	if settings_open:
		close_settings()
	else:
		open_settings()


func open_settings() -> void:
	if settings_open:
		return
	reset_free_look()
	settings_open = true
	settings_panel.open()
	hud.set_settings_open(true)
	# Keep the world visible through the panel without overlapping HUD text.
	for control in [hud, cockpit_hud, mission_hud.root_control, interception_hud.root_control if interception_hud != null else null]:
		if control != null:
			settings_background_visibility[control] = control.visible
			control.hide()
	if observing:
		observation_controls.visible = false


func close_settings() -> void:
	if not settings_open:
		return
	if settings_panel.visible:
		settings_panel.close()
		return
	settings_open = false
	hud.set_settings_open(false)
	for control in settings_background_visibility:
		if is_instance_valid(control):
			control.visible = settings_background_visibility[control]
	settings_background_visibility.clear()
	observation_controls.visible = observing


func toggle_camera() -> void:
	if cockpit_mode:
		set_cockpit_mode(false)
		return
	if observing:
		exit_observation()
		return
	wide_camera = not wide_camera
	hud.set_camera_mode(wide_camera)


func toggle_pause() -> void:
	if observing:
		observation_frozen = not observation_frozen
		observation_controls.set_frozen(observation_frozen)
		return
	paused = not paused
	hud.set_paused(paused)
	cockpit_hud.set_paused(paused)


func reset_flight() -> void:
	if settings_open:
		close_settings()
		if settings_open:
			return
	if intro_active:
		finish_intro()
	enemy_spawn_pending = false
	if combat != null:
		combat.intro_pending = false
	reset_free_look()
	if observing:
		reset_observation_view()
		return
	model.reset()
	previous_model_position = model.position
	previous_model_orientation = model.orientation
	previous_model_speed = model.speed
	visual_position = model.position
	visual_orientation = model.orientation
	visual_speed = model.speed
	paused = false
	frozen = false
	snap_camera = true
	hud.set_paused(false)
	cockpit_hud.set_paused(false)
	if combat != null:
		combat.restart()
	if interception_hud != null:
		interception_hud.start_briefing_stream()
	if takeoff != null:
		takeoff.restart()
	if wingtip_trails != null:
		wingtip_trails.clear_trails()


func return_to_level_select() -> void:
	if settings_open:
		close_settings()
		if settings_open:
			return
	reset_free_look()
	Engine.max_fps = 0
	get_tree().root.scaling_3d_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func rejoin_pursuit() -> void:
	if pursuit == null or not is_instance_valid(pursuit.target) or pursuit.target.destroyed:
		return
	if observing:
		exit_observation()
	var target_model = pursuit.target.model
	var direction = Vector3(target_model.forward.x, 0.0, target_model.forward.z).normalized()
	model.position = target_model.position - direction * 700.0
	model.orientation = Quaternion(Vector3.UP, atan2(direction.x, direction.z))
	model.speed = target_model.speed
	model.inputs = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0}
	model.vertical_speed = 0.0
	model.update_attitude()
	previous_model_position = model.position
	previous_model_orientation = model.orientation
	previous_model_speed = model.speed
	visual_position = model.position
	visual_orientation = model.orientation
	visual_speed = model.speed
	snap_camera = true
	wingtip_trails.clear_trails()
	pursuit.rejoin_recommended = false


func toggle_observation() -> void:
	if observing:
		exit_observation()
	else:
		enter_observation()


func enter_observation() -> void:
	if settings_open:
		close_settings()
		if settings_open:
			return
	if cockpit_mode:
		set_cockpit_mode(false)
	reset_free_look()
	observing = true
	observation_frozen = false
	orbiting = false
	model.inputs = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0}
	observation_target = visual_position + (Vector3(0.0, 2.0, 0.0) if level_id == 1 else visual_orientation * Vector3(0.57, 0.10, -0.50))
	reset_observation_view()
	hud.visible = false
	observation_controls.visible = true
	observation_controls.set_frozen(false)
	if wingtip_trails != null:
		wingtip_trails.clear_trails()
		wingtip_trails.visible = false


func exit_observation() -> void:
	if not observing:
		return
	observing = false
	observation_frozen = false
	orbiting = false
	observation_controls.visible = false
	hud.visible = not cockpit_mode
	cockpit_hud.visible = cockpit_mode
	if wingtip_trails != null:
		wingtip_trails.visible = true
		wingtip_trails.clear_trails()
	snap_camera = false


func reset_observation_view() -> void:
	observation_yaw = 0.65
	observation_pitch = 0.35
	observation_distance = 35.0 if level_id == 1 else 16.0
	orbiting = false


func update_observation_camera(dt: float) -> void:
	var horizontal = cos(observation_pitch)
	var offset = Vector3(
		sin(observation_yaw) * horizontal,
		sin(observation_pitch),
		cos(observation_yaw) * horizontal
	) * observation_distance
	var blend = 1.0 - exp(-dt * 8.0)
	camera.position = camera.position.lerp(observation_target + offset, blend)
	camera_look = camera_look.lerp(observation_target, blend)
	camera.look_at(camera_look, Vector3.UP)
	camera.fov = lerp(camera.fov, 48.0, 1.0 - exp(-dt * 5.0))


func pad_edge(index: int) -> bool:
	var pads = Input.get_connected_joypads()
	var current = not pads.is_empty() and Input.is_joy_button_pressed(pads[0], index)
	var previous = previous_pad_buttons.get(index, false)
	previous_pad_buttons[index] = current
	return current and not previous


func pad_axis(axis: int) -> float:
	var pads = Input.get_connected_joypads()
	return Input.get_joy_axis(pads[0], axis) if not pads.is_empty() else 0.0


func throttle_input(up: float, down: float, left_trigger: float, right_trigger: float) -> float:
	# A deliberate keyboard command takes priority over a controller's resting axes.
	if up > 0.0 or down > 0.0:
		return clamp(up - down, -1.0, 1.0)
	# Godot's trigger axes are 0..1, unlike signed stick axes.
	return clamp(right_trigger, 0.0, 1.0) - clamp(left_trigger, 0.0, 1.0)


func toggle_landing_gear() -> void:
	if paused or frozen or settings_open or observing or observation_frozen:
		return
	if model.toggle_landing_gear():
		takeoff.queue_toast("GEAR EXTENDING" if model.gear_target_down else "GEAR RETRACTING")
	elif model.on_ground:
		takeoff.queue_toast("GEAR / GROUND LOCK")


func deadzone(value: float) -> float:
	if abs(value) < 0.12:
		return 0.0
	return sign(value) * (abs(value) - 0.12) / 0.88


func mouse_over_flight_ui() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered is Button or hovered is HSlider or hovered is CheckBox or hovered is PanelContainer:
			return true
		hovered = hovered.get_parent()
	return false


func read_controls() -> Dictionary:
	if pad_edge(JOY_BUTTON_START):
		toggle_pause()
	if pad_edge(JOY_BUTTON_Y):
		toggle_camera()
	if pad_edge(JOY_BUTTON_X):
		reset_flight()
	var pad_pitch = -deadzone(pad_axis(JOY_AXIS_LEFT_Y))
	var pad_roll = deadzone(pad_axis(JOY_AXIS_LEFT_X))
	var pad_yaw = Input.get_action_strength("yaw_right") - Input.get_action_strength("yaw_left")
	var right_trigger = pad_axis(JOY_AXIS_TRIGGER_RIGHT)
	var left_trigger = pad_axis(JOY_AXIS_TRIGGER_LEFT)
	var pitch_input = Input.get_action_strength("pitch_up") - Input.get_action_strength("pitch_down") + pad_pitch
	var roll_input = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left") + pad_roll
	var yaw_input = pad_yaw + pad_axis(JOY_AXIS_RIGHT_X)
	if settings.values.invert_pitch:
		pitch_input = -pitch_input
	return {
		"pitch": clamp(pitch_input, -1.0, 1.0),
		"roll": clamp(roll_input, -1.0, 1.0),
		"yaw": clamp(yaw_input, -1.0, 1.0),
		"throttleDelta": throttle_input(Input.get_action_strength("throttle_up"), Input.get_action_strength("throttle_down"), left_trigger, right_trigger),
		"airbrake": Input.is_action_pressed("airbrake") or (not Input.get_connected_joypads().is_empty() and Input.is_joy_button_pressed(Input.get_connected_joypads()[0], JOY_BUTTON_A)),
	}


func _physics_process(dt: float) -> void:
	previous_model_position = model.position
	previous_model_orientation = model.orientation
	previous_model_speed = model.speed
	if combat != null:
		combat.hold = intro_active or enemy_spawn_pending or paused or frozen or settings_open or observing or observation_frozen or model.crashed
	if intro_active or observing:
		return
	if not paused and not frozen and not settings_open and not model.crashed:
		if enemy_spawn_pending:
			enemy_spawn_countdown = max(0.0, enemy_spawn_countdown - dt)
			if enemy_spawn_countdown <= 0.0:
				spawn_pending_enemies()
		var controls = read_controls()
		if combat != null and combat.has_method("cinematic_controls"):
			controls = combat.cinematic_controls(dt, controls)
		if combat != null and level_id != 4:
			controls = combat.apply_nose_assist(dt, controls)
		model.step(dt, controls)
		if combat != null and level_id != 4:
			combat.apply_gun_assist(dt)
		if takeoff != null:
			takeoff.step(dt)


func _process(dt: float) -> void:
	var interpolation = clamp(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	visual_position = previous_model_position.lerp(model.position, interpolation)
	visual_orientation = previous_model_orientation.slerp(model.orientation, interpolation).normalized()
	visual_speed = lerp(previous_model_speed, model.speed, interpolation)
	aircraft_root.position = visual_position
	aircraft_root.quaternion = visual_orientation
	var throttle = model.throttle
	if prop != null:
		var hold_prop = (paused and not observing) or frozen or observation_frozen or model.crashed
		prop.rotation.x += (0.0 if hold_prop else (5.0 + throttle * 52.0) * dt)
	var inputs = model.inputs
	update_control_surfaces(dt, inputs)
	if transport_gear != null:
		transport_gear.apply_extension(model.gear_extension)
		transport_gear.apply_suspension(model.landing_gear_strokes())
	if intro_active:
		update_intro_camera(dt)
	elif observing:
		update_observation_camera(dt)
	else:
		update_camera(dt)
	if wingtip_trails != null:
		wingtip_trails.update_trail(dt, model, intro_active or paused or frozen or settings_open or observing or observation_frozen or model.crashed)
	var hold_clouds = observation_frozen or (level_id != 3 and (paused or frozen or settings_open))
	if strike_island != null:
		strike_island.set_simulation_paused(paused or frozen or settings_open or observing or observation_frozen)
	if not hold_clouds:
		cloud_time += dt
	update_atmosphere()
	hud.update_state(model.telemetry())
	cockpit_hud.update_state(model.telemetry())
	hud.set_free_look(free_look_active)
	if combat != null:
		var combat_state = combat.snapshot()
		hud.update_combat(combat_state)
		cockpit_hud.update_combat(combat_state)
	update_audio()
	if perf_enabled:
		perf_elapsed += dt
		if perf_elapsed >= 3.0:
			print("PERF: fps=", Engine.get_frames_per_second())
			perf_elapsed = 0.0


func update_control_surfaces(dt: float, inputs: Dictionary) -> void:
	var surface_blend = 1.0 - exp(-dt * 12.0)
	var rudder_blend = 1.0 - exp(-dt * 10.0)
	if level_id == 1:
		if transport_surfaces != null:
			transport_surfaces.apply_inputs(dt, inputs)
		if elevator_l != null:
			elevator_l.rotation.x = lerp(elevator_l.rotation.x, -inputs.pitch * 0.24, surface_blend)
		if elevator_r != null:
			elevator_r.rotation.x = lerp(elevator_r.rotation.x, -inputs.pitch * 0.24, surface_blend)
	else:
		if aileron_l != null:
			aileron_l.rotation.y = 0.0
			aileron_l.rotation.z = lerp(aileron_l.rotation.z, inputs.roll * 0.28, surface_blend)
		if aileron_r != null:
			aileron_r.rotation.y = 0.0
			aileron_r.rotation.z = lerp(aileron_r.rotation.z, -inputs.roll * 0.28, surface_blend)
		if elevator_l != null:
			elevator_l.rotation.y = 0.0
			elevator_l.rotation.z = lerp(elevator_l.rotation.z, -inputs.pitch * 0.24, surface_blend)
		if elevator_r != null:
			elevator_r.rotation.y = 0.0
			elevator_r.rotation.z = lerp(elevator_r.rotation.z, -inputs.pitch * 0.24, surface_blend)
	if rudder != null:
		rudder.rotation.y = lerp(rudder.rotation.y, inputs.yaw * 0.30, rudder_blend)


func apply_performance_settings(force: bool = false) -> void:
	if settings == null:
		return
	var scale = clamp(float(settings.values.get("render_scale", 1.0)), 0.5, 1.0)
	if force or scale != applied_render_scale:
		get_tree().root.scaling_3d_scale = scale
		applied_render_scale = scale
	var cap = int(settings.values.get("fps_cap", 0))
	if force or cap != applied_fps_cap:
		Engine.max_fps = cap
		applied_fps_cap = cap
	var use_volume_clouds = bool(settings.values.get("volume_clouds", true))
	if cloud_material != null and (force or use_volume_clouds != applied_volume_clouds):
		if use_volume_clouds:
			world_environment.sky.sky_material = cloud_material
		else:
			if fallback_sky_material == null:
				fallback_sky_material = ProceduralSkyMaterial.new()
				fallback_sky_material.sky_top_color = Color("#326b9f")
				fallback_sky_material.sky_horizon_color = Color("#a3c1d0")
				fallback_sky_material.ground_bottom_color = Color("#294953")
				fallback_sky_material.ground_horizon_color = Color("#a3c1d0")
				fallback_sky_material.sky_curve = 0.18
				fallback_sky_material.sun_angle_max = 5.0
				fallback_sky_material.sun_curve = 0.08
			world_environment.sky.sky_material = fallback_sky_material
		applied_volume_clouds = use_volume_clouds


func update_atmosphere() -> void:
	apply_performance_settings()
	if cloud_material != null:
		cloud_material.set_shader_parameter("coverage", max(0.80, settings.values.cloud_coverage) if level_id in [2, 5] else (min(0.4, settings.values.cloud_coverage) if level_id in [1, 4] else settings.values.cloud_coverage))
		cloud_material.set_shader_parameter("cloud_top", 7800.0 if level_id in [2, 5] else settings.values.cloud_top)
		cloud_material.set_shader_parameter("cloud_base", 2400.0 if level_id in [2, 5] else (1800.0 if level_id in [1, 4] else -1500.0))
		cloud_material.set_shader_parameter("clear_radius", 1800.0 if level_id in [2, 5] else 0.0)
		cloud_material.set_shader_parameter("cloud_focus", visual_position + visual_orientation * Vector3(0, 0, 600))
		cloud_material.set_shader_parameter("quality", settings.values.cloud_quality)
		cloud_material.set_shader_parameter("cloud_time", cloud_time)
	if sun_light != null:
		sun_light.rotation_degrees.x = -float(settings.values.sun_elevation)
	if world_environment != null:
		world_environment.fog_density = float(settings.values.fog_density)
	hud.update_contrast(settings.values.hud_contrast)


func update_audio() -> void:
	var volume = max(0.0, float(settings.values.audio_volume))
	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(volume) if volume > 0.0 else 0.0)
	if engine_player == null or wind_player == null:
		return
	var muted = (paused and not observing) or frozen or observation_frozen or model.crashed
	var engine_gain = 0.035 + model.throttle * 0.035
	var wind_gain = clamp((model.speed - 30.0) / 1800.0, 0.001, 0.07)
	engine_player.volume_db = -60.0 if muted or engine_gain <= 0.0001 else linear_to_db(engine_gain)
	engine_player.pitch_scale = 0.75 + model.throttle * 0.45 + model.speed * 0.001
	wind_player.volume_db = -60.0 if muted or wind_gain <= 0.0001 else linear_to_db(wind_gain)
	wind_player.pitch_scale = 0.9 + model.speed * 0.002


func set_cockpit_mode(value: bool) -> void:
	reset_free_look()
	if value and (cockpit_eye_front == null or cockpit_eye_rear == null):
		push_warning("Cockpit eye anchors are missing")
		return
	if value and observing:
		exit_observation()
	if cockpit_mode == value:
		return
	cockpit_mode = value
	hud.visible = not value and not observing
	cockpit_hud.visible = value and not observing
	camera.near = 0.02 if value else 0.2
	camera.fov = 62.0 if value else 52.0
	snap_camera = true


func switch_cockpit_seat() -> void:
	if level_id == 1:
		match cockpit_seat:
			"front": cockpit_seat = "rear"
			"rear": cockpit_seat = "instructor"
			_: cockpit_seat = "front"
	else:
		cockpit_seat = "rear" if cockpit_seat == "front" else "front"
	cockpit_hud.set_seat(cockpit_seat.to_upper())


func update_cockpit_camera(dt: float) -> void:
	var anchor = cockpit_eye_front
	var default_pitch = 5.77
	if level_id == 1:
		if cockpit_seat == "rear":
			anchor = cockpit_eye_rear
			default_pitch = 4.0
		elif cockpit_seat == "instructor":
			anchor = cockpit_eye_instructor
			default_pitch = 3.0
	elif cockpit_seat == "rear":
		anchor = cockpit_eye_rear
		default_pitch = 4.15
	if anchor == null:
		set_cockpit_mode(false)
		return
	var forward = (visual_orientation * Vector3(0, 0, 1)).normalized()
	var plane_up = (visual_orientation * Vector3.UP).normalized()
	var pitch_down = float(anchor.get_meta("pitch_down_degrees", default_pitch)) if anchor.has_meta("pitch_down_degrees") else default_pitch
	var pitch = deg_to_rad(pitch_down)
	var direction = (forward * cos(pitch) - plane_up * sin(pitch)).normalized()
	camera.global_position = anchor.global_position
	camera.look_at(camera.global_position + direction * 100.0, plane_up)
	camera.fov = lerp(camera.fov, 62.0, 1.0 - exp(-dt * 6.0))


func update_camera(dt: float) -> void:
	if cockpit_mode:
		update_cockpit_camera(dt)
		return
	var forward = (visual_orientation * Vector3(0, 0, 1)).normalized()
	var plane_up = (visual_orientation * Vector3.UP).normalized()
	var distance = float(settings.values.camera_distance) * (3.0 if level_id == 1 else 1.0) * (1.5 if wide_camera else 1.0)
	var height = distance * 0.25
	if not free_look_active:
		var recenter_blend = 1.0 - exp(-dt * 8.0)
		free_look_yaw = lerp(free_look_yaw, 0.0, recenter_blend)
		free_look_pitch = lerp(free_look_pitch, 0.0, recenter_blend)
	var angle_weight = clamp(max(abs(free_look_yaw), abs(free_look_pitch)) * 4.0, 0.0, 1.0)
	var focus_target = 1.0 if free_look_active else angle_weight
	free_look_focus = lerp(free_look_focus, focus_target, 1.0 - exp(-dt * 12.0))

	var desired_offset = -forward * distance + Vector3.UP * height
	desired_offset = Quaternion(Vector3.UP, free_look_yaw) * desired_offset
	var pitch_axis = desired_offset.normalized().cross(Vector3.UP).normalized()
	if pitch_axis.length_squared() > 0.001:
		desired_offset = Quaternion(pitch_axis, free_look_pitch) * desired_offset
	var desired_position = visual_position + desired_offset
	desired_position.y = max(6.0, desired_position.y)
	var normal_look = visual_position + forward * (0.0 if level_id == 1 else 28.0) + Vector3.UP * (5.0 if level_id == 1 else 2.0)
	var orbit_look = visual_position + Vector3.UP * 1.2
	var desired_look = normal_look.lerp(orbit_look, free_look_focus)
	var follow = clamp(float(settings.values.camera_roll_follow), 0.0, 1.0)
	var desired_up = (Vector3.UP * (1.0 - follow) + plane_up * follow).normalized()
	desired_up = desired_up.lerp(Vector3.UP, free_look_focus).normalized()
	if snap_camera or settings_open:
		camera.position = desired_position
		camera_look = desired_look
		snap_camera = false
	else:
		var smoothing = max(0.5, float(settings.values.camera_smoothing))
		if free_look_active:
			smoothing = max(smoothing, 14.0)
		camera.position = camera.position.lerp(desired_position, 1.0 - exp(-dt * smoothing))
		camera_look = camera_look.lerp(desired_look, 1.0 - exp(-dt * smoothing * 1.2))
	camera.look_at(camera_look, desired_up)
	var target_fov = 52.0 + clamp((visual_speed - 60.0) / 100.0, 0.0, 1.0) * float(settings.values.camera_fov_boost) + (1.5 if wide_camera else 0.0)
	if combat != null and combat.has_method("cinematic_active") and combat.cinematic_active():
		target_fov += 10.0
	camera.fov = lerp(camera.fov, target_fov, 1.0 - exp(-dt * 5.0))


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(engine_player):
		engine_player.stop()
		engine_player.stream = null
	if is_instance_valid(wind_player):
		wind_player.stop()
		wind_player.stream = null
