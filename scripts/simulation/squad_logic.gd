class_name SquadLogic
extends RefCounted

const HUMAN_TEAM := &"red"
const PRESSURE_DISTANCE := 3.0
const PASS_ERROR_RADIANS := 0.12
const ARRIVAL_STOP_RADIUS := 0.18
const ARRIVAL_SLOW_RADIUS := 2.4
const PASS_FIELD_OF_VIEW_DEGREES := 160.0
const PASS_ANGLE_PENALTY_METRES_PER_RADIAN := 4.0


static func human_actor_id(owner_actor_id: StringName, owner_team: StringName, human_team: StringName = HUMAN_TEAM) -> StringName:
	return owner_actor_id if owner_team == human_team else &""


static func support_target(team: StringName, slot: int, ball_position: Vector3, team_has_possession: bool, ball_velocity: Vector3 = Vector3.ZERO, opponents: Array = []) -> Vector2:
	var attack_direction := 1.0 if team == &"red" else -1.0
	if team_has_possession:
		var depth: float = float([7.0, 3.0, 3.0, -4.0, -6.0][clampi(slot, 0, 4)])
		var lane: float = float([0.0, -7.0, 7.0, -5.0, 5.0][clampi(slot, 0, 4)])
		var lead_factor: float = float([0.15, 0.75, 0.58, 0.30, 0.42][clampi(slot, 0, 4)])
		var lead := Vector2(ball_velocity.x, ball_velocity.z) * lead_factor
		return Vector2(
			clampf(ball_position.x + attack_direction * depth + lead.x, -14.5, 14.5),
			clampf(lane + lead.y, -7.2, 7.2)
		)
	var own_goal_x := -17.0 if team == &"red" else 17.0
	var shell_center_x := lerpf(own_goal_x, ball_position.x, 0.62)
	var shell_center_z := clampf(ball_position.z * 0.22, -1.4, 1.4)
	var shell_depth: float = float([4.0, 1.0, 1.0, -5.0, -5.0][clampi(slot, 0, 4)])
	var shell_lane: float = float([0.0, -7.0, 7.0, -5.5, 5.5][clampi(slot, 0, 4)])
	var shell_target := Vector2(
		clampf(shell_center_x + attack_direction * shell_depth, -13.8, 13.8),
		clampf(shell_center_z + shell_lane, -7.2, 7.2)
	)
	if opponents.is_empty():
		return shell_target
	var ranked_opponents := opponents.duplicate()
	ranked_opponents.sort_custom(func(a: Variant, b: Variant) -> bool: return _entry_planar(a).y < _entry_planar(b).y)
	var matchup_order := [2, 0, 4, 1, 3]
	var matchup_index: int = matchup_order[clampi(slot, 0, 4)]
	matchup_index = mini(matchup_index, ranked_opponents.size() - 1)
	var opponent := _entry_planar(ranked_opponents[matchup_index])
	var own_goal := Vector2(own_goal_x, 0.0)
	var goal_side := opponent + (own_goal - opponent).normalized() * 1.6
	var marking_weight: float = float([0.38, 0.42, 0.42, 0.28, 0.28][clampi(slot, 0, 4)])
	var marked_target := shell_target.lerp(goal_side, marking_weight)
	marked_target.x = clampf(marked_target.x, -13.8, 13.8)
	marked_target.y = clampf(marked_target.y, -7.2, 7.2)
	return marked_target


static func pressure_target(team: StringName, ball_position: Vector3, ball_velocity: Vector3) -> Vector2:
	var ball := _planar(ball_position)
	var own_goal := Vector2(-17.0 if team == &"red" else 17.0, 0.0)
	if ball.distance_to(own_goal) < 7.0:
		return ball + (own_goal - ball).normalized() * 1.4
	return ball + Vector2(ball_velocity.x, ball_velocity.z) * 0.22


static func tactical_facing(position: Vector2, movement: Vector2, ball_position: Vector3, team_has_possession: bool) -> Vector2:
	if not team_has_possession:
		var toward_ball := _planar(ball_position) - position
		if not toward_ball.is_zero_approx():
			return toward_ball.normalized()
	return movement.normalized() if not movement.is_zero_approx() else Vector2.ZERO


