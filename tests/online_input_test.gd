extends SceneTree


func _init() -> void:
	var controller := load("res://scripts/network/online_input.gd")
	if controller == null or not controller.has_method("compose_movement_input"):
		fail("Online input needs a shared keyboard-and-touch movement composer")
		return
	var touch_only: Vector2 = controller.compose_movement_input(Vector2.ZERO, Vector2(0.65, -0.4))
	if not touch_only.is_equal_approx(Vector2(0.65, -0.4)):
		fail("A guest's mobile joystick movement must be included in network input; got %s" % touch_only)
		return
	var combined: Vector2 = controller.compose_movement_input(Vector2.RIGHT, Vector2.DOWN)
	if not is_equal_approx(combined.length(), 1.0) or combined.x <= 0.0 or combined.y <= 0.0:
		fail("Combined guest inputs must retain both directions and clamp to unit length; got %s" % combined)
		return
	print("Online movement packets include keyboard and mobile joystick input.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
