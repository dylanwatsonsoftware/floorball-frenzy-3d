class_name NetworkPredictionHarness
extends RefCounted


const OnlineInputScript = preload("res://scripts/network/online_input.gd")
const ConditionsScript = preload("res://scripts/network/network_condition_simulator.gd")
const RemoteSnapshotBufferScript = preload("res://scripts/network/remote_snapshot_buffer.gd")
const FIXED_DELTA := 1.0 / 60.0
const SNAPSHOT_INTERVAL_TICKS := 2
const REMOTE_INTERPOLATION_DELAY_MS := 110


static func run_profile(profile_name: StringName, duration_seconds: float, seed: int = 1) -> Dictionary:
	var profile: Dictionary = ConditionsScript.profile(profile_name)
	var input_conditions = ConditionsScript.new(int(profile.rtt_ms), float(profile.loss_percent) / 100.0, int(profile.jitter_ms), seed)
	var snapshot_conditions = ConditionsScript.new(int(profile.rtt_ms), float(profile.loss_percent) / 100.0, int(profile.jitter_ms), seed + 1009)
	var host_position := Vector3.ZERO
	var host_velocity := Vector3.ZERO
	var client_position := Vector3.ZERO
	var client_velocity := Vector3.ZERO
	var host_input := Vector2.ZERO
	var command_sequence := 0
	var acknowledged_sequence := -1
	var snapshot_sequence := 0
	var last_snapshot_sequence := -1
	var pending_inputs: Array = []
	var input_packets: Array = []
	var snapshot_packets: Array = []
	var correction_samples: Array[float] = []
	var prediction_error_samples: Array[float] = []
	var snap_count := 0
	var total_ticks := ceili((duration_seconds + 1.5) / FIXED_DELTA)
	for tick in total_ticks:
		var now_ms := roundi(float(tick) * FIXED_DELTA * 1000.0)
		var trace_time := float(tick) * FIXED_DELTA
		var movement := _trace_input(trace_time) if trace_time < duration_seconds else Vector2.ZERO
		command_sequence += 1
		var command := {"seq": command_sequence, "move": movement, "delta": FIXED_DELTA, "speed_multiplier": 1.0}
		pending_inputs.append(command)
		var input_schedule: Dictionary = input_conditions.schedule(command_sequence, now_ms)
		if not bool(input_schedule.dropped):
			input_packets.append({"delivery_ms": input_schedule.delivery_ms, "command": command})
		var client_step: Dictionary = OnlineInputScript.predict_player_state(client_position, client_velocity, movement, FIXED_DELTA, 1.0)
		client_position = client_step.position
		client_velocity = client_step.velocity

		var remaining_inputs: Array = []
		for packet: Dictionary in input_packets:
			if int(packet.delivery_ms) <= now_ms:
				var delivered: Dictionary = packet.command
				if int(delivered.seq) > acknowledged_sequence:
					host_input = delivered.move
					acknowledged_sequence = int(delivered.seq)
			else:
				remaining_inputs.append(packet)
		input_packets = remaining_inputs
		var host_step: Dictionary = OnlineInputScript.predict_player_state(host_position, host_velocity, host_input, FIXED_DELTA, 1.0)
		host_position = host_step.position
		host_velocity = host_step.velocity

		if tick % SNAPSHOT_INTERVAL_TICKS == 0:
			snapshot_sequence += 1
			var snapshot_schedule: Dictionary = snapshot_conditions.schedule(snapshot_sequence, now_ms)
			if not bool(snapshot_schedule.dropped):
				snapshot_packets.append({"delivery_ms": snapshot_schedule.delivery_ms, "seq": snapshot_sequence, "ack": acknowledged_sequence, "position": host_position, "velocity": host_velocity})
		var remaining_snapshots: Array = []
		for packet: Dictionary in snapshot_packets:
			if int(packet.delivery_ms) <= now_ms:
				if int(packet.seq) <= last_snapshot_sequence:
					continue
				last_snapshot_sequence = int(packet.seq)
				pending_inputs = OnlineInputScript.discard_acknowledged_inputs(pending_inputs, int(packet.ack))
				var replayed: Dictionary = OnlineInputScript.replay_player_inputs(packet.position, packet.velocity, pending_inputs)
				var error := client_position.distance_to(replayed.position)
				prediction_error_samples.append(error)
				if error >= 2.5:
					snap_count += 1
				var reconciled_position: Vector3 = OnlineInputScript.reconcile_position(client_position, replayed.position, true)
				correction_samples.append(client_position.distance_to(reconciled_position))
				client_position = reconciled_position
				client_velocity = replayed.velocity
			else:
				remaining_snapshots.append(packet)
		snapshot_packets = remaining_snapshots
	correction_samples.sort()
	prediction_error_samples.sort()
	return {
		"maximum_correction_m": correction_samples.back() if not correction_samples.is_empty() else 0.0,
		"p95_correction_m": _percentile(correction_samples, 0.95),
		"maximum_prediction_error_m": prediction_error_samples.back() if not prediction_error_samples.is_empty() else 0.0,
		"p95_prediction_error_m": _percentile(prediction_error_samples, 0.95),
		"final_error_m": client_position.distance_to(host_position),
		"snap_count": snap_count,
		"samples": correction_samples.size(),
	}


