extends SceneTree


func _init() -> void:
	var parry := load("res://scripts/simulation/parry.gd")
	if parry == null:
		fail("Parry simulation is missing")
		return

	var player_position := Vector3.ZERO
	var contact_position := Vector3(0.4, 0.22, 0.0)
	var incoming := Vector3(-14.0, 2.0, 0.0)
	if not parry.can_parry(contact_position, incoming, player_position, true):
		fail("A fast shot travelling into a player during the dash timing window must parry")
		return
	if parry.can_parry(contact_position, incoming, player_position, false):
		fail("The same contact outside the 150 ms timing window must not parry")
		return
	if parry.can_parry(contact_position, Vector3(14.0, 2.0, 0.0), player_position, true):
		fail("A ball already travelling away from the player must not parry")
		return
	if parry.can_parry(contact_position, Vector3(-8.0, 0.0, 0.0), player_position, true):
		fail("Slow dribbling contact must remain a dash steal rather than a parry")
		return

	var reflected: Vector3 = parry.reflected_velocity(incoming)
	if not reflected.is_equal_approx(Vector3(21.0, 2.0, 0.0)):
		fail("Parries must reverse planar velocity at the original 1.5x multiplier while preserving lift; got %s" % reflected)
		return

	print("Perfect parry rules are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
