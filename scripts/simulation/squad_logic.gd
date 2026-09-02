class_name SquadLogic
extends RefCounted

const HUMAN_TEAM := &"red"
const PRESSURE_DISTANCE := 3.0
const PASS_ERROR_RADIANS := 0.12
const ARRIVAL_STOP_RADIUS := 0.18
const ARRIVAL_SLOW_RADIUS := 2.4


static func human_actor_id(owner_actor_id: StringName, owner_team: StringName, human_team: StringName = HUMAN_TEAM) -> StringName:
	return owner_actor_id if owner_team == human_team else &""


static func support_target(team: StringName, slot: int, ball_position: Vector3, team_has_possession: bool, ball_velocity: Vector3 = Vector3.ZERO) -> Vector2:
	var attack_direction := 1.0 if team == &"red" else -1.0
	if team_has_possession:
		var depth: float = float([2.2, 5.8, 4.1, -1.8, -3.6][clampi(slot, 0, 4)])
		var lane: float = float([0.4, -5.0, 4.6, -3.2, 3.8][clampi(slot, 0, 4)])
		var lead_factor: float = float([0.15, 0.75, 0.58, 0.30, 0.42][clampi(slot, 0, 4)])
		var lead := Vector2(ball_velocity.x, ball_velocity.z) * lead_factor
		return Vector2(
			clampf(ball_position.x + attack_direction * depth + lead.x, -14.5, 14.5),
			clampf(lane + lead.y, -7.2, 7.2)
		)
	var own_goal_x := -17.0 if team == &"red" else 17.0
	var shell_center_x := lerpf(own_goal_x, ball_position.x, 0.5)
	var shell_center_z := clampf(ball_position.z * 0.22, -1.4, 1.4)
	var shell_depth: float = float([0.0, 2.0, 1.4, -2.4, -1.7][clampi(slot, 0, 4)])
	var shell_lane: float = float([0.2, -4.8, 4.1, -3.3, 3.8][clampi(slot, 0, 4)])
	return Vector2(
		clampf(shell_center_x + attack_direction * shell_depth, -14.5, 14.5),
		clampf(shell_center_z + shell_lane, -7.2, 7.2)
	)


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
