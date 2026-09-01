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
	]
	for path in required_nodes:
		if scene.get_node_or_null(path) == null:
			fail("Missing greybox node: %s" % path)
			return

	var camera := scene.get_node("Arena/BroadcastCamera") as Camera3D
	if not camera.current:
		fail("Broadcast camera must be active by default")
		return

	print("Greybox scene contract is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
