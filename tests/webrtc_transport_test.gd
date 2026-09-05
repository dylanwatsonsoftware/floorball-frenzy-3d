extends SceneTree


func _init() -> void:
	var transport = load("res://scripts/network/webrtc_transport.gd")
	if transport == null:
		fail("WebRTC transport is missing")
		return
	if transport.classify_connection_path("relay", "srflx") != &"relay":
		fail("A selected ICE pair containing a TURN relay candidate must be reported as relayed")
		return
	if transport.classify_connection_path("host", "srflx") != &"direct":
		fail("Host/server-reflexive selected ICE pairs must be reported as direct")
		return
	if transport.classify_connection_path("", "") != &"checking":
		fail("Unknown selected ICE candidates must remain checking instead of claiming a direct path")
		return
	print("WebRTC connection-path diagnostics classify selected ICE pairs.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
