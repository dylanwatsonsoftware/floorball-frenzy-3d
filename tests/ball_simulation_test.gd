extends SceneTree


func _init() -> void:
	var script := load("res://scripts/simulation/ball_simulation.gd")
	if script == null:
		fail("Ball simulation script is missing")
		return

	var low_shot: Vector3 = script.shot_velocity(Vector2.RIGHT, 0.0)
	var charged_shot: Vector3 = script.shot_velocity(Vector2.RIGHT, 1.0)
	if low_shot.x <= 0.0 or not is_equal_approx(low_shot.z, 0.0):
		fail("Shot must travel in its planar aim direction")
		return
	if charged_shot.length() <= low_shot.length():
		fail("Charged shot must be faster than an uncharged shot")
		return
	if charged_shot.y <= low_shot.y:
		fail("Charged shot must have more lift")
		return
	var overcharged_shot: Vector3 = script.shot_velocity(Vector2.RIGHT, 2.0)
	if not overcharged_shot.is_equal_approx(charged_shot):
		fail("A fully charged shot must stay at full power instead of becoming weak because the button was held too long")
		return
	var almost_full: Vector3 = script.shot_velocity(Vector2.RIGHT, 0.95)
	if charged_shot.x <= almost_full.x or charged_shot.x - almost_full.x > script.SHOT_SPEED_SCALE * 0.06:
		fail("Shot power must ramp smoothly into full charge without a narrow timing spike")
		return
	var moving_shot: Vector3 = script.shot_velocity(Vector2.RIGHT, 0.5, Vector3(4.0, 0.0, 2.0))
	var static_shot: Vector3 = script.shot_velocity(Vector2.RIGHT, 0.5)
	if not is_equal_approx(moving_shot.x, static_shot.x + 4.0) or not is_equal_approx(moving_shot.z, static_shot.z + 2.0):
		fail("Slap shots must inherit planar player momentum")
		return
	var pass_velocity: Vector3 = script.pass_velocity(Vector2(1.0, 0.15), Vector3(4.0, 0.0, 0.0))
	var pass_speed := Vector2(pass_velocity.x, pass_velocity.z).length()
	if pass_speed < 7.0 or pass_speed > 10.0 or pass_velocity.y > 0.5:
		fail("A floorball pass must stay grounded and catchable instead of behaving like a shot; got %s" % pass_velocity)
		return
	var one_touch_shot: Vector3 = script.shot_velocity(Vector2.RIGHT, 0.5, Vector3.ZERO, true)
	if not is_equal_approx(one_touch_shot.x, static_shot.x * 1.25) or not is_equal_approx(one_touch_shot.y, static_shot.y):
		fail("One-touch must preserve lift while applying the original 25% planar power bonus")
		return
	var bolt_shot: Vector3 = script.shot_velocity(Vector2.RIGHT, 0.5, Vector3.ZERO, false, true)
	if not is_equal_approx(bolt_shot.x, static_shot.x * 1.44) or not is_equal_approx(bolt_shot.y, static_shot.y):
		fail("Bolt must preserve lift while stacking the original two 20% dash-shot boosts")
		return

	var airborne: Dictionary = script.step(Vector3(0.0, 3.0, 0.0), Vector3.ZERO, 0.1)
	if airborne.velocity.y >= 0.0:
		fail("Gravity must pull an airborne ball downward")
		return

	var floor_hit: Dictionary = script.step(Vector3(0.0, script.BALL_RADIUS + 0.01, 0.0), Vector3(0.0, -3.0, 0.0), 0.1)
	if floor_hit.position.y < script.BALL_RADIUS - 0.001 or floor_hit.velocity.y <= 0.0:
		fail("Ball must bounce upward from the floor; got position=%s velocity=%s" % [floor_hit.position, floor_hit.velocity])
		return

	var wall_hit: Dictionary = script.step(Vector3(script.RINK_HALF_LENGTH - 0.05, script.BALL_RADIUS, 0.0), Vector3(8.0, 0.0, 0.0), 0.1)
	if wall_hit.position.x > script.RINK_HALF_LENGTH or wall_hit.velocity.x >= 0.0:
		fail("Ball must bounce inward from the side wall")
		return

	var post_hit: Dictionary = script.step(Vector3(15.75, 0.5, 1.25), Vector3(10.0, 0.0, 0.0), 0.05)
	if post_hit.velocity.x >= 0.0:
		fail("Ball simulation must apply goal-frame collisions before scoring")
		return

	print("Ball simulation is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
