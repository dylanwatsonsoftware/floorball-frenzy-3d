extends SceneTree


func _init() -> void:
	var match_sim := load("res://scripts/simulation/match_simulation.gd")
	if match_sim == null:
		fail("Match simulation script is missing")
		return
	if not is_equal_approx(match_sim.GOAL_LINE_X, 16.5) or not is_equal_approx(match_sim.GOAL_HALF_WIDTH, 0.8) or not is_equal_approx(match_sim.GOAL_HEIGHT, 1.15):
		fail("Scoring must use the official 1.6 x 1.15 metre goal on the goalkeeper-area goal line")
		return

	var red_goal: StringName = match_sim.detect_goal(
		Vector3(16.3, 0.5, 0.0),
		Vector3(16.7, 0.45, 0.2),
		Vector3(20.0, -1.0, 2.0)
	)
	if red_goal != &"red":
		fail("Crossing the right goal line through the mouth must score for red")
		return

	var blue_goal: StringName = match_sim.detect_goal(
		Vector3(-16.3, 0.5, 0.0),
		Vector3(-16.7, 0.45, -0.2),
		Vector3(-20.0, -1.0, -2.0)
	)
	if blue_goal != &"blue":
		fail("Crossing the left goal line through the mouth must score for blue")
		return

	if match_sim.detect_goal(Vector3(16.3, 1.3, 0.0), Vector3(16.7, 1.25, 0.0), Vector3.RIGHT) != &"":
		fail("A ball above the crossbar must not score")
		return
	if match_sim.detect_goal(Vector3(16.3, 0.5, 1.0), Vector3(16.7, 0.45, 1.0), Vector3.RIGHT) != &"":
		fail("A ball outside the goal mouth must not score")
		return

	var result: Dictionary = match_sim.apply_goal({"red": 4, "blue": 2}, &"red")
	if result.red != 5 or result.blue != 2 or result.winner != &"red":
		fail("The fifth goal must produce a red match winner; got %s" % result)
		return

	print("Match scoring simulation is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
