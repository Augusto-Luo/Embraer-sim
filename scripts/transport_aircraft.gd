extends "res://scripts/enemy_aircraft.gd"

const ROUTE_RADIUS = 3500.0
const STRAIGHT_LENGTH = 3200.0
const CRUISE_SPEED = 150.0

var route_origin = Vector3.ZERO
var route_orientation = Quaternion()
var route_distance = 0.0
var route_bank = 0.0
var turning = false


func _ready() -> void:
	route_origin = position
	route_orientation = quaternion
	model = FlightModel.new({
		"position": position,
		"orientation": quaternion,
		"speed": CRUISE_SPEED,
		"invincible": true,
		"boundary_radius": 15000.0,
	})
	previous_position = model.position
	previous_orientation = model.orientation
	visual = load("res://assets/kc390-training.glb").instantiate()
	add_child(visual)
	apply_training_materials(visual, {})
	state = "straight"
	set_meta("gun_hit_radius", 17.0)
	set_meta("missile_hit_radius", 24.0)
	# The transport follows its route regardless of player locks or shots.
	gun_cooldown = INF
	missile_cooldown = INF


func apply_training_materials(node: Node, materials: Dictionary) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var original = node.get_active_material(surface)
			if original is not StandardMaterial3D:
				continue
			var material_name = original.resource_name.to_lower()
			if material_name.contains("glass") or material_name.contains("fan") or material_name.contains("luz") or material_name == "material":
				continue
			var key = original.get_instance_id()
			if not materials.has(key):
				var adjusted = original.duplicate()
				adjusted.albedo_color *= Color(0.55, 0.60, 0.65, 1.0)
				adjusted.roughness = 0.75
				adjusted.metallic = 0.08
				materials[key] = adjusted
			node.set_surface_override_material(surface, materials[key])
	for child in node.get_children():
		apply_training_materials(child, materials)


func notify_player_lock() -> void:
	pass


func notify_missile() -> void:
	pass


func step_ai(dt: float, _director) -> void:
	if destroyed:
		step_wreck(dt)
		return
	previous_position = model.position
	previous_orientation = model.orientation
	state_time += dt
	route_distance += CRUISE_SPEED * dt
	var circuit_length = STRAIGHT_LENGTH * 2.0 + TAU * ROUTE_RADIUS
	var distance = fposmod(route_distance, circuit_length)
	var local_position = Vector3.ZERO
	var yaw = 0.0
	turning = false
	if distance < STRAIGHT_LENGTH:
		local_position.z = distance
	elif distance < STRAIGHT_LENGTH + PI * ROUTE_RADIUS:
		yaw = (distance - STRAIGHT_LENGTH) / ROUTE_RADIUS
		local_position = Vector3(ROUTE_RADIUS * (1.0 - cos(yaw)), 0.0, STRAIGHT_LENGTH + ROUTE_RADIUS * sin(yaw))
		turning = true
	elif distance < STRAIGHT_LENGTH * 2.0 + PI * ROUTE_RADIUS:
		yaw = PI
		local_position = Vector3(ROUTE_RADIUS * 2.0, 0.0, STRAIGHT_LENGTH - (distance - STRAIGHT_LENGTH - PI * ROUTE_RADIUS))
	else:
		yaw = PI + (distance - STRAIGHT_LENGTH * 2.0 - PI * ROUTE_RADIUS) / ROUTE_RADIUS
		local_position = Vector3(ROUTE_RADIUS * (1.0 - cos(yaw)), 0.0, ROUTE_RADIUS * sin(yaw))
	route_bank = lerp(route_bank, deg_to_rad(-12.0 if turning else 0.0), 1.0 - exp(-dt * 1.4))
	model.position = route_origin + route_orientation * local_position
	model.orientation = (route_orientation * Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.BACK, route_bank)).normalized()
	model.speed = CRUISE_SPEED
	model.time += dt
	model.update_attitude()
	state = "wide turn" if turning else "straight"


func apply_hit(kind: String) -> void:
	# Large, forgiving target; damage is only for optional weapons practice.
	if destroyed:
		return
	gun_hits += 30 if kind == "missile" else 1
	if gun_hits >= 30:
		destroyed = true
		state = "destroyed"
		death_time = 0.0
		wreck_velocity = model.forward * model.speed * 0.25
		start_wreck_smoke()
