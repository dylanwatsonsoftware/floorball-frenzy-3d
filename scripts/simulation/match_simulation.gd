class_name MatchSimulation
extends RefCounted

const WINNING_SCORE := 5
const GOAL_LINE_X := 16.0
const GOAL_HALF_WIDTH := 1.25
const GOAL_HEIGHT := 1.48


static func detect_goal(previous_position: Vector3, current_position: Vector3, current_velocity: Vector3) -> StringName:
	var inside_mouth := absf(current_position.z) <= GOAL_HALF_WIDTH
	var below_crossbar := current_position.y < GOAL_HEIGHT
	if not inside_mouth or not below_crossbar:
		return &""

	var crossed_right := previous_position.x <= GOAL_LINE_X and current_position.x > GOAL_LINE_X
	if crossed_right and current_velocity.x > 0.0:
		return &"red"

	var crossed_left := previous_position.x >= -GOAL_LINE_X and current_position.x < -GOAL_LINE_X
	if crossed_left and current_velocity.x < 0.0:
		return &"blue"

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
