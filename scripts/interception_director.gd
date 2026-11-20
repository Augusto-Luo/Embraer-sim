extends Node3D

# Level 05 is a self-contained night navigation mission. No combat or control
# assistance is attached outside the short encounter; its stabilizer uses the same flight forces.
const EchoContact = preload("res://scripts/echo_contact.gd")
const EchoAudio = preload("res://scripts/echo_audio.gd")
const EchoMothman = preload("res://scripts/echo_mothman.gd")
const TransportProfile = preload("res://scripts/transport_profile.gd")
const REVEAL_SECONDS = 14.0
const FOLLOW_REQUIRED = 6.0
const ESCORT_SECONDS = 35.0
const NAV_RADIUS = 650.0
const DEVIATION_GRACE = 20.0

var player
var camera: Camera3D
var controller
var stage = "night_flight"
var stage_elapsed = 0.0
var mission_elapsed = 0.0
var follow_time = 0.0
var escort_time = 0.0
var drift_time = 0.0
var warning = ""
var completed = false
var failed = false
var origin = Vector3.ZERO
var route_forward = Vector3.BACK
var route_right = Vector3.RIGHT
var signal_position = Vector3.ZERO
var safe_waypoints: Array[Vector3] = []
var waypoint_index = 0
var contact
var audio
var navigation_ring: MeshInstance3D
var ring_material: StandardMaterial3D
var radio_text = "NIGHT CORRIDOR CLEAR. MAINTAIN YOUR FLIGHT PATH."
var radio_source = "RANGE CONTROL"
var radio_interference = 0.0
var contact_distance = 0.0
var nav_distance = 0.0
var nose_angle = 180.0
var last_contact_position = Vector3.ZERO
var ghost_revealed = false
var final_echo_sent = false
var monster
var monster_time = -1.0
var reveal_heading = Vector3.BACK
var reveal_altitude = 5200.0
var reveal_speed = 100.0
var reveal_cues = {}



func _ready() -> void:
	controller = get_parent()
	build_navigation_ring()
	audio = EchoAudio.new()
	audio.controller = controller
	add_child(audio)
	monster = EchoMothman.new()
	add_child(monster)
	restart()


func restart() -> void:
	if is_instance_valid(contact):
		remove_child(contact)
		contact.queue_free()
	contact = null
	monster_time = -1.0
	reveal_cues.clear()
	if monster != null:
		monster.clear()
	if controller != null:
		controller.echo_lightning = 0.0
		controller.echo_clearance = 0.0
	stage = "night_flight"
	stage_elapsed = 0.0
	mission_elapsed = 0.0
	follow_time = 0.0
	escort_time = 0.0
	drift_time = 0.0
	warning = ""
	completed = false
	failed = false
	ghost_revealed = false
	final_echo_sent = false
	origin = player.position
	route_forward = Vector3(player.forward.x, 0.0, player.forward.z).normalized()
	if route_forward.length_squared() < 0.1:
		route_forward = Vector3.BACK
	route_right = Vector3(route_forward.z, 0.0, -route_forward.x)
	signal_position = origin + route_forward * 2400.0
	safe_waypoints.clear()
	waypoint_index = 0
	last_contact_position = signal_position
	contact_distance = 0.0
	nav_distance = player.position.distance_to(signal_position)
	radio_text = "NIGHT CORRIDOR CLEAR. MAINTAIN YOUR FLIGHT PATH."
	radio_source = "RANGE CONTROL"
	radio_interference = 0.0
	if audio != null:
		audio.restart()
	if navigation_ring != null:
		navigation_ring.visible = true
		update_navigation_ring()


func is_held() -> bool:
	return controller == null or controller.intro_active or controller.paused or controller.frozen or controller.settings_open or controller.observing or controller.observation_frozen


func change_stage(value: String, text: String, source: String = "RANGE CONTROL") -> void:
	stage = value
	stage_elapsed = 0.0
	drift_time = 0.0
	warning = ""
	radio_text = text
	radio_source = source
	audio.current_stage = value


