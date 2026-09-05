extends Node


var enabled := false
var role: StringName = &""
var room_id := ""
var host_name := ""
var remote_input := Vector2.ZERO
var remote_dash := false
var remote_shoot := false
var remote_pass := false
var remote_rtt_ms := 0.0
var remote_input_sequence := -1
var remote_input_sent_ms := -1
var remote_simulated_sequence := -1
var remote_simulated_sent_ms := -1


func start(next_role: StringName, next_room_id: String, next_host_name: String = "") -> void:
	enabled = true
	role = next_role
	room_id = next_room_id
	host_name = next_host_name
	clear_remote_input()


func stop() -> void:
	enabled = false
	role = &""
	room_id = ""
	host_name = ""
	clear_remote_input()


func local_team() -> StringName:
	return &"red" if role == &"host" else &"blue"


func is_authority() -> bool:
	return enabled and role == &"host"


func clear_remote_input() -> void:
	remote_input = Vector2.ZERO
	remote_dash = false
	remote_shoot = false
	remote_pass = false
	remote_rtt_ms = 0.0
	remote_input_sequence = -1
	remote_input_sent_ms = -1
	remote_simulated_sequence = -1
	remote_simulated_sent_ms = -1


func set_remote_command(sequence: int, sent_at_ms: int) -> void:
	if sequence <= remote_input_sequence:
		return
	remote_input_sequence = sequence
	remote_input_sent_ms = sent_at_ms


func mark_remote_command_simulated() -> void:
	if remote_input_sequence <= remote_simulated_sequence:
		return
	remote_simulated_sequence = remote_input_sequence
	remote_simulated_sent_ms = remote_input_sent_ms
