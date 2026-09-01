class_name BallSimulation
extends RefCounted

const GoalCollisionScript = preload("res://scripts/simulation/goal_collision.gd")
const RinkCollisionScript = preload("res://scripts/simulation/rink_collision.gd")

const SHOT_BASE_SPEED := 13.0
const SHOT_SPEED_SCALE := 12.0
const SHOT_BASE_LIFT := 1.5
const SHOT_LIFT_SCALE := 5.5
const PERFECT_CHARGE_WINDOW := 0.08
const PERFECT_SHOT_MULTIPLIER := 1.12
const ONE_TOUCH_MULTIPLIER := 1.25
const TRAILBLAZER_MULTIPLIER := 1.2
const BOLT_MULTIPLIER := 1.2
const SCOOP_CHARGE_WINDOW := 0.3125
const SCOOP_BACKWARD_SPEED := 3.75
const SCOOP_LIFT := 9.0
const BALL_RADIUS := 0.22
const RINK_HALF_LENGTH := RinkCollisionScript.HALF_LENGTH
const RINK_HALF_WIDTH := RinkCollisionScript.HALF_WIDTH
const GRAVITY := 14.0
const FLOOR_BOUNCE := 0.42
const WALL_BOUNCE := 0.78
const ROLLING_DECELERATION := 1.8
const MIN_VERTICAL_BOUNCE := 0.6


static func shot_velocity(aim: Vector2, charge: float, inherited_velocity: Vector3 = Vector3.ZERO, one_touch: bool = false, bolt: bool = false) -> Vector3:
	return shot_plan(aim, charge, inherited_velocity, one_touch, bolt).velocity


static func shot_plan(aim: Vector2, charge: float, inherited_velocity: Vector3 = Vector3.ZERO, one_touch: bool = false, bolt: bool = false) -> Dictionary:
	var direction := aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
	var clamped_charge := clampf(charge, 0.0, 1.0)
	var power_fraction := clamped_charge
	var speed := SHOT_BASE_SPEED + SHOT_SPEED_SCALE * power_fraction
	if one_touch:
		speed *= ONE_TOUCH_MULTIPLIER
	if bolt:
		speed *= TRAILBLAZER_MULTIPLIER * BOLT_MULTIPLIER
	var scoop := is_scoop_shot(direction, clamped_charge, inherited_velocity)
	var lift := SCOOP_LIFT if scoop else SHOT_BASE_LIFT + SHOT_LIFT_SCALE * power_fraction
	return {
		"velocity": Vector3(direction.x * speed + inherited_velocity.x, lift, direction.y * speed + inherited_velocity.z),
		"is_scoop": scoop,
	}


static func is_scoop_shot(aim: Vector2, charge: float, inherited_velocity: Vector3) -> bool:
	var direction := aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
	var planar_velocity := Vector2(inherited_velocity.x, inherited_velocity.z)
	return charge < SCOOP_CHARGE_WINDOW and direction.dot(planar_velocity) < -SCOOP_BACKWARD_SPEED


static func is_perfect_charge(charge: float) -> bool:
	return absf(charge - 1.0) <= PERFECT_CHARGE_WINDOW


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

	var rink_collision := RinkCollisionScript.resolve(next_position, next_velocity)
	next_position = rink_collision.position
	next_velocity = rink_collision.velocity

	return {
		"position": next_position,
		"velocity": next_velocity,
	}
