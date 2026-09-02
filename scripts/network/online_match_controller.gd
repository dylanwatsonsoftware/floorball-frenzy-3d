class_name OnlineMatchController
extends Node


const TransportScript = preload("res://scripts/network/webrtc_transport.gd")
const SNAPSHOT_SECONDS := 1.0 / 20.0

var _transport: FloorballWebRTCTransport
var _arena: Node3D
var _ball: Node3D
var _sequence := 0
var _snapshot_elapsed := 0.0
var _last_snapshot := -1
var _status: Label
var _match_flow: Node


func _ready() -> void:
	_arena = get_parent().get_node("Arena") as Node3D
	_ball = _arena.get_node("Ball") as Node3D
	_match_flow = get_parent().get_node("MatchFlow")
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
		_transport.send({"type": "input", "seq": _sequence, "move": _vector_to_array(Input.get_vector("move_left", "move_right", "move_up", "move_down")), "dash": Input.is_action_pressed("dash"), "shoot": Input.is_action_pressed("shoot"), "pass": Input.is_action_just_pressed("pass"), "switch": Input.is_action_just_pressed("switch_player")})
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
		OnlineMatch.remote_pass = bool(message.get("pass", false))
		if bool(message.get("switch", false)) and _ball.has_method("switch_human_player_for_team"):
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
	return {"type": "snapshot", "seq": _sequence, "actors": actors, "ball": _vector3_to_array(_ball.global_position), "ball_velocity": _vector3_to_array(_ball.ball_velocity), "owner": String(_ball.call("get_control_owner_actor_id")), "red_human": String(_ball.call("get_human_control_actor_id_for_team", &"red")), "blue_human": String(_ball.call("get_human_control_actor_id_for_team", &"blue")), "score": _match_flow.score.duplicate()}


func _apply_snapshot(snapshot: Dictionary) -> void:
	var actor_by_id := {}
	for actor in _arena.call("get_field_players"):
		actor_by_id[String(actor.call("get_actor_id"))] = actor
	for state: Dictionary in snapshot.get("actors", []):
		var actor: CharacterBody3D = actor_by_id.get(String(state.get("id", "")))
		if actor != null:
			actor.global_position = actor.global_position.lerp(_array_to_vector3(state.get("p", [])), 0.55)
			actor.velocity = _array_to_vector3(state.get("v", []))
			actor.rotation.y = lerp_angle(actor.rotation.y, float(state.get("r", actor.rotation.y)), 0.55)
	_ball.global_position = _ball.global_position.lerp(_array_to_vector3(snapshot.get("ball", [])), 0.65)
	_ball.ball_velocity = _array_to_vector3(snapshot.get("ball_velocity", []))
	if _ball.has_method("apply_network_control_state"):
		_ball.call("apply_network_control_state", StringName(snapshot.get("owner", "")), StringName(snapshot.get("red_human", "red_1")), StringName(snapshot.get("blue_human", "blue_1")))
	var score: Dictionary = snapshot.get("score", {})
	if not score.is_empty() and _match_flow.has_method("apply_network_score"):
		_match_flow.call("apply_network_score", int(score.get("red", 0)), int(score.get("blue", 0)))


func _set_client_replica_mode() -> void:
	_ball.set_physics_process(false)
	for actor in _arena.call("get_field_players"):
		actor.set_physics_process(false)


func _set_authority_waiting(waiting: bool) -> void:
	_ball.set_physics_process(not waiting)
	for actor in _arena.call("get_field_players"):
		actor.set_physics_process(not waiting)


func _vector_to_array(value: Vector2) -> Array:
	return [value.x, value.y]


func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _array_to_vector(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else Vector2.ZERO


func _array_to_vector3(value: Variant) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) if value is Array and value.size() >= 3 else Vector3.ZERO
