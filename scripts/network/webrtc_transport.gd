class_name FloorballWebRTCTransport
extends Node


const ApiEndpointScript = preload("res://scripts/network/api_endpoint.gd")
const POLL_SECONDS := 0.25

signal connected
signal disconnected
signal message_received(message: Dictionary)
signal status_changed(message: String)

var _role: StringName
var _room_id := ""
var _peer: Object
var _channel: Object
var _poll_remaining := 0.0
var _polling := false
var _pending_ice: Array[Dictionary] = []
var _has_remote_description := false


func start(role: StringName, room_id: String) -> bool:
	_role = role
	_room_id = room_id
	if not OS.has_feature("web"):
		status_changed.emit("Online play currently runs in the web build")
		return false
	if not ClassDB.class_exists(&"WebRTCPeerConnection"):
		status_changed.emit("WebRTC is unavailable in this build")
		return false
	status_changed.emit("Preparing secure connection…")
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_ice_servers_received.bind(request))
	if request.request(ApiEndpointScript.current_base() + "/ice-servers") != OK:
		request.queue_free()
		_initialize_peer(_fallback_ice_servers())
	return true


func _on_ice_servers_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	var servers = JSON.parse_string(body.get_string_from_utf8()) if code == 200 else null
	_initialize_peer(servers if servers is Array else _fallback_ice_servers())


func _initialize_peer(ice_servers: Array) -> void:
	_peer = ClassDB.instantiate(&"WebRTCPeerConnection")
	var init_result := int(_peer.call("initialize", {"iceServers": ice_servers}))
	if init_result != OK:
		_peer = null
		status_changed.emit("WebRTC requires a web export (or the native WebRTC extension)")
		return
	_peer.connect("session_description_created", _on_session_description_created)
	_peer.connect("ice_candidate_created", _on_ice_candidate_created)
	_peer.connect("data_channel_received", _on_data_channel_received)
	if _role == &"host":
		_channel = _peer.call("create_data_channel", "game", {"ordered": false, "maxRetransmits": 0})
		_peer.call("create_offer")
	status_changed.emit("Waiting for opponent…" if _role == &"host" else "Joining room…")
	set_process(true)


func _fallback_ice_servers() -> Array:
	return [
		{"urls": "stun:stun.relay.metered.ca:80"},
		{"urls": "stun:stun.l.google.com:19302"},
		{"urls": "stun:stun.cloudflare.com:3478"},
	]


func _process(delta: float) -> void:
	if _peer == null:
		return
	_peer.call("poll")
	if _channel != null:
		_channel.call("poll")
		var state := int(_channel.call("get_ready_state"))
		if state == 1 and not bool(get_meta("announced_open", false)):
			set_meta("announced_open", true)
			connected.emit()
			status_changed.emit("Connected")
		elif state == 3 and bool(get_meta("announced_open", false)) and not bool(get_meta("announced_closed", false)):
			set_meta("announced_closed", true)
			disconnected.emit()
			status_changed.emit("Opponent disconnected")
		while state == 1 and int(_channel.call("get_available_packet_count")) > 0:
			var packet: PackedByteArray = _channel.call("get_packet")
			var value = JSON.parse_string(packet.get_string_from_utf8())
			if value is Dictionary:
				message_received.emit(value)
	_poll_remaining -= delta
	if _poll_remaining <= 0.0 and not _polling:
		_poll_remaining = POLL_SECONDS
		_poll_signals()


func send(message: Dictionary) -> void:
	if _channel == null or int(_channel.call("get_ready_state")) != 1:
		return
	_channel.call("put_packet", JSON.stringify(message).to_utf8_buffer())


func close() -> void:
	set_process(false)
	if _channel != null:
		_channel.call("close")
	if _peer != null:
		_peer.call("close")
	_peer = null
	_channel = null


func _on_session_description_created(type: String, sdp: String) -> void:
	_peer.call("set_local_description", type, sdp)
	_post_signal({"type": type, "sdp": sdp, "roomId": _room_id})


func _on_data_channel_received(channel: Object) -> void:
	_channel = channel


func _on_ice_candidate_created(media: String, index: int, candidate: String) -> void:
	_post_signal({"type": "ice", "candidate": {"sdpMid": media, "sdpMLineIndex": index, "candidate": candidate}, "roomId": _room_id})


func _poll_signals() -> void:
	_polling = true
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_signals_received.bind(request))
	var url := "%s/signal?room=%s&role=%s&t=%d" % [ApiEndpointScript.current_base(), _room_id.uri_encode(), String(_role), Time.get_ticks_msec()]
	if request.request(url) != OK:
		_polling = false
		request.queue_free()


func _on_signals_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	_polling = false
	if code != 200 or _peer == null:
		return
	var messages = JSON.parse_string(body.get_string_from_utf8())
	if not messages is Array:
		return
	for message: Dictionary in messages:
		var type := String(message.get("type", ""))
		if type == "offer" and _role == &"client":
			_peer.call("set_remote_description", "offer", String(message.get("sdp", "")))
			_has_remote_description = true
			_peer.call("create_answer")
			_flush_ice()
		elif type == "answer" and _role == &"host":
			_peer.call("set_remote_description", "answer", String(message.get("sdp", "")))
			_has_remote_description = true
			_flush_ice()
		elif type == "ice":
			var candidate: Dictionary = message.get("candidate", {})
			_pending_ice.append(candidate)
			_flush_ice()


func _flush_ice() -> void:
	if not _has_remote_description:
		return
	for candidate in _pending_ice:
		_peer.call("add_ice_candidate", String(candidate.get("sdpMid", "0")), int(candidate.get("sdpMLineIndex", 0)), String(candidate.get("candidate", "")))
	_pending_ice.clear()


func _post_signal(message: Dictionary) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_a: int, _b: int, _c: PackedStringArray, _d: PackedByteArray) -> void: request.queue_free())
	request.request(ApiEndpointScript.current_base() + "/signal", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"room": _room_id, "role": String(_role), "msg": message}))