func _physics_process(dt: float) -> void:
	var hold = is_held()
	audio.set_held(hold)
	if navigation_ring != null:
		navigation_ring.visible = not controller.observing and not controller.intro_active and stage not in ["complete", "failed", "monster_reveal", "free_flight"]
	if hold or player == null or dt <= 0.0 or stage == "failed":
		return
	if stage == "complete":
		stage_elapsed += dt
		if stage_elapsed >= 4.0 and not final_echo_sent:
			final_echo_sent = true
			radio_source = "ECO-13 / UNKNOWN"
			radio_text = "THANK YOU FOR KEEPING THE LIGHTS ON."
			radio_interference = 0.25
			audio.play_cue("echo")
		return
	mission_elapsed += dt
	stage_elapsed += dt
	if monster_time >= 0.0:
		monster_time += dt
		monster.flash_strength = lightning_value()
		monster.step(dt, monster_time)
	controller.echo_lightning = lightning_value()
	if is_instance_valid(contact) and stage in ["contact", "escort", "lost_contact"]:
		contact.step(dt)
		last_contact_position = contact.position
		contact_distance = player.position.distance_to(contact.position)
		var toward = (contact.position - player.position).normalized()
		nose_angle = rad_to_deg(acos(clamp(player.forward.dot(toward), -1.0, 1.0)))
	nav_distance = player.position.distance_to(navigation_position())
	match stage:
		"night_flight":
			if stage_elapsed >= 20.0 and nav_distance <= 900.0:
				change_stage("signal", "UNKNOWN CARRIER AT BEACON 13. PROCEED AND IDENTIFY.")
				radio_interference = 0.3
				audio.play_cue("static")
			else:
				check_navigation_deviation(dt, nav_distance > 4500.0 or abs(player.position.y - origin.y) > 1000.0)
		"signal":
			if stage_elapsed >= 6.0 and nav_distance <= 1200.0:
				spawn_contact()
				change_stage("contact", "ECO-13. WE HAVE BEEN EXPECTING YOU.", "ECO-13 / UNKNOWN")
				radio_interference = 0.55
				audio.play_cue("echo")
			else:
				check_navigation_deviation(dt, nav_distance > 3500.0 or abs(player.position.y - origin.y) > 1000.0)
		"contact":
			var aligned = player.forward.dot(contact.forward) > 0.45 and (player.position - contact.position).dot(contact.forward) < -100.0
			var in_window = contact_distance >= 800.0 and contact_distance <= 1400.0 and nose_angle <= 20.0 and aligned
			follow_time = min(FOLLOW_REQUIRED, follow_time + dt) if in_window else max(0.0, follow_time - dt * 0.35)
			check_navigation_deviation(dt, contact_distance > 3800.0 or abs(player.position.y - origin.y) > 1000.0)
			if stage != "failed" and follow_time >= FOLLOW_REQUIRED:
				contact.begin_arc()
				change_stage("escort", "CONTACT CONFIRMED. FOLLOW THE LIGHTS. KEEP YOUR DISTANCE.")
				radio_interference = 0.2
				audio.play_cue("echo")
		"escort":
			var following = contact_distance >= 400.0 and contact_distance <= 2200.0 and nose_angle < 65.0 and abs(player.position.y - origin.y) < 700.0
			if following:
				escort_time += dt
			check_navigation_deviation(dt, not following)
			if stage != "failed" and escort_time >= ESCORT_SECONDS:
				prepare_safe_route()
				change_stage("lost_contact", "ECO-13... THERE IS NO AIRCRAFT REGISTERED ON THAT CHANNEL.")
				radio_interference = 0.85
				audio.play_cue("static")
		"lost_contact":
			if is_instance_valid(contact):
				contact.set_opacity(1.0 - smoothstep(0.0, 6.0, stage_elapsed))
			if stage_elapsed >= 8.0 and reveal_entry_ready():
				if is_instance_valid(contact):
					contact.queue_free()
				contact = null
				begin_monster_reveal()
			elif stage_elapsed >= 8.0:
				check_navigation_deviation(dt, true)
				warning = "NIVELE AS ASAS" if stage != "failed" else "ROTA PERDIDA"
		"monster_reveal":
			for cue in [[8.0, "thunder_far"], [10.8, "thunder_near"], [11.7, "pressure"]]:
				if stage_elapsed >= float(cue[0]) and not reveal_cues.has(cue[1]):
					reveal_cues[cue[1]] = true
					audio.play_cue(cue[1])
			if stage_elapsed >= REVEAL_SECONDS:
				finish_monster_reveal()
		"free_flight":
			# No course, altitude, distance or elapsed-time failure in exploration.
			drift_time = 0.0
			warning = ""
			if stage_elapsed >= 14.0:
				radio_text = ""
		"return_route":
			if nav_distance <= NAV_RADIUS:
				waypoint_index += 1
				drift_time = 0.0
				if waypoint_index >= safe_waypoints.size():
					completed = true
					change_stage("complete", "SAFE CORRIDOR CONFIRMED. ECO-13 IS NO LONGER ON RADAR.")
					radio_interference = 0.0
					audio.play_cue("echo")
				else:
					radio_text = "BEACON ONE CONFIRMED. CONTINUE TO THE EXIT."
					audio.play_cue("echo")
			else:
				check_navigation_deviation(dt, nav_distance > 4300.0 or abs(player.position.y - origin.y) > 1000.0)
	update_navigation_ring()


