extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	var ball := arena.get_node("Ball")
	var carrier := arena.get_node("BlueTeammate2") as CharacterBody3D
	for actor in arena.call("get_field_players"):
		actor.set_physics_process(false)
		if actor.call("get_team") == &"red":
			actor.position = Vector3(8.0, 0.75, 7.0)
	carrier.position = Vector3(-11.8, 0.75, 1.2)
	carrier.velocity = Vector3.ZERO
	var facing: Vector3 = carrier.call("get_facing_direction")
	var right := Vector3(-facing.z, 0.0, facing.x)
	ball.position = carrier.position + facing * 0.9 + right * 0.75 + Vector3(0.0, -0.53, 0.0)
	ball.ball_velocity = Vector3.ZERO
	var carrier_index: int = arena.call("get_field_players").find(carrier)
	ball.set("_control_owner", carrier_index)
	if not ball.call("is_controlled_by_actor", &"blue_2"):
		fail("The scoring scenario must begin with a support Pirate carrying the ball; facing=%s ball=%s owner=%s" % [facing, ball.position, ball.call("get_control_owner_actor_id")])
		return
	var resting_angle: float = (carrier.get_node("StickRig") as Node3D).rotation.y
	ball.call("_update_ai_pass", 0.35)
	if is_equal_approx((carrier.get_node("StickRig") as Node3D).rotation.y, resting_angle):
		fail("The actual Pirate carrier must visibly wind up a shot near goal")
		return
	ball.call("_update_ai_pass", 0.30)
	if ball.call("get_control_owner_actor_id") != &"" or ball.ball_velocity.x >= -9.0:
		fail("A support Pirate in scoring range must shoot toward the left goal; owner=%s velocity=%s" % [ball.call("get_control_owner_actor_id"), ball.ball_velocity])
		return
	if absf(ball.ball_velocity.z) > 5.0:
		fail("The Pirate shot must target the goal mouth rather than dumping the ball sideways; velocity=%s" % ball.ball_velocity)
		return
	print("Every Pirate ball carrier can wind up and shoot at goal.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
