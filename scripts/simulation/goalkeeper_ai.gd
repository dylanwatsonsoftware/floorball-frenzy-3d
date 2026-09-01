class_name GoalkeeperAI
extends RefCounted

const HOME_X := 15.75
const CREASE_FRONT_X := 14.4
const CREASE_BACK_X := 17.35
const CREASE_HALF_WIDTH := 2.25
const INTERCEPT_DISTANCE := 4.2


static func target(team: StringName, ball_position: Vector3, loose_ball: bool) -> Vector2:
	var side := -1.0 if team == &"red" else 1.0
	var home_x := side * HOME_X
	var target_z := clampf(ball_position.z * 0.34, -1.9, 1.9)
	var distance_to_goal := Vector2(ball_position.x - home_x, ball_position.z).length()
	var target_x := home_x
	if loose_ball and distance_to_goal <= INTERCEPT_DISTANCE:
		target_x = ball_position.x
		target_z = ball_position.z
	var minimum_x := -CREASE_BACK_X if team == &"red" else CREASE_FRONT_X
	var maximum_x := -CREASE_FRONT_X if team == &"red" else CREASE_BACK_X
	return Vector2(clampf(target_x, minimum_x, maximum_x), clampf(target_z, -CREASE_HALF_WIDTH, CREASE_HALF_WIDTH))
