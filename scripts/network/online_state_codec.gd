class_name OnlineStateCodec
extends RefCounted

const MAGIC_SIZE := 4


static func is_snapshot_packet(packet: PackedByteArray) -> bool:
	return packet.size() >= MAGIC_SIZE and packet[0] == 0x46 and packet[1] == 0x46 and packet[2] == 0x53 and packet[3] == 0x32


static func encode_snapshot(snapshot: Dictionary) -> PackedByteArray:
	var stream := StreamPeerBuffer.new()
	stream.big_endian = false
	stream.put_u8(0x46)
	stream.put_u8(0x46)
	stream.put_u8(0x53)
	stream.put_u8(0x32)
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
	stream.put_u8(1 if bool(snapshot.get("ball_attached", false)) else 0)
	stream.put_utf8_string(String(snapshot.get("red_human", "red_1")))
	stream.put_utf8_string(String(snapshot.get("blue_human", "blue_1")))
	var score: Dictionary = snapshot.get("score", {})
	stream.put_16(int(score.get("red", 0)))
	stream.put_16(int(score.get("blue", 0)))
	stream.put_32(int(snapshot.get("goal_seq", 0)))
	stream.put_32(int(snapshot.get("faceoff_seq", 0)))
	stream.put_utf8_string(String(snapshot.get("scorer", "")))
	stream.put_utf8_string(String(snapshot.get("phase", "play")))
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
	snapshot.ball_attached = stream.get_u8() == 1
	snapshot.red_human = stream.get_utf8_string()
	snapshot.blue_human = stream.get_utf8_string()
	snapshot.score = {"red": stream.get_16(), "blue": stream.get_16()}
	snapshot.goal_seq = stream.get_32()
	snapshot.faceoff_seq = stream.get_32()
	snapshot.scorer = stream.get_utf8_string()
	snapshot.phase = stream.get_utf8_string()
	return snapshot


static func _put_vector3(stream: StreamPeerBuffer, value: Variant) -> void:
	for index in range(3):
		stream.put_float(float(value[index]) if value is Array and value.size() > index else 0.0)


static func _get_vector3(stream: StreamPeerBuffer) -> Array:
	return [stream.get_float(), stream.get_float(), stream.get_float()]
