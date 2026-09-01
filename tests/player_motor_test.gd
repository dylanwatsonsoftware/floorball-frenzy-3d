extends SceneTree


func _init() -> void:
	var script := load("res://scripts/gameplay/player_motor.gd")
	if script == null:
		fail("Player motor script is missing")
		return

	var accelerated: Vector3 = script.step_velocity(Vector3.ZERO, Vector2.RIGHT, 0.1)
	if not is_equal_approx(accelerated.y, 0.0):
		fail("Player velocity must remain on the XZ plane")
		return
	if accelerated.x <= 0.0:
		fail("Right input must accelerate along positive X")
		return

	var capped: Vector3 = script.step_velocity(Vector3(100.0, 0.0, 0.0), Vector2.RIGHT, 1.0)
	if capped.length() > script.MAX_SPEED + 0.001:
		fail("Player speed must be capped")
		return

	var slowed: Vector3 = script.step_velocity(Vector3(5.0, 0.0, 0.0), Vector2.ZERO, 0.1)
	if slowed.length() >= 5.0:
		fail("Player must decelerate with no input")
		return

	var combined: Vector2 = script.combine_inputs(Vector2.RIGHT, Vector2.DOWN)
	if not is_equal_approx(combined.length(), 1.0) or combined.x <= 0.0 or combined.y <= 0.0:
		fail("Keyboard and touch movement must combine without exceeding unit length; got %s" % combined)
		return

	print("Player motor is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
