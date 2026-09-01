extends SceneTree


func _init() -> void:
	var rink := load("res://scripts/simulation/rink_collision.gd")
	if rink == null:
		fail("Rounded rink collision simulation is missing")
		return

	var straight: Dictionary = rink.resolve(
		Vector3(rink.HALF_LENGTH + 0.2, 0.22, 0.0),
		Vector3(8.0, 0.0, 1.0)
	)
	if straight.position.x > rink.HALF_LENGTH or straight.velocity.x >= 0.0:
		fail("A straight side-board hit must rebound into the rink")
		return

	var corner_center := Vector2(rink.HALF_LENGTH - rink.CORNER_RADIUS, rink.HALF_WIDTH - rink.CORNER_RADIUS)
	var outside_corner: Vector2 = corner_center + Vector2.ONE.normalized() * (rink.CORNER_RADIUS + 0.5)
	var corner: Dictionary = rink.resolve(
		Vector3(outside_corner.x, 0.22, outside_corner.y),
		Vector3(7.0, 0.0, 7.0)
	)
	var corrected_offset: Vector2 = Vector2(corner.position.x, corner.position.z) - corner_center
	if corrected_offset.length() > rink.CORNER_RADIUS + 0.001 or corner.velocity.x >= 0.0 or corner.velocity.z >= 0.0:
		fail("A rounded corner hit must project and rebound diagonally inward; got %s" % corner)
		return

	var inside := Vector3(rink.HALF_LENGTH - 1.7, 0.22, rink.HALF_WIDTH - 1.7)
	var untouched: Dictionary = rink.resolve(inside, Vector3(-2.0, 0.0, 1.0))
	if not untouched.position.is_equal_approx(inside) or not untouched.velocity.is_equal_approx(Vector3(-2.0, 0.0, 1.0)):
		fail("A ball inside the rounded boundary must remain untouched")
		return

	var body: Dictionary = rink.constrain_body(Vector3(18.0, 0.75, 8.5), Vector3(5.0, 0.0, 5.0), 18.1, 8.6, 1.8)
	var body_center := Vector2(16.3, 6.8)
	var body_offset := Vector2(body.position.x, body.position.z) - body_center
	if body_offset.length() > 1.801 or Vector2(body.velocity.x, body.velocity.z).dot(body_offset.normalized()) > 0.001:
		fail("Players must slide along rounded corners instead of entering the boards")
		return

	print("Rounded rink collision is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
