extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	root.get_node("OnlineMatch").call("start", &"host", "ABC234", "Test Game")
	var match_scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(match_scene)
	await process_frame
	var arena := match_scene.get_node("Arena")
	var human_by_team := {&"red": 0, &"blue": 0}
	var ai_by_team := {&"red": 0, &"blue": 0}
	for actor in arena.call("get_field_players"):
		var team: StringName = actor.call("get_team")
		if bool(actor.call("is_human_controlled")):
			human_by_team[team] += 1
		else:
			ai_by_team[team] += 1
	if human_by_team[&"red"] != 1 or human_by_team[&"blue"] != 1:
		fail("An online match needs exactly one human-controlled player on each side; got %s" % human_by_team)
		return
	if ai_by_team[&"red"] != 5 or ai_by_team[&"blue"] != 5:
		fail("An online match needs five AI teammates on each side; got %s" % ai_by_team)
		return
	if match_scene.get_node_or_null("OnlineMatchController") == null:
		fail("Online matches must attach their authoritative networking controller")
		return
	var authority_snapshot: Dictionary = match_scene.get_node("OnlineMatchController").call("_capture_snapshot")
	if not authority_snapshot.has("input_ack"):
		fail("Authority snapshots must acknowledge the newest processed guest input")
		return
	if not authority_snapshot.has("host_time_ms") or not authority_snapshot.has("input_echo_ms"):
		fail("Authority snapshots must carry host time and echo guest send-time for packet-age estimation")
		return
	match_scene.queue_free()
	await process_frame
	root.get_node("OnlineMatch").call("stop")

	root.get_node("OnlineMatch").call("start", &"client", "ABC234", "Test Game")
	var client_match := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(client_match)
	await process_frame
	await process_frame
	var client_arena := client_match.get_node("Arena")
	for replicated_actor in client_arena.call("get_field_players"):
		if replicated_actor.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
			fail("Guest replicas must use network smoothing without a second physics-interpolation pass")
			return
	var local_actor: CharacterBody3D = client_arena.call("get_local_human_actor")
	if local_actor == null or local_actor.call("get_team") != &"blue":
		fail("A guest must resolve the Pirates human as its locally controlled player")
		return
	for child_name in ["ControlRing", "AimArrow", "PlayerMarker"]:
		if local_actor.get_node_or_null(child_name) == null:
			fail("The guest-controlled player is missing its %s" % child_name)
			return
	if not local_actor.get_node("ControlRing").visible or not local_actor.get_node("PlayerMarker").visible:
		fail("The guest-controlled player must show its coloured ring and overhead arrow")
		return
	var remote_actor: CharacterBody3D
	for actor in client_arena.call("get_field_players"):
		if actor.call("get_team") == &"red" and bool(actor.call("is_human_controlled")):
			remote_actor = actor
			break
	if remote_actor == null or not remote_actor.get_node("PlayerMarker").visible:
		fail("Guests must see which Lambs player their opponent currently controls")
		return
	if remote_actor.get_node("ControlRing").visible:
		fail("Only the local player should receive the ground control ring")
		return
	var camera_actor: CharacterBody3D = client_arena.call("get_camera_actor", client_arena.get_node("Ball"))
	if camera_actor != local_actor:
		fail("The guest camera must follow the locally controlled Pirates player")
		return
	var client_controller := client_match.get_node("OnlineMatchController")
	var client_ball = client_arena.get_node("Ball")
	client_ball.global_position = Vector3(0.0, 1.0, 0.0)
	client_ball.ball_velocity = Vector3(2.0, 0.0, 0.0)
	client_controller.call("_predict_replicas", 1.0 / 60.0)
	if client_ball.global_position.x <= 0.0 or client_ball.global_position.y >= 1.0:
		fail("A guest must locally simulate loose-ball velocity and gravity between snapshots")
		return
	var goal_snapshot: Dictionary = client_controller.call("_capture_snapshot")
	goal_snapshot.score = {"red": 0, "blue": 1}
	goal_snapshot.goal_seq = 1
	goal_snapshot.scorer = "blue"
	goal_snapshot.phase = "goal"
	goal_snapshot.faceoff_seq = 0
	client_controller.call("_apply_snapshot", goal_snapshot)
	if (client_match.get_node("HUD/MessageLabel") as Label).text != "PIRATES GOAL!" or not (client_match.get_node("HUD/GoalFlash") as ColorRect).visible:
		fail("A guest goal snapshot must show the Pirates goal celebration immediately")
		return
	var faceoff_snapshot: Dictionary = goal_snapshot.duplicate(true)
	faceoff_snapshot.phase = "play"
	faceoff_snapshot.faceoff_seq = 1
	for actor_state: Dictionary in faceoff_snapshot.actors:
		if actor_state.id == String(local_actor.call("get_actor_id")):
			actor_state.p = [-5.0, 0.75, 0.0]
	client_controller.call("_apply_snapshot", faceoff_snapshot)
	if not local_actor.global_position.is_equal_approx(Vector3(-5.0, 0.75, 0.0)):
		fail("A synchronized faceoff must snap deliberately after the celebration instead of drifting through lag correction")
		return
	if not (client_match.get_node("HUD/MessageLabel") as Label).text.is_empty():
		fail("The goal message must clear when the authoritative match returns to play")
		return
	print("Online matches give both host and guest a visible, camera-tracked human player.")
	client_match.queue_free()
	root.get_node("OnlineMatch").call("stop")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
