class_name DashSteal
extends RefCounted

const POKE_FORCE_MULTIPLIER := 1.6


static func can_steal(body_controller: int, player_dashing: bool, already_consumed: bool) -> bool:
	return body_controller == 0 and player_dashing and not already_consumed


static func poke_velocity(player_velocity: Vector3) -> Vector3:
	return Vector3(player_velocity.x * POKE_FORCE_MULTIPLIER, 0.0, player_velocity.z * POKE_FORCE_MULTIPLIER)
