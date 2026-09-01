class_name RinkCollision
extends RefCounted

const HALF_LENGTH := 18.65
const HALF_WIDTH := 9.15
const CORNER_RADIUS := 1.8
const BALL_BOUNCE := 0.78


static func resolve(position: Vector3, velocity: Vector3) -> Dictionary:
	return _resolve_boundary(position, velocity, HALF_LENGTH, HALF_WIDTH, CORNER_RADIUS, BALL_BOUNCE)


static func constrain_body(position: Vector3, velocity: Vector3, half_length: float, half_width: float, corner_radius: float) -> Dictionary:
	return _resolve_boundary(position, velocity, half_length, half_width, corner_radius, 0.0)


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
