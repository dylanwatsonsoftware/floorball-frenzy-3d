extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	if not arena.has_method("get_field_players"):
		fail("The arena must expose its 3v3 field-player roster")
		return
	var players: Array = arena.call("get_field_players")
	if players.size() != 6:
		fail("A local match must contain exactly six field players; got %d" % players.size())
		return
	var teams := {&"red": 0, &"blue": 0}
	var ids := {}
	for actor in players:
		if not actor.has_method("get_team") or not actor.has_method("get_actor_id"):
			fail("Every field player must expose stable team and actor identity")
			return
		var team: StringName = actor.call("get_team")
		var actor_id: StringName = actor.call("get_actor_id")
		teams[team] += 1
		ids[actor_id] = true
	if teams.red != 3 or teams.blue != 3 or ids.size() != 6:
		fail("The roster must have three uniquely identified players per team; teams=%s ids=%s" % [teams, ids])
		return
	for actor in players:
		if actor.has_method("is_human_controlled") and actor.call("is_human_controlled"):
			fail("No red player should consume human input before gaining possession")
			return

	var ball := scene.get_node("Arena/Ball")
	var red_two := scene.get_node("Arena/RedTeammate2") as CharacterBody3D
	for actor in players:
		actor.set_physics_process(false)
	red_two.position = Vector3(-2.0, 0.75, 0.0)
	red_two.velocity = Vector3.ZERO
	ball.position = red_two.position + Vector3(0.9, -0.53, 0.75)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	if not ball.has_method("is_controlled_by_actor") or not ball.call("is_controlled_by_actor", &"red_2"):
		fail("Ball ownership must identify the individual squad player carrying it")
		return
	if not red_two.call("is_human_controlled") or scene.get_node("Arena/Player").call("is_human_controlled"):
		fail("Human control must switch to red_2 alone when red_2 gains possession")
		return
	red_two.set_physics_process(true)
	await physics_frame
	var carrier_ring := red_two.get_node_or_null("ControlRing") as MeshInstance3D
	var captain_ring := scene.get_node_or_null("Arena/Player/ControlRing") as MeshInstance3D
	if carrier_ring == null or captain_ring == null or not carrier_ring.visible or captain_ring.visible:
		fail("The active red carrier must have a clear control indicator that follows possession")
		return
	var controlled_start_z: float = red_two.position.z
	Input.action_press("move_down")
	for frame in 10:
		await physics_frame
	Input.action_release("move_down")
	if red_two.position.z <= controlled_start_z + 0.08:
		fail("Movement input must drive the red ball carrier instead of its off-ball AI; start=%s end=%s" % [controlled_start_z, red_two.position.z])
		return
	var carrier_stick := red_two.get_node("StickRig") as Node3D
	var captain_stick := scene.get_node("Arena/Player/StickRig") as Node3D
	var carrier_rest_angle := carrier_stick.rotation.y
	var captain_rest_angle := captain_stick.rotation.y
	Input.action_press("shoot")
	for frame in 5:
		await physics_frame
	Input.action_release("shoot")
	if is_equal_approx(carrier_stick.rotation.y, carrier_rest_angle) or not is_equal_approx(captain_stick.rotation.y, captain_rest_angle):
		fail("Shot input must animate the current red ball carrier's stick, not the original captain")
		return
	Input.action_release("shoot")
	ball.call("reset_for_faceoff")
	var blue_two := scene.get_node("Arena/BlueTeammate2") as CharacterBody3D
	blue_two.position = Vector3(2.0, 0.75, 0.0)
	ball.position = blue_two.position + Vector3(-0.9, -0.53, -0.75)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	if not ball.call("is_controlled_by_actor", &"blue_2"):
		fail("AI passing setup must begin with blue_2 possession")
		return
	scene.get_node("Arena/Player").position = Vector3(1.2, 0.75, 0.1)
	ball.call("_update_ai_pass", 1.0)
	if ball.call("is_controlled_by_actor", &"blue_2") or Vector2(ball.ball_velocity.x, ball.ball_velocity.z).length() < 7.0:
		fail("A pressured blue carrier must release a real catchable pass to team support; velocity=%s" % ball.ball_velocity)
		return
	red_two.position = Vector3.ZERO
	scene.get_node("Arena/BlueTeammate3").position = Vector3.ZERO
	scene.get_node("MatchFlow").call("_reset_faceoff")
	if not red_two.position.is_equal_approx(Vector3(-7.0, 0.75, -4.0)) or not scene.get_node("Arena/BlueTeammate3").position.is_equal_approx(Vector3(7.0, 0.75, 4.0)):
		fail("Every squad player must return to a distinct formation position after a goal")
		return

	print("3v3 scene roster and loose-ball control state are valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
