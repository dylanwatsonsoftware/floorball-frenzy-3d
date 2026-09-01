class_name GoalCollision
extends RefCounted

const GOAL_LINE_X := 16.5
const CAGE_DEPTH := 1.35
const GOAL_HALF_WIDTH := 0.8
const CROSSBAR_HEIGHT := 1.15
const FRAME_RADIUS := 0.12
const BALL_RADIUS := 0.22
const CONTACT_RADIUS := FRAME_RADIUS + BALL_RADIUS
const BOUNCE := 0.78


static func resolve(previous_position: Vector3, next_position: Vector3, velocity: Vector3) -> Dictionary:
	var position := next_position
	var next_velocity := velocity

	for goal_sign in [-1.0, 1.0]:
		var goal_x: float = float(goal_sign) * GOAL_LINE_X
		for post_z in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
			if maxf(previous_position.y, position.y) <= CROSSBAR_HEIGHT + CONTACT_RADIUS:
				var post_result := _resolve_post(previous_position, position, next_velocity, Vector2(goal_x, post_z))
				if post_result.collided:
					return post_result

		var crossed_frame_x := _crossed_plane(previous_position.x, position.x, goal_x, next_velocity.x)
		var near_crossbar := absf(position.y - CROSSBAR_HEIGHT) <= CONTACT_RADIUS
		var within_crossbar := absf(position.z) <= GOAL_HALF_WIDTH + BALL_RADIUS
		if crossed_frame_x and near_crossbar and within_crossbar:
			position.x = goal_x - signf(next_velocity.x) * CONTACT_RADIUS
			next_velocity.x = -next_velocity.x * BOUNCE
			return _result(position, next_velocity, true)

		var cage_back_x: float = float(goal_sign) * (GOAL_LINE_X + CAGE_DEPTH)
		var crossed_back := _crossed_plane(previous_position.x, position.x, cage_back_x, next_velocity.x)
		var inside_cage_height := position.y <= CROSSBAR_HEIGHT + BALL_RADIUS
		var inside_cage_width := absf(position.z) <= GOAL_HALF_WIDTH + BALL_RADIUS
		if crossed_back and inside_cage_height and inside_cage_width:
			position.x = cage_back_x - signf(next_velocity.x) * BALL_RADIUS
			next_velocity.x = -next_velocity.x * BOUNCE
			return _result(position, next_velocity, true)

		var cage_min_x := minf(goal_x, cage_back_x) - BALL_RADIUS
		var cage_max_x := maxf(goal_x, cage_back_x) + BALL_RADIUS
		var inside_cage_depth := position.x >= cage_min_x and position.x <= cage_max_x
		if inside_cage_depth and inside_cage_height:
			for side_z in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
				if _crossed_plane(previous_position.z, position.z, side_z, next_velocity.z):
					position.z = side_z - signf(next_velocity.z) * BALL_RADIUS
					next_velocity.z = -next_velocity.z * BOUNCE
					return _result(position, next_velocity, true)

	return _result(position, next_velocity, false)


static func _resolve_post(previous_position: Vector3, next_position: Vector3, velocity: Vector3, post: Vector2) -> Dictionary:
	var start := Vector2(previous_position.x, previous_position.z)
	var finish := Vector2(next_position.x, next_position.z)
	var segment := finish - start
	var segment_length_squared := segment.length_squared()
	var amount := 0.0 if segment_length_squared <= 0.000001 else clampf((post - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest := start + segment * amount
	if closest.distance_to(post) > CONTACT_RADIUS:
		return _result(next_position, velocity, false)

	var normal := (start - post).normalized()
	if normal.is_zero_approx():
		normal = -Vector2(velocity.x, velocity.z).normalized()
	if normal.is_zero_approx():
		normal = Vector2.LEFT
	var planar_velocity := Vector2(velocity.x, velocity.z)
	var reflected := planar_velocity.bounce(normal) * BOUNCE
	var position := next_position
	position.x = post.x + normal.x * CONTACT_RADIUS
	position.z = post.y + normal.y * CONTACT_RADIUS
	var next_velocity := velocity
	next_velocity.x = reflected.x
	next_velocity.z = reflected.y
	return _result(position, next_velocity, true)


static func _crossed_plane(previous: float, current: float, plane: float, velocity: float) -> bool:
	return (velocity > 0.0 and previous <= plane and current >= plane) or (velocity < 0.0 and previous >= plane and current <= plane)


static func _result(position: Vector3, velocity: Vector3, collided: bool) -> Dictionary:
	return {
		"position": position,
		"velocity": velocity,
		"collided": collided,
	}
