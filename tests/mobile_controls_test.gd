extends SceneTree


func _init() -> void:
	var controls := load("res://scripts/gameplay/mobile_controls.gd")
	if controls == null:
		fail("Mobile controls script is missing")
		return

	var inside_deadzone: Vector2 = controls.calculate_stick_vector(Vector2(10.0, 0.0), 80.0, 0.2)
	if not inside_deadzone.is_zero_approx():
		fail("Joystick movement inside the dead zone must be zero")
		return

	var halfway: Vector2 = controls.calculate_stick_vector(Vector2(48.0, 0.0), 80.0, 0.2)
	if not is_equal_approx(halfway.x, 0.5) or not is_zero_approx(halfway.y):
		fail("Joystick movement must scale after the dead zone; got %s" % halfway)
		return

	var clamped: Vector2 = controls.calculate_stick_vector(Vector2(160.0, 0.0), 80.0, 0.2)
	if not clamped.is_equal_approx(Vector2.RIGHT):
		fail("Joystick movement must clamp to unit length; got %s" % clamped)
		return

	print("Mobile control math is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
