class_name OnlineInput
extends RefCounted

const DEFAULT_SNAPSHOT_SECONDS := 1.0 / 30.0
const MAX_REPLICA_PREDICTION_STEP := 0.05


static func compose_movement_input(keyboard_or_controller: Vector2, mobile_joystick: Vector2) -> Vector2:
	return (keyboard_or_controller + mobile_joystick).limit_length(1.0)


static func predict_position(current: Vector3, movement: Vector2, delta: float, speed: float) -> Vector3:
	return current + Vector3(movement.x, 0.0, movement.y).limit_length(1.0) * speed * maxf(delta, 0.0)


static func predict_replica_position(current: Vector3, authoritative_velocity: Vector3, delta: float) -> Vector3:
	return current + authoritative_velocity * clampf(delta, 0.0, MAX_REPLICA_PREDICTION_STEP)


static func reconcile_position(current: Vector3, authoritative: Vector3, locally_predicted: bool) -> Vector3:
	var error := current.distance_to(authoritative)
	if locally_predicted and error < 0.32:
		return current
	var weight := 0.1 if locally_predicted and error < 2.5 else 0.72
	return current.lerp(authoritative, weight)


static func reconcile_ball_position(current: Vector3, authoritative: Vector3) -> Vector3:
	var error := current.distance_to(authoritative)
	if error < 0.18:
		return current
	var weight := 0.18 if error < 1.2 else 0.72
	return current.lerp(authoritative, weight)


static func reconcile_rotation(current: float, authoritative: float, locally_predicted: bool, actively_steering: bool) -> float:
	if locally_predicted and actively_steering:
		return current
	return lerp_angle(current, authoritative, 0.55)


static func next_action_sequence(current: int, just_pressed: bool) -> int:
	return current + 1 if just_pressed else current


static func prediction_speed(has_ball: bool) -> float:
	return 9.0 * (0.88 if has_ball else 1.0)
