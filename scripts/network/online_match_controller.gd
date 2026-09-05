class_name OnlineMatchController
extends Node


const TransportScript = preload("res://scripts/network/webrtc_transport.gd")
const OnlineInputScript = preload("res://scripts/network/online_input.gd")
const BallSimulationScript = preload("res://scripts/simulation/ball_simulation.gd")
const StateCodecScript = preload("res://scripts/network/online_state_codec.gd")
const NetworkDiagnosticsScript = preload("res://scripts/network/network_diagnostics.gd")
const PredictedBallActionScript = preload("res://scripts/network/predicted_ball_action.gd")
const StickSlapScript = preload("res://scripts/simulation/stick_slap.gd")
const SquadLogicScript = preload("res://scripts/simulation/squad_logic.gd")
const BallInteractionScript = preload("res://scripts/simulation/ball_interaction.gd")
const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const SNAPSHOT_SECONDS := OnlineInputScript.DEFAULT_SNAPSHOT_SECONDS
const RINK_HALF_LENGTH := 19.1
const RINK_HALF_WIDTH := 9.1

var _transport: FloorballWebRTCTransport
var _arena: Node3D
var _ball: Node3D
var _sequence := 0
var _snapshot_elapsed := 0.0
var _last_snapshot := -1
var _status: Label
var _match_flow: Node
var _mobile_controls: Control
var _pass_sequence := 0
var _switch_sequence := 0
var _last_remote_pass_sequence := 0
var _last_remote_switch_sequence := 0
var _last_faceoff_sequence := -1
var _pending_inputs: Array = []
var _last_remote_input_sent_ms := -1
var _estimated_rtt_ms := 0.0
var _host_clock_offset_ms := 0.0
var _has_clock_offset := false
var _snapshot_age_seconds := 0.0
var _received_snapshots := 0
var _missing_snapshots := 0
var _ball_attached_to_owner := false
var _diagnostics: RefCounted
var _diagnostics_label: Label
var _diagnostics_refresh_elapsed := 0.0
var _latest_player_prediction_error := 0.0
var _latest_ball_prediction_error := 0.0
var _simulation_tick := 0
var _last_captured_owner: StringName = &""
var _possession_sequence := 0
var _last_captured_ball_state: StringName = &"loose"
var _ball_action_sequence := 0
var _ball_action_type: StringName = &""
var _ball_action_tick := 0
var _predicted_ball_action: RefCounted
var _last_authoritative_action_sequence := 0
var _local_shoot_was_pressed := false
var _local_shoot_charge := 0.0
var _predicted_possession_actor_id: StringName = &""
var _predicted_possession_remaining := 0.0
var _remote_rotation_targets: Dictionary = {}


func _ready() -> void:
	_arena = get_parent().get_node("Arena") as Node3D
	_ball = _arena.get_node("Ball") as Node3D
	_match_flow = get_parent().get_node("MatchFlow")
	_mobile_controls = get_parent().get_node_or_null("HUD/MobileControls") as Control
	_status = Label.new()
	_status.position = Vector2(20.0, 20.0)
	_status.add_theme_font_size_override("font_size", 18)
	_status.text = "ONLINE · ROOM %s" % OnlineMatch.room_id
	_status.mouse_filter = Control.MOUSE_FILTER_STOP
	_status.gui_input.connect(_on_status_input)
	get_parent().get_node("HUD").add_child(_status)
	_diagnostics = NetworkDiagnosticsScript.new()
	_diagnostics_label = Label.new()
	_diagnostics_label.name = "Diagnostics"
	_diagnostics_label.position = Vector2(20.0, 48.0)
	_diagnostics_label.add_theme_font_size_override("font_size", 14)
	_diagnostics_label.visible = false
	add_child(_diagnostics_label)
	_transport = TransportScript.new()
	add_child(_transport)
	_transport.status_changed.connect(func(text: String) -> void: _status.text = "ONLINE · %s · %s" % [OnlineMatch.room_id, text])
	_transport.message_received.connect(_on_message)
	_transport.connected.connect(_on_connected)
	_transport.disconnected.connect(_on_disconnected)
	if OnlineMatch.role == &"host":
		_set_authority_waiting(true)
	_transport.start(OnlineMatch.role, OnlineMatch.room_id)
	if OnlineMatch.role == &"client":
		_set_client_replica_mode()


