class_name OnlineInput
extends RefCounted


static func compose_movement_input(keyboard_or_controller: Vector2, mobile_joystick: Vector2) -> Vector2:
	return (keyboard_or_controller + mobile_joystick).limit_length(1.0)
