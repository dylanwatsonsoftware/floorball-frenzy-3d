class_name RinkCollision
extends RefCounted

const HALF_LENGTH := 19.65
const HALF_WIDTH := 9.65
const CORNER_RADIUS := 1.8
const BALL_BOUNCE := 0.78
const GOALKEEPER_AREA_FRONT_X := 15.5
const GOAL_LINE_X := 16.5
const GOAL_BACK_X := 17.31
const GOALKEEPER_AREA_HALF_WIDTH := 1.25
const GOAL_HALF_WIDTH := 0.8
const PLAYER_BODY_RADIUS := 0.4


static func resolve(position: Vector3, velocity: Vector3) -> Dictionary:
	return _resolve_boundary(position, velocity, HALF_LENGTH, HALF_WIDTH, CORNER_RADIUS, BALL_BOUNCE)


static func constrain_body(position: Vector3, velocity: Vector3, half_length: float, half_width: float, corner_radius: float) -> Dictionary:
	return _resolve_boundary(position, velocity, half_length, half_width, corner_radius, 0.0)


static func constrain_field_player(position: Vector3, velocity: Vector3) -> Dictionary:
	var next_position := position
	var next_velocity := velocity
	for goal_sign in [-1.0, 1.0]:
		var local_position := Vector2(next_position.x * goal_sign, next_position.z)
		var local_velocity := Vector2(next_velocity.x * goal_sign, next_velocity.z)
		var house := _exclude_rectangle(local_position, local_velocity, GOALKEEPER_AREA_FRONT_X, GOAL_LINE_X, GOALKEEPER_AREA_HALF_WIDTH, PLAYER_BODY_RADIUS)
		local_position = house.position
		local_velocity = house.velocity
		var cage := _exclude_rectangle(local_position, local_velocity, GOAL_LINE_X, GOAL_BACK_X, GOAL_HALF_WIDTH, PLAYER_BODY_RADIUS)
		local_position = cage.position
		local_velocity = cage.velocity
		next_position.x = local_position.x * goal_sign
		next_position.z = local_position.y
		next_velocity.x = local_velocity.x * goal_sign
		next_velocity.z = local_velocity.y
	return {"position": next_position, "velocity": next_velocity}


static func _exclude_rectangle(position: Vector2, velocity: Vector2, min_x: float, max_x: float, half_width: float, margin: float) -> Dictionary:
	var left := min_x - margin
	var right := max_x + margin
	var top := -half_width - margin
	var bottom := half_width + margin
	if position.x <= left or position.x >= right or position.y <= top or position.y >= bottom:
		return {"position": position, "velocity": velocity}
	var distances := [position.x - left, right - position.x, position.y - top, bottom - position.y]
	var edge := distances.find(distances.min())
	var normal := Vector2.ZERO
	match edge:
		0:
			position.x = left
			normal = Vector2.LEFT
		1:
			position.x = right
			normal = Vector2.RIGHT
		2:
			position.y = top
			normal = Vector2.UP
		_:
			position.y = bottom
			normal = Vector2.DOWN
	var inward_speed := velocity.dot(normal)
	if inward_speed < 0.0:
		velocity -= normal * inward_speed
	return {"position": position, "velocity": velocity}


static func _resolve_boundary(position: Vector3, velocity: Vector3, half_length: float, half_width: float, corner_radius: float, bounce: float) -> Dictionary:
	var next_position := position
	var next_velocity := velocity
	var abs_x := absf(next_position.x)
	var abs_z := absf(next_position.z)
	var corner_start_x := half_length - corner_radius
	var corner_start_z := half_width - corner_radius

	if abs_x > corner_start_x and abs_z > corner_start_z:
		var sign_x := signf(next_position.x)
		var sign_z := signf(next_position.z)
		var center := Vector2(sign_x * corner_start_x, sign_z * corner_start_z)
		var planar := Vector2(next_position.x, next_position.z)
		var offset := planar - center
		if offset.length() > corner_radius:
			var normal := offset.normalized()
			planar = center + normal * corner_radius
			next_position.x = planar.x
			next_position.z = planar.y
			var planar_velocity := Vector2(next_velocity.x, next_velocity.z)
			var outward_speed := planar_velocity.dot(normal)
			if outward_speed > 0.0:
				planar_velocity -= normal * outward_speed * (1.0 + bounce)
				next_velocity.x = planar_velocity.x
				next_velocity.z = planar_velocity.y
			return {"position": next_position, "velocity": next_velocity, "collided": true}

	var collided := false
	if absf(next_position.x) > half_length:
		next_position.x = clampf(next_position.x, -half_length, half_length)
		if next_velocity.x * signf(next_position.x) > 0.0:
			next_velocity.x = -next_velocity.x * bounce
		collided = true
	if absf(next_position.z) > half_width:
		next_position.z = clampf(next_position.z, -half_width, half_width)
		if next_velocity.z * signf(next_position.z) > 0.0:
			next_velocity.z = -next_velocity.z * bounce
		collided = true
	return {"position": next_position, "velocity": next_velocity, "collided": collided}