func check_navigation_deviation(dt: float, deviating: bool) -> void:
	if deviating or player.outside_boundary:
		drift_time += dt
		warning = "RETORNE AO SINAL" if stage in ["contact", "escort"] else "RETORNE AO CORREDOR"
		if drift_time >= DEVIATION_GRACE:
			failed = true
			change_stage("failed", "SIGNAL LOST. RETURN TO MISSION SELECT OR RESTART THE FLIGHT.")
			warning = "ROTA PERDIDA"
			radio_interference = 0.45
			audio.play_cue("static")
	else:
		drift_time = max(0.0, drift_time - dt * 2.0)
		warning = "" if drift_time <= 0.0 else "RETORNANDO AO CORREDOR"


func spawn_contact() -> void:
	contact = EchoContact.new()
	var heading = Vector3(player.forward.x, 0.0, player.forward.z).normalized()
	if heading.length_squared() < 0.1:
		heading = route_forward
	contact.position = player.position + heading * 1600.0
	contact.position.y = origin.y
	contact.quaternion = Quaternion(Vector3.UP, atan2(heading.x, heading.z))
	add_child(contact)
	last_contact_position = contact.position
	contact_distance = player.position.distance_to(contact.position)
	ghost_revealed = true


func prepare_safe_route() -> void:
	# Continue the wide right bend instead of asking a heavy transport to make
	# an immediate U-turn. The two exit legs remain inside the mission boundary.
	var heading = Vector3(player.forward.x, 0.0, player.forward.z).normalized()
	if heading.length_squared() < 0.1:
		heading = route_forward
	var lateral = Vector3(heading.z, 0.0, -heading.x)
	var first = player.position + heading * 3000.0 + lateral * 2300.0
	var second = first + heading * 1300.0 + lateral * 3500.0
	safe_waypoints.clear()
	for point in [first, second]:
		# Clamp only unusually long investigations; exits stay inside the world.
		var horizontal = Vector2(point.x, point.z).limit_length(12500.0)
		safe_waypoints.append(Vector3(horizontal.x, origin.y, horizontal.y))
	waypoint_index = 0


func navigation_position() -> Vector3:
	if stage == "free_flight":
		return player.position
	if stage in ["contact", "escort"] and is_instance_valid(contact):
		return contact.position
	if stage in ["lost_contact", "monster_reveal", "return_route", "complete"] and not safe_waypoints.is_empty():
		return safe_waypoints[min(waypoint_index, safe_waypoints.size() - 1)]
	return signal_position


func contact_position() -> Vector3:
	return contact.position if is_instance_valid(contact) else last_contact_position


func build_navigation_ring() -> void:
	navigation_ring = MeshInstance3D.new()
	navigation_ring.name = "NightNavigationBeacon"
	var ring = TorusMesh.new()
	ring.inner_radius = 255.0
	ring.outer_radius = 260.0
	ring.rings = 48
	ring.ring_segments = 6
	navigation_ring.mesh = ring
	navigation_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(0.49, 0.85, 0.75, 0.24)
	ring_material.emission_enabled = true
	ring_material.emission = Color("89d8c7")
	ring_material.emission_energy_multiplier = 0.45
	ring_material.no_depth_test = false
	navigation_ring.material_override = ring_material
	add_child(navigation_ring)


