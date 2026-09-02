extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	if not arena.has_method("get_field_players"):
		fail("The arena must expose its 6v6 roster")
		return
	var players: Array = arena.call("get_field_players")
	if players.size() != 12:
		fail("A local match must contain twelve players; got %d" % players.size())
		return
	var teams := {&"red": 0, &"blue": 0}
	var ids := {}
	for actor in players:
		if not actor.has_method("get_team") or not actor.has_method("get_actor_id"):
			fail("Every field player must expose stable team and actor identity")
			return
		if StringName(actor.get_meta("role", &"field")) != &"goalkeeper" and (not actor.has_method("set_shot_aim_locked") or not actor.has_method("set_stick_slap_angle")):
			fail("Every field-player controller must support the complete AI shot animation contract: %s" % actor.name)
			return
		var team: StringName = actor.call("get_team")
		var actor_id: StringName = actor.call("get_actor_id")
		teams[team] += 1
		ids[actor_id] = true
	if teams.red != 6 or teams.blue != 6 or ids.size() != 12:
		fail("The roster must have six uniquely identified players per team; teams=%s ids=%s" % [teams, ids])
		return
	var initial_humans := []
	for actor in players:
		if actor.has_method("is_human_controlled") and actor.call("is_human_controlled"):
			initial_humans.append(actor.call("get_actor_id"))
	if initial_humans.size() != 1 or initial_humans[0] != &"red_1":
		fail("A new match must begin with exactly the Lambs captain under player control; humans=%s" % initial_humans)
		return

	var ball := scene.get_node("Arena/Ball")
	var red_two := scene.get_node("Arena/RedTeammate2") as CharacterBody3D
	for actor in players:
		actor.set_physics_process(false)
	red_two.position = Vector3(-2.0, 0.75, 0.0)
	red_two.velocity = Vector3.ZERO
	var red_two_pocket := red_two.get_node("StickRig/BladePocket") as Marker3D
	ball.position = Vector3(red_two_pocket.global_position.x, 0.22, red_two_pocket.global_position.z)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	if not ball.has_method("is_controlled_by_actor") or not ball.call("is_controlled_by_actor", &"red_2"):
		fail("Ball ownership must identify the individual squad player carrying it")
		return
	if not red_two.call("is_human_controlled") or scene.get_node("Arena/Player").call("is_human_controlled"):
		fail("Human control must switch to red_2 alone when red_2 gains possession")
		return
	var captain := scene.get_node("Arena/Player") as CharacterBody3D
	captain.set_physics_process(true)
	await physics_frame
	captain.set_physics_process(false)
	red_two.set_physics_process(true)
	if not red_two.has_method("try_dash") or not red_two.has_method("is_dashing"):
		fail("Every red player that can receive control must expose the core dash movement")
		return
	var dash_start: Vector3 = red_two.position
	if not red_two.call("try_dash", Vector2.DOWN):
		fail("A newly controlled support player must be able to start a ready dash")
		return
	for frame in 8:
		await physics_frame
	if red_two.position.distance_to(dash_start) < 1.2:
		fail("Support-player dash must create a real sustained movement burst; displacement=%s" % red_two.position.distance_to(dash_start))
		return
	await physics_frame
	var carrier_ring := red_two.get_node_or_null("ControlRing") as MeshInstance3D
	var captain_ring := scene.get_node_or_null("Arena/Player/ControlRing") as MeshInstance3D
	if carrier_ring == null or captain_ring == null or not carrier_ring.visible or captain_ring.visible:
		fail("The active red carrier must have a clear control indicator that follows possession")
		return
	var controlled_start_z: float = red_two.position.z
	Input.action_press("move_down")
	for frame in 10:
		await physics_frame
	Input.action_release("move_down")
	if red_two.position.z <= controlled_start_z + 0.08:
		fail("Movement input must drive the red ball carrier instead of its off-ball AI; start=%s end=%s" % [controlled_start_z, red_two.position.z])
		return
	var carrier_stick := red_two.get_node("StickRig") as Node3D
	var captain_stick := scene.get_node("Arena/Player/StickRig") as Node3D
	var carrier_arrow := red_two.get_node_or_null("AimArrow") as Node3D
	var captain_arrow := scene.get_node_or_null("Arena/Player/AimArrow") as Node3D
	if carrier_arrow == null or captain_arrow == null:
		fail("Every potentially controlled red player must have charged-shot arrow geometry")
		return
	var carrier_rest_angle := carrier_stick.rotation.y
	var captain_rest_angle := captain_stick.rotation.y
	red_two_pocket.force_update_transform()
	ball.position = Vector3(red_two_pocket.global_position.x, 0.22, red_two_pocket.global_position.z)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	Input.action_press("shoot")
	await physics_frame
	var early_shaft := carrier_arrow.get_node("Shaft") as MeshInstance3D
	var early_length: float = (early_shaft.mesh as BoxMesh).size.z
	for frame in 24:
		await physics_frame
	var charged_length: float = (early_shaft.mesh as BoxMesh).size.z
	var arrow_material := early_shaft.material_override as StandardMaterial3D
	if is_equal_approx(carrier_stick.rotation.y, carrier_rest_angle) or not is_equal_approx(captain_stick.rotation.y, captain_rest_angle):
		Input.action_release("shoot")
		fail("Shot input must animate the current red ball carrier's stick, not the original captain; carrier=%s rest=%s captain=%s rest=%s" % [carrier_stick.rotation.y, carrier_rest_angle, captain_stick.rotation.y, captain_rest_angle])
		return
	Input.action_release("shoot")
	await physics_frame
	if charged_length <= early_length + 0.5 or arrow_material.albedo_color.r <= arrow_material.albedo_color.g:
		fail("The active carrier's arrow must visibly lengthen and warm toward red while charging")
		return
	if carrier_arrow.visible or captain_arrow.visible:
		fail("Aiming arrows must hide immediately when the shot is released")
		return
	Input.action_release("shoot")
	ball.call("reset_for_faceoff")
	var blue_two := scene.get_node("Arena/BlueTeammate2") as CharacterBody3D
	blue_two.set_physics_process(false)
	blue_two.position = Vector3(2.0, 0.75, 0.0)
	var blue_two_blade := blue_two.get_node("StickRig/Blade") as MeshInstance3D
	var blue_two_blade_center := (blue_two.get_node("StickRig/BladePocket") as Marker3D).global_position
	ball.position = Vector3(blue_two_blade_center.x, 0.22, blue_two_blade_center.z)
	ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	if not ball.call("is_controlled_by_actor", &"blue_2"):
		fail("AI passing setup must begin with blue_2 possession; ball=%s blade=%s facing=%s owner=%s" % [ball.global_position, blue_two_blade_center, blue_two.call("get_facing_direction"), ball.call("get_control_owner_actor_id")])
		return
	blue_two.set_physics_process(true)
	scene.get_node("Arena/Player").position = Vector3(1.2, 0.75, 0.1)
	ball.call("_update_ai_pass", 1.0)
	if ball.call("is_controlled_by_actor", &"blue_2") or Vector2(ball.ball_velocity.x, ball.ball_velocity.z).length() < 7.0:
		fail("A pressured blue carrier must release a real catchable pass to team support; velocity=%s" % ball.ball_velocity)
		return
	red_two.position = Vector3.ZERO
	scene.get_node("Arena/BlueTeammate3").position = Vector3.ZERO
	scene.get_node("MatchFlow").call("_reset_faceoff")
	if not red_two.position.is_equal_approx(Vector3(-7.0, 0.75, -4.0)) or not scene.get_node("Arena/BlueTeammate3").position.is_equal_approx(Vector3(7.0, 0.75, 4.0)):
		fail("Every squad player must return to a distinct formation position after a goal")
		return

	print("6v6 scene roster and loose-ball control state are valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
