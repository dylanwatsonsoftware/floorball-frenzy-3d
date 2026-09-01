class_name BallSimulation
extends RefCounted

const GoalCollisionScript = preload("res://scripts/simulation/goal_collision.gd")

const SHOT_BASE_SPEED := 13.0
const SHOT_SPEED_SCALE := 12.0
const SHOT_BASE_LIFT := 1.5
const SHOT_LIFT_SCALE := 5.5
const BALL_RADIUS := 0.22
const RINK_HALF_LENGTH := 18.65
const RINK_HALF_WIDTH := 9.15
const GRAVITY := 14.0
const FLOOR_BOUNCE := 0.42
const WALL_BOUNCE := 0.78
const ROLLING_DECELERATION := 1.8
const MIN_VERTICAL_BOUNCE := 0.6


static func shot_velocity(aim: Vector2, charge: float, inherited_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	var direction := aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
	var clamped_charge := clampf(charge, 0.0, 1.0)
	var speed := SHOT_BASE_SPEED + SHOT_SPEED_SCALE * clamped_charge
	var lift := SHOT_BASE_LIFT + SHOT_LIFT_SCALE * clamped_charge
	return Vector3(direction.x * speed + inherited_velocity.x, lift, direction.y * speed + inherited_velocity.z)


static func step(position: Vector3, velocity: Vector3, delta: float) -> Dictionary:
	var next_velocity := velocity
	next_velocity.y -= GRAVITY * delta
	var next_position := position + next_velocity * delta

	if next_position.y <= BALL_RADIUS:
		next_position.y = BALL_RADIUS
		if next_velocity.y < -MIN_VERTICAL_BOUNCE:
			next_velocity.y = -next_velocity.y * FLOOR_BOUNCE
		else:
			next_velocity.y = 0.0
		var planar := Vector2(next_velocity.x, next_velocity.z)
		planar = planar.move_toward(Vector2.ZERO, ROLLING_DECELERATION * delta)
		next_velocity.x = planar.x
		next_velocity.z = planar.y

	var goal_collision := GoalCollisionScript.resolve(position, next_position, next_velocity)
	next_position = goal_collision.position
	next_velocity = goal_collision.velocity

	if absf(next_position.x) > RINK_HALF_LENGTH:
		next_position.x = clampf(next_position.x, -RINK_HALF_LENGTH, RINK_HALF_LENGTH)
		next_velocity.x = -next_velocity.x * WALL_BOUNCE
	if absf(next_position.z) > RINK_HALF_WIDTH:
		next_position.z = clampf(next_position.z, -RINK_HALF_WIDTH, RINK_HALF_WIDTH)
		next_velocity.z = -next_velocity.z * WALL_BOUNCE

	return {
		"position": next_position,
		"velocity": next_velocity,
	}