func _exit_tree() -> void:
	if _transport != null:
		_transport.close()


func _on_connected() -> void:
	if OnlineMatch.role == &"host":
		_set_authority_waiting(false)
		_arena.call("reset_squads_for_faceoff")
		_ball.call("reset_for_faceoff")


func _on_disconnected() -> void:
	if OnlineMatch.role == &"host":
		_set_authority_waiting(true)


func _physics_process(delta: float) -> void:
	_simulation_tick += 1
	if Input.is_action_just_pressed("toggle_network_diagnostics"):
		set_diagnostics_visible(not _diagnostics_label.visible)
	_diagnostics.record_frame(delta)
	_diagnostics_refresh_elapsed += delta
	if _diagnostics_refresh_elapsed >= 0.25:
		_diagnostics_refresh_elapsed = 0.0
		_refresh_diagnostics()
	if OnlineMatch.role == &"client":
		_predicted_possession_remaining = maxf(0.0, _predicted_possession_remaining - delta)
		if _predicted_possession_remaining <= 0.0:
			_predicted_possession_actor_id = &""
		_sequence += 1
		var movement := _movement_input()
		var pass_pressed := Input.is_action_just_pressed("pass")
		var shoot_pressed := Input.is_action_pressed("shoot")
		_pass_sequence = OnlineInputScript.next_action_sequence(_pass_sequence, pass_pressed)
		_switch_sequence = OnlineInputScript.next_action_sequence(_switch_sequence, Input.is_action_just_pressed("switch_player"))
		_transport.send({"type": "input", "seq": _sequence, "tick": _simulation_tick, "sent_ms": Time.get_ticks_msec(), "rtt_ms": _estimated_rtt_ms, "move": _vector_to_array(movement), "dash": Input.is_action_pressed("dash"), "shoot": shoot_pressed, "pass_seq": _pass_sequence, "switch_seq": _switch_sequence})
		_record_pending_input(_sequence, movement, delta)
		_predict_local_player(movement, delta)
		_predict_replicas(delta)
		_predict_local_pickup(delta)
		_update_predicted_ball_action(shoot_pressed, pass_pressed, delta)
		return
	_snapshot_elapsed += delta
	if _snapshot_elapsed >= SNAPSHOT_SECONDS:
		_snapshot_elapsed = 0.0
		_sequence += 1
		_transport.send(StateCodecScript.encode_snapshot(_capture_snapshot()))


func _on_message(message: Dictionary) -> void:
	var type := String(message.get("type", ""))
	if OnlineMatch.role == &"host" and type == "input":
		var seq := int(message.get("seq", -1))
		if seq <= _last_snapshot:
			return
		_last_snapshot = seq
		_last_remote_input_sent_ms = int(message.get("sent_ms", -1))
		OnlineMatch.remote_input = _array_to_vector(message.get("move", [0.0, 0.0]))
		OnlineMatch.remote_dash = bool(message.get("dash", false))
		OnlineMatch.remote_shoot = bool(message.get("shoot", false))
		OnlineMatch.remote_rtt_ms = clampf(float(message.get("rtt_ms", 0.0)), 0.0, 500.0)
		var pass_sequence := int(message.get("pass_seq", 0))
		if pass_sequence > _last_remote_pass_sequence:
			_last_remote_pass_sequence = pass_sequence
			OnlineMatch.remote_pass = true
		var switch_sequence := int(message.get("switch_seq", 0))
		if switch_sequence > _last_remote_switch_sequence and _ball.has_method("switch_human_player_for_team"):
			_last_remote_switch_sequence = switch_sequence
			_ball.call("switch_human_player_for_team", &"blue")
	elif OnlineMatch.role == &"client" and type == "snapshot":
		var seq := int(message.get("seq", -1))
		if seq <= _last_snapshot:
			return
		if _last_snapshot >= 0:
			_missing_snapshots += maxi(0, seq - _last_snapshot - 1)
		_received_snapshots += 1
		_last_snapshot = seq
		_diagnostics.record_snapshot_sequence(seq)
		_apply_snapshot(message)
		_update_connection_diagnostics()


