extends SceneTree


func _init() -> void:
	var codec = load("res://scripts/network/online_state_codec.gd")
	if codec == null:
		fail("Online snapshots need a binary state codec")
		return
	var actors: Array = []
	for index in range(12):
		actors.append({"id": "red_%d" % index, "p": [float(index), 0.75, -2.0], "v": [1.0, 0.0, 0.5], "r": 0.25, "dc": 0.8, "dr": 0.12 if index == 7 else 0.0, "dd": [1.0, 0.0, 0.0]})
	var snapshot := {
		"type": "snapshot", "seq": 42, "host_time_ms": 123456, "input_ack": 37, "input_echo_ms": 123400,
		"actors": actors, "ball": [1.0, 0.22, 2.0], "ball_velocity": [8.0, 0.18, -1.0],
		"owner": "blue_1", "ball_attached": true, "red_human": "red_1", "blue_human": "blue_1",
		"ball_state": "possessed", "possession_seq": 9, "action_seq": 12, "action_type": "pass", "action_tick": 720,
		"pickup_ack_seq": 6, "pickup_result": "accepted", "pickup_actor": "blue_1",
		"stick_angles": [0.0, 18.0, 0.0, -42.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"score": {"red": 2, "blue": 3}, "goal_seq": 4, "faceoff_seq": 5, "scorer": "blue", "phase": "play",
	}
	var encoded: PackedByteArray = codec.encode_snapshot(snapshot)
	if not codec.is_snapshot_packet(encoded):
		fail("Encoded state must have a recognizable versioned packet header")
		return
	if encoded[3] != 0x31:
		fail("Possession metadata must remain wire-compatible with already-open FFS1 web clients")
		return
	var json_size := JSON.stringify(snapshot).to_utf8_buffer().size()
	if encoded.size() >= json_size * 0.75:
		fail("Binary snapshots should materially reduce high-frequency packet size; binary=%d json=%d" % [encoded.size(), json_size])
		return
	var decoded: Dictionary = codec.decode_snapshot(encoded)
	if decoded.seq != 42 or decoded.input_ack != 37 or decoded.actors.size() != 12:
		fail("Binary snapshot metadata did not survive a round trip")
		return
	if decoded.actors[7].id != "red_7" or not is_equal_approx(float(decoded.actors[7].p[0]), 7.0):
		fail("Binary actor state did not survive a round trip")
		return
	if not is_equal_approx(float(decoded.actors[7].dc), 0.8) or not is_equal_approx(float(decoded.actors[7].dr), 0.12) or not is_equal_approx(float(decoded.actors[7].dd[0]), 1.0):
		fail("Authoritative dash state must survive snapshots so guest replay can continue an acknowledged dash; got %s" % decoded.actors[7])
		return
	if decoded.score != {"red": 2, "blue": 3} or decoded.owner != "blue_1" or not decoded.ball_attached:
		fail("Binary match and possession state did not survive a round trip")
		return
	if decoded.ball_state != "possessed" or decoded.possession_seq != 9 or decoded.action_seq != 12 or decoded.action_type != "pass" or decoded.action_tick != 720:
		fail("Explicit ball ownership and action generations must survive a snapshot round trip; got %s" % decoded)
		return
	if decoded.get("pickup_ack_seq", -1) != 6 or decoded.get("pickup_result", "") != "accepted" or decoded.get("pickup_actor", "") != "blue_1":
		fail("Explicit pickup decisions must survive compact snapshot round trips; got %s" % decoded)
		return
	if decoded.stick_angles.size() != 12 or not is_equal_approx(float(decoded.stick_angles[1]), 18.0) or not is_equal_approx(float(decoded.stick_angles[3]), -42.0):
		fail("Per-player stick action poses must survive compact snapshot round trips; got %s" % decoded.get("stick_angles", []))
		return
	var legacy_packet: PackedByteArray = codec.encode_snapshot(snapshot, false)
	var legacy_decoded: Dictionary = codec.decode_snapshot(legacy_packet)
	if legacy_decoded.owner != "blue_1" or not legacy_decoded.ball_attached:
		fail("New guests must infer possession attachment when receiving an older FFS1 snapshot")
		return
	if not legacy_decoded.get("stick_angles", []).is_empty():
		fail("Legacy FFS1 snapshots must decode without per-player action poses")
		return
	print("Online snapshots use compact binary state packets.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
