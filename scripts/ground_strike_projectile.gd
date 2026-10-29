extends "res://scripts/combat_projectile.gd"

var director


func _process(dt: float) -> void:
	if director != null and director.is_held():
		return
	super._process(dt)


func step(dt: float, _targets: Array, _player) -> Dictionary:
	if not active or dt <= 0.0 or (director != null and director.is_held()):
		return {}
	previous_position = position
	if kind == "missile":
		var direction = velocity.normalized()
		if is_instance_valid(target) and not target.destroyed:
			var desired = (target.aim_position() - position).normalized()
			direction = direction.slerp(desired, clampf(turn_rate * dt, 0.0, 1.0)).normalized()
		velocity = direction * minf(max_speed, velocity.length() + 75.0 * dt)
	var destination = position + velocity * dt
	if director != null:
		var impact = director.trace_segment(position, destination, kind)
		if not impact.is_empty():
			position = impact.position
			active = false
			impact.finished = true
			impact.kind = kind
			if impact.get("hit", false):
				impact.damage = impact.target.apply_hit(kind)
			return impact
	position = destination
	point_along_velocity()
	ttl -= dt
	if ttl <= 0.0:
		active = false
		return {"finished": true, "expired": true, "kind": kind, "position": position}
	return {}
