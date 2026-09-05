extends SceneTree


func _init() -> void:
	var harness = load("res://scripts/network/network_ball_prediction_harness.gd")
	if harness == null:
		fail("Ball prediction needs the same repeatable latency/loss validation as player movement")
		return
	for action_type in [&"pass", &"shot"]:
		for seed in range(1, 11):
			var result: Dictionary = harness.run_profile(&"quality_gate", action_type, seed)
			if float(result.get("maximum_correction_m", INF)) > 0.30 or float(result.get("p95_correction_m", INF)) > 0.20:
				fail("Guest %s corrections exceed the quality gate; seed=%d result=%s" % [action_type, seed, result])
				return
			if float(result.get("final_error_m", INF)) > 0.20:
				fail("Guest %s prediction must converge with the host; seed=%d result=%s" % [action_type, seed, result])
				return
			if int(result.get("reattach_count", 1)) != 0:
				fail("Guest %s prediction must never reattach from a stale possession snapshot; seed=%d result=%s" % [action_type, seed, result])
				return
	print("Guest pass and shot prediction pass the 150 ms RTT / 2% loss quality gate.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
