extends SceneTree


func _init() -> void:
	var harness_script = load("res://scripts/network/network_prediction_harness.gd")
	if harness_script == null:
		fail("Guest prediction needs a repeatable end-to-end quality harness")
		return
	var quality: Dictionary = harness_script.run_profile(&"quality_gate", 12.0, 11)
	if float(quality.get("maximum_correction_m", INF)) > 0.30:
		fail("Quality-gate prediction corrections must stay under 30 cm; got %s" % quality)
		return
	if float(quality.get("p95_correction_m", INF)) > 0.20:
		fail("95%% of quality-gate prediction corrections must stay under 20 cm; got %s" % quality)
		return
	if float(quality.get("final_error_m", INF)) > 0.15:
		fail("Guest and host must converge after the input trace ends; got %s" % quality)
		return
	if int(quality.get("snap_count", 1)) != 0:
		fail("The 150 ms / 2%% loss quality gate must not require hard player snaps; got %s" % quality)
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
