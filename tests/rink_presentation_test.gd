extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	var floor := arena.get_node("RinkFloor") as MeshInstance3D
	var floor_size: Vector3 = (floor.mesh as BoxMesh).size
	if not is_equal_approx(floor_size.x, 40.0) or not is_equal_approx(floor_size.z, 20.0):
		fail("The full floorball rink must use the official 40 x 20 metre dimensions; got %s" % floor_size)
		return
	if not floor.material_override is ShaderMaterial or "plank" not in (floor.material_override as ShaderMaterial).shader.code.to_lower():
		fail("The rink floor must use a lightweight procedural wood-plank surface")
		return
	if arena.get_node_or_null("CenterCircle") != null:
		fail("A basketball-style centre circle is not part of official floorball markings")
		return

	var required_markings := [
		"CenterLine", "CenterSpot",
		"LeftGoalCreaseRear", "LeftGoalCreaseFront", "LeftGoalCreaseTop", "LeftGoalCreaseBottom",
		"RightGoalCreaseRear", "RightGoalCreaseFront", "RightGoalCreaseTop", "RightGoalCreaseBottom",
		"LeftGoalkeeperAreaRear", "LeftGoalkeeperAreaFront", "LeftGoalkeeperAreaTop", "LeftGoalkeeperAreaBottom",
		"RightGoalkeeperAreaRear", "RightGoalkeeperAreaFront", "RightGoalkeeperAreaTop", "RightGoalkeeperAreaBottom",
		"FaceOffLeftTop", "FaceOffLeftBottom", "FaceOffCenterTop", "FaceOffCenterBottom", "FaceOffRightTop", "FaceOffRightBottom",
	]
	for marking_name in required_markings:
		if arena.get_node_or_null(marking_name) == null:
			fail("Missing official floorball marking: %s" % marking_name)
			return
	var left_crease_rear := arena.get_node("LeftGoalCreaseRear") as MeshInstance3D
	var left_crease_front := arena.get_node("LeftGoalCreaseFront") as MeshInstance3D
	if not is_equal_approx(left_crease_rear.position.x, -17.15) or not is_equal_approx(absf(left_crease_front.position.x - left_crease_rear.position.x), 4.0):
		fail("The 4 x 5 metre goal crease must begin 2.85 metres from the short board")
		return
	var left_keeper_rear := arena.get_node("LeftGoalkeeperAreaRear") as MeshInstance3D
	var left_keeper_front := arena.get_node("LeftGoalkeeperAreaFront") as MeshInstance3D
	if not is_equal_approx(left_keeper_rear.position.x, -16.5) or not is_equal_approx(absf(left_keeper_front.position.x - left_keeper_rear.position.x), 1.0):
		fail("The 1 x 2.5 metre goalkeeper area must place the official goal line at x=16.5")
		return

	var red_players: Array = arena.call("get_team_players", &"red")
	for actor in red_players:
		if actor.get_node_or_null("PlayerMarker") == null:
			fail("Every potentially controlled red player needs a floating downward arrow")
			return
	await process_frame
	if _visible_marker_count(red_players) != 1:
		fail("Exactly one controlled-player arrow must be visible; count=%d" % _visible_marker_count(red_players))
		return
	var ball := arena.get_node("Ball")
	var red_two := arena.get_node("RedTeammate2") as CharacterBody3D
	for actor in arena.call("get_field_players"):
		actor.set_physics_process(false)
	red_two.position = Vector3(-2.0, 0.75, 0.0)
	ball.position = red_two.position + Vector3(0.9, -0.53, 0.75)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await process_frame
	if not red_two.get_node("PlayerMarker").visible or _visible_marker_count(red_players) != 1:
		fail("The floating arrow must follow possession-based control handoffs to red_2")
		return

	print("Official wood rink presentation and controlled-player marker are valid.")
	scene.queue_free()
	quit(0)


func _visible_marker_count(players: Array) -> int:
	var count := 0
	for actor in players:
		var marker := actor.get_node("PlayerMarker") as Node3D
		if marker.visible:
			count += 1
	return count


func fail(message: String) -> void:
	push_error(message)
	quit(1)
