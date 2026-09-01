extends SceneTree

func _init() -> void:
	if not ResourceLoader.exists("res://scripts/simulation/goalkeeper_ai.gd"):
		fail("Dedicated goalkeeper AI is missing")
		return
	var GoalkeeperAI = load("res://scripts/simulation/goalkeeper_ai.gd")
	var red_home: Vector2 = GoalkeeperAI.target(&"red", Vector3(4.0, 0.22, 7.5), false)
	var blue_home: Vector2 = GoalkeeperAI.target(&"blue", Vector3(-4.0, 0.22, -7.5), false)
	if red_home.x < -17.4 or red_home.x > -14.4 or absf(red_home.y) > 2.25:
		fail("Lambs goalkeeper must track the ball while remaining in the left crease; target=%s" % red_home)
		return
	if blue_home.x < 14.4 or blue_home.x > 17.4 or absf(blue_home.y) > 2.25:
		fail("Pirates goalkeeper must track the ball while remaining in the right crease; target=%s" % blue_home)
		return
	var red_intercept: Vector2 = GoalkeeperAI.target(&"red", Vector3(-15.4, 0.22, 1.4), true)
	if red_intercept.distance_to(Vector2(-15.4, 1.4)) > 0.8:
		fail("A nearby loose ball must pull the goalkeeper forward for a save; target=%s" % red_intercept)
		return
	print("Goalkeeper AI tracks play and protects its crease.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