func update_navigation_ring() -> void:
	if navigation_ring == null:
		return
	navigation_ring.position = navigation_position()
	var toward = navigation_ring.position - player.position
	if toward.length_squared() > 1.0:
		navigation_ring.quaternion = Quaternion(Vector3.UP, atan2(toward.x, toward.z)) * Quaternion(Vector3.RIGHT, PI * 0.5)
	var terminal = stage in ["lost_contact", "return_route"]
	ring_material.albedo_color = Color(0.96, 0.71, 0.39, 0.28) if terminal else Color(0.49, 0.85, 0.75, 0.20)
	ring_material.emission = Color("f5c38c") if terminal else Color("89d8c7")
	# Keep the aircraft silhouette free of a giant ring during the investigation.
	navigation_ring.visible = navigation_ring.visible and stage not in ["contact", "escort", "monster_reveal", "free_flight"]


func interception_snapshot() -> Dictionary:
	var title = "CORREDOR NOTURNO"
	var objective = "Mantenha o rumo até o sinalizador."
	var detail = "KC-390 / Voo noturno a 5.200 m."
	var progress = clamp(stage_elapsed / 20.0, 0.0, 1.0)
	var label = "BEACON 13"
	match stage:
		"signal":
			title = "SINAL DESCONHECIDO"
			objective = "Aproxime-se do sinal ECO-13."
			detail = "Um chamado surgiu na frequência de emergência."
			progress = clamp(stage_elapsed / 6.0, 0.0, 1.0)
		"contact":
			title = "CONTATO ECO-13"
			objective = "Acompanhe o contato por 6 segundos."
			detail = "Mantenha 800–1.400 m, pela cauda, com o contato à frente."
			progress = clamp(follow_time / FOLLOW_REQUIRED, 0.0, 1.0)
			label = "ECO-13"
		"escort":
			title = "SIGA AS LUZES"
			objective = "Acompanhe a curva do ECO-13."
			detail = "Use curvas suaves. Mantenha 400–2.200 m e a mesma altitude."
			progress = clamp(escort_time / ESCORT_SECONDS, 0.0, 1.0)
			label = "ECO-13"
		"lost_contact":
			title = "CONTATO PERDIDO"
			objective = "Nivele as asas e observe à frente."
			detail = "O ECO-13 desapareceu. Nivele as asas e mantenha a altitude."
			progress = clamp(stage_elapsed / 8.0, 0.0, 1.0)
			label = "LAST SIGNAL"
		"monster_reveal":
			title = "TRANSMISSÃO INTERROMPIDA"
			objective = "Mantenha a calma."
			detail = ""
			progress = clamp(stage_elapsed / REVEAL_SECONDS, 0.0, 1.0)
			label = ""
		"free_flight":
			title = "VOO LIVRE"
			objective = "Explore livremente."
			detail = "Aproxime-se, circule e observe no seu ritmo. O controle é seu."
			progress = 0.0
			label = ""
		"return_route":
			title = "ROTA DE SAÍDA"
			objective = "Siga os dois sinalizadores âmbar."
			detail = "Sinalizador %d / 2. Retorne ao ar livre." % (min(waypoint_index + 1, 2))
			progress = float(waypoint_index) / 2.0
			label = "EXIT BEACON %02d" % (min(waypoint_index + 1, 2))
		"complete":
			title = "VOO CONCLUÍDO"
			objective = "Você saiu do corredor."
			detail = "Nenhum ECO-13 consta no registro de voo."
			progress = 1.0
		"failed":
			title = "ROTA PERDIDA"
			objective = "Você se afastou do corredor."
			detail = "Reinicie o voo para investigar o sinal novamente."
			progress = 0.0
	var has_contact = is_instance_valid(contact) and stage in ["contact", "escort"]
	return {
		"cinematic": cinematic_active(), "cinematic_time": stage_elapsed,
		"navigation_active": stage != "free_flight", "free_flight": stage == "free_flight", "stage_elapsed": stage_elapsed,
		"stage": stage, "title": title, "objective": objective, "detail": detail,
		"target_id": "ECO-13", "target_valid": has_contact,
		"distance": contact_distance if has_contact else nav_distance,
		"waypoint_distance": nav_distance, "waypoint_index": min(waypoint_index + 1, 2), "waypoint_count": 2 if stage in ["return_route", "lost_contact"] else 1,
		"progress": progress, "follow_time": follow_time, "follow_required": FOLLOW_REQUIRED,
		"mission_elapsed": mission_elapsed, "warning": warning, "completed": completed, "failed": failed,
		"navigation_position": navigation_position(), "contact_position": contact_position(), "nav_label": label,
		"radio_text": radio_text, "radio_source": radio_source, "radio_interference": radio_interference,
		"drift_time": drift_time, "signal_lost": stage == "lost_contact", "angle": nose_angle,
	}


