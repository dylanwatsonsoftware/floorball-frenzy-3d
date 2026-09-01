extends SceneTree


func _init() -> void:
	var script := load("res://scripts/presentation/camera_presets.gd")
	if script == null:
		fail("Camera preset script is missing")
		return

	var presets: Array = script.all()
	if presets.size() != 3:
		fail("Expected exactly three camera presets")
		return

	var expected_names := ["Broadcast", "Toy Box", "Action"]
	for index in presets.size():
		var preset: Dictionary = presets[index]
		if preset.get("name") != expected_names[index]:
			fail("Unexpected camera preset order")
			return
		if not preset.has_all(["position", "target", "fov"]):
			fail("Camera preset is incomplete")
			return
		if preset.fov < 30.0 or preset.fov > 55.0:
			fail("Camera FOV is outside the readable range")
			return

	print("Camera presets are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
