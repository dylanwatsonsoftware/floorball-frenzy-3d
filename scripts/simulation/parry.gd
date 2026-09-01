class_name Parry
extends RefCounted

const MIN_SHOT_SPEED := 13.0
const INCOMING_DOT_THRESHOLD := -0.5
const VELOCITY_MULTIPLIER := 1.5


static func can_parry(ball_position: Vector3, ball_velocity: Vector3, player_position: Vector3, timing_window_active: bool) -> bool:
	if not timing_window_active:
		return false
	var planar_velocity := Vector2(ball_velocity.x, ball_velocity.z)
	var speed := planar_velocity.length()
	if speed <= MIN_SHOT_SPEED:
		return false
	var outward := Vector2(ball_position.x - player_position.x, ball_position.z - player_position.z).normalized()
	if outward.is_zero_approx():
		return false
	return planar_velocity.normalized().dot(outward) < INCOMING_DOT_THRESHOLD


static func reflected_velocity(ball_velocity: Vector3) -> Vector3:
	return Vector3(-ball_velocity.x * VELOCITY_MULTIPLIER, ball_velocity.y, -ball_velocity.z * VELOCITY_MULTIPLIER)
