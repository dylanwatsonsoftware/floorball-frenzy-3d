class_name MatchSimulation
extends RefCounted

const WINNING_SCORE := 5
const GOAL_LINE_X := 16.5
const GOAL_HALF_WIDTH := 0.8
const GOAL_HEIGHT := 1.15


static func detect_goal(previous_position: Vector3, current_position: Vector3, current_velocity: Vector3) -> StringName:
	for goal_data in [[GOAL_LINE_X, &"red", 1.0], [-GOAL_LINE_X, &"blue", -1.0]]:
		var goal_x: float = goal_data[0]
		var direction: float = goal_data[2]
		var travel_x := current_position.x - previous_position.x
		if absf(travel_x) <= 0.00001 or current_velocity.x * direction <= 0.0:
			continue
		var crossing_t := (goal_x - previous_position.x) / travel_x
		if crossing_t < 0.0 or crossing_t > 1.0:
			continue
		var crossing := previous_position.lerp(current_position, crossing_t)
		if absf(crossing.z) <= GOAL_HALF_WIDTH and crossing.y < GOAL_HEIGHT:
			return goal_data[1]

	return &""


static func apply_goal(score: Dictionary, scorer: StringName) -> Dictionary:
	var next_score := {
		"red": int(score.get("red", 0)),
		"blue": int(score.get("blue", 0)),
		"winner": &"",
	}
	if scorer != &"red" and scorer != &"blue":
		return next_score

	next_score[scorer] += 1
	if next_score[scorer] >= WINNING_SCORE:
		next_score.winner = scorer
	return next_score