func cinematic_active() -> bool:
	return stage == "monster_reveal"


func begin_monster_reveal() -> void:
	reveal_heading = Vector3(player.forward.x, 0.0, player.forward.z).normalized()
	if reveal_heading.length_squared() < 0.1:
		reveal_heading = route_forward
	reveal_altitude = player.position.y
	reveal_speed = clamp(player.speed, 85.0, 105.0)
	monster.begin(player.position, reveal_heading)
	monster_time = 0.0
	reveal_cues.clear()
	change_stage("monster_reveal", "", "ECO-13 / CARRIER LOST")
	radio_interference = 0.0
	controller.begin_echo_reveal()


func finish_monster_reveal() -> void:
	if not cinematic_active():
		return
	controller.echo_lightning = 0.0
	controller.camera.fov = 62.0
	monster.flash_strength = 0.0
	# Keep the same actor and aircraft state. Only the brief stabilizer ends.
	monster.enter_free_flight()
	player.boundary_radius = INF
	player.outside_boundary = false
	safe_waypoints.clear()
	nav_distance = 0.0
	if navigation_ring != null:
		navigation_ring.hide()
	change_stage("free_flight", "FLIGHT CONTROLS ARE YOURS. EXPLORE AT YOUR DISCRETION.")
	radio_interference = 0.0


func lightning_value() -> float:
	if not cinematic_active():
		return 0.0
	var t = stage_elapsed
	var first = smoothstep(7.05, 7.10, t) * (1.0 - smoothstep(7.37, 7.85, t)) * 0.62
	var main = smoothstep(9.48, 9.53, t) * (1.0 - smoothstep(10.02, 10.95, t))
	return max(first, main)


func cinematic_controls(_dt: float, controls: Dictionary) -> Dictionary:
	if not cinematic_active():
		return controls
	# A short, limited stabilizer drives the same force-based transport model.
	# It never sets position, orientation, speed or engine power directly.
	var heading_error = wrapf(atan2(reveal_heading.x, reveal_heading.z) - atan2(player.forward.x, player.forward.z), -PI, PI)
	var bank_target = clamp(-heading_error * 1.1, -0.30, 0.30)
	var roll = clamp((bank_target - player.bank) * 3.0 - player.angular_rates.y * 0.8, -1.0, 1.0)
	var pitch_target = TransportProfile.angle_of_attack(player.speed) + clamp((reveal_altitude - player.position.y) * 0.0009 - player.vertical_speed * 0.012, -0.12, 0.12)
	var pitch = clamp((pitch_target - player.pitch) * 6.0 - player.angular_rates.x * 0.9, -1.0, 1.0)
	var throttle = clamp((0.04 + 0.0004 * reveal_speed * reveal_speed) / 4.6 + (reveal_speed - player.speed) * 0.055, 0.0, 1.0)
	return {"pitch": pitch, "roll": roll, "yaw": 0.0, "throttleDelta": clamp((throttle - player.throttle) * 12.0, -1.0, 1.0), "airbrake": false}


func reveal_entry_ready() -> bool:
	var trim_pitch = TransportProfile.angle_of_attack(player.speed)
	return abs(player.bank) < 0.32 and abs(player.pitch - trim_pitch) < 0.16 and abs(player.vertical_speed) < 12.0 and player.speed >= 70.0 and player.speed <= 145.0 and not player.outside_boundary
