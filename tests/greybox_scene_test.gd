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

	var required_nodes := [
		"Arena/RinkFloor",
		"Arena/Player",
		"Arena/Ball",
		"Arena/LeftGoal",
		"Arena/RightGoal",
		"Arena/BroadcastCamera",
		"HUD/CameraLabel",
		"HUD/MobileControls",
	]
	for path in required_nodes:
		if scene.get_node_or_null(path) == null:
			fail("Missing greybox node: %s" % path)
			return

	var camera := scene.get_node("Arena/BroadcastCamera") as Camera3D
	if not camera.current:
		fail("Broadcast camera must be active by default")
		return

	var ball := scene.get_node("Arena/Ball")
	if not ball.has_method("launch"):
		fail("Ball must expose deterministic launch behavior")
		return
	if scene.get_node_or_null("HUD/ChargeLabel") == null:
		fail("HUD must expose shot charging feedback")
		return
	var mobile_controls := scene.get_node("HUD/MobileControls")
	if not mobile_controls.has_method("get_movement_vector"):
		fail("Mobile controls must expose a movement vector")
		return
	if scene.get_node_or_null("HUD/MobileControls/MoveBase") == null:
		fail("Mobile controls must show a movement joystick")
		return
	if scene.get_node_or_null("HUD/MobileControls/ShootButton") == null:
		fail("Mobile controls must show a shoot button")
		return
	var ball_start: Vector3 = ball.position
	ball.launch(Vector2.RIGHT, 1.0)
	await physics_frame
	await physics_frame
	if ball.position.x <= ball_start.x or ball.position.y <= ball_start.y:
		fail("Launched ball must move forward and lift into 3D space; start=%s end=%s" % [ball_start, ball.position])
		return

	print("Greybox scene contract is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
