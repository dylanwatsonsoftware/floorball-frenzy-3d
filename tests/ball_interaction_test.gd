extends SceneTree


func _init() -> void:
	var interaction := load("res://scripts/simulation/ball_interaction.gd")
	if interaction == null:
		fail("Ball interaction script is missing")
		return

	var player := {
		"position": Vector3(0.0, 0.75, 0.0),
		"velocity": Vector3(5.0, 0.0, 0.0),
		"facing": Vector3.RIGHT,
	}
	var controlled: Dictionary = interaction.step(
		Vector3(1.3, 0.22, 0.0),
		Vector3.ZERO,
		[player],
		0.1
	)
	if controlled.controller != 0 or controlled.velocity.x <= 0.0:
		fail("A grounded ball at the stick must follow the moving player; got %s" % controlled)
		return

	var distant: Dictionary = interaction.step(
		Vector3(5.0, 0.22, 0.0),
		Vector3(2.0, 0.0, 0.0),
		[player],
		0.1
	)
	if distant.controller != -1 or not distant.velocity.is_equal_approx(Vector3(2.0, 0.0, 0.0)):
		fail("Distant balls must not receive possession assistance")
		return

	var airborne: Dictionary = interaction.step(
		Vector3(1.3, 1.2, 0.0),
		Vector3(2.0, -1.0, 0.0),
		[player],
		0.1
	)
	if airborne.controller != -1 or not airborne.velocity.is_equal_approx(Vector3(2.0, -1.0, 0.0)):
		fail("Airborne balls must pass over possession assistance")
		return

	var fast_shot: Dictionary = interaction.step(
		Vector3(1.3, 0.22, 0.0),
		Vector3(14.0, 1.0, 0.0),
		[player],
		0.1
	)
	if fast_shot.controller != -1 or not fast_shot.velocity.is_equal_approx(Vector3(14.0, 1.0, 0.0)):
		fail("Fast shots must not be captured by dribble assistance")
		return

	var body_contact: Dictionary = interaction.step(
		Vector3(0.3, 0.22, 0.0),
		Vector3.ZERO,
		[player],
		0.1
	)
	if body_contact.position.x < interaction.BODY_CONTACT_DISTANCE - 0.001:
		fail("Player body contact must separate the ball; got %s" % body_contact.position)
		return

	print("Ball contact and dribbling are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
