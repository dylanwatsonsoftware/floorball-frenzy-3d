class_name PlayerMotor
extends RefCounted

const MAX_SPEED := 9.0
const ACCELERATION := 42.0
const TURN_ACCELERATION := 64.0
const DECELERATION := 40.0
const DASH_SPEED := 15.0
const DASH_COOLDOWN := 1.1
const DASH_DURATION := 0.18
const BALL_CARRIER_SPEED_MULTIPLIER := 0.88
const OFF_BALL_SPEED_MULTIPLIER := 1.08
const AI_SPEED_MULTIPLIER := 0.88
const FACING_RESPONSE := 12.0


static func combine_inputs(primary: Vector2, secondary: Vector2) -> Vector2:
	return (primary + secondary).limit_length(1.0)


static func movement_speed_multiplier(is_human: bool, has_ball: bool, base_multiplier: float = 1.0) -> float:
	var control_multiplier := BALL_CARRIER_SPEED_MULTIPLIER if has_ball else OFF_BALL_SPEED_MULTIPLIER
	return maxf(0.0, base_multiplier) * control_multiplier * (1.0 if is_human else AI_SPEED_MULTIPLIER)


static func step_velocity(current: Vector3, input_vector: Vector2, delta: float, speed_multiplier: float = 1.0) -> Vector3:
	var planar := Vector3(current.x, 0.0, current.z)
	var input_direction := input_vector.limit_length(1.0)
	var boosted_max_speed := MAX_SPEED * maxf(0.0, speed_multiplier)
	var target := Vector3(input_direction.x, 0.0, input_direction.y) * boosted_max_speed
	var rate := DECELERATION
	if not input_direction.is_zero_approx():
		rate = TURN_ACCELERATION if not planar.is_zero_approx() and planar.normalized().dot(Vector3(input_direction.x, 0.0, input_direction.y)) < 0.0 else ACCELERATION
	return planar.move_toward(target, rate * delta).limit_length(boosted_max_speed)


static func step_command_state(state: Dictionary, command: Dictionary) -> Dictionary:
	var delta := maxf(0.0, float(command.get("delta", 0.0)))
	var movement: Vector2 = command.get("move", Vector2.ZERO)
	var facing_input: Vector2 = command.get("facing", movement)
	var position: Vector3 = state.get("position", Vector3.ZERO)
	var velocity: Vector3 = state.get("velocity", Vector3.ZERO)
	var rotation := float(state.get("rotation", 0.0))
	var dash_cooldown := maxf(0.0, float(state.get("dash_cooldown", 0.0)) - delta)
	var dash_remaining := maxf(0.0, float(state.get("dash_remaining", 0.0)) - delta)
	var dash_direction: Vector3 = state.get("dash_direction", facing_from_rotation(rotation))
	var dash_started := false
	if bool(command.get("dash_pressed", false)) and dash_cooldown <= 0.0:
		var dash := start_dash(movement, dash_cooldown, facing_from_rotation(rotation))
		if bool(dash.started):
			dash_started = true
			dash_direction = dash.velocity.normalized()
			dash_cooldown = float(dash.cooldown)
			dash_remaining = DASH_DURATION
	if dash_remaining > 0.0:
		velocity = dash_direction * DASH_SPEED
	else:
		velocity = step_velocity(velocity, movement, delta, float(command.get("speed_multiplier", 1.0)))
	position += velocity * delta
	if not facing_input.is_zero_approx():
		rotation = step_facing_rotation(rotation, facing_input, delta)
	return {
		"position": position,
		"velocity": velocity,
		"rotation": rotation,
		"dash_cooldown": dash_cooldown,
		"dash_remaining": dash_remaining,
		"dash_direction": dash_direction,
		"dash_started": dash_started,
	}


static func start_dash(input_vector: Vector2, cooldown_remaining: float, facing: Vector3 = Vector3.RIGHT) -> Dictionary:
	if cooldown_remaining > 0.0:
		return {"started": false, "velocity": Vector3.ZERO, "cooldown": cooldown_remaining}
	var direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	if direction.is_zero_approx():
		direction = Vector3(facing.x, 0.0, facing.z).normalized()
	return {"started": true, "velocity": direction * DASH_SPEED, "cooldown": DASH_COOLDOWN}


static func step_facing_rotation(current_rotation: float, desired_direction: Vector2, delta: float, response: float = FACING_RESPONSE) -> float:
	if desired_direction.is_zero_approx():
		return current_rotation
	var direction := desired_direction.normalized()
	var target := atan2(direction.x, direction.y)
	var weight := 1.0 - exp(-maxf(response, 0.0) * maxf(delta, 0.0))
	return lerp_angle(current_rotation, target, weight)


static func facing_from_rotation(rotation_y: float) -> Vector3:
	return Vector3(sin(rotation_y), 0.0, cos(rotation_y)).normalized()
