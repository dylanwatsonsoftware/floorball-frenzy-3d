class_name BallInteraction
extends RefCounted

const BODY_CONTACT_DISTANCE := 0.74
const BLADE_FORWARD_OFFSET := 0.9
const BLADE_RIGHT_OFFSET := 0.75
const STICK_CONTROL_RADIUS := 1.25
const RETENTION_RADIUS := 1.9
const CONTROL_HEIGHT := 0.68
const BODY_CONTACT_HEIGHT := 1.5
const DRIBBLE_LEAD_SPEED := 2.2
const VELOCITY_TRANSFER := 0.72
const ASSIST_RATE := 8.0
const MAX_CONTROL_SPEED := 10.0
const MAX_RETENTION_RELATIVE_SPEED := 7.5
const POSITION_ASSIST_RATE := 7.0


static func step(ball_position: Vector3, ball_velocity: Vector3, participants: Array, delta: float, previous_controller: int = -1) -> Dictionary:
	var next_position := ball_position
	var next_velocity := ball_velocity
	if ball_position.y > BODY_CONTACT_HEIGHT:
		return _result(next_position, next_velocity, -1, -1)

	var body_controller := -1
	for body_index in participants.size():
		var participant: Dictionary = participants[body_index]
		var player_position: Vector3 = participant.position
		var player_velocity: Vector3 = participant.velocity
		var planar_offset := Vector2(next_position.x - player_position.x, next_position.z - player_position.z)
		var distance := planar_offset.length()
		if distance >= BODY_CONTACT_DISTANCE:
			continue
		body_controller = body_index

		var fallback := Vector2(participant.facing.x, participant.facing.z).normalized()
		var normal := planar_offset.normalized() if distance > 0.001 else fallback
		if normal.is_zero_approx():
			normal = Vector2.RIGHT
		next_position.x = player_position.x + normal.x * BODY_CONTACT_DISTANCE
		next_position.z = player_position.z + normal.y * BODY_CONTACT_DISTANCE

		var relative_velocity := Vector2(player_velocity.x - next_velocity.x, player_velocity.z - next_velocity.z)
		var transfer_speed := relative_velocity.dot(normal)
		if transfer_speed > 0.0:
			next_velocity.x += normal.x * transfer_speed * VELOCITY_TRANSFER
			next_velocity.z += normal.y * transfer_speed * VELOCITY_TRANSFER

	var controller := -1
	if ball_position.y > CONTROL_HEIGHT:
		return _result(next_position, next_velocity, controller, body_controller)
	var blocked_controller := previous_controller if body_controller >= 0 and body_controller != previous_controller else -1
	if previous_controller >= 0 and previous_controller < participants.size() and previous_controller != blocked_controller:
		var previous_owner: Dictionary = participants[previous_controller]
		var previous_pocket := blade_pocket(previous_owner)
		if not previous_pocket.is_empty():
			var retained_distance: float = Vector2(next_position.x, next_position.z).distance_to(previous_pocket.target)
			var relative_speed: float = Vector2(next_velocity.x - previous_owner.velocity.x, next_velocity.z - previous_owner.velocity.z).length()
			if retained_distance <= RETENTION_RADIUS and relative_speed <= MAX_RETENTION_RELATIVE_SPEED:
				controller = previous_controller
	if controller < 0 and Vector2(next_velocity.x, next_velocity.z).length() > MAX_CONTROL_SPEED:
		return _result(next_position, next_velocity, controller, body_controller)
	var closest_stick_distance := INF
	for index in participants.size():
		if controller >= 0 or index == blocked_controller:
			continue
		var participant: Dictionary = participants[index]
		var pocket := blade_pocket(participant)
		if pocket.is_empty() or not is_in_blade_pocket(next_position, participant):
			continue
		var stick_distance: float = Vector2(next_position.x, next_position.z).distance_to(pocket.target)
		if stick_distance <= STICK_CONTROL_RADIUS and stick_distance < closest_stick_distance:
			controller = index
			closest_stick_distance = stick_distance

	if controller >= 0:
		var owner: Dictionary = participants[controller]
		var owner_facing := Vector2(owner.facing.x, owner.facing.z).normalized()
		if owner.get("slap_phase", &"idle") == &"backswing":
			next_velocity.x = owner.velocity.x
			next_velocity.z = owner.velocity.z
			return _result(next_position, next_velocity, controller, body_controller)
		var pocket := blade_pocket(owner)
		var ball_planar := Vector2(next_position.x, next_position.z)
		ball_planar = ball_planar.lerp(pocket.target, clampf(delta * POSITION_ASSIST_RATE, 0.0, 1.0))
		next_position.x = ball_planar.x
		next_position.z = ball_planar.y
		var target_velocity := Vector2(owner.velocity.x, owner.velocity.z) + owner_facing * DRIBBLE_LEAD_SPEED
		var current_velocity := Vector2(next_velocity.x, next_velocity.z)
		var assisted_velocity := current_velocity.lerp(target_velocity, clampf(delta * ASSIST_RATE, 0.0, 1.0))
		next_velocity.x = assisted_velocity.x
		next_velocity.z = assisted_velocity.y

	return _result(next_position, next_velocity, controller, body_controller)


static func blade_pocket(participant: Dictionary) -> Dictionary:
	var facing := Vector2(participant.facing.x, participant.facing.z).normalized()
	if facing.is_zero_approx():
		return {}
	var right := Vector2(-facing.y, facing.x)
	var player_planar := Vector2(participant.position.x, participant.position.z)
	var target := player_planar + facing * BLADE_FORWARD_OFFSET + right * BLADE_RIGHT_OFFSET
	if participant.has("blade_target"):
		var blade_target: Vector3 = participant.blade_target
		target = Vector2(blade_target.x, blade_target.z)
	return {
		"facing": facing,
		"right": right,
		"target": target,
		"player": player_planar,
	}


static func is_in_blade_pocket(ball_position: Vector3, participant: Dictionary) -> bool:
	var pocket := blade_pocket(participant)
	if pocket.is_empty() or ball_position.y > CONTROL_HEIGHT:
		return false
	var ball_planar := Vector2(ball_position.x, ball_position.z)
	var relative: Vector2 = ball_planar - pocket.player
	if relative.dot(pocket.facing) <= 0.08:
		return false
	# Authored 3D blade markers already identify the concave playing face and
	# may be mirrored around either team's player. Keep the side heuristic only
	# for the mathematical fallback pocket, where it prevents back-face pickup.
	if not participant.has("blade_target") and relative.dot(pocket.right) <= -0.3:
		return false
	return ball_planar.distance_to(pocket.target) <= STICK_CONTROL_RADIUS


static func _result(position: Vector3, velocity: Vector3, controller: int, body_controller: int) -> Dictionary:
	return {
		"position": position,
		"velocity": velocity,
		"controller": controller,
		"body_controller": body_controller,
	}
