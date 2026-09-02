class_name OnlineSession
extends RefCounted


const ROOM_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var _last_input_sequence := -1
var _last_snapshot_sequence := -1


func local_team_for_role(role: StringName) -> StringName:
	return &"red" if role == &"host" else &"blue"


func ai_count_for_team(_team: StringName, _local_team: StringName) -> int:
	return 5


func accept_input_sequence(sequence: int) -> bool:
	if sequence <= _last_input_sequence:
		return false
	_last_input_sequence = sequence
	return true


func accept_snapshot_sequence(sequence: int) -> bool:
	if sequence <= _last_snapshot_sequence:
		return false
	_last_snapshot_sequence = sequence
	return true


func make_room_id(random_source: Callable = Callable()) -> String:
	var result := ""
	for index in 6:
		var value: int = int(random_source.call()) if random_source.is_valid() else randi()
		result += ROOM_ALPHABET[int(value) % ROOM_ALPHABET.length()]
	return result
