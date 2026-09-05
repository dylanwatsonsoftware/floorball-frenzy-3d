class_name NetworkBallPredictionHarness
extends RefCounted


const BallSimulationScript = preload("res://scripts/simulation/ball_simulation.gd")
const ConditionsScript = preload("res://scripts/network/network_condition_simulator.gd")
const OnlineInputScript = preload("res://scripts/network/online_input.gd")
const PredictedActionScript = preload("res://scripts/network/predicted_ball_action.gd")
const StickSlapScript = preload("res://scripts/simulation/stick_slap.gd")
const FIXED_DELTA := 1.0 / 60.0


static func run_profile(profile_name: StringName, action_type: StringName, seed: int = 1) -> Dictionary:
	var profile: Dictionary = ConditionsScript.profile(profile_name)
	var one_way_seconds := float(profile.rtt_ms) / 2000.0
	var commands = ConditionsScript.new(int(profile.rtt_ms), float(profile.loss_percent) / 100.0, int(profile.jitter_ms), seed)
	var snapshots = ConditionsScript.new(int(profile.rtt_ms), float(profile.loss_percent) / 100.0, int(profile.jitter_ms), seed + 733)
	var blade_position := Vector3(0.0, BallSimulationScript.BALL_RADIUS, 0.0)
	var direction := Vector2.RIGHT
	var client_action = PredictedActionScript.new()
	client_action.begin(1, action_type, blade_position, direction, Vector3.ZERO, 0.75, action_type == &"shot")
	var host_action: RefCounted
	var host_started := false
	var client_confirmed := false
	var client_position := blade_position
	var client_velocity := Vector3.ZERO
	var host_position := blade_position
	var host_velocity := Vector3.ZERO
	var input_packets: Array = []
	var snapshot_packets: Array = []
	var corrections: Array[float] = []
	var reattach_count := 0
	var rejected_stale_snapshots := 0
	var snapshot_sequence := 0
	var last_received_snapshot := -1
	for tick in 180:
		var now_ms := roundi(float(tick) * FIXED_DELTA * 1000.0)
		if not host_started:
			var command_schedule: Dictionary = commands.schedule(tick + 1, now_ms)
			if not bool(command_schedule.dropped):
				input_packets.append({"delivery_ms": command_schedule.delivery_ms})
		var remaining_inputs: Array = []
		for packet: Dictionary in input_packets:
			if int(packet.delivery_ms) <= now_ms and not host_started:
				host_started = true
				host_action = PredictedActionScript.new()
				host_action.call("begin", 1, action_type, blade_position, direction, Vector3.ZERO, 0.75, false)
				host_action.set("elapsed", StickSlapScript.network_start_elapsed(action_type, one_way_seconds))
			else:
				remaining_inputs.append(packet)
		input_packets = remaining_inputs

		if not client_confirmed:
			var client_state: Dictionary = client_action.step(FIXED_DELTA, blade_position)
			client_position = client_state.position
			client_velocity = client_state.velocity
		else:
			var client_state: Dictionary = BallSimulationScript.step(client_position, client_velocity, FIXED_DELTA)
			client_position = client_state.position
			client_velocity = client_state.velocity
		var host_released := false
		if host_started:
			var host_state: Dictionary = host_action.call("step", FIXED_DELTA, blade_position)
			host_position = host_state.position
			host_velocity = host_state.velocity
			host_released = not bool(host_state.attached)

		if tick % 2 == 0:
			snapshot_sequence += 1
			var schedule: Dictionary = snapshots.schedule(snapshot_sequence, now_ms)
			if not bool(schedule.dropped):
				snapshot_packets.append({
					"delivery_ms": schedule.delivery_ms,
					"sent_ms": now_ms,
					"seq": snapshot_sequence,
					"action_seq": 1 if host_released else 0,
					"ball_state": ("passing" if action_type == &"pass" else "shot") if host_released else "possessed",
					"position": host_position,
					"velocity": host_velocity,
				})
		var remaining_snapshots: Array = []
		for packet: Dictionary in snapshot_packets:
			if int(packet.delivery_ms) <= now_ms:
				if int(packet.seq) <= last_received_snapshot:
					continue
				last_received_snapshot = int(packet.seq)
				if int(packet.action_seq) < 1:
					if not bool(client_action.get("attached")):
						rejected_stale_snapshots += 1
					continue
				if not client_confirmed:
					client_confirmed = true
					client_action.call("finish")
				var packet_age := float(now_ms - int(packet.sent_ms)) / 1000.0
				var projected: Dictionary = BallSimulationScript.step(packet.position, packet.velocity, packet_age)
				var reconciled: Vector3 = OnlineInputScript.reconcile_ball_position(client_position, projected.position)
				corrections.append(client_position.distance_to(reconciled))
				client_position = reconciled
				client_velocity = projected.velocity
			else:
				remaining_snapshots.append(packet)
		snapshot_packets = remaining_snapshots
	corrections.sort()
	return {
		"maximum_correction_m": corrections.back() if not corrections.is_empty() else INF,
		"p95_correction_m": _percentile(corrections, 0.95),
		"final_error_m": client_position.distance_to(host_position),
		"reattach_count": reattach_count,
		"rejected_stale_snapshots": rejected_stale_snapshots,
		"confirmed": client_confirmed,
	}


static func _percentile(sorted_samples: Array[float], ratio: float) -> float:
	if sorted_samples.is_empty():
		return INF
	var index := clampi(ceili(float(sorted_samples.size()) * ratio) - 1, 0, sorted_samples.size() - 1)
	return sorted_samples[index]