func _capture_snapshot() -> Dictionary:
	var actors: Array = []
	for actor in _arena.call("get_field_players"):
		actors.append({"id": String(actor.call("get_actor_id")), "p": _vector3_to_array(actor.global_position), "v": _vector3_to_array(actor.velocity), "r": actor.rotation.y})
	var match_state: Dictionary = _match_flow.call("get_network_state") if _match_flow.has_method("get_network_state") else {}
	var owner_id := String(_ball.call("get_control_owner_actor_id"))
	var slap_phase := StringName(_ball.call("get_slap_phase")) if _ball.has_method("get_slap_phase") else &"idle"
	var owner_name := StringName(owner_id)
	if owner_name != _last_captured_owner:
		_possession_sequence += 1
		_last_captured_owner = owner_name
	var pending_action := StringName(_ball.call("get_pending_action_type")) if _ball.has_method("get_pending_action_type") else &""
	var ball_state: StringName = &"possessed" if not owner_id.is_empty() else (&"passing" if pending_action == &"pass" else &"shot" if pending_action == &"shot" else &"loose")
	if ball_state in [&"passing", &"shot"] and ball_state != _last_captured_ball_state:
		_ball_action_sequence += 1
		_ball_action_type = pending_action
		_ball_action_tick = _simulation_tick
	_last_captured_ball_state = ball_state
	return {"type": "snapshot", "seq": _sequence, "host_time_ms": Time.get_ticks_msec(), "input_ack": _last_snapshot, "input_echo_ms": _last_remote_input_sent_ms, "actors": actors, "ball": _vector3_to_array(_ball.global_position), "ball_velocity": _vector3_to_array(_ball.ball_velocity), "owner": owner_id, "ball_attached": not owner_id.is_empty(), "ball_state": String(ball_state), "possession_seq": _possession_sequence, "action_seq": _ball_action_sequence, "action_type": String(_ball_action_type), "action_tick": _ball_action_tick, "red_human": String(_ball.call("get_human_control_actor_id_for_team", &"red")), "blue_human": String(_ball.call("get_human_control_actor_id_for_team", &"blue")), "score": _match_flow.score.duplicate(), "goal_seq": int(match_state.get("goal_seq", 0)), "faceoff_seq": int(match_state.get("faceoff_seq", 0)), "scorer": String(match_state.get("scorer", "")), "phase": String(match_state.get("phase", "play")), "slap_phase": String(slap_phase)}


