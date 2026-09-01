extends SceneTree


func _init() -> void:
	var script := load("res://scripts/simulation/ball_simulation.gd")
	if script == null:
		fail("Ball simulation script is missing")
		return

	var backward_motion := Vector3(-4.0, 0.0, 0.0)
	if not script.is_scoop_shot(Vector2.RIGHT, 0.2, backward_motion):
		fail("A quick shot while retreating opposite the aim must become a scoop")
		return
	if script.is_scoop_shot(Vector2.RIGHT, 0.4, backward_motion):
		fail("Charging beyond the original 250 ms window must prevent a scoop")
		return
	if script.is_scoop_shot(Vector2.RIGHT, 0.2, Vector3(4.0, 0.0, 0.0)):
		fail("Moving toward the aim must remain a normal low shot")
		return

	var scoop: Dictionary = script.shot_plan(Vector2.RIGHT, 0.2, backward_motion)
	var ordinary: Dictionary = script.shot_plan(Vector2.RIGHT, 0.2, Vector3.ZERO)
	if not scoop.is_scoop or ordinary.is_scoop:
		fail("Shot plans must expose scoop state for gameplay presentation")
		return
	if scoop.velocity.y <= ordinary.velocity.y or scoop.velocity.y < 8.0:
		fail("A scoop must launch with an unmistakably higher arc; scoop=%s ordinary=%s" % [scoop.velocity, ordinary.velocity])
		return
	if not is_equal_approx(scoop.velocity.x, ordinary.velocity.x - 4.0):
		fail("Scoop shots must retain the player's planar momentum")
		return

	print("Scoop shot rules are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
