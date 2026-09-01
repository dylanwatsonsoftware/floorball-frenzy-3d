class_name SquadLogic
extends RefCounted

const HUMAN_TEAM := &"red"
const PRESSURE_DISTANCE := 3.0
const PASS_ERROR_RADIANS := 0.12


static func human_actor_id(owner_actor_id: StringName, owner_team: StringName, human_team: StringName = HUMAN_TEAM) -> StringName:
	return owner_actor_id if owner_team == human_team else &""


static func support_target(team: StringName, slot: int, ball_position: Vector3, team_has_possession: bool) -> Vector2:
	var attack_direction := 1.0 if team == &"red" else -1.0
	var lane_z := -4.0 if slot == 1 else 4.0 if slot == 2 else 0.0
	var longitudinal_offset := 3.4 if team_has_possession else -3.2
	var target_x := clampf(ball_position.x + attack_direction * longitudinal_offset, -14.0, 14.0)
	return Vector2(target_x, lane_z)


static func is_closest_to_ball(actor_id: StringName, actor_position: Vector3, teammates: Array, ball_position: Vector3) -> bool:
	var own_distance := _planar(actor_position).distance_squared_to(_planar(ball_position))
	for teammate in teammates:
		if StringName(teammate.actor_id) == actor_id:
			continue
		var teammate_distance := _planar(teammate.position).distance_squared_to(_planar(ball_position))
		if teammate_distance < own_distance - 0.001:
			return false
	return true


static func pass_plan(carrier_position: Vector3, teammates: Array, opponent_positions: Array, team: StringName, pass_index: int) -> Dictionary:
	var nearest_pressure := INF
	for opponent_position in opponent_positions:
		nearest_pressure = minf(nearest_pressure, _planar(carrier_position).distance_to(_planar(opponent_position)))
	if nearest_pressure > PRESSURE_DISTANCE or teammates.is_empty():
		return _no_pass()

	var attack_direction := 1.0 if team == &"red" else -1.0
	var best_teammate: Dictionary = {}
	var best_score := -INF
	for teammate in teammates:
		var target_position: Vector3 = teammate.position
		var forward_progress := (target_position.x - carrier_position.x) * attack_direction
		var openness := INF
		for opponent_position in opponent_positions:
			openness = minf(openness, _planar(target_position).distance_to(_planar(opponent_position)))
		var score := forward_progress * 0.7 + minf(openness, 6.0) * 0.5
		if score > best_score:
			best_score = score
			best_teammate = teammate
	if best_teammate.is_empty():
		return _no_pass()

	var target: Vector3 = best_teammate.position
	var exact_direction := (_planar(target) - _planar(carrier_position)).normalized()
	var error := sin(float(pass_index + 1) * 2.17) * PASS_ERROR_RADIANS
	return {
		"wants_pass": true,
		"target_actor": StringName(best_teammate.actor_id),
		"target_position": target,
		"direction": exact_direction.rotated(error),
	}


static func _no_pass() -> Dictionary:
	return {
		"wants_pass": false,
		"target_actor": &"",
		"target_position": Vector3.ZERO,
		"direction": Vector2.ZERO,
	}


static func _planar(value: Vector3) -> Vector2:
	return Vector2(value.x, value.z)