func _apply_snapshot(snapshot: Dictionary) -> void:
	_update_snapshot_timing(snapshot)
	var actor_by_id := {}
	var local_actor := _arena.call("get_local_human_actor") as CharacterBody3D
	var faceoff_sequence := int(snapshot.get("faceoff_seq", 0))
	var is_new_faceoff := faceoff_sequence > _last_faceoff_sequence
	_last_faceoff_sequence = maxi(_last_faceoff_sequence, faceoff_sequence)
	_pending_inputs = [] if is_new_faceoff else OnlineInputScript.discard_acknowledged_inputs(_pending_inputs, int(snapshot.get("input_ack", -1)))
	for actor in _arena.call("get_field_players"):
		actor_by_id[String(actor.call("get_actor_id"))] = actor
	for state: Dictionary in snapshot.get("actors", []):
		var actor: CharacterBody3D = actor_by_id.get(String(state.get("id", "")))
		if actor != null:
			var is_local_actor := actor == local_actor
			var actively_steering := is_local_actor and Vector2(actor.velocity.x, actor.velocity.z).length_squared() > 0.01
			var authoritative_position := _array_to_vector3(state.get("p", []))
			var authoritative_velocity := _array_to_vector3(state.get("v", []))
			if is_local_actor and not is_new_faceoff:
				var replayed_state: Dictionary = OnlineInputScript.replay_player_inputs(authoritative_position, authoritative_velocity, _pending_inputs)
				authoritative_position = replayed_state.position
				authoritative_velocity = replayed_state.velocity
				authoritative_position.x = clampf(authoritative_position.x, -RINK_HALF_LENGTH, RINK_HALF_LENGTH)
				authoritative_position.z = clampf(authoritative_position.z, -RINK_HALF_WIDTH, RINK_HALF_WIDTH)
				_latest_player_prediction_error = actor.global_position.distance_to(authoritative_position)
			elif not is_new_faceoff:
				authoritative_position = OnlineInputScript.project_snapshot_position(authoritative_position, authoritative_velocity, _snapshot_age_seconds)
			actor.global_position = authoritative_position if is_new_faceoff else OnlineInputScript.reconcile_position(actor.global_position, authoritative_position, is_local_actor)
			actor.velocity = authoritative_velocity
			var authoritative_rotation := float(state.get("r", actor.rotation.y))
			if is_new_faceoff or is_local_actor:
				var replicated_rotation := authoritative_rotation if is_new_faceoff else OnlineInputScript.reconcile_rotation(actor.rotation.y, authoritative_rotation, true, actively_steering)
				_apply_actor_rotation(actor, replicated_rotation)
			else:
				_remote_rotation_targets[String(actor.call("get_actor_id"))] = authoritative_rotation
	_last_authoritative_action_sequence = maxi(_last_authoritative_action_sequence, int(snapshot.get("action_seq", 0)))
	var ignore_ball_snapshot := false
	if _predicted_ball_action != null and bool(_predicted_ball_action.get("active")):
		if _predicted_ball_action.call("should_accept_snapshot", snapshot):
			_predicted_ball_action.call("finish")
		else:
			ignore_ball_snapshot = float(_predicted_ball_action.get("elapsed")) < 1.5
			if not ignore_ball_snapshot:
				_predicted_ball_action.call("finish")
	var snapshot_owner := StringName(snapshot.get("owner", ""))
	if not _predicted_possession_actor_id.is_empty():
		if snapshot_owner == _predicted_possession_actor_id:
			_predicted_possession_actor_id = &""
			_predicted_possession_remaining = 0.0
		elif snapshot_owner.is_empty() and _predicted_possession_remaining > 0.0:
			ignore_ball_snapshot = true
		else:
			_predicted_possession_actor_id = &""
			_predicted_possession_remaining = 0.0
	if ignore_ball_snapshot:
		_apply_network_score(snapshot)
		return
	_ball_attached_to_owner = bool(snapshot.get("ball_attached", not snapshot_owner.is_empty()))
	if _ball.has_method("apply_network_control_state"):
		_ball.call("apply_network_control_state", snapshot_owner, StringName(snapshot.get("red_human", "red_1")), StringName(snapshot.get("blue_human", "blue_1")))
	var possession := _network_possession(snapshot_owner) if _ball_attached_to_owner else {}
	var authoritative_ball := _array_to_vector3(snapshot.get("ball", []))
	var authoritative_ball_velocity := _array_to_vector3(snapshot.get("ball_velocity", []))
	var local_actor_id := String(local_actor.call("get_actor_id")) if local_actor != null else ""
	if not possession.is_empty():
		authoritative_ball = possession.position
		authoritative_ball_velocity = possession.velocity
	elif not is_new_faceoff and String(snapshot_owner) != local_actor_id:
		var aged_ball: Dictionary = BallSimulationScript.step(authoritative_ball, authoritative_ball_velocity, _snapshot_age_seconds)
		authoritative_ball = aged_ball.position
		authoritative_ball_velocity = aged_ball.velocity
	_latest_ball_prediction_error = _ball.global_position.distance_to(authoritative_ball)
	_diagnostics.record_prediction_error(_latest_player_prediction_error, _latest_ball_prediction_error)
	_ball.global_position = authoritative_ball if is_new_faceoff or not possession.is_empty() else OnlineInputScript.reconcile_ball_position(_ball.global_position, authoritative_ball)
	_ball.ball_velocity = authoritative_ball_velocity
	_apply_network_score(snapshot)


func _apply_network_score(snapshot: Dictionary) -> void:
	var score: Dictionary = snapshot.get("score", {})
	if not score.is_empty() and _match_flow.has_method("apply_network_state"):
		_match_flow.call("apply_network_state", int(score.get("red", 0)), int(score.get("blue", 0)), int(snapshot.get("goal_seq", 0)), StringName(snapshot.get("scorer", "")), StringName(snapshot.get("phase", "play")))
	elif not score.is_empty() and _match_flow.has_method("apply_network_score"):
		_match_flow.call("apply_network_score", int(score.get("red", 0)), int(score.get("blue", 0)))


