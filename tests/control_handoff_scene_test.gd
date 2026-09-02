extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	var ball := arena.get_node("Ball")
	var players: Array = arena.call("get_field_players")
	var red_two := arena.get_node("RedTeammate2") as CharacterBody3D
	for actor in players:
		if actor != red_two:
			actor.set_physics_process(false)

	# Loose-ball movement must never silently transfer control to whoever happens
	# to be closest. Control is sticky until SWITCH or a teammate takes possession.
	var initial_actor: StringName = ball.call("get_human_control_actor_id")
	red_two.position = Vector3.ZERO + Vector3(0.0, 0.75, 0.0)
	ball.position = Vector3(0.2, 0.22, 0.0)
	ball.ball_velocity = Vector3(12.0, 0.0, 0.0)
	await physics_frame
	if _human_count(players) != 1 or ball.call("get_human_control_actor_id") != initial_actor:
		fail("A loose ball must preserve the current player; initial=%s current=%s count=%d" % [initial_actor, ball.call("get_human_control_actor_id"), _human_count(players)])
		return
	var switched_actor: StringName = ball.call("switch_human_player")
	if switched_actor == initial_actor or _human_count(players) != 1:
		fail("Manual switching must be the only loose-ball transfer; initial=%s actor=%s count=%d" % [initial_actor, switched_actor, _human_count(players)])
		return
	ball.call("reset_for_faceoff")
	if ball.call("get_human_control_actor_id") != switched_actor:
		fail("A faceoff reset must preserve the player's explicit selection; switched=%s current=%s" % [switched_actor, ball.call("get_human_control_actor_id")])
		return
	# Capture and charge while changing direction. Charging must not freeze facing.
	ball.ball_velocity = Vector3.ZERO
	ball.position = red_two.position + Vector3(0.9, -0.53, 0.75)
	await physics_frame
	await physics_frame
	if not ball.call("is_controlled_by_actor", &"red_2"):
		fail("Turning-shot setup must begin with red_2 possession")
		return
	var initial_facing: Vector3 = red_two.call("get_facing_direction")
	Input.action_press("shoot")
	Input.action_press("move_down")
	for frame in 12:
		await physics_frame
	Input.action_release("move_down")
	var turned_facing: Vector3 = red_two.call("get_facing_direction")
	if turned_facing.z < 0.55 or turned_facing.is_equal_approx(initial_facing):
		Input.action_release("shoot")
		fail("The controlled carrier must be able to turn toward movement while charging; initial=%s turned=%s" % [initial_facing, turned_facing])
		return
	if not ball.call("is_controlled_by_actor", &"red_2") or not red_two.call("is_human_controlled"):
		Input.action_release("shoot")
		fail("Turning and running during a charge must retain the controlled carrier")
		return
	if _visible_arrow_count(players) != 1 or not red_two.get_node("AimArrow").visible:
		Input.action_release("shoot")
		fail("Exactly the charging player's arrow must be visible")
		return

	# A genuine control handoff while held must cancel, never migrate, a charge.
	ball.call("launch", Vector2.LEFT, 1.0, Vector3.ZERO, false, &"blue")
	ball.position = Vector3(-10.0, 0.22, 0.0)
	await physics_frame
	await physics_frame
	if _human_count(players) != 1:
		Input.action_release("shoot")
		fail("A control handoff must still leave exactly one human-controlled red player")
		return
	if _visible_arrow_count(players) != 0 or ball.call("get_shot_charge_ratio") > 0.0:
		Input.action_release("shoot")
		fail("Possession/control changes must cancel the old charge instead of moving its arrow; arrows=%d charge=%s" % [_visible_arrow_count(players), ball.call("get_shot_charge_ratio")])
		return

	Input.action_release("shoot")
	print("Control handoff and running shot aim remain coherent.")
	scene.queue_free()
	quit(0)


func _human_count(players: Array) -> int:
	var count := 0
	for actor in players:
		if actor.call("get_team") == &"red" and actor.call("is_human_controlled"):
			count += 1
	return count


func _visible_arrow_count(players: Array) -> int:
	var count := 0
	for actor in players:
		var arrow := actor.get_node_or_null("AimArrow") as Node3D
		if arrow != null and arrow.visible:
			count += 1
	return count


func fail(message: String) -> void:
	push_error(message)
	quit(1)
