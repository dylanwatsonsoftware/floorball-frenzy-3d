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