func _update_predicted_ball_action(shoot_pressed: bool, pass_pressed: bool, delta: float) -> void:
	var actor := _arena.call("get_local_human_actor") as CharacterBody3D
	if actor == null:
		return
	var owns_ball := _ball.has_method("is_controlled_by_actor") and bool(_ball.call("is_controlled_by_actor", actor.call("get_actor_id")))
	if pass_pressed and owns_ball and (_predicted_ball_action == null or not bool(_predicted_ball_action.get("active"))):
		_begin_predicted_ball_action(actor, &"pass", 0.38, false)
	if shoot_pressed and owns_ball and (_predicted_ball_action == null or not bool(_predicted_ball_action.get("active"))):
		_local_shoot_charge = minf(1.6, _local_shoot_charge + delta)
		actor.call("set_shot_aim_locked", true)
		actor.call("set_stick_slap_angle", lerpf(-2.0, StickSlapScript.BACKSWING_ANGLE, pow(minf(1.0, _local_shoot_charge / 0.8), 2.0)))
	elif _local_shoot_was_pressed and _local_shoot_charge > 0.0 and owns_ball:
		_begin_predicted_ball_action(actor, &"shot", _local_shoot_charge / 0.8, true)
		_local_shoot_charge = 0.0
	elif not shoot_pressed:
		_local_shoot_charge = 0.0
	_local_shoot_was_pressed = shoot_pressed
	if _predicted_ball_action == null or not bool(_predicted_ball_action.get("active")):
		return
	var blade := actor.get_node_or_null("StickRig/BladePocket") as Marker3D
	if blade == null:
		return
	blade.force_update_transform()
	var predicted: Dictionary = _predicted_ball_action.call("step", delta, blade.global_position)
	actor.call("set_stick_slap_angle", StickSlapScript.angle_at(float(predicted.elapsed)))
	_ball.global_position = predicted.position
	_ball.ball_velocity = predicted.velocity
	_ball_attached_to_owner = bool(predicted.attached)
	if not _ball_attached_to_owner and _ball.has_method("apply_network_control_state"):
		var red_human := StringName(_ball.call("get_human_control_actor_id_for_team", &"red"))
		var blue_human := StringName(_ball.call("get_human_control_actor_id_for_team", &"blue"))
		_ball.call("apply_network_control_state", &"", red_human, blue_human)


func _begin_predicted_ball_action(actor: CharacterBody3D, action_type: StringName, charge: float, begin_forward_swing: bool) -> void:
	_predicted_ball_action = PredictedBallActionScript.new()
	var direction := Vector2(actor.call("get_facing_direction").x, actor.call("get_facing_direction").z)
	if action_type == &"pass":
		var teammates: Array = []
		for candidate in _arena.call("get_team_players", actor.call("get_team")):
			if StringName(candidate.get_meta("role", &"field")) == &"goalkeeper":
				continue
			teammates.append({"actor_id": candidate.call("get_actor_id"), "position": candidate.global_position})
		var target: Dictionary = SquadLogicScript.forward_teammate(actor.call("get_actor_id"), actor.global_position, actor.call("get_facing_direction"), teammates)
		if not target.is_empty():
			direction = Vector2(target.position.x - actor.global_position.x, target.position.z - actor.global_position.z)
	var blade := actor.get_node_or_null("StickRig/BladePocket") as Marker3D
	var origin := _ball.global_position
	if blade != null:
		blade.force_update_transform()
		origin = blade.global_position
	_predicted_ball_action.call("begin", _last_authoritative_action_sequence + 1, action_type, origin, direction, actor.velocity, charge, begin_forward_swing)


func _predict_local_pickup(_delta: float) -> void:
	if _ball_attached_to_owner or (_predicted_ball_action != null and bool(_predicted_ball_action.get("active"))):
		return
	if _ball.global_position.y > BallInteractionScript.CONTROL_HEIGHT or Vector2(_ball.ball_velocity.x, _ball.ball_velocity.z).length() > BallInteractionScript.MAX_CONTROL_SPEED:
		return
	var actor := _arena.call("get_local_human_actor") as CharacterBody3D
	if actor == null:
		return
	var blade := actor.get_node_or_null("StickRig/BladePocket") as Marker3D
	if blade == null:
		return
	blade.force_update_transform()
	var participant := {"position": actor.global_position, "velocity": actor.velocity, "facing": actor.call("get_facing_direction"), "blade_target": blade.global_position}
	if not BallInteractionScript.is_in_blade_pocket(_ball.global_position, participant):
		return
	_predicted_possession_actor_id = actor.call("get_actor_id")
	_predicted_possession_remaining = 0.40
	_ball_attached_to_owner = true
	_ball.global_position = blade.global_position
	_ball.ball_velocity = actor.velocity
	if _ball.has_method("apply_network_control_state"):
		var red_human := StringName(_ball.call("get_human_control_actor_id_for_team", &"red"))
		var blue_human := StringName(_ball.call("get_human_control_actor_id_for_team", &"blue"))
		_ball.call("apply_network_control_state", _predicted_possession_actor_id, red_human, blue_human)


