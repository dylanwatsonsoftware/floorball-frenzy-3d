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
	var authority_controller := match_scene.get_node("OnlineMatchController")
	authority_controller.call("_set_authority_waiting", false)
	var authority_snapshot: Dictionary = authority_controller.call("_capture_snapshot")
	if not authority_snapshot.has("input_ack"):
		fail("Authority snapshots must acknowledge the newest processed guest input")
		return
	var received_command := {"type": "input", "seq": 77, "tick": 240, "sent_ms": Time.get_ticks_msec(), "rtt_ms": 80.0, "move": [1.0, 0.0], "facing": [1.0, 0.0], "dash_seq": 0, "shoot": false, "pass_seq": 0, "switch_seq": 0}
	authority_controller.call("_on_message", received_command)
	var received_but_unsimulated: Dictionary = authority_controller.call("_capture_snapshot")
	if int(received_but_unsimulated.input_ack) >= 77:
		fail("The host must not acknowledge a guest command merely because the network layer received it")
		return
	await process_frame
	var simulated_snapshot: Dictionary = authority_controller.call("_capture_snapshot")
	if int(simulated_snapshot.input_ack) != 77:
		fail("The authoritative player step must acknowledge the exact guest command it simulated; got %s" % simulated_snapshot.input_ack)
		return
	if not authority_snapshot.has("host_time_ms") or not authority_snapshot.has("input_echo_ms"):
		fail("Authority snapshots must carry host time and echo guest send-time for packet-age estimation")
		return
	var authority_action_actor: CharacterBody3D = arena.call("get_field_players")[0]
	authority_action_actor.call("set_stick_slap_angle", 32.0)
	authority_snapshot = match_scene.get_node("OnlineMatchController").call("_capture_snapshot")
	if authority_snapshot.get("stick_angles", []).size() != authority_snapshot.actors.size() or not is_equal_approx(float(authority_snapshot.stick_angles[0]), 32.0):
		fail("Authority snapshots must include every player's current stick/torso action pose")
		return
	authority_action_actor.call("set_stick_slap_angle", 0.0)
	match_scene.queue_free()
	await process_frame
	root.get_node("OnlineMatch").call("stop")

	root.get_node("OnlineMatch").call("start", &"client", "ABC234", "Test Game")
	var client_match := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(client_match)
	await process_frame
	await process_frame
	var client_arena := client_match.get_node("Arena")
	var client_controller := client_match.get_node("OnlineMatchController")
	for replicated_actor in client_arena.call("get_field_players"):
		if replicated_actor.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
			fail("Guest replicas must use network smoothing without a second physics-interpolation pass")
			return
	var local_actor: CharacterBody3D = client_arena.call("get_local_human_actor")
	if local_actor == null or local_actor.call("get_team") != &"blue":
		fail("A guest must resolve the Pirates human as its locally controlled player")
		return
	var dash_start: Vector3 = local_actor.global_position
	client_controller.call("_predict_local_player", Vector2.RIGHT, 1.0 / 60.0, true)
	if local_actor.velocity.length() < 14.99 or local_actor.global_position.x <= dash_start.x + 0.20 or not bool(local_actor.call("is_dashing")):
		fail("A guest dash must move its local player immediately instead of waiting for host acknowledgement; position=%s velocity=%s" % [local_actor.global_position, local_actor.velocity])
		return
	local_actor.call("apply_network_dash_state", 0.0, 0.0, Vector3.RIGHT)
	local_actor.global_position = dash_start
	local_actor.velocity = Vector3.ZERO
	client_controller.set("_local_prediction_state", {})
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
	remote_actor.call("apply_network_rotation", PI * 0.5)
	var replicated_facing: Vector3 = remote_actor.call("get_facing_direction")
	if replicated_facing.dot(Vector3.RIGHT) < 0.99:
		fail("Applying a replicated rotation must update the remote actor's gameplay and visual facing together; got %s" % replicated_facing)
		return
	if remote_actor.get_node("ControlRing").visible:
		fail("Only the local player should receive the ground control ring")
		return
	var remote_pose_snapshot: Dictionary = client_controller.call("_capture_snapshot")
	remote_pose_snapshot.stick_angles = []
	for actor_state: Dictionary in remote_pose_snapshot.actors:
		remote_pose_snapshot.stick_angles.append(38.0 if actor_state.id == String(remote_actor.call("get_actor_id")) else 0.0)
	client_controller.call("_apply_snapshot", remote_pose_snapshot)
	if not is_equal_approx(float(remote_actor.get_meta("stick_slap_angle", 0.0)), 38.0) or absf((remote_actor.get_node("BodyRig") as Node3D).rotation.y) < 0.1:
		fail("A guest must render the replicated opponent stick swing and torso twist")
		return
	var camera_actor: CharacterBody3D = client_arena.call("get_camera_actor", client_arena.get_node("Ball"))
	if camera_actor != local_actor:
		fail("The guest camera must follow the locally controlled Pirates player")
		return
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
	if not diagnostics_label.visible or not diagnostics_label.text.contains("FPS") or not diagnostics_label.text.contains("PLAYER ERR") or not diagnostics_label.text.contains("INPUT ACK") or not diagnostics_label.text.contains("PATH") or not diagnostics_label.text.contains("TAP TO EXPORT TRACE"):
		fail("The diagnostics overlay must expose frame and prediction measurements when enabled")
		return
	var trace_json: String = client_controller.call("_trace_json")
	var trace_document = JSON.parse_string(trace_json)
	if not trace_document is Dictionary or String(trace_document.get("format", "")) != "floorball-network-trace" or (trace_document.get("entries", []) as Array).is_empty():
		fail("The guest diagnostics panel must retain portable authoritative snapshots for one-tap export")
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
	if client_ball.get_parent() != client_arena:
		fail("A possessed replica ball must remain in rink space so owner rotation cannot orbit it around the player")
		return
	remote_actor.velocity = Vector3.ZERO
	client_ball.global_position = remote_blade_pocket.global_position + Vector3(1.0, 0.0, 0.0)
	var pre_follow_position: Vector3 = client_ball.global_position
	client_controller.call("_predict_replicas", 1.0 / 60.0)
	if client_ball.global_position.distance_to(pre_follow_position) > 0.21:
		fail("A possessed replica must approach its owner's blade without a one-frame teleport")
		return
	for follow_frame in 29:
		client_controller.call("_predict_replicas", 1.0 / 60.0)
	remote_blade_pocket.force_update_transform()
	if client_ball.global_position.distance_to(remote_blade_pocket.global_position) > 0.05:
		fail("A possessed guest replica ball must settle onto its authoritative owner's blade")
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
	var alternate_red_human: CharacterBody3D
	for candidate in client_arena.call("get_field_players"):
		if candidate.call("get_team") == &"red" and candidate != remote_actor:
			alternate_red_human = candidate
			break
	local_possession_snapshot.red_human = String(alternate_red_human.call("get_actor_id"))
	client_controller.call("_apply_snapshot", local_possession_snapshot)
	for local_follow_frame in 60:
		client_controller.call("_predict_replicas", 1.0 / 60.0)
	await process_frame
	if not bool(local_actor.call("is_human_controlled")) or not local_actor.get_node("PlayerMarker").visible or not local_actor.get_node("ControlRing").visible:
		fail("Guest possession attachment must not make the selected player lose its human-control markers")
		return
	client_controller.call("_update_predicted_ball_action", true, false, 0.2)
	if not local_actor.get_node("AimArrow").visible:
		fail("Charging a guest shot must immediately show the local aiming arrow without waiting for the host")
		return
	client_controller.set("_local_shoot_was_pressed", false)
	client_controller.set("_local_shoot_charge", 0.0)
	client_ball.call("_hide_aim_arrow")
	local_actor.call("set_stick_slap_angle", 0.0)
	var local_blade_pocket := local_actor.get_node("StickRig/BladePocket") as Marker3D
	var local_ball_start: Vector3 = client_ball.global_position
	client_controller.call("_predict_local_player", Vector2.RIGHT, 0.1)
	client_controller.call("_predict_replicas", 0.1)
	local_blade_pocket.force_update_transform()
	if client_ball.global_position.x <= local_ball_start.x:
		fail("The guest-owned ball must begin following the guest's locally predicted blade immediately")
		return
	for local_movement_follow_frame in 20:
		client_controller.call("_predict_replicas", 1.0 / 60.0)
	local_blade_pocket.force_update_transform()
	if client_ball.global_position.distance_to(local_blade_pocket.global_position) > 0.05:
		fail("The guest-owned ball must settle onto the locally predicted blade without snapping")
		return
	client_controller.call("_begin_predicted_ball_action", local_actor, &"pass", 0.38, false)
	for action_step in 3:
		client_controller.call("_update_predicted_ball_action", false, false, 0.11)
	if client_ball.ball_velocity.length() < 7.5 or client_ball.call("get_control_owner_actor_id") != &"":
		fail("A guest pass must release from the blade locally before its host round trip; velocity=%s owner=%s parent=%s" % [client_ball.ball_velocity, client_ball.call("get_control_owner_actor_id"), client_ball.get_parent().name])
		return
	if client_ball.call("get_human_control_actor_id_for_team", &"red") != alternate_red_human.call("get_actor_id"):
		fail("A guest's predicted pass must preserve the authoritative opponent selection instead of temporarily jumping to red_1")
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
	if client_ball.get_parent() != client_arena:
		fail("A released replica ball must return to the arena before loose-ball prediction")
		return
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
	client_controller.call("_predict_local_player", Vector2.RIGHT, 1.0 / 60.0, true)
	for actor_state: Dictionary in faceoff_snapshot.actors:
		if actor_state.id == String(local_actor.call("get_actor_id")):
			actor_state.p = [-5.0, 0.75, 0.0]
	client_controller.call("_apply_snapshot", faceoff_snapshot)
	if not local_actor.global_position.is_equal_approx(Vector3(-5.0, 0.75, 0.0)):
		fail("A synchronized faceoff must snap deliberately after the celebration instead of drifting through lag correction")
		return
	if bool(local_actor.call("is_dashing")):
		fail("A synchronized faceoff must clear outstanding predicted dash state")
		return
	if not (client_match.get_node("HUD/MessageLabel") as Label).text.is_empty():
		fail("The goal message must clear when the authoritative match returns to play")
		return
	var selected_before_switch: StringName = client_ball.call("get_human_control_actor_id_for_team", &"blue")
	client_controller.call("_predict_local_switch", 500)
	var selected_after_switch: StringName = client_ball.call("get_human_control_actor_id_for_team", &"blue")
	if selected_after_switch == selected_before_switch:
		fail("Guest switch input must select the next player locally instead of waiting for a round trip")
		return
	var stale_switch_snapshot: Dictionary = faceoff_snapshot.duplicate(true)
	stale_switch_snapshot.input_ack = 499
	stale_switch_snapshot.blue_human = String(selected_before_switch)
	client_controller.call("_apply_snapshot", stale_switch_snapshot)
	if client_ball.call("get_human_control_actor_id_for_team", &"blue") != selected_after_switch:
		fail("A snapshot older than the guest switch input must not toggle control back to the previous player")
		return
	await process_frame
	var switched_actor: CharacterBody3D
	for candidate in client_arena.call("get_team_players", &"blue"):
		if candidate.call("get_actor_id") == selected_after_switch:
			switched_actor = candidate
			break
	if switched_actor == null or not switched_actor.get_node("PlayerMarker").visible or not switched_actor.get_node("ControlRing").visible:
		fail("The locally switched guest player must immediately receive its arrow and control ring")
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
