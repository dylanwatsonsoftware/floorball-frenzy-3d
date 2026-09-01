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
		"LeftGoalPostTopMark", "LeftGoalPostBottomMark", "RightGoalPostTopMark", "RightGoalPostBottomMark",
	]
	for marking_name in required_markings:
		if arena.get_node_or_null(marking_name) == null:
			fail("Missing official floorball marking: %s" % marking_name)
			return
	var center_line := arena.get_node("CenterLine") as MeshInstance3D
	var center_line_size: Vector3 = (center_line.mesh as BoxMesh).size
	var marking_material := center_line.material_override as StandardMaterial3D
	if center_line_size.x < 0.08 or not marking_material.emission_enabled or marking_material.albedo_color.get_luminance() < 0.75:
		fail("Regulation markings must remain clearly painted and readable against wood at mobile camera distance")
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
	var left_post_top := arena.get_node("LeftGoalPostTopMark") as MeshInstance3D
	var left_post_bottom := arena.get_node("LeftGoalPostBottomMark") as MeshInstance3D
	if not is_equal_approx(absf(left_post_top.position.z - left_post_bottom.position.z), 1.6):
		fail("Painted goal-post marks must be 1.6 metres apart on the goal line")
		return

	var red_players: Array = arena.call("get_team_players", &"red")
	var lamb_variants := {}
	var pirate_variants := {}
	for actor in arena.call("get_field_players"):
		var rig := actor.get_node_or_null("BodyRig") as Node3D
		if rig == null:
			fail("Every field player needs a lightweight animated humanoid rig")
			return
		for part_name in ["Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
			if rig.get_node_or_null(part_name) == null:
				fail("Humanoid rig is missing %s on %s" % [part_name, actor.name])
				return
		if not rig.has_method("apply_movement_pose"):
			fail("Humanoid rigs must expose deterministic running animation")
			return
		var team: StringName = actor.call("get_team")
		var signature: String = String(rig.get_meta("variant_signature", ""))
		if signature.is_empty():
			fail("Every mascot player needs a distinct visual variant signature")
			return
		if team == &"red":
			for mascot_part in ["LambWool", "LambWoolCollar", "LambFace", "LeftLambEar", "RightLambEar", "Muzzle"]:
				if rig.get_node_or_null(mascot_part) == null:
					fail("The Lambs must read as anthropomorphic lambs; missing %s" % mascot_part)
					return
			lamb_variants[signature] = true
			var lamb_jersey := (rig.get_node("Torso") as MeshInstance3D).material_override as StandardMaterial3D
			if lamb_jersey.albedo_color.g <= lamb_jersey.albedo_color.r:
				fail("The Lambs must wear recognisable green, white and black")
				return
		else:
			for mascot_part in ["PirateBandana", "PirateTricorne", "PirateEyePatch", "PirateNose", "PirateBeard", "LeftHumanEar", "RightHumanEar"]:
				if rig.get_node_or_null(mascot_part) == null:
					fail("The Pirates must read as distinct human pirate mascots; missing %s" % mascot_part)
					return
			pirate_variants[signature] = true
		var left_leg := rig.get_node("LeftLeg") as Node3D
		var right_leg := rig.get_node("RightLeg") as Node3D
		rig.call("apply_movement_pose", 7.0, 0.18, false)
		if absf(left_leg.rotation.x) < 0.08 or left_leg.rotation.x * right_leg.rotation.x >= 0.0:
			fail("Running must visibly swing the legs in opposing directions")
			return
	if lamb_variants.size() != 6 or pirate_variants.size() != 6:
		fail("All six characters on each team must be visually distinguishable; lambs=%d pirates=%d" % [lamb_variants.size(), pirate_variants.size()])
		return
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
	red_two.velocity = Vector3.ZERO
	var facing: Vector3 = red_two.call("get_facing_direction")
	var right := Vector3(-facing.z, 0.0, facing.x)
	ball.position = red_two.position + facing * 0.9 + right * 0.75 + Vector3(0.0, -0.53, 0.0)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	if not red_two.get_node("PlayerMarker").visible or _visible_marker_count(red_players) != 1:
		fail("The floating arrow must follow possession-based control handoffs to red_2; owner=%s human=%s visible=%d" % [ball.call("get_control_owner_actor_id"), ball.call("get_human_control_actor_id"), _visible_marker_count(red_players)])
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
