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
	var fuego_capped: Vector3 = script.step_velocity(Vector3(100.0, 0.0, 0.0), Vector2.RIGHT, 1.0, 1.2)
	if not is_equal_approx(fuego_capped.length(), script.MAX_SPEED * 1.2):
		fail("En Fuego movement must use the boosted maximum speed")
		return
	var carrier_capped: Vector3 = script.step_velocity(Vector3(100.0, 0.0, 0.0), Vector2.RIGHT, 1.0, script.BALL_CARRIER_SPEED_MULTIPLIER)
	if carrier_capped.length() >= capped.length() or carrier_capped.length() < capped.length() * 0.8:
		fail("Ball carriers must be slightly slower so defenders can realistically close them down; carrier=%s free=%s" % [carrier_capped.length(), capped.length()])
		return
	if script.OFF_BALL_SPEED_MULTIPLIER <= 1.0 or script.AI_SPEED_MULTIPLIER >= 1.0:
		fail("Off-ball skaters must gain pace while AI receives a modest global handicap")
		return
	var ai_support_speed: float = script.MAX_SPEED * script.AI_SPEED_MULTIPLIER * script.OFF_BALL_SPEED_MULTIPLIER
	var ai_carrier_speed: float = script.MAX_SPEED * script.AI_SPEED_MULTIPLIER * script.BALL_CARRIER_SPEED_MULTIPLIER
	if ai_support_speed <= ai_carrier_speed * 1.15 or ai_support_speed >= script.MAX_SPEED:
		fail("AI support must outrun its carrier without matching full human pace")
		return

	var slowed: Vector3 = script.step_velocity(Vector3(5.0, 0.0, 0.0), Vector2.ZERO, 0.1)
	if slowed.length() >= 5.0:
		fail("Player must decelerate with no input")
		return

	var combined: Vector2 = script.combine_inputs(Vector2.RIGHT, Vector2.DOWN)
	if not is_equal_approx(combined.length(), 1.0) or combined.x <= 0.0 or combined.y <= 0.0:
		fail("Keyboard and touch movement must combine without exceeding unit length; got %s" % combined)
		return

	var dash: Dictionary = script.start_dash(Vector2.RIGHT, 0.0)
	if not dash.started or not is_equal_approx(dash.velocity.length(), script.DASH_SPEED):
		fail("A ready dash must start at dash speed")
		return
	var blocked: Dictionary = script.start_dash(Vector2.RIGHT, 0.2)
	if blocked.started or not blocked.velocity.is_zero_approx():
		fail("A dash must not start while its cooldown is active")
		return
	var fallback: Dictionary = script.start_dash(Vector2.ZERO, 0.0, Vector3.LEFT)
	if not fallback.started or fallback.velocity.x >= 0.0:
		fail("A stationary dash must use the player's facing direction")
		return

	print("Player motor is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
