class_name PlayerContact
extends RefCounted

const CONTACT_DISTANCE := 1.08
const DRIVER_SLOWDOWN := 0.22
const MOMENTUM_TRANSFER := 0.42


static func resolve(position_a: Vector3, velocity_a: Vector3, position_b: Vector3, velocity_b: Vector3) -> Dictionary:
	var offset := Vector2(position_b.x - position_a.x, position_b.z - position_a.z)
	var distance := offset.length()
	var normal := offset.normalized() if distance > 0.001 else Vector2.RIGHT
	var next_a := position_a
	var next_b := position_b
	if distance < CONTACT_DISTANCE:
		var separation := (CONTACT_DISTANCE - distance) * 0.5
		next_a.x -= normal.x * separation
		next_a.z -= normal.y * separation
		next_b.x += normal.x * separation
		next_b.z += normal.y * separation

	var relative_approach := Vector2(velocity_a.x - velocity_b.x, velocity_a.z - velocity_b.z).dot(normal)
	if distance > CONTACT_DISTANCE + 0.02 or relative_approach <= 0.05:
		return _result(next_a, velocity_a, next_b, velocity_b, false)

	var next_velocity_a := velocity_a
	var next_velocity_b := velocity_b
	var a_drive := maxf(0.0, Vector2(velocity_a.x, velocity_a.z).dot(normal))
	var b_drive := maxf(0.0, -Vector2(velocity_b.x, velocity_b.z).dot(normal))
	var total_drive := maxf(0.001, a_drive + b_drive)
	var a_share := a_drive / total_drive
	var b_share := b_drive / total_drive
	var a_slowdown := relative_approach * DRIVER_SLOWDOWN * (1.0 - b_share * 0.5)
	var b_slowdown := relative_approach * DRIVER_SLOWDOWN * (1.0 - a_share * 0.5)
	var to_b := relative_approach * MOMENTUM_TRANSFER * a_share
	var to_a := relative_approach * MOMENTUM_TRANSFER * b_share
	next_velocity_a.x -= normal.x * (to_a + a_slowdown)
	next_velocity_a.z -= normal.y * (to_a + a_slowdown)
	next_velocity_b.x += normal.x * (to_b + b_slowdown)
	next_velocity_b.z += normal.y * (to_b + b_slowdown)
	return _result(next_a, next_velocity_a, next_b, next_velocity_b, true)


static func _result(position_a: Vector3, velocity_a: Vector3, position_b: Vector3, velocity_b: Vector3, collided: bool) -> Dictionary:
	return {
		"position_a": position_a,
		"velocity_a": velocity_a,
		"position_b": position_b,
		"velocity_b": velocity_b,
		"collided": collided,
	}
