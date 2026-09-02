class_name OnlineMatchController
extends Node


const TransportScript = preload("res://scripts/network/webrtc_transport.gd")
const OnlineInputScript = preload("res://scripts/network/online_input.gd")
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


func _ready() -> void:
	_arena = get_parent().get_node("Arena") as Node3D
	_ball = _arena.get_node("Ball") as Node3D
	_match_flow = get_parent().get_node("MatchFlow")
	_mobile_controls = get_parent().get_node_or_null("HUD/MobileControls") as Control
	_status = Label.new()
	_status.position = Vector2(20.0, 20.0)
	_status.add_theme_font_size_override("font_size", 18)
	_status.text = "ONLINE · ROOM %s" % OnlineMatch.room_id
	get_parent().get_node("HUD").add_child(_status)
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
	if OnlineMatch.role == &"client":
		_sequence += 1
		var movement := _movement_input()
		_pass_sequence = OnlineInputScript.next_action_sequence(_pass_sequence, Input.is_action_just_pressed("pass"))
		_switch_sequence = OnlineInputScript.next_action_sequence(_switch_sequence, Input.is_action_just_pressed("switch_player"))
		_transport.send({"type": "input", "seq": _sequence, "move": _vector_to_array(movement), "dash": Input.is_action_pressed("dash"), "shoot": Input.is_action_pressed("shoot"), "pass_seq": _pass_sequence, "switch_seq": _switch_sequence})
		_predict_local_player(movement, delta)
		return
	_snapshot_elapsed += delta
	if _snapshot_elapsed >= SNAPSHOT_SECONDS:
		_snapshot_elapsed = 0.0
		_sequence += 1
		_transport.send(_capture_snapshot())


func _on_message(message: Dictionary) -> void:
	var type := String(message.get("type", ""))
	if OnlineMatch.role == &"host" and type == "input":
		var seq := int(message.get("seq", -1))
		if seq <= _last_snapshot:
			return
		_last_snapshot = seq
		OnlineMatch.remote_input = _array_to_vector(message.get("move", [0.0, 0.0]))
		OnlineMatch.remote_dash = bool(message.get("dash", false))
		OnlineMatch.remote_shoot = bool(message.get("shoot", false))
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
		_last_snapshot = seq
		_apply_snapshot(message)


func _capture_snapshot() -> Dictionary:
	var actors: Array = []
	for actor in _arena.call("get_field_players"):
		actors.append({"id": String(actor.call("get_actor_id")), "p": _vector3_to_array(actor.global_position), "v": _vector3_to_array(actor.velocity), "r": actor.rotation.y})
	var match_state: Dictionary = _match_flow.call("get_network_state") if _match_flow.has_method("get_network_state") else {}
	return {"type": "snapshot", "seq": _sequence, "actors": actors, "ball": _vector3_to_array(_ball.global_position), "ball_velocity": _vector3_to_array(_ball.ball_velocity), "owner": String(_ball.call("get_control_owner_actor_id")), "red_human": String(_ball.call("get_human_control_actor_id_for_team", &"red")), "blue_human": String(_ball.call("get_human_control_actor_id_for_team", &"blue")), "score": _match_flow.score.duplicate(), "goal_seq": int(match_state.get("goal_seq", 0)), "faceoff_seq": int(match_state.get("faceoff_seq", 0)), "scorer": String(match_state.get("scorer", "")), "phase": String(match_state.get("phase", "play"))}


func _apply_snapshot(snapshot: Dictionary) -> void:
	var actor_by_id := {}
	var local_actor := _arena.call("get_local_human_actor") as CharacterBody3D
	var faceoff_sequence := int(snapshot.get("faceoff_seq", 0))
	var is_new_faceoff := faceoff_sequence > _last_faceoff_sequence
	_last_faceoff_sequence = maxi(_last_faceoff_sequence, faceoff_sequence)
	for actor in _arena.call("get_field_players"):
		actor_by_id[String(actor.call("get_actor_id"))] = actor
	for state: Dictionary in snapshot.get("actors", []):
		var actor: CharacterBody3D = actor_by_id.get(String(state.get("id", "")))
		if actor != null:
			var authoritative_position := _array_to_vector3(state.get("p", []))
			actor.global_position = authoritative_position if is_new_faceoff else OnlineInputScript.reconcile_position(actor.global_position, authoritative_position, actor == local_actor)
			actor.velocity = _array_to_vector3(state.get("v", []))
			actor.rotation.y = float(state.get("r", actor.rotation.y)) if is_new_faceoff else lerp_angle(actor.rotation.y, float(state.get("r", actor.rotation.y)), 0.55)
	var authoritative_ball := _array_to_vector3(snapshot.get("ball", []))
	_ball.global_position = authoritative_ball if is_new_faceoff else _ball.global_position.lerp(authoritative_ball, 0.65)
	_ball.ball_velocity = _array_to_vector3(snapshot.get("ball_velocity", []))
	if _ball.has_method("apply_network_control_state"):
		_ball.call("apply_network_control_state", StringName(snapshot.get("owner", "")), StringName(snapshot.get("red_human", "red_1")), StringName(snapshot.get("blue_human", "blue_1")))
	var score: Dictionary = snapshot.get("score", {})
	if not score.is_empty() and _match_flow.has_method("apply_network_state"):
		_match_flow.call("apply_network_state", int(score.get("red", 0)), int(score.get("blue", 0)), int(snapshot.get("goal_seq", 0)), StringName(snapshot.get("scorer", "")), StringName(snapshot.get("phase", "play")))
	elif not score.is_empty() and _match_flow.has_method("apply_network_score"):
		_match_flow.call("apply_network_score", int(score.get("red", 0)), int(score.get("blue", 0)))


func _set_client_replica_mode() -> void:
	_ball.set_physics_process(false)
	for actor in _arena.call("get_field_players"):
		actor.set_physics_process(false)


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
	var prediction_speed: float = OnlineInputScript.prediction_speed(has_ball)
	var previous_position := actor.global_position
	var predicted := OnlineInputScript.predict_position(previous_position, movement, delta, prediction_speed)
	predicted.x = clampf(predicted.x, -RINK_HALF_LENGTH, RINK_HALF_LENGTH)
	predicted.z = clampf(predicted.z, -RINK_HALF_WIDTH, RINK_HALF_WIDTH)
	actor.global_position = predicted
	actor.velocity = Vector3(movement.x, 0.0, movement.y) * prediction_speed
	if has_ball:
		_ball.global_position += predicted - previous_position
	if not movement.is_zero_approx():
		actor.rotation.y = atan2(movement.x, movement.y)


func _vector_to_array(value: Vector2) -> Array:
	return [value.x, value.y]


func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _array_to_vector(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else Vector2.ZERO


func _array_to_vector3(value: Variant) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) if value is Array and value.size() >= 3 else Vector3.ZERO
