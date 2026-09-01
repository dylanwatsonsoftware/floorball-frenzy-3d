class_name SimpleAI
extends RefCounted

const STICK_RANGE := 2.25
const STRIKE_HEIGHT := 0.7
const MAX_STRIKE_BALL_SPEED := 8.0
const DASH_RANGE := 10.7
const LEFT_GOAL := Vector2(-16.0, 0.0)


static func decide(ai_position: Vector3, ball_position: Vector3, opponent_position: Vector3, ball_velocity: Vector3, dash_ready: bool = true) -> Dictionary:
	var to_ball := Vector2(ball_position.x - ai_position.x, ball_position.z - ai_position.z)
	var distance_to_ball := to_ball.length()
	var movement := to_ball.normalized() if distance_to_ball > STICK_RANGE else Vector2.ZERO

	if not movement.is_zero_approx():
		var to_opponent := Vector2(opponent_position.x - ai_position.x, opponent_position.z - ai_position.z)
		if to_opponent.length() < 1.8 and movement.dot(to_opponent.normalized()) > 0.65:
			var avoidance := Vector2(-movement.y, movement.x)
			if avoidance.dot(to_opponent) > 0.0:
				avoidance = -avoidance
			movement = (movement + avoidance * 0.65).normalized()

	var planar_ball_speed := Vector2(ball_velocity.x, ball_velocity.z).length()
	var wants_shot := distance_to_ball <= STICK_RANGE and ball_position.y <= STRIKE_HEIGHT and planar_ball_speed <= MAX_STRIKE_BALL_SPEED
	var shot_direction := (LEFT_GOAL - Vector2(ball_position.x, ball_position.z)).normalized()
	var wants_dash := dash_ready and distance_to_ball > DASH_RANGE and not movement.is_zero_approx()

	return {
		"movement": movement,
		"wants_shot": wants_shot,
		"shot_direction": shot_direction,
		"wants_dash": wants_dash,
	}
