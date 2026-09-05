class_name OnlineInput
extends RefCounted

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const DEFAULT_SNAPSHOT_SECONDS := 1.0 / 30.0
const MAX_REPLICA_PREDICTION_STEP := 0.05
const MAX_SNAPSHOT_AGE_SECONDS := 0.15
const MAX_BALL_CORRECTION_PER_SNAPSHOT := 0.28
const MAX_REMOTE_CORRECTION_PER_SNAPSHOT := 0.28
const REMOTE_ROTATION_RESPONSE := 12.0


static func compose_movement_input(keyboard_or_controller: Vector2, mobile_joystick: Vector2) -> Vector2:
	return (keyboard_or_controller + mobile_joystick).limit_length(1.0)


static func predict_position(current: Vector3, movement: Vector2, delta: float, speed: float) -> Vector3:
	return current + Vector3(movement.x, 0.0, movement.y).limit_length(1.0) * speed * maxf(delta, 0.0)


static func predict_player_state(position: Vector3, velocity: Vector3, movement: Vector2, delta: float, speed_multiplier: float) -> Dictionary:
	var step_delta := maxf(delta, 0.0)
	var next_velocity: Vector3 = PlayerMotorScript.step_velocity(velocity, movement, step_delta, speed_multiplier)
	return {"position": position + next_velocity * step_delta, "velocity": next_velocity}


static func predict_replica_position(current: Vector3, authoritative_velocity: Vector3, delta: float) -> Vector3:
	return current + authoritative_velocity * clampf(delta, 0.0, MAX_REPLICA_PREDICTION_STEP)


static func reconcile_position(current: Vector3, authoritative: Vector3, locally_predicted: bool) -> Vector3:
	var error := current.distance_to(authoritative)
	if locally_predicted and error < 0.06:
		return current
	if locally_predicted:
		return current.lerp(authoritative, 0.1 if error < 2.5 else 0.72)
	var correction := (authoritative - current) * 0.72
	return current + correction.limit_length(MAX_REMOTE_CORRECTION_PER_SNAPSHOT)


static func reconcile_ball_position(current: Vector3, authoritative: Vector3) -> Vector3:
	var error := current.distance_to(authoritative)
	if error < 0.18:
		return current
	var weight := 0.18 if error < 1.2 else 0.72
	var correction := (authoritative - current) * weight
	return current + correction.limit_length(MAX_BALL_CORRECTION_PER_SNAPSHOT)


static func discard_acknowledged_inputs(inputs: Array, acknowledged_sequence: int) -> Array:
	var remaining: Array = []
	for input: Dictionary in inputs:
		if int(input.get("seq", -1)) > acknowledged_sequence:
			remaining.append(input)
	return remaining


static func replay_inputs(authoritative_position: Vector3, inputs: Array) -> Vector3:
	var replayed := authoritative_position
	for input: Dictionary in inputs:
		replayed = predict_position(replayed, input.get("move", Vector2.ZERO), float(input.get("delta", 0.0)), float(input.get("speed", 0.0)))
	return replayed


static func replay_player_inputs(authoritative_position: Vector3, authoritative_velocity: Vector3, inputs: Array) -> Dictionary:
	var state := {"position": authoritative_position, "velocity": authoritative_velocity}
	for input: Dictionary in inputs:
		state = predict_player_state(
			state.position,
			state.velocity,
			input.get("move", Vector2.ZERO),
			float(input.get("delta", 0.0)),
			float(input.get("speed_multiplier", 1.0))
		)
	return state


static func estimate_clock_offset_ms(received_at_ms: int, host_sent_at_ms: int, round_trip_ms: float) -> float:
	return float(received_at_ms - host_sent_at_ms) - maxf(0.0, round_trip_ms) * 0.5


static func snapshot_age_seconds(received_at_ms: int, host_sent_at_ms: int, host_to_local_offset_ms: float) -> float:
	var age_ms := float(received_at_ms - host_sent_at_ms) - host_to_local_offset_ms
	return clampf(age_ms / 1000.0, 0.0, MAX_SNAPSHOT_AGE_SECONDS)


static func project_snapshot_position(position: Vector3, velocity: Vector3, age_seconds: float) -> Vector3:
	return position + velocity * clampf(age_seconds, 0.0, MAX_SNAPSHOT_AGE_SECONDS)


static func packet_loss_percent(received_packets: int, missing_packets: int) -> float:
	var total := received_packets + missing_packets
	return 0.0 if total <= 0 else float(missing_packets) / float(total) * 100.0


static func connection_diagnostic_text(round_trip_ms: float, loss_percent: float) -> String:
	return "%d ms · %.1f%% LOSS · WEBRTC" % [roundi(maxf(0.0, round_trip_ms)), clampf(loss_percent, 0.0, 100.0)]


static func reconcile_rotation(current: float, authoritative: float, locally_predicted: bool, actively_steering: bool) -> float:
	if locally_predicted and actively_steering:
		return current
	return lerp_angle(current, authoritative, 0.55)


static func interpolate_remote_rotation(current: float, target: float, delta: float) -> float:
	var weight := 1.0 - exp(-REMOTE_ROTATION_RESPONSE * maxf(delta, 0.0))
	return lerp_angle(current, target, weight)


static func next_action_sequence(current: int, just_pressed: bool) -> int:
	return current + 1 if just_pressed else current


static func prediction_speed(has_ball: bool) -> float:
	return 9.0 * (0.88 if has_ball else 1.0)
