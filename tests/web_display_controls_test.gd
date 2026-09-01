extends SceneTree


func _init() -> void:
	var controls := load("res://scripts/presentation/web_display_controls.gd")
	if controls == null:
		fail("Web display controls script is missing")
		return

	if not controls.should_show_orientation_hint(Vector2(390.0, 844.0), true):
		fail("Touchscreen portrait viewports must request landscape orientation")
		return
	if controls.should_show_orientation_hint(Vector2(844.0, 390.0), true):
		fail("Landscape viewports must not show the rotation hint")
		return
	if controls.should_show_orientation_hint(Vector2(390.0, 844.0), false):
		fail("Desktop portrait windows must not show a mobile rotation hint")
		return

	var request_script: String = controls.web_fullscreen_script()
	for contract in ["requestFullscreen", "orientation.lock", "landscape", "catch"]:
		if not request_script.contains(contract):
			fail("Fullscreen request must include %s" % contract)
			return

	print("Web display controls are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
