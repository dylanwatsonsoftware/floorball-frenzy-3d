extends SceneTree


func _init() -> void:
	var goals := load("res://scripts/simulation/goal_collision.gd")
	if goals == null:
		fail("Goal collision script is missing")
		return

	var post_hit: Dictionary = goals.resolve(
		Vector3(15.75, 0.5, 1.25),
		Vector3(16.25, 0.5, 1.25),
		Vector3(10.0, 0.0, 0.0)
	)
	if post_hit.velocity.x >= 0.0:
		fail("A shot through a goal post must rebound into the rink; got %s" % post_hit)
		return

	var crossbar_hit: Dictionary = goals.resolve(
		Vector3(15.75, 1.5, 0.0),
		Vector3(16.25, 1.4, 0.0),
		Vector3(10.0, -2.0, 0.0)
	)
	if crossbar_hit.velocity.x >= 0.0:
		fail("A shot through the crossbar must rebound into the rink; got %s" % crossbar_hit)
		return

	var cage_back_hit: Dictionary = goals.resolve(
		Vector3(17.1, 0.4, 0.0),
		Vector3(17.6, 0.4, 0.0),
		Vector3(10.0, 0.0, 0.0)
	)
	if cage_back_hit.velocity.x >= 0.0:
		fail("The goal cage back must rebound the ball toward the mouth")
		return

	var cage_side_hit: Dictionary = goals.resolve(
		Vector3(16.5, 0.4, 1.1),
		Vector3(16.6, 0.4, 1.4),
		Vector3(2.0, 0.0, 6.0)
	)
	if cage_side_hit.velocity.z >= 0.0:
		fail("The goal cage side must rebound the ball inward")
		return

	var clean_goal: Dictionary = goals.resolve(
		Vector3(15.75, 0.4, 0.0),
		Vector3(16.25, 0.4, 0.0),
		Vector3(10.0, 0.0, 0.0)
	)
	if clean_goal.collided or clean_goal.velocity.x <= 0.0:
		fail("A valid shot through the open mouth must remain unobstructed")
		return

	print("Goal frame and cage collisions are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
