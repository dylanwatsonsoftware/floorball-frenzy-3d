class_name OnlineInput
extends RefCounted


static func compose_movement_input(keyboard_or_controller: Vector2, mobile_joystick: Vector2) -> Vector2:
	return (keyboard_or_controller + mobile_joystick).limit_length(1.0)


static func predict_position(current: Vector3, movement: Vector2, delta: float, speed: float) -> Vector3:
	return current + Vector3(movement.x, 0.0, movement.y).limit_length(1.0) * speed * maxf(delta, 0.0)


static func reconcile_position(current: Vector3, authoritative: Vector3, locally_predicted: bool) -> Vector3:
	var error := current.distance_to(authoritative)
	var weight := 0.18 if locally_predicted and error < 2.5 else 0.72
	return current.lerp(authoritative, weight)


static func next_action_sequence(current: int, just_pressed: bool) -> int:
	return current + 1 if just_pressed else current
