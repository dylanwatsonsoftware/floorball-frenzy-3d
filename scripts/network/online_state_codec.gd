class_name OnlineStateCodec
extends RefCounted

const MAGIC_SIZE := 4


static func is_snapshot_packet(packet: PackedByteArray) -> bool:
	return packet.size() >= MAGIC_SIZE and packet[0] == 0x46 and packet[1] == 0x46 and packet[2] == 0x53 and packet[3] == 0x31


static func encode_snapshot(snapshot: Dictionary, include_extended_ball_state: bool = true) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.big_endian = false
	stream.put_u8(0x46)
	stream.put_u8(0x46)
	stream.put_u8(0x53)
	stream.put_u8(0x31)
	stream.put_32(int(snapshot.get("seq", 0)))
	stream.put_64(int(snapshot.get("host_time_ms", 0)))
	stream.put_32(int(snapshot.get("input_ack", -1)))
	stream.put_64(int(snapshot.get("input_echo_ms", -1)))
	var actors: Array = snapshot.get("actors", [])
	stream.put_u8(actors.size())
	for actor: Dictionary in actors:
		stream.put_utf8_string(String(actor.get("id", "")))
		_put_vector3(stream, actor.get("p", []))
		_put_vector3(stream, actor.get("v", []))
		stream.put_float(float(actor.get("r", 0.0)))
	_put_vector3(stream, snapshot.get("ball", []))
	_put_vector3(stream, snapshot.get("ball_velocity", []))
	stream.put_utf8_string(String(snapshot.get("owner", "")))
	stream.put_utf8_string(String(snapshot.get("red_human", "red_1")))
	stream.put_utf8_string(String(snapshot.get("blue_human", "blue_1")))
	var score: Dictionary = snapshot.get("score", {})
	stream.put_16(int(score.get("red", 0)))
	stream.put_16(int(score.get("blue", 0)))
	stream.put_32(int(snapshot.get("goal_seq", 0)))
	stream.put_32(int(snapshot.get("faceoff_seq", 0)))
	stream.put_utf8_string(String(snapshot.get("scorer", "")))
	stream.put_utf8_string(String(snapshot.get("phase", "play")))
	stream.put_u8(1 if bool(snapshot.get("ball_attached", false)) else 0)
	if include_extended_ball_state:
		stream.put_utf8_string(String(snapshot.get("ball_state", "possessed" if bool(snapshot.get("ball_attached", false)) else "loose")))
		stream.put_32(int(snapshot.get("possession_seq", 0)))
		stream.put_32(int(snapshot.get("action_seq", 0)))
		stream.put_utf8_string(String(snapshot.get("action_type", "")))
		stream.put_32(int(snapshot.get("action_tick", 0)))
		var stick_angles: Array = snapshot.get("stick_angles", [])
		stream.put_u8(stick_angles.size())
		for angle: Variant in stick_angles:
			stream.put_float(float(angle))
		stream.put_u8(actors.size())
		for actor: Dictionary in actors:
			stream.put_float(float(actor.get("dc", 0.0)))
			stream.put_float(float(actor.get("dr", 0.0)))
			_put_vector3(stream, actor.get("dd", []))
	return stream.data_array


static func decode_snapshot(packet: PackedByteArray) -> Dictionary:
	if not is_snapshot_packet(packet):
		return {}
	var stream := StreamPeerBuffer.new()
	stream.big_endian = false
	stream.data_array = packet
	stream.seek(MAGIC_SIZE)
	var snapshot := {
		"type": "snapshot",
		"seq": stream.get_32(),
		"host_time_ms": stream.get_64(),
		"input_ack": stream.get_32(),
		"input_echo_ms": stream.get_64(),
	}
	var actors: Array = []
	for _index in range(stream.get_u8()):
		actors.append({"id": stream.get_utf8_string(), "p": _get_vector3(stream), "v": _get_vector3(stream), "r": stream.get_float()})
	snapshot.actors = actors
	snapshot.ball = _get_vector3(stream)
	snapshot.ball_velocity = _get_vector3(stream)
	snapshot.owner = stream.get_utf8_string()
	snapshot.red_human = stream.get_utf8_string()
	snapshot.blue_human = stream.get_utf8_string()
	snapshot.score = {"red": stream.get_16(), "blue": stream.get_16()}
	snapshot.goal_seq = stream.get_32()
	snapshot.faceoff_seq = stream.get_32()
	snapshot.scorer = stream.get_utf8_string()
	snapshot.phase = stream.get_utf8_string()
	snapshot.ball_attached = stream.get_u8() == 1 if stream.get_available_bytes() > 0 else not String(snapshot.owner).is_empty()
	snapshot.ball_state = stream.get_utf8_string() if stream.get_available_bytes() > 0 else ("possessed" if snapshot.ball_attached else "loose")
	snapshot.possession_seq = stream.get_32() if stream.get_available_bytes() >= 4 else 0
	snapshot.action_seq = stream.get_32() if stream.get_available_bytes() >= 4 else 0
	snapshot.action_type = stream.get_utf8_string() if stream.get_available_bytes() > 0 else ""
	snapshot.action_tick = stream.get_32() if stream.get_available_bytes() >= 4 else 0
	var stick_angles: Array = []
	if stream.get_available_bytes() > 0:
		for _index in range(stream.get_u8()):
			if stream.get_available_bytes() < 4:
				break
			stick_angles.append(stream.get_float())
	snapshot.stick_angles = stick_angles
	if stream.get_available_bytes() > 0:
		var dash_state_count := mini(stream.get_u8(), actors.size())
		for actor_index in dash_state_count:
			if stream.get_available_bytes() < 20:
				break
			actors[actor_index].dc = stream.get_float()
			actors[actor_index].dr = stream.get_float()
			actors[actor_index].dd = _get_vector3(stream)
	return snapshot


static func _put_vector3(stream: StreamPeerBuffer, value: Variant) -> void:
	for index in range(3):
		stream.put_float(float(value[index]) if value is Array and value.size() > index else 0.0)


static func _get_vector3(stream: StreamPeerBuffer) -> Array:
	return [stream.get_float(), stream.get_float(), stream.get_float()]
