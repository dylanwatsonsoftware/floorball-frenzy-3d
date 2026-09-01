extends SceneTree


func _init() -> void:
	var ai := load("res://scripts/simulation/simple_ai.gd")
	if ai == null:
		fail("Simple AI script is missing")
		return

	var chase: Dictionary = ai.decide(
		Vector3(5.0, 0.75, 0.0),
		Vector3(0.0, 0.22, 2.0),
		Vector3(-5.0, 0.75, 0.0),
		Vector3.ZERO
	)
	if chase.movement.x >= 0.0 or chase.movement.y <= 0.0:
		fail("Blue AI must chase a loose ball on the XZ plane; got %s" % chase.movement)
		return
	if chase.wants_shot:
		fail("Blue AI must not shoot while out of stick range")
		return
	if chase.wants_dash:
		fail("Blue AI must save its dash while the ball is already nearby")
		return

	var far_chase: Dictionary = ai.decide(
		Vector3(12.0, 0.75, 0.0),
		Vector3(0.0, 0.22, 0.0),
		Vector3(-5.0, 0.75, 0.0),
		Vector3.ZERO,
		true
	)
	if not far_chase.wants_dash:
		fail("Blue AI must use a ready dash when the loose ball is over the original range threshold")
		return
	var cooling_down: Dictionary = ai.decide(Vector3(12.0, 0.75, 0.0), Vector3.ZERO, Vector3(-5.0, 0.75, 0.0), Vector3.ZERO, false)
	if cooling_down.wants_dash:
		fail("Blue AI must not request another dash during cooldown")
		return

	var in_range: Dictionary = ai.decide(
		Vector3(1.0, 0.75, 0.0),
		Vector3(0.0, 0.22, 0.0),
		Vector3(-5.0, 0.75, 0.0),
		Vector3.ZERO
	)
	if not in_range.wants_shot:
		fail("Blue AI must prepare a shot when the grounded ball is in range")
		return
	if in_range.shot_direction.x >= 0.0:
		fail("Blue AI must aim shots toward the left goal")
		return

	var airborne: Dictionary = ai.decide(
		Vector3(1.0, 0.75, 0.0),
		Vector3(0.0, 1.2, 0.0),
		Vector3(-5.0, 0.75, 0.0),
		Vector3.ZERO
	)
	if airborne.wants_shot:
		fail("Blue AI must not strike a ball above stick height")
		return

	print("Simple AI decisions are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
