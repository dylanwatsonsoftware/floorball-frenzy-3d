extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var packed := load("res://scenes/match/match.tscn") as PackedScene
	if packed == null:
		fail("Main scene could not be loaded")
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var player := scene.get_node("Arena/Player")
	var opponent := scene.get_node("Arena/Opponent")
	var ball := scene.get_node("Arena/Ball")
	var opponent_start: Vector3 = opponent.position
	for frame in 20:
		await physics_frame
	if opponent.position.distance_to(opponent_start) > 0.05:
		fail("The AI must hold a neutral opening instead of beating the human to every faceoff; start=%s end=%s velocity=%s" % [opponent_start, opponent.position, opponent.velocity])
		return
	# Isolate red stick behavior from the eleven autonomous roster actors.
	for actor in scene.get_node("Arena").call("get_field_players"):
		if actor != player:
			actor.set_physics_process(false)
	player.position = Vector3(-5.0, 0.75, 0.0)
	player.velocity = Vector3.ZERO
	ball.position = player.position + Vector3(0.9, -0.53, 0.75)
	ball.ball_velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	ball.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	if not ball.has_method("is_controlled_by") or not ball.call("is_controlled_by", &"red"):
		fail("Live ball gameplay must persist red stick ownership after capture")
		return
	for frame in 30:
		await physics_frame
	var blade := player.get_node("StickRig/Blade") as MeshInstance3D
	var blade_pocket := player.get_node("StickRig/BladePocket") as Marker3D
	var blade_world_center := blade_pocket.global_position
	var carried_gap := Vector2(ball.global_position.x, ball.global_position.z).distance_to(Vector2(blade_world_center.x, blade_world_center.z))
	if carried_gap > 0.36:
		fail("A possessed ball must settle visibly onto the actual blade instead of an obsolete physics offset; gap=%s ball=%s blade=%s owner=%s" % [carried_gap, ball.global_position, blade_world_center, ball.call("get_control_owner_actor_id")])
		return
	ball.call("begin_slap", Vector2.RIGHT, 0.7)
	opponent.call("try_dash", Vector2.LEFT)
	var opponent_index: int = scene.get_node("Arena").call("get_field_players").find(opponent)
	ball.call("_apply_dash_steal", opponent_index)
	if not ball.call("is_controlled_by_actor", player.call("get_actor_id")):
		fail("An AI dash must not strip the ball during the player's committed shot wind-up")
		return
	ball.call("_cancel_slap")
	ball.position = Vector3(0.0, 4.0, 0.0)
	ball.ball_velocity = Vector3.ZERO

	Input.action_press("shoot")
	for frame in 3:
		await physics_frame
	if ball.call("get_slap_phase") != &"backswing":
		Input.action_release("shoot")
		fail("Holding Shoot must animate a backswing even when no ball is in range")
		return
	Input.action_release("shoot")
	await physics_frame
	if ball.call("get_slap_phase") == &"idle":
		fail("Releasing Shoot without the ball must still play the forward slap and recovery")
		return
	for frame in 30:
		await physics_frame

	# A carried ball can lag behind the exact visual blade point during a turn or run.
	# The forward slap must still connect while it remains in the retained stick zone.
	player.position = Vector3.ZERO + Vector3(0.0, 0.75, 0.0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	blade_pocket.force_update_transform()
	ball.position = Vector3(blade_pocket.global_position.x, 0.22, blade_pocket.global_position.z)
	ball.ball_velocity = Vector3.ZERO
	ball.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	if not ball.call("is_controlled_by", &"red"):
		fail("Reliable-shot setup must begin with real red possession")
		return
	ball.call("begin_slap", Vector2.RIGHT, 0.7)
	await physics_frame
	if not ball.call("is_controlled_by", &"red"):
		fail("A ball inside the retained carry zone must remain possessed during backswing")
		return
	var peak_shot_speed := 0.0
	for frame in 20:
		await physics_frame
		peak_shot_speed = maxf(peak_shot_speed, ball.ball_velocity.length())
	if peak_shot_speed < 7.5:
		fail("A forward slap must reliably hit a retained ball; peak_speed=%s velocity=%s" % [peak_shot_speed, ball.ball_velocity])
		return

	print("Possession and empty-slap scene behavior is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
