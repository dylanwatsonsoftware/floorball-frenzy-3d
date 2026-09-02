extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	var ball := arena.get_node("Ball")
	var carrier := arena.get_node("Player") as CharacterBody3D
	var red_players: Array = arena.call("get_team_players", &"red")
	for actor in arena.call("get_field_players"):
		if actor != carrier:
			actor.set_physics_process(false)
	carrier.position = Vector3.ZERO + Vector3(0.0, 0.75, 0.0)
	carrier.velocity = Vector3.ZERO
	var nearest: CharacterBody3D
	var next_nearest: CharacterBody3D
	for actor in red_players:
		if actor == carrier:
			continue
		if nearest == null:
			nearest = actor
		elif next_nearest == null:
			next_nearest = actor
	nearest.position = Vector3(4.0, 0.75, 0.0)
	next_nearest.position = Vector3(0.0, 0.75, 7.0)
	for actor in red_players:
		if actor != carrier and actor != nearest and actor != next_nearest:
			actor.position = Vector3(12.0, 0.75, 8.0)
	ball.position = carrier.position + Vector3(0.9, -0.53, 0.75)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	if not ball.call("is_controlled_by_actor", carrier.call("get_actor_id")):
		fail("Pass test must begin with the human carrier possessing the ball")
		return
	if not ball.has_method("pass_to_closest_teammate") or not ball.call("pass_to_closest_teammate"):
		fail("A possessed human player must be able to start an automatic pass")
		return
	if ball.call("get_slap_phase") == &"idle":
		fail("Passing must visibly animate the same physical stick slap as shooting")
		return
	var expected := Vector2(nearest.global_position.x - carrier.global_position.x, nearest.global_position.z - carrier.global_position.z).normalized()
	var peak_pass_velocity := Vector2.ZERO
	for frame in 20:
		await physics_frame
		var frame_velocity := Vector2(ball.ball_velocity.x, ball.ball_velocity.z)
		if frame_velocity.length() > peak_pass_velocity.length():
			peak_pass_velocity = frame_velocity
	if peak_pass_velocity.length() < 6.0 or peak_pass_velocity.length() > 10.5 or peak_pass_velocity.normalized().dot(expected) < 0.93:
		fail("Pass contact must send the ball at controlled speed toward the nearest teammate; peak=%s expected=%s" % [peak_pass_velocity, expected])
		return
	print("Human Pass slaps toward the nearest teammate at controlled speed.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
