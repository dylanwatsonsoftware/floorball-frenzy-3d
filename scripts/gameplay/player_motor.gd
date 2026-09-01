class_name PlayerMotor
extends RefCounted

const MAX_SPEED := 9.0
const ACCELERATION := 32.0
const DECELERATION := 24.0


static func step_velocity(current: Vector3, input_vector: Vector2, delta: float) -> Vector3:
	var planar := Vector3(current.x, 0.0, current.z)
	var input_direction := input_vector.limit_length(1.0)
	var target := Vector3(input_direction.x, 0.0, input_direction.y) * MAX_SPEED
	var rate := ACCELERATION if not input_direction.is_zero_approx() else DECELERATION
	return planar.move_toward(target, rate * delta).limit_length(MAX_SPEED)
