extends SceneTree

func _init() -> void:
	if not ResourceLoader.exists("res://scripts/simulation/goalkeeper_ai.gd"):
		fail("Dedicated goalkeeper AI is missing")
		return
	var GoalkeeperAI = load("res://scripts/simulation/goalkeeper_ai.gd")
	var red_home: Vector2 = GoalkeeperAI.target(&"red", Vector3(4.0, 0.22, 7.5), false)
	var blue_home: Vector2 = GoalkeeperAI.target(&"blue", Vector3(-4.0, 0.22, -7.5), false)
	var red_goal_center := Vector2(-16.5, 0.0)
	var blue_goal_center := Vector2(16.5, 0.0)
	if absf(red_home.distance_to(red_goal_center) - GoalkeeperAI.ARC_RADIUS) > 0.01 or red_home.x <= red_goal_center.x:
		fail("Lambs goalkeeper must track play along the inward-facing semicircle; target=%s" % red_home)
		return
	if absf(blue_home.distance_to(blue_goal_center) - GoalkeeperAI.ARC_RADIUS) > 0.01 or blue_home.x >= blue_goal_center.x:
		fail("Pirates goalkeeper must mirror the inward-facing semicircle; target=%s" % blue_home)
		return
	var red_outside: Vector2 = GoalkeeperAI.constrain_to_goal_area(&"red", Vector2(-12.0, 4.0))
	if not red_outside.is_equal_approx(Vector2(-13.83, 1.82)):
		fail("The entire Lambs goalkeeper body must remain inside the large 4 x 5 metre goal area; position=%s" % red_outside)
		return
	var blue_outside: Vector2 = GoalkeeperAI.constrain_to_goal_area(&"blue", Vector2(12.0, -4.0))
	if not blue_outside.is_equal_approx(Vector2(13.83, -1.82)):
		fail("The entire Pirates goalkeeper body must remain inside the large 4 x 5 metre goal area; position=%s" % blue_outside)
		return
	print("Goalkeeper AI tracks play and protects its crease.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
