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
		Vector3(0.9, 0.22, 0.75),
		Vector3.ZERO,
		[player],
		0.1
	)
	if controlled.controller != 0 or controlled.velocity.x <= 0.0:
		fail("A grounded ball at the stick must follow the moving player; got %s" % controlled)
		return
	if controlled.body_controller != -1:
		fail("Stick control must not count as the body touch used for one-touch timing")
		return

	var wrong_side: Dictionary = interaction.step(Vector3(0.9, 0.22, -0.75), Vector3.ZERO, [player], 0.1)
	if wrong_side.controller != -1:
		fail("The back of the curved blade must not magnetically capture the ball")
		return

	var backswing_player := player.duplicate()
	backswing_player.slap_phase = &"backswing"
	var neutral: Dictionary = interaction.step(Vector3(0.9, 0.22, 0.75), Vector3.ZERO, [backswing_player], 0.1)
	if neutral.controller != 0 or not is_equal_approx(neutral.velocity.x, player.velocity.x) or not is_equal_approx(neutral.velocity.z, player.velocity.z):
		fail("During backswing the ball must inherit player motion without a stick impulse; got %s" % neutral)
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
		Vector3(0.9, 1.2, 0.75),
		Vector3(2.0, -1.0, 0.0),
		[player],
		0.1
	)
	if airborne.controller != -1 or not airborne.velocity.is_equal_approx(Vector3(2.0, -1.0, 0.0)):
		fail("Airborne balls must pass over possession assistance")
		return
	var torso_hit: Dictionary = interaction.step(
		Vector3(0.3, 1.2, 0.0),
		Vector3(-14.0, 0.0, 0.0),
		[player],
		0.1
	)
	if torso_hit.body_controller != 0 or torso_hit.controller != -1:
		fail("A lifted shot at torso height must still report body contact without magnetic stick control")
		return

	var fast_shot: Dictionary = interaction.step(
		Vector3(0.9, 0.22, 0.75),
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
	if body_contact.body_controller != 0:
		fail("Body collision must identify the player who last touched the ball")
		return

	print("Ball contact and dribbling are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