func _set_client_replica_mode() -> void:
	_ball.set_physics_process(false)
	_ball.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for actor in _arena.call("get_field_players"):
		actor.set_physics_process(false)
		actor.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _update_snapshot_timing(snapshot: Dictionary) -> void:
	var received_at_ms := Time.get_ticks_msec()
	var echoed_input_ms := int(snapshot.get("input_echo_ms", -1))
	if echoed_input_ms >= 0:
		var rtt_sample := maxf(0.0, float(received_at_ms - echoed_input_ms))
		_estimated_rtt_ms = rtt_sample if _estimated_rtt_ms <= 0.0 else lerpf(_estimated_rtt_ms, rtt_sample, 0.15)
		_diagnostics.record_round_trip(rtt_sample)
	var host_time_ms := int(snapshot.get("host_time_ms", received_at_ms))
	var offset_sample := OnlineInputScript.estimate_clock_offset_ms(received_at_ms, host_time_ms, _estimated_rtt_ms)
	_host_clock_offset_ms = offset_sample if not _has_clock_offset else lerpf(_host_clock_offset_ms, offset_sample, 0.1)
	_has_clock_offset = true
	_snapshot_age_seconds = OnlineInputScript.snapshot_age_seconds(received_at_ms, host_time_ms, _host_clock_offset_ms)
	_diagnostics.record_snapshot_age(_snapshot_age_seconds)


func _update_connection_diagnostics() -> void:
	var loss := OnlineInputScript.packet_loss_percent(_received_snapshots, _missing_snapshots)
	_status.text = "ONLINE · %s · %s" % [OnlineMatch.room_id, OnlineInputScript.connection_diagnostic_text(_estimated_rtt_ms, loss)]


func set_diagnostics_visible(is_visible: bool) -> void:
	_diagnostics_label.visible = is_visible
	if is_visible:
		_refresh_diagnostics()


func _on_status_input(event: InputEvent) -> void:
	var activated: bool = false
	if event is InputEventScreenTouch:
		activated = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		activated = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if activated:
		set_diagnostics_visible(not _diagnostics_label.visible)


func _refresh_diagnostics() -> void:
	if _diagnostics_label == null:
		return
	var report: Dictionary = _diagnostics.report()
	_diagnostics_label.text = "FPS %.0f · FRAME %.1f ms\nRTT %.0f ms · JITTER %.1f ms · LOSS %.1f%%\nSNAPSHOT AGE %.1f ms\nPLAYER ERR %.2f m · BALL ERR %.2f m" % [
		float(report.get("fps", 0.0)),
		float(report.get("frame_ms", 0.0)),
		float(report.get("rtt_ms", 0.0)),
		float(report.get("jitter_ms", 0.0)),
		float(report.get("loss_percent", 0.0)),
		float(report.get("snapshot_age_ms", 0.0)),
		float(report.get("player_error_m", 0.0)),
		float(report.get("ball_error_m", 0.0)),
	]


func _set_authority_waiting(waiting: bool) -> void:
	_ball.set_physics_process(not waiting)
	for actor in _arena.call("get_field_players"):
		actor.set_physics_process(not waiting)


func _movement_input() -> Vector2:
	var mobile := Vector2.ZERO
	if _mobile_controls != null and _mobile_controls.has_method("get_movement_vector"):
		mobile = _mobile_controls.call("get_movement_vector")
	return OnlineInputScript.compose_movement_input(Input.get_vector("move_left", "move_right", "move_up", "move_down"), mobile)


