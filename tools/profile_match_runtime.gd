extends SceneTree

const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 360


func _init() -> void:
	call_deferred("profile")


func profile() -> void:
	# Command-line-launched windows can otherwise be treated as background apps and
	# sleep between frames, which measures OS throttling instead of game workload.
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Engine.max_fps = 0
	DisplayServer.window_move_to_foreground()
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var disable_ik := "--disable-ik" in OS.get_cmdline_user_args()
	if disable_ik:
		for actor in scene.get_node("Arena").call("get_field_players"):
			var solvers: Array = (actor.get_node("BodyRig") as Node3D).get("_hand_ik_solvers")
			solvers.clear()
	for frame in WARMUP_FRAMES:
		await process_frame
	var frame_times_ms: Array[float] = []
	var previous_tick := Time.get_ticks_usec()
	for frame in SAMPLE_FRAMES:
		await process_frame
		var current_tick := Time.get_ticks_usec()
		frame_times_ms.append(float(current_tick - previous_tick) / 1000.0)
		previous_tick = current_tick
	frame_times_ms.sort()
	var arena := scene.get_node("Arena")
	var renderer_name := RenderingServer.get_video_adapter_name()
	var result := {
		"players": arena.call("get_field_players").size(),
		"sample_frames": SAMPLE_FRAMES,
		"median_frame_ms": _percentile(frame_times_ms, 0.50),
		"p95_frame_ms": _percentile(frame_times_ms, 0.95),
		"p99_frame_ms": _percentile(frame_times_ms, 0.99),
		"maximum_frame_ms": frame_times_ms[-1],
		"median_fps": 1000.0 / maxf(0.001, _percentile(frame_times_ms, 0.50)),
		"renderer": renderer_name,
		"measurement_scope": "script_animation_cpu" if renderer_name.is_empty() else "presented_frame_cadence",
		"low_processor_mode": OS.low_processor_usage_mode,
		"hand_ik_enabled": not disable_ik,
	}
	var output := JSON.stringify(result, "  ")
	print(output)
	var file := FileAccess.open("/tmp/floorball-runtime-profile.json", FileAccess.WRITE)
	if file != null:
		file.store_string(output + "\n")
	quit(0)


func _percentile(sorted_values: Array[float], percentile: float) -> float:
	var index := clampi(roundi(float(sorted_values.size() - 1) * percentile), 0, sorted_values.size() - 1)
	return sorted_values[index]