static func arrival_movement(position: Vector2, target: Vector2, stop_radius: float = ARRIVAL_STOP_RADIUS, slow_radius: float = ARRIVAL_SLOW_RADIUS) -> Vector2:
	var offset := target - position
	var distance := offset.length()
	if distance <= stop_radius:
		return Vector2.ZERO
	return offset.normalized() * minf(1.0, (distance - stop_radius) / maxf(0.001, slow_radius - stop_radius))


static func next_human_actor_id(current_actor_id: StringName, teammates: Array, ball_position: Vector3) -> StringName:
	if teammates.is_empty():
		return &""
	var ranked := teammates.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var distance_a := _planar(a.position).distance_squared_to(_planar(ball_position))
		var distance_b := _planar(b.position).distance_squared_to(_planar(ball_position))
		if is_equal_approx(distance_a, distance_b):
			return String(a.actor_id) < String(b.actor_id)
		return distance_a < distance_b
	)
	var current_index := -1
	for index in ranked.size():
		if StringName(ranked[index].actor_id) == current_actor_id:
			current_index = index
			break
	if current_index < 0:
		return StringName(ranked[0].actor_id)
	return StringName(ranked[(current_index + 1) % ranked.size()].actor_id)


static func is_closest_to_ball(actor_id: StringName, actor_position: Vector3, teammates: Array, ball_position: Vector3) -> bool:
	var own_distance := _planar(actor_position).distance_squared_to(_planar(ball_position))
	for teammate in teammates:
		if StringName(teammate.actor_id) == actor_id:
			continue
		var teammate_distance := _planar(teammate.position).distance_squared_to(_planar(ball_position))
		if teammate_distance < own_distance - 0.001:
			return false
	return true


static func closest_teammate(carrier_id: StringName, carrier_position: Vector3, teammates: Array) -> Dictionary:
	var closest: Dictionary = {}
	var closest_distance := INF
	for teammate in teammates:
		if StringName(teammate.actor_id) == carrier_id:
			continue
		var distance := _planar(carrier_position).distance_squared_to(_planar(teammate.position))
		if distance < closest_distance:
			closest_distance = distance
			closest = teammate
	return closest


static func forward_teammate(carrier_id: StringName, carrier_position: Vector3, facing: Vector3, teammates: Array) -> Dictionary:
	var planar_facing := Vector2(facing.x, facing.z).normalized()
	if planar_facing.is_zero_approx():
		return {}
	var minimum_dot := cos(deg_to_rad(PASS_FIELD_OF_VIEW_DEGREES * 0.5))
	var best: Dictionary = {}
	var best_score := INF
	for teammate in teammates:
		if StringName(teammate.actor_id) == carrier_id:
			continue
		var offset := _planar(teammate.position) - _planar(carrier_position)
		var distance := offset.length()
		if distance <= 0.01:
			continue
		var alignment := planar_facing.dot(offset.normalized())
		if alignment < minimum_dot:
			continue
		var angle := acos(clampf(alignment, -1.0, 1.0))
		var score := distance + angle * PASS_ANGLE_PENALTY_METRES_PER_RADIAN
		if score < best_score:
			best_score = score
			best = teammate
	return best


static func pass_plan(carrier_position: Vector3, teammates: Array, opponent_positions: Array, team: StringName, pass_index: int, carrier_facing: Vector3 = Vector3.ZERO) -> Dictionary:
	if teammates.is_empty():
		return _no_pass()
	var clockwise := pass_index % 4 == 3
	var carrier_angle := atan2(carrier_position.z, carrier_position.x)
	var best_teammate: Dictionary = {}
	var best_arc := INF
	for teammate in teammates:
		var target_position: Vector3 = teammate.position
		if not carrier_facing.is_zero_approx():
			var to_target := (_planar(target_position) - _planar(carrier_position)).normalized()
			var planar_facing := Vector2(carrier_facing.x, carrier_facing.z).normalized()
			if planar_facing.dot(to_target) < cos(deg_to_rad(PASS_FIELD_OF_VIEW_DEGREES * 0.5)):
				continue
		var target_angle := atan2(target_position.z, target_position.x)
		var arc := fposmod(target_angle - carrier_angle, TAU) if clockwise else fposmod(carrier_angle - target_angle, TAU)
		if arc < 0.05:
			arc += TAU
		if arc < best_arc:
			best_arc = arc
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


static func _entry_planar(entry: Variant) -> Vector2:
	var value: Vector3 = entry.position if entry is Dictionary else entry
	return _planar(value)
