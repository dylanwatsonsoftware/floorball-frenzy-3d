extends SceneTree


func _init() -> void:
	var harness_script = load("res://scripts/network/network_prediction_harness.gd")
	if harness_script == null:
		fail("Guest prediction needs a repeatable end-to-end quality harness")
		return
	for seed in range(1, 21):
		var quality: Dictionary = harness_script.run_profile(&"quality_gate", 12.0, seed)
		if float(quality.get("maximum_correction_m", INF)) > 0.30:
			fail("Quality-gate prediction corrections must stay under 30 cm for every seed; seed=%d result=%s" % [seed, quality])
			return
		if float(quality.get("p95_correction_m", INF)) > 0.20:
			fail("95%% of quality-gate prediction corrections must stay under 20 cm; seed=%d result=%s" % [seed, quality])
			return
		if float(quality.get("final_error_m", INF)) > 0.15:
			fail("Guest and host must converge after the input trace ends; seed=%d result=%s" % [seed, quality])
			return
		if int(quality.get("snap_count", 1)) != 0:
			fail("The 150 ms / 2%% loss quality gate must not require hard player snaps; seed=%d result=%s" % [seed, quality])
			return
	for seed in range(1, 21):
		var dash_quality: Dictionary = harness_script.run_dash_profile(&"quality_gate", seed)
		if not bool(dash_quality.get("predicted_immediately", false)):
			fail("Guest dash input must react locally before the host round trip; seed=%d result=%s" % [seed, dash_quality])
			return
		if float(dash_quality.get("maximum_correction_m", INF)) > 0.30 or float(dash_quality.get("final_error_m", INF)) > 0.15 or int(dash_quality.get("snap_count", 1)) != 0:
			fail("Guest dashes must reconcile without routine snaps at 150 ms RTT / 2%% loss; seed=%d result=%s" % [seed, dash_quality])
			return
	var degraded: Dictionary = harness_script.run_profile(&"degraded", 12.0, 17)
	if float(degraded.get("maximum_correction_m", INF)) > 0.65 or int(degraded.get("snap_count", 1)) != 0 or float(degraded.get("final_error_m", INF)) > 0.30:
		fail("A 250 ms / 5%% loss connection should degrade gently and recover without hard snaps; got %s" % degraded)
		return
	for seed in range(1, 11):
		var remote: Dictionary = harness_script.run_remote_profile(&"quality_gate", 12.0, seed)
		if float(remote.get("maximum_correction_m", INF)) > 0.30 or float(remote.get("p95_correction_m", INF)) > 0.20:
			fail("Remote players must not jump between jittered snapshots; seed=%d result=%s" % [seed, remote])
			return
		if float(remote.get("final_error_m", INF)) > 0.20:
			fail("Remote replicas must converge after movement ends; seed=%d result=%s" % [seed, remote])
			return
	var frame_rates: Dictionary = harness_script.compare_frame_rates(10.0)
	if float(frame_rates.get("distance_m", INF)) > 0.02:
		fail("A fixed simulation tick must produce equivalent movement at 30 and 60 render FPS; got %s" % frame_rates)
		return
	print("Guest prediction passes the repeatable 150 ms RTT / 2% loss quality gate.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
