extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	var ball := arena.get_node("Ball")
	var keepers := [arena.get_node_or_null("LambsGoalkeeper"), arena.get_node_or_null("PiratesGoalkeeper")]
	for index in keepers.size():
		var keeper := keepers[index] as CharacterBody3D
		if keeper == null or StringName(keeper.get_meta("role", &"")) != &"goalkeeper":
			fail("Each team must have a dedicated goalkeeper role")
			return
		if keeper.get_node_or_null("GoalkeeperHelmet") == null or keeper.get_node_or_null("StickRig") != null:
			fail("Goalkeepers need modeled helmets and must not carry floorball sticks")
			return
		if not keeper.has_method("is_goalkeeper") or not keeper.call("is_goalkeeper"):
			fail("Goalkeepers need a dedicated crease-aware controller")
			return
		if absf(keeper.position.x) < 14.5 or absf(keeper.position.z) > 2.5:
			fail("Goalkeepers must begin kneeling in front of their own goals; position=%s" % keeper.position)
			return
		var rig := keeper.get_node("BodyRig") as Node3D
		if not bool(rig.get_meta("kneeling", false)) or rig.position.y > -0.15:
			fail("Goalkeeper presentation must use a visibly lowered kneeling pose")
			return
	var lamb_keeper := keepers[0] as CharacterBody3D
	var red_players: Array = arena.call("get_team_players", &"red")
	var keeper_index: int = arena.call("get_field_players").find(lamb_keeper)
	ball.set("_control_owner", keeper_index)
	ball.call("_update_human_control_from_possession", -1)
	if ball.call("get_human_control_actor_id") != &"red_gk" or not lamb_keeper.call("is_human_controlled"):
		fail("A Lambs goalkeeper gaining possession must receive human control")
		return
	var selected := false
	for attempt in red_players.size():
		if ball.call("switch_human_player") == &"red_gk":
			selected = true
			break
	if not selected:
		fail("The goalkeeper must be reachable through the SWITCH order")
		return
	var pirate_keeper := keepers[1] as CharacterBody3D
	var pirate_keeper_index: int = arena.call("get_field_players").find(pirate_keeper)
	ball.set("_control_owner", pirate_keeper_index)
	ball.position = pirate_keeper.position + Vector3(-0.8, -0.33, 0.0)
	ball.ball_velocity = Vector3.ZERO
	ball.call("_update_ai_pass", 0.8)
	if ball.call("get_control_owner_actor_id") != &"" or ball.ball_velocity.x >= -5.0:
		fail("An AI goalkeeper must promptly throw or roll the ball back into play; velocity=%s owner=%s" % [ball.ball_velocity, ball.call("get_control_owner_actor_id")])
		return
	print("6v6 goalkeeper roster, presentation and control handoff are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
