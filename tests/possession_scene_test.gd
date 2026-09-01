extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var packed := load("res://scenes/app/main.tscn") as PackedScene
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
		fail("The AI must hold a neutral opening instead of beating the human to every faceoff")
		return
	player.position = Vector3(-5.0, 0.75, 0.0)
	player.velocity = Vector3.ZERO
	ball.position = player.position + Vector3(0.9, -0.53, 0.75)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	if not ball.has_method("is_controlled_by") or not ball.call("is_controlled_by", &"red"):
		fail("Live ball gameplay must persist red stick ownership after capture")
		return
	ball.position = Vector3(0.0, 0.22, 0.0)
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

	print("Possession and empty-slap scene behavior is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
