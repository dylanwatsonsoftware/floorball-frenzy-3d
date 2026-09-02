class_name GoalkeeperAI
extends RefCounted

const GOAL_LINE_X := 16.5
const ARC_RADIUS := 1.45
const ARC_HALF_ANGLE := deg_to_rad(68.0)
const LARGE_AREA_REAR_X := 17.15
const LARGE_AREA_FRONT_X := 13.15
const LARGE_AREA_HALF_WIDTH := 2.5
const KEEPER_BODY_RADIUS := 0.68


static func target(team: StringName, ball_position: Vector3, _loose_ball: bool) -> Vector2:
	var inward_sign := 1.0 if team == &"red" else -1.0
	var goal_center := Vector2(-GOAL_LINE_X if team == &"red" else GOAL_LINE_X, 0.0)
	var to_ball := Vector2(ball_position.x, ball_position.z) - goal_center
	var inward_distance := to_ball.x * inward_sign
	var angle := clampf(atan2(to_ball.y, maxf(0.001, inward_distance)), -ARC_HALF_ANGLE, ARC_HALF_ANGLE)
	var arc_direction := Vector2(inward_sign * cos(angle), sin(angle))
	return constrain_to_goal_area(team, goal_center + arc_direction * ARC_RADIUS)


static func constrain_to_goal_area(team: StringName, position: Vector2) -> Vector2:
	var minimum_x := -LARGE_AREA_REAR_X + KEEPER_BODY_RADIUS if team == &"red" else LARGE_AREA_FRONT_X + KEEPER_BODY_RADIUS
	var maximum_x := -LARGE_AREA_FRONT_X - KEEPER_BODY_RADIUS if team == &"red" else LARGE_AREA_REAR_X - KEEPER_BODY_RADIUS
	var half_width := LARGE_AREA_HALF_WIDTH - KEEPER_BODY_RADIUS
	return Vector2(clampf(position.x, minimum_x, maximum_x), clampf(position.y, -half_width, half_width))