static func run_dash_profile(profile_name: StringName, seed: int = 1) -> Dictionary:
	var profile: Dictionary = ConditionsScript.profile(profile_name)
	var input_conditions = ConditionsScript.new(int(profile.rtt_ms), float(profile.loss_percent) / 100.0, int(profile.jitter_ms), seed + 3109)
	var snapshot_conditions = ConditionsScript.new(int(profile.rtt_ms), float(profile.loss_percent) / 100.0, int(profile.jitter_ms), seed + 4211)
	var host_state := _initial_command_state()
	var client_state := _initial_command_state()
	var host_movement := Vector2.ZERO
	var host_dash_sequence := 0
	var sent_dash_sequence := 0
	var acknowledged_sequence := -1
	var command_sequence := 0
	var snapshot_sequence := 0
	var last_snapshot_sequence := -1
	var pending_inputs: Array = []
	var input_packets: Array = []
	var snapshot_packets: Array = []
	var corrections: Array[float] = []
	var predicted_immediately := false
	var snap_count := 0
	for tick in 240:
		var now_ms := roundi(float(tick) * FIXED_DELTA * 1000.0)
		var movement := Vector2.RIGHT if tick < 150 else Vector2.ZERO
		var dash_pressed := tick == 30
		if dash_pressed:
			sent_dash_sequence += 1
		command_sequence += 1
		var command := {"seq": command_sequence, "move": movement, "facing": movement, "dash_pressed": dash_pressed, "dash_seq": sent_dash_sequence, "delta": FIXED_DELTA, "speed_multiplier": 1.0}
		pending_inputs.append(command)
		var input_schedule: Dictionary = input_conditions.schedule(command_sequence, now_ms)
		if not bool(input_schedule.dropped):
			input_packets.append({"delivery_ms": input_schedule.delivery_ms, "command": command})
		client_state = OnlineInputScript.predict_player_command_state(client_state, command)
		if dash_pressed:
			predicted_immediately = bool(client_state.dash_started) and client_state.velocity.length() >= 14.99

		var host_dash_pressed := false
		var remaining_inputs: Array = []
		for packet: Dictionary in input_packets:
			if int(packet.delivery_ms) <= now_ms:
				var delivered: Dictionary = packet.command
				if int(delivered.seq) > acknowledged_sequence:
					host_movement = delivered.move
					acknowledged_sequence = int(delivered.seq)
					if int(delivered.dash_seq) > host_dash_sequence:
						host_dash_sequence = int(delivered.dash_seq)
						host_dash_pressed = true
			else:
				remaining_inputs.append(packet)
		input_packets = remaining_inputs
		var host_command := {"move": host_movement, "facing": host_movement, "dash_pressed": host_dash_pressed, "delta": FIXED_DELTA, "speed_multiplier": 1.0}
		host_state = OnlineInputScript.predict_player_command_state(host_state, host_command)

		if tick % SNAPSHOT_INTERVAL_TICKS == 0:
			snapshot_sequence += 1
			var snapshot_schedule: Dictionary = snapshot_conditions.schedule(snapshot_sequence, now_ms)
			if not bool(snapshot_schedule.dropped):
				snapshot_packets.append({"delivery_ms": snapshot_schedule.delivery_ms, "seq": snapshot_sequence, "ack": acknowledged_sequence, "state": host_state.duplicate()})
		var remaining_snapshots: Array = []
		for packet: Dictionary in snapshot_packets:
			if int(packet.delivery_ms) <= now_ms:
				if int(packet.seq) <= last_snapshot_sequence:
					continue
				last_snapshot_sequence = int(packet.seq)
				pending_inputs = OnlineInputScript.discard_acknowledged_inputs(pending_inputs, int(packet.ack))
				var replayed: Dictionary = OnlineInputScript.replay_player_commands(packet.state, pending_inputs)
				var error: float = client_state.position.distance_to(replayed.position)
				if error >= 2.5:
					snap_count += 1
				var reconciled_position := OnlineInputScript.reconcile_position(client_state.position, replayed.position, true)
				corrections.append(client_state.position.distance_to(reconciled_position))
				client_state = replayed
				client_state.position = reconciled_position
			else:
				remaining_snapshots.append(packet)
		snapshot_packets = remaining_snapshots
	corrections.sort()
	return {
		"predicted_immediately": predicted_immediately,
		"maximum_correction_m": corrections.back() if not corrections.is_empty() else INF,
		"p95_correction_m": _percentile(corrections, 0.95),
		"final_error_m": client_state.position.distance_to(host_state.position),
		"snap_count": snap_count,
	}


