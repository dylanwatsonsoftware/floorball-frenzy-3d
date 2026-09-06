extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	var ball := arena.get_node("Ball")
	var carrier := arena.get_node("Player") as CharacterBody3D
	var thief := arena.get_node("Opponent") as CharacterBody3D
	ball.call("apply_network_control_state", &"red_1", &"red_1", &"blue_1")
	if not thief.call("try_dash", Vector2.LEFT):
		fail("Steal animation setup requires a live dash")
		return
	var thief_index: int = arena.call("get_field_players").find(thief)
	ball.call("_apply_dash_steal", thief_index)
	var thief_rig := thief.get_node("BodyRig") as Node3D
	var carrier_rig := carrier.get_node("BodyRig") as Node3D
	thief_rig.call("_process", 0.0)
	carrier_rig.call("_process", 0.0)
	if float(thief_rig.get_meta("poke_pose_weight", 0.0)) < 0.7:
		fail("A successful thief must immediately show a strong stick-jab pose")
		return
	if float(carrier_rig.get_meta("contest_recoil_weight", 0.0)) < 0.55:
		fail("The dispossessed carrier must visibly recoil from the contest")
		return
	var thief_stick := thief.get_node("StickRig") as Node3D
	var rest_transform: Transform3D = thief_stick.get_meta("swing_rest_transform", thief_stick.transform)
	var jab_angle := absf(Vector2(rest_transform.basis.x.x, rest_transform.basis.x.z).angle_to(Vector2(thief_stick.basis.x.x, thief_stick.basis.x.z)))
	if jab_angle < deg_to_rad(12.0):
		fail("The steal pose must visibly poke the stick toward the loose ball; angle=%s" % rad_to_deg(jab_angle))
		return
	for frame in 28:
		await process_frame
	if float(thief_rig.get_meta("poke_pose_weight", 1.0)) > 0.05 or float(carrier_rig.get_meta("contest_recoil_weight", 1.0)) > 0.05:
		fail("Contest reactions must recover promptly without delaying control")
		return
	print("Successful steals trigger a readable poke and possession-loss recoil.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
