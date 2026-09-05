extends SceneTree


func _init() -> void:
	var metrics_script = load("res://scripts/network/network_diagnostics.gd")
	if metrics_script == null:
		fail("Network diagnostics need a reusable metrics collector")
		return
	var metrics = metrics_script.new()
	metrics.record_frame(1.0 / 60.0)
	metrics.record_frame(1.0 / 30.0)
	metrics.record_round_trip(100.0)
	metrics.record_round_trip(140.0)
	metrics.record_snapshot_sequence(10)
	metrics.record_snapshot_sequence(12)
	metrics.record_snapshot_age(0.08)
	metrics.record_prediction_error(0.24, 0.42)
	var report: Dictionary = metrics.report()
	if absf(float(report.get("fps", 0.0)) - 40.0) > 0.01:
		fail("Diagnostics must report average frame rate; got %s" % report)
		return
	if absf(float(report.get("rtt_ms", 0.0)) - 120.0) > 0.01:
		fail("Diagnostics must report average round-trip time; got %s" % report)
		return
	if absf(float(report.get("jitter_ms", 0.0)) - 20.0) > 0.01:
		fail("Diagnostics must expose round-trip variation; got %s" % report)
		return
	if absf(float(report.get("loss_percent", 0.0)) - (100.0 / 3.0)) > 0.01:
		fail("A missing snapshot sequence must be reflected in packet loss; got %s" % report)
		return
	if not is_equal_approx(float(report.get("snapshot_age_ms", 0.0)), 80.0):
		fail("Diagnostics must expose snapshot age in milliseconds; got %s" % report)
		return
	if not is_equal_approx(float(report.get("player_error_m", 0.0)), 0.24) or not is_equal_approx(float(report.get("ball_error_m", 0.0)), 0.42):
		fail("Diagnostics must expose player and ball prediction errors; got %s" % report)
		return

	var conditions_script = load("res://scripts/network/network_condition_simulator.gd")
	if conditions_script == null:
		fail("Network testing needs a deterministic condition simulator")
		return
	var conditions = conditions_script.new(150, 0.02, 30, 7)
	var first: Dictionary = conditions.schedule(1, 1000)
	var repeated: Dictionary = conditions.schedule(1, 1000)
	if first != repeated:
		fail("Network conditions must be deterministic so a failing trace can be replayed")
		return
	if int(first.get("delivery_ms", 0)) < 1045 or int(first.get("delivery_ms", 0)) > 1105:
		fail("A 150 ms RTT profile should apply roughly 75 ms one-way delay plus bounded jitter; got %s" % first)
		return
	var quality_profile: Dictionary = conditions_script.profile(&"quality_gate")
	if quality_profile.get("rtt_ms") != 150 or quality_profile.get("loss_percent") != 2.0 or quality_profile.get("jitter_ms") != 30:
		fail("The quality-gate profile must match the roadmap validation matrix; got %s" % quality_profile)
		return
	print("Network diagnostics and deterministic condition profiles are available.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
