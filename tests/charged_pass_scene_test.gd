extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	var ball = arena.get_node("Ball")
	var carrier := arena.get_node("Player") as CharacterBody3D
	for actor in arena.call("get_field_players"):
		if actor != carrier:
			actor.set_physics_process(false)
	var target := arena.get_node("RedTeammate2") as CharacterBody3D
	carrier.position = Vector3(0.0, 0.75, 0.0)
	target.position = Vector3(12.0, 0.75, 0.0)
	for actor in arena.call("get_team_players", &"red"):
		if actor != carrier and actor != target:
			actor.position = Vector3(-8.0, 0.75, float(actor.get_index()) * 0.2)
	ball.position = carrier.position + Vector3(0.9, -0.53, 0.75)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	Input.action_press("pass")
	for frame in 30:
		await physics_frame
	var held_charge = ball.get("_pass_charge_seconds")
	if held_charge == null or float(held_charge) < 0.35 or ball.call("get_slap_phase") != &"idle":
		Input.action_release("pass")
		fail("Holding Pass must build power without releasing the ball early")
		return
	Input.action_release("pass")
	await physics_frame
	if ball.call("get_slap_phase") == &"idle" or float(ball.get("_pending_slap_charge")) < 1.15:
		fail("Releasing a charged Pass must begin a powerful pass swing; phase=%s power=%s owner=%s" % [ball.call("get_slap_phase"), ball.get("_pending_slap_charge"), ball.call("get_control_owner_actor_id")])
		return
	print("Pass input charges while held and releases a stronger pass swing.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
