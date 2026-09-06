extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var ball := scene.get_node("Arena/Ball")
	var receiver := scene.get_node("Arena/Player") as CharacterBody3D
	var body_rig := receiver.get_node("BodyRig") as Node3D
	ball.call("apply_network_control_state", &"", &"red_1", &"blue_1")
	ball.ball_velocity = Vector3(7.0, 0.0, 0.0)
	ball.call("apply_network_control_state", &"red_1", &"red_1", &"blue_1")
	await process_frame
	var receive_weight := float(body_rig.get_meta("receive_pose_weight", 0.0))
	if receive_weight < 0.18:
		fail("Catching a fast ball must trigger a visible receive/cushion pose; weight=%s" % receive_weight)
		return
	body_rig.call("_process", 0.0)
	var stick := receiver.get_node("StickRig") as Node3D
	var rest_transform: Transform3D = stick.get_meta("swing_rest_transform", stick.transform)
	var cushioned_angle := absf(Vector2(rest_transform.basis.x.x, rest_transform.basis.x.z).angle_to(Vector2(stick.basis.x.x, stick.basis.x.z)))
	if cushioned_angle < deg_to_rad(4.0):
		fail("The receive pose must draw the stick backward to cushion the incoming ball; angle=%s" % rad_to_deg(cushioned_angle))
		return
	for frame in 28:
		await process_frame
	if float(body_rig.get_meta("receive_pose_weight", 1.0)) > 0.05:
		fail("The receive/cushion pose must settle promptly back into controllable locomotion")
		return
	print("Fast possession changes trigger a short stick-and-body receive cushion.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
