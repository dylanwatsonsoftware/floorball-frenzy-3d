class_name NetworkDiagnostics
extends RefCounted


const MAX_SAMPLES := 120

var _frame_seconds: Array[float] = []
var _round_trip_ms: Array[float] = []
var _snapshot_age_seconds: Array[float] = []
var _received_snapshots := 0
var _missing_snapshots := 0
var _last_snapshot_sequence := -1
var _player_error_m := 0.0
var _ball_error_m := 0.0
var _input_sent := -1
var _input_ack := -1
var _connection_path: StringName = &"checking"


func record_frame(delta: float) -> void:
	_append_sample(_frame_seconds, maxf(delta, 0.000001))


func record_round_trip(round_trip_ms: float) -> void:
	_append_sample(_round_trip_ms, maxf(round_trip_ms, 0.0))


func record_snapshot_sequence(sequence: int) -> void:
	if _last_snapshot_sequence >= 0 and sequence > _last_snapshot_sequence:
		_missing_snapshots += maxi(0, sequence - _last_snapshot_sequence - 1)
	_received_snapshots += 1
	_last_snapshot_sequence = maxi(_last_snapshot_sequence, sequence)


func record_snapshot_age(age_seconds: float) -> void:
	_append_sample(_snapshot_age_seconds, maxf(age_seconds, 0.0))


func record_prediction_error(player_error_m: float, ball_error_m: float) -> void:
	_player_error_m = maxf(player_error_m, 0.0)
	_ball_error_m = maxf(ball_error_m, 0.0)


func record_command_progress(sent_sequence: int, acknowledged_sequence: int) -> void:
	_input_sent = maxi(_input_sent, sent_sequence)
	_input_ack = mini(_input_sent, maxi(_input_ack, acknowledged_sequence))


func record_connection_path(path: StringName) -> void:
	_connection_path = path if path in [&"direct", &"relay"] else &"checking"


func report() -> Dictionary:
	var average_frame_seconds := _average(_frame_seconds)
	var average_rtt := _average(_round_trip_ms)
	var total_snapshots := _received_snapshots + _missing_snapshots
	return {
		"fps": 0.0 if average_frame_seconds <= 0.0 else 1.0 / average_frame_seconds,
		"frame_ms": average_frame_seconds * 1000.0,
		"rtt_ms": average_rtt,
		"jitter_ms": _mean_absolute_deviation(_round_trip_ms, average_rtt),
		"loss_percent": 0.0 if total_snapshots <= 0 else float(_missing_snapshots) / float(total_snapshots) * 100.0,
		"snapshot_age_ms": _average(_snapshot_age_seconds) * 1000.0,
		"player_error_m": _player_error_m,
		"ball_error_m": _ball_error_m,
		"input_sent": _input_sent,
		"input_ack": _input_ack,
		"unacknowledged_inputs": maxi(0, _input_sent - _input_ack),
		"connection_path": _connection_path,
	}


func _append_sample(samples: Array[float], value: float) -> void:
	samples.append(value)
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()


func _average(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for value in samples:
		total += value
	return total / float(samples.size())


func _mean_absolute_deviation(samples: Array[float], average: float) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for value in samples:
		total += absf(value - average)
	return total / float(samples.size())
