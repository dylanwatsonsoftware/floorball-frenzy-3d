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
	var diagnostics_label := client_controller.get_node_or_null("Diagnostics") as Label
	if diagnostics_label == null:
		fail("Online matches need an optional diagnostics overlay for measuring guest prediction")
		return
	if not InputMap.has_action("toggle_network_diagnostics"):
		fail("Developers need an input action to toggle online diagnostics on real devices")
		return
	client_controller.call("set_diagnostics_visible", false)
	var diagnostic_tap := InputEventScreenTouch.new()
	diagnostic_tap.pressed = true
	client_controller.call("_on_status_input", diagnostic_tap)
	if not diagnostics_label.visible:
		fail("Tapping online status must reveal diagnostics on touch-only devices")
		return
	client_controller.call("set_diagnostics_visible", true)
	client_controller.call("_refresh_diagnostics")
	if not diagnostics_label.visible or not diagnostics_label.text.contains("FPS") or not diagnostics_label.text.contains("PLAYER ERR"):
		fail("The diagnostics overlay must expose frame and prediction measurements when enabled")
		return
	var client_ball = client_arena.get_node("Ball")
	var pickup_blade := local_actor.get_node("StickRig/BladePocket") as Marker3D
	pickup_blade.force_update_transform()
	client_ball.global_position = Vector3(pickup_blade.global_position.x, 0.22, pickup_blade.global_position.z)
	client_ball.ball_velocity = Vector3.ZERO
	client_ball.call("apply_network_control_state", &"", &"red_1", local_actor.call("get_actor_id"))
	client_controller.call("_predict_local_pickup", 1.0 / 60.0)
	if client_ball.call("get_control_owner_actor_id") != local_actor.call("get_actor_id") or client_ball.global_position.distance_to(pickup_blade.global_position) > 0.05:
		fail("A guest must predict an eligible local blade pickup instead of waiting for a host round trip")
		return
	var possessed_snapshot: Dictionary = client_controller.call("_capture_snapshot")
	possessed_snapshot.owner = String(remote_actor.call("get_actor_id"))
	possessed_snapshot.ball_attached = true
	possessed_snapshot.ball = [18.0, 0.22, 8.0]
	possessed_snapshot.ball_velocity = [20.0, 0.0, 0.0]
	client_controller.call("_apply_snapshot", possessed_snapshot)
	var remote_blade_pocket := remote_actor.get_node("StickRig/BladePocket") as Marker3D
	remote_blade_pocket.force_update_transform()
	if client_ball.global_position.distance_to(remote_blade_pocket.global_position) > 0.05:
		fail("A possessed guest replica ball must attach to its authoritative owner's blade instead of reconciling stale ball coordinates")
		return
	var previous_possessed_ball_position: Vector3 = client_ball.global_position
	remote_actor.velocity = Vector3(4.0, 0.0, 0.0)
	client_controller.call("_predict_replicas", 1.0 / 60.0)
	remote_blade_pocket.force_update_transform()
	if client_ball.global_position.distance_to(remote_blade_pocket.global_position) > 0.05 or client_ball.global_position.x <= previous_possessed_ball_position.x:
		fail("A possessed replica ball must follow its owner's predicted blade between snapshots")
		return
	var local_possession_snapshot: Dictionary = possessed_snapshot.duplicate(true)
	local_possession_snapshot.owner = String(local_actor.call("get_actor_id"))
	local_possession_snapshot.blue_human = String(local_actor.call("get_actor_id"))
	client_controller.call("_apply_snapshot", local_possession_snapshot)
	var local_blade_pocket := local_actor.get_node("StickRig/BladePocket") as Marker3D
	var local_ball_start: Vector3 = client_ball.global_position
	client_controller.call("_predict_local_player", Vector2.RIGHT, 0.1)
	client_controller.call("_predict_replicas", 0.1)
	local_blade_pocket.force_update_transform()
	if client_ball.global_position.distance_to(local_blade_pocket.global_position) > 0.05 or client_ball.global_position.x <= local_ball_start.x:
		fail("The guest-owned ball must follow the guest's locally predicted blade immediately")
		return
	client_controller.call("_begin_predicted_ball_action", local_actor, &"pass", 0.38, false)
	for action_step in 3:
		client_controller.call("_update_predicted_ball_action", false, false, 0.11)
	if client_ball.ball_velocity.length() < 7.5 or client_ball.call("get_control_owner_actor_id") != &"":
		fail("A guest pass must release from the blade locally before its host round trip")
		return
	var predicted_pass_position: Vector3 = client_ball.global_position
	var stale_possession_snapshot: Dictionary = local_possession_snapshot.duplicate(true)
	stale_possession_snapshot.action_seq = 0
	stale_possession_snapshot.ball_state = "possessed"
	client_controller.call("_apply_snapshot", stale_possession_snapshot)
	if client_ball.global_position.distance_to(predicted_pass_position) > 0.01:
		fail("A stale possession snapshot must not pull a locally predicted guest pass back onto the stick")
		return
	var released_snapshot: Dictionary = local_possession_snapshot.duplicate(true)
	released_snapshot.owner = ""
	released_snapshot.ball_attached = false
	released_snapshot.ball_state = "passing"
	released_snapshot.action_seq = 1
	released_snapshot.action_type = "pass"
	released_snapshot.ball = _vector3_array(client_ball.global_position)
	released_snapshot.ball_velocity = [8.0, 0.18, 0.0]
	client_controller.call("_apply_snapshot", released_snapshot)
	var release_start: Vector3 = client_ball.global_position
	client_controller.call("_predict_replicas", 1.0 / 60.0)
	if client_ball.global_position.x <= release_start.x:
		fail("A released guest ball must resume local pass/shot movement immediately")
		return
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


func _vector3_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