func _predict_local_player(movement: Vector2, delta: float) -> void:
	var actor := _arena.call("get_local_human_actor") as CharacterBody3D
	if actor == null:
		return
	var has_ball := _ball.has_method("is_controlled_by_actor") and bool(_ball.call("is_controlled_by_actor", actor.call("get_actor_id")))
	var speed_multiplier := 0.88 if has_ball else 1.0
	var predicted: Dictionary = OnlineInputScript.predict_player_state(actor.global_position, actor.velocity, movement, delta, speed_multiplier)
	predicted.position.x = clampf(predicted.position.x, -RINK_HALF_LENGTH, RINK_HALF_LENGTH)
	predicted.position.z = clampf(predicted.position.z, -RINK_HALF_WIDTH, RINK_HALF_WIDTH)
	actor.global_position = predicted.position
	actor.velocity = predicted.velocity
	if not movement.is_zero_approx():
		var predicted_rotation := PlayerMotorScript.step_facing_rotation(actor.rotation.y, movement, delta)
		if actor.has_method("apply_network_rotation"):
			actor.call("apply_network_rotation", predicted_rotation)
		else:
			actor.rotation.y = predicted_rotation


func _record_pending_input(sequence: int, movement: Vector2, delta: float) -> void:
	var actor := _arena.call("get_local_human_actor") as CharacterBody3D
	var has_ball := actor != null and _ball.has_method("is_controlled_by_actor") and bool(_ball.call("is_controlled_by_actor", actor.call("get_actor_id")))
	_pending_inputs.append({"seq": sequence, "move": movement, "delta": delta, "speed_multiplier": 0.88 if has_ball else 1.0})
	if _pending_inputs.size() > 120:
		_pending_inputs.pop_front()


func _predict_replicas(delta: float) -> void:
	var local_actor := _arena.call("get_local_human_actor") as CharacterBody3D
	for actor in _arena.call("get_field_players"):
		if actor == local_actor:
			continue
		var predicted: Vector3 = OnlineInputScript.predict_replica_position(actor.global_position, actor.velocity, delta)
		predicted.x = clampf(predicted.x, -RINK_HALF_LENGTH, RINK_HALF_LENGTH)
		predicted.z = clampf(predicted.z, -RINK_HALF_WIDTH, RINK_HALF_WIDTH)
		actor.global_position = predicted
		var actor_id := String(actor.call("get_actor_id"))
		if _remote_rotation_targets.has(actor_id):
			_apply_actor_rotation(actor, OnlineInputScript.interpolate_remote_rotation(actor.rotation.y, float(_remote_rotation_targets[actor_id]), delta))
	var owner_id := StringName(_ball.call("get_control_owner_actor_id")) if _ball.has_method("get_control_owner_actor_id") else &""
	var possession := _network_possession(owner_id) if _ball_attached_to_owner else {}
	if not possession.is_empty():
		_ball.global_position = possession.position
		_ball.ball_velocity = possession.velocity
	else:
		var prediction_delta := clampf(delta, 0.0, OnlineInputScript.MAX_REPLICA_PREDICTION_STEP)
		var predicted_ball: Dictionary = BallSimulationScript.step(_ball.global_position, _ball.ball_velocity, prediction_delta)
		_ball.global_position = predicted_ball.position
		_ball.ball_velocity = predicted_ball.velocity


func _network_possession(owner_id: StringName) -> Dictionary:
	if owner_id.is_empty():
		return {}
	for actor in _arena.call("get_field_players"):
		if actor.call("get_actor_id") != owner_id:
			continue
		var blade_pocket := actor.get_node_or_null("StickRig/BladePocket") as Marker3D
		if blade_pocket == null:
			return {}
		blade_pocket.force_update_transform()
		return {"position": blade_pocket.global_position, "velocity": actor.velocity}
	return {}


func _vector_to_array(value: Vector2) -> Array:
	return [value.x, value.y]


func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _array_to_vector(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else Vector2.ZERO


func _array_to_vector3(value: Variant) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) if value is Array and value.size() >= 3 else Vector3.ZERO


func _apply_actor_rotation(actor: CharacterBody3D, rotation_y: float) -> void:
	if actor.has_method("apply_network_rotation"):
		actor.call("apply_network_rotation", rotation_y)
	else:
		actor.rotation.y = rotation_y
