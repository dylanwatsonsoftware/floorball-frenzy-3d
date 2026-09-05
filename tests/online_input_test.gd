extends SceneTree


func _init() -> void:
	var controller := load("res://scripts/network/online_input.gd")
	if controller == null or not controller.has_method("compose_movement_input"):
		fail("Online input needs a shared keyboard-and-touch movement composer")
		return
	var touch_only: Vector2 = controller.compose_movement_input(Vector2.ZERO, Vector2(0.65, -0.4))
	if not touch_only.is_equal_approx(Vector2(0.65, -0.4)):
		fail("A guest's mobile joystick movement must be included in network input; got %s" % touch_only)
		return
	var combined: Vector2 = controller.compose_movement_input(Vector2.RIGHT, Vector2.DOWN)
	if not is_equal_approx(combined.length(), 1.0) or combined.x <= 0.0 or combined.y <= 0.0:
		fail("Combined guest inputs must retain both directions and clamp to unit length; got %s" % combined)
		return
	var predicted: Vector3 = controller.predict_position(Vector3(2.0, 0.75, 3.0), Vector2.RIGHT, 0.1, 9.0)
	if not predicted.is_equal_approx(Vector3(2.9, 0.75, 3.0)):
		fail("Guest movement should be predicted immediately while awaiting the host; got %s" % predicted)
		return
	var shared_step: Dictionary = controller.predict_player_state(Vector3(2.0, 0.75, 3.0), Vector3.ZERO, Vector2.RIGHT, 0.1, 1.0)
	if not shared_step.position.is_equal_approx(Vector3(2.32, 0.75, 3.0)) or not shared_step.velocity.is_equal_approx(Vector3(3.2, 0.0, 0.0)):
		fail("Guest prediction must use PlayerMotor acceleration instead of jumping directly to maximum speed; got %s" % shared_step)
		return
	var local_reconciled: Vector3 = controller.reconcile_position(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), true)
	var remote_reconciled: Vector3 = controller.reconcile_position(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), false)
	if local_reconciled.x >= remote_reconciled.x or local_reconciled.x <= 0.0:
		fail("Local prediction must receive gentler correction than remote interpolation; local=%s remote=%s" % [local_reconciled, remote_reconciled])
		return
	var tiny_correction: Vector3 = controller.reconcile_position(Vector3.ZERO, Vector3(0.2, 0.0, 0.0), true)
	if not tiny_correction.is_zero_approx():
		fail("Tiny authoritative differences should stay inside a prediction dead zone instead of causing micro-stutter; got %s" % tiny_correction)
		return
	var predicted_heading := deg_to_rad(90.0)
	var delayed_heading := deg_to_rad(20.0)
	var steering_heading: float = controller.reconcile_rotation(predicted_heading, delayed_heading, true, true)
	if not is_equal_approx(steering_heading, predicted_heading):
		fail("An actively steering guest must keep its predicted heading instead of being turned back by a delayed snapshot")
		return
	var remote_heading: float = controller.reconcile_rotation(0.0, deg_to_rad(90.0), false, false)
	if remote_heading <= 0.0 or remote_heading >= deg_to_rad(90.0):
		fail("Remote character turns should be visibly smoothed toward the authoritative heading")
		return
	var replica_step: Vector3 = controller.predict_replica_position(Vector3(2.0, 0.75, 3.0), Vector3(6.0, 0.0, -3.0), 1.0 / 60.0)
	if not replica_step.is_equal_approx(Vector3(2.1, 0.75, 2.95)):
		fail("Remote replicas should continue along their last authoritative velocity between snapshots; got %s" % replica_step)
		return
	var stalled_step: Vector3 = controller.predict_replica_position(Vector3.ONE, Vector3(40.0, 0.0, 0.0), 0.2)
	if stalled_step.distance_to(Vector3.ONE) > 2.01:
		fail("Replica prediction must be bounded after a long frame so it cannot create a large visual jump")
		return
	var tiny_ball_error: Vector3 = controller.reconcile_ball_position(Vector3.ZERO, Vector3(0.12, 0.0, 0.0))
	if not tiny_ball_error.is_zero_approx():
		fail("Small ball prediction errors should stay in a dead zone instead of making the ball wobble")
		return
	var moderate_ball_error: Vector3 = controller.reconcile_ball_position(Vector3.ZERO, Vector3(0.8, 0.0, 0.0))
	if moderate_ball_error.x <= 0.0 or moderate_ball_error.x >= 0.4:
		fail("Moderate ball errors should correct gently; got %s" % moderate_ball_error)
		return
	var pending_inputs: Array = [
		{"seq": 7, "move": Vector2.RIGHT, "delta": 0.1, "speed": 9.0},
		{"seq": 8, "move": Vector2.DOWN, "delta": 0.1, "speed": 9.0},
	]
	var unacknowledged: Array = controller.discard_acknowledged_inputs(pending_inputs, 7)
	if unacknowledged.size() != 1 or int(unacknowledged[0].seq) != 8:
		fail("A guest must retain only inputs newer than the host acknowledgement")
		return
	var replayed_position: Vector3 = controller.replay_inputs(Vector3.ZERO, unacknowledged)
	if not replayed_position.is_equal_approx(Vector3(0.0, 0.0, 0.9)):
		fail("Unacknowledged guest inputs must replay over the host position; got %s" % replayed_position)
		return
	var shared_pending_inputs: Array = [
		{"seq": 7, "move": Vector2.RIGHT, "delta": 0.1, "speed_multiplier": 1.0},
		{"seq": 8, "move": Vector2.RIGHT, "delta": 0.1, "speed_multiplier": 1.0},
	]
	var replayed_state: Dictionary = controller.replay_player_inputs(Vector3.ZERO, Vector3.ZERO, shared_pending_inputs)
	if not replayed_state.position.is_equal_approx(Vector3(0.96, 0.0, 0.0)) or not replayed_state.velocity.is_equal_approx(Vector3(6.4, 0.0, 0.0)):
		fail("Guest replay must reproduce consecutive authoritative PlayerMotor steps; got %s" % replayed_state)
		return
	var braking_state: Dictionary = controller.predict_player_state(Vector3.ZERO, Vector3(9.0, 0.0, 0.0), Vector2.ZERO, 0.1, 1.0)
	if not braking_state.velocity.is_equal_approx(Vector3(6.6, 0.0, 0.0)):
		fail("Guest prediction must reproduce authoritative deceleration when input stops; got %s" % braking_state)
		return
	var clock_offset_ms: float = controller.estimate_clock_offset_ms(1120, 1000, 80.0)
	if not is_equal_approx(clock_offset_ms, 80.0):
		fail("Snapshot timing must account for half the measured round trip when aligning host and guest clocks")
		return
	var packet_age: float = controller.snapshot_age_seconds(1160, 1000, clock_offset_ms)
	if not is_equal_approx(packet_age, 0.08):
		fail("Snapshot age should be derived from its host timestamp and estimated clock offset; got %s" % packet_age)
		return
	var capped_age: float = controller.snapshot_age_seconds(2000, 1000, clock_offset_ms)
	if capped_age > 0.1501:
		fail("Old packet projection must be capped so delay spikes cannot launch replicas ahead")
		return
	if not is_equal_approx(controller.packet_loss_percent(95, 5), 5.0):
		fail("Connection diagnostics must calculate snapshot packet loss")
		return
	var diagnostic: String = controller.connection_diagnostic_text(84.4, 3.2)
	if diagnostic != "84 ms · 3.2% LOSS · WEBRTC":
		fail("Connection diagnostics should be compact and readable in-game; got '%s'" % diagnostic)
		return
	if controller.next_action_sequence(4, false) != 4 or controller.next_action_sequence(4, true) != 5:
		fail("Discrete online actions need persistent sequence numbers so unreliable packets can be repeated safely")
		return
	if not is_equal_approx(controller.prediction_speed(false), 9.0) or not is_equal_approx(controller.prediction_speed(true), 7.92):
		fail("Guest prediction must use the same carrier speed penalty as the host simulation")
		return
	var constants: Dictionary = controller.get_script_constant_map()
	if not constants.has("DEFAULT_SNAPSHOT_SECONDS") or float(constants.get("DEFAULT_SNAPSHOT_SECONDS", 1.0)) > 1.0 / 30.0 + 0.0001:
		fail("Online snapshots should update at least 30 times per second to avoid visible remote stutter")
		return
	print("Online movement packets include keyboard and mobile joystick input.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
