class_name BallInteraction
extends RefCounted

const BODY_CONTACT_DISTANCE := 0.74
const STICK_REACH := 1.3
const STICK_CONTROL_RADIUS := 0.78
const CONTROL_HEIGHT := 0.68
const DRIBBLE_LEAD_SPEED := 2.2
const VELOCITY_TRANSFER := 0.72
const ASSIST_RATE := 8.0
const MAX_CONTROL_SPEED := 10.0


static func step(ball_position: Vector3, ball_velocity: Vector3, participants: Array, delta: float) -> Dictionary:
	var next_position := ball_position
	var next_velocity := ball_velocity
	if ball_position.y > CONTROL_HEIGHT:
		return _result(next_position, next_velocity, -1)

	for participant in participants:
		var player_position: Vector3 = participant.position
		var player_velocity: Vector3 = participant.velocity
		var planar_offset := Vector2(next_position.x - player_position.x, next_position.z - player_position.z)
		var distance := planar_offset.length()
		if distance >= BODY_CONTACT_DISTANCE:
			continue

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
	if Vector2(next_velocity.x, next_velocity.z).length() > MAX_CONTROL_SPEED:
		return _result(next_position, next_velocity, controller)
	var closest_stick_distance := INF
	for index in participants.size():
		var participant: Dictionary = participants[index]
		var facing := Vector2(participant.facing.x, participant.facing.z).normalized()
		if facing.is_zero_approx():
			continue
		var player_planar := Vector2(participant.position.x, participant.position.z)
		var stick_target := player_planar + facing * STICK_REACH
		var ball_planar := Vector2(next_position.x, next_position.z)
		var stick_distance := ball_planar.distance_to(stick_target)
		if stick_distance <= STICK_CONTROL_RADIUS and stick_distance < closest_stick_distance:
			controller = index
			closest_stick_distance = stick_distance

	if controller >= 0:
		var owner: Dictionary = participants[controller]
		var owner_facing := Vector2(owner.facing.x, owner.facing.z).normalized()
		var target_velocity := Vector2(owner.velocity.x, owner.velocity.z) + owner_facing * DRIBBLE_LEAD_SPEED
		var current_velocity := Vector2(next_velocity.x, next_velocity.z)
		var assisted_velocity := current_velocity.lerp(target_velocity, clampf(delta * ASSIST_RATE, 0.0, 1.0))
		next_velocity.x = assisted_velocity.x
		next_velocity.z = assisted_velocity.y

	return _result(next_position, next_velocity, controller)


static func _result(position: Vector3, velocity: Vector3, controller: int) -> Dictionary:
	return {
		"position": position,
		"velocity": velocity,
		"controller": controller,
	}