static func compare_frame_rates(duration_seconds: float) -> Dictionary:
	var at_30 := _simulate_with_render_rate(duration_seconds, 30)
	var at_60 := _simulate_with_render_rate(duration_seconds, 60)
	return {"distance_m": at_30.distance_to(at_60), "at_30": at_30, "at_60": at_60}


static func run_remote_profile(profile_name: StringName, duration_seconds: float, seed: int = 1) -> Dictionary:
	var profile: Dictionary = ConditionsScript.profile(profile_name)
	var conditions = ConditionsScript.new(int(profile.rtt_ms), float(profile.loss_percent) / 100.0, int(profile.jitter_ms), seed + 2027)
	var host_position := Vector3.ZERO
	var host_velocity := Vector3.ZERO
	var replica_position := Vector3.ZERO
	var replica_velocity := Vector3.ZERO
	var packets: Array = []
	var snapshot_buffer = RemoteSnapshotBufferScript.new()
	var corrections: Array[float] = []
	var snapshot_sequence := 0
	var last_snapshot := -1
	var total_ticks := ceili((duration_seconds + 1.5) / FIXED_DELTA)
	for tick in total_ticks:
		var now_ms := roundi(float(tick) * FIXED_DELTA * 1000.0)
		var trace_time := float(tick) * FIXED_DELTA
		var movement := _trace_input(trace_time) if trace_time < duration_seconds else Vector2.ZERO
		var host_step: Dictionary = OnlineInputScript.predict_player_state(host_position, host_velocity, movement, FIXED_DELTA, 1.0)
		host_position = host_step.position
		host_velocity = host_step.velocity
		if tick % SNAPSHOT_INTERVAL_TICKS == 0:
			snapshot_sequence += 1
			var schedule: Dictionary = conditions.schedule(snapshot_sequence, now_ms)
			if not bool(schedule.dropped):
				packets.append({"delivery_ms": schedule.delivery_ms, "sent_ms": now_ms, "seq": snapshot_sequence, "position": host_position, "velocity": host_velocity})
		var remaining: Array = []
		for packet: Dictionary in packets:
			if int(packet.delivery_ms) <= now_ms:
				if int(packet.seq) <= last_snapshot:
					continue
				last_snapshot = int(packet.seq)
				snapshot_buffer.push(int(packet.sent_ms), packet.position, packet.velocity, 0.0)
			else:
				remaining.append(packet)
		packets = remaining
		var buffered: Dictionary = snapshot_buffer.sample(now_ms - REMOTE_INTERPOLATION_DELAY_MS)
		if buffered.is_empty():
			replica_position = OnlineInputScript.predict_replica_position(replica_position, replica_velocity, FIXED_DELTA)
		else:
			var reconciled: Vector3 = OnlineInputScript.reconcile_position(replica_position, buffered.position, false)
			corrections.append(replica_position.distance_to(reconciled))
			replica_position = reconciled
			replica_velocity = buffered.velocity
	corrections.sort()
	return {
		"maximum_correction_m": corrections.back() if not corrections.is_empty() else INF,
		"p95_correction_m": _percentile(corrections, 0.95),
		"final_error_m": replica_position.distance_to(host_position),
	}


static func _simulate_with_render_rate(duration_seconds: float, render_rate: int) -> Vector3:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var accumulator := 0.0
	var frame_delta := 1.0 / float(render_rate)
	for frame in roundi(duration_seconds * float(render_rate)):
		accumulator += frame_delta
		while accumulator + 0.000001 >= FIXED_DELTA:
			var step: Dictionary = OnlineInputScript.predict_player_state(position, velocity, Vector2.RIGHT, FIXED_DELTA, 1.0)
			position = step.position
			velocity = step.velocity
			accumulator -= FIXED_DELTA
	return position


static func _initial_command_state() -> Dictionary:
	return {"position": Vector3.ZERO, "velocity": Vector3.ZERO, "rotation": 0.0, "dash_cooldown": 0.0, "dash_remaining": 0.0, "dash_direction": Vector3.RIGHT}


static func _trace_input(time_seconds: float) -> Vector2:
	if time_seconds < 3.0:
		return Vector2.RIGHT
	if time_seconds < 5.0:
		return Vector2.DOWN
	if time_seconds < 7.0:
		return Vector2.LEFT
	if time_seconds < 9.0:
		return Vector2.UP
	return Vector2.ZERO


static func _percentile(sorted_samples: Array[float], ratio: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(ceili(float(sorted_samples.size()) * ratio) - 1, 0, sorted_samples.size() - 1)
	return sorted_samples[index]
