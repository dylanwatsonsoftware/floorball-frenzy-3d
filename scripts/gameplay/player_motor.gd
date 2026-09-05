class_name PlayerMotor
extends RefCounted

const MAX_SPEED := 9.0
const ACCELERATION := 42.0
const TURN_ACCELERATION := 64.0
const DECELERATION := 40.0
const DASH_SPEED := 15.0
const DASH_COOLDOWN := 1.1
const BALL_CARRIER_SPEED_MULTIPLIER := 0.88
const OFF_BALL_SPEED_MULTIPLIER := 1.08
const AI_SPEED_MULTIPLIER := 0.88


static func combine_inputs(primary: Vector2, secondary: Vector2) -> Vector2:
	return (primary + secondary).limit_length(1.0)


static func step_velocity(current: Vector3, input_vector: Vector2, delta: float, speed_multiplier: float = 1.0) -> Vector3:
	var planar := Vector3(current.x, 0.0, current.z)
	var input_direction := input_vector.limit_length(1.0)
	var boosted_max_speed := MAX_SPEED * maxf(0.0, speed_multiplier)
	var target := Vector3(input_direction.x, 0.0, input_direction.y) * boosted_max_speed
	var rate := DECELERATION
	if not input_direction.is_zero_approx():
		rate = TURN_ACCELERATION if not planar.is_zero_approx() and planar.normalized().dot(Vector3(input_direction.x, 0.0, input_direction.y)) < 0.0 else ACCELERATION
	return planar.move_toward(target, rate * delta).limit_length(boosted_max_speed)


static func start_dash(input_vector: Vector2, cooldown_remaining: float, facing: Vector3 = Vector3.RIGHT) -> Dictionary:
	if cooldown_remaining > 0.0:
		return {"started": false, "velocity": Vector3.ZERO, "cooldown": cooldown_remaining}
	var direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	if direction.is_zero_approx():
		direction = Vector3(facing.x, 0.0, facing.z).normalized()
	return {"started": true, "velocity": direction * DASH_SPEED, "cooldown": DASH_COOLDOWN}
