extends SceneTree


func _init() -> void:
	var contact := load("res://scripts/simulation/player_contact.gd")
	if contact == null:
		fail("Core player contact simulation is missing")
		return

	var driven: Dictionary = contact.resolve(
		Vector3(0.0, 0.75, 0.0),
		Vector3(8.0, 0.0, 0.0),
		Vector3(1.04, 0.75, 0.0),
		Vector3.ZERO
	)
	if not driven.collided:
		fail("Players touching while one drives through the other must register a body check")
		return
	if driven.velocity_b.x <= 1.0:
		fail("A committed runner must push momentum into a stationary opponent; got %s" % driven)
		return
	if driven.velocity_a.x <= driven.velocity_b.x:
		fail("The driving player must keep forward momentum instead of stopping dead; got %s" % driven)
		return
	if driven.position_a.distance_to(driven.position_b) < contact.CONTACT_DISTANCE - 0.001:
		fail("Body contact must never leave the players overlapping")
		return

	var separating: Dictionary = contact.resolve(
		Vector3(0.0, 0.75, 0.0),
		Vector3.LEFT * 3.0,
		Vector3(1.04, 0.75, 0.0),
		Vector3.RIGHT * 3.0
	)
	if separating.collided:
		fail("Players already moving apart must not receive a second bump impulse")
		return

	var head_on: Dictionary = contact.resolve(
		Vector3(0.0, 0.75, 0.0),
		Vector3.RIGHT * 6.0,
		Vector3(1.04, 0.75, 0.0),
		Vector3.LEFT * 6.0
	)
	if not head_on.collided or absf(head_on.velocity_a.x) >= 6.0 or absf(head_on.velocity_b.x) >= 6.0:
		fail("An even head-on check must slow both runners symmetrically; got %s" % head_on)
		return
	if not is_equal_approx(head_on.velocity_a.x, -head_on.velocity_b.x):
		fail("Equal opposing momentum must produce an equal body-check response; got %s" % head_on)
		return

	print("Core player body contact is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
