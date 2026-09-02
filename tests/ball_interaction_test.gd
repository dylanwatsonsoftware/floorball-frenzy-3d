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

	var direct_pickup: Dictionary = interaction.step(
		Vector3(1.15, 0.22, 0.0),
		Vector3.ZERO,
		[player],
		0.1
	)
	if direct_pickup.controller != 0:
		fail("Approaching a loose ball directly in front must feed it into the curved stick pocket")
		return

	var authored_player := player.duplicate()
	authored_player.blade_target = Vector3(0.9, 0.22, -0.38)
	var authored_pickup: Dictionary = interaction.step(
		authored_player.blade_target,
		Vector3.ZERO,
		[authored_player],
		0.1
	)
	if authored_pickup.controller != 0:
		fail("An authored 3D blade-front anchor must remain catchable even when the stick is mirrored around the player")
		return
	var network_player := authored_player.duplicate()
	network_player.network_pickup_assist = true
	var compensated_player: Dictionary = interaction.compensate_network_blade(network_player, 0.12)
	if not compensated_player.blade_target.is_equal_approx(network_player.blade_target + network_player.velocity * 0.12):
		fail("Remote blade pickup must project toward the guest's current movement to cover transit delay")
		return
	var latency_assisted_pickup: Dictionary = interaction.step(
		Vector3(2.7, 0.22, -0.38),
		Vector3.ZERO,
		[compensated_player],
		0.1
	)
	if latency_assisted_pickup.controller != 0:
		fail("The remote human needs a modest blade-pocket allowance to compensate for network delay")
		return

	var turned_player := player.duplicate()
	turned_player.facing = Vector3.FORWARD
	turned_player.velocity = Vector3.ZERO
	var retained: Dictionary = interaction.step(
		Vector3(0.9, 0.22, 0.75),
		Vector3.ZERO,
		[turned_player],
		0.1,
		0
	)
	if retained.controller != 0:
		fail("A controlled ball must remain attached through an ordinary sharp direction change")
		return
	var running_player := player.duplicate()
	running_player.velocity = Vector3(12.0, 0.0, 0.0)
	var running_control: Dictionary = interaction.step(
		Vector3(0.9, 0.22, 0.75),
		Vector3(14.0, 0.0, 0.0),
		[running_player],
		0.1,
		0
	)
	if running_control.controller != 0:
		fail("Possession must not drop merely because the player and carried ball are moving at full speed")
		return

	var challenger := {
		"position": Vector3(0.9, 0.75, 0.75),
		"velocity": Vector3(-5.0, 0.0, 0.0),
		"facing": Vector3.LEFT,
	}
	var bumped: Dictionary = interaction.step(
		Vector3(0.9, 0.22, 0.75),
		Vector3.ZERO,
		[player, challenger],
		0.1,
		0
	)
	if bumped.controller == 0:
		fail("Opponent body contact must still knock the ball out of retained stick possession")
		return
	var team_owner := player.duplicate()
	team_owner.team = &"red"
	var teammate := challenger.duplicate()
	teammate.team = &"red"
	var friendly_overlap: Dictionary = interaction.step(
		Vector3(0.9, 0.22, 0.75),
		Vector3.ZERO,
		[team_owner, teammate],
		0.1,
		0
	)
	if friendly_overlap.controller != 0:
		fail("A teammate crossing the carrier's stick must not steal or knock away possession; got %s" % friendly_overlap)
		return
	var protected_owner := team_owner.duplicate()
	protected_owner.shot_protected = true
	var opponent_challenger := challenger.duplicate()
	opponent_challenger.team = &"blue"
	var protected_overlap: Dictionary = interaction.step(
		Vector3(0.9, 0.22, 0.75),
		Vector3.ZERO,
		[protected_owner, opponent_challenger],
		0.1,
		0
	)
	if protected_overlap.controller != 0:
		fail("A carrier winding up a shot must retain possession through incidental challenge contact; got %s" % protected_overlap)
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
