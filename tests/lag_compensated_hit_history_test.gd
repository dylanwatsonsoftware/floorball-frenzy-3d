extends SceneTree


func _init() -> void:
	var history_script = load("res://scripts/network/lag_compensated_hit_history.gd")
	if history_script == null:
		fail("Guest hit validation needs a bounded host transform history")
		return
	var history = history_script.new()
	history.record(1000, &"blue_1", Vector3.ZERO, Vector3.RIGHT, Vector3(0.8, 0.22, 0.0), Vector3(1.25, 0.22, 0.0), &"blue_1")
	history.record(1100, &"blue_1", Vector3(1.0, 0.0, 0.0), Vector3.RIGHT, Vector3(1.8, 0.22, 0.0), Vector3(2.25, 0.22, 0.0), &"blue_1")
	if not history.can_hit(&"blue_1", 1050):
		fail("A delayed guest shot must validate against interpolated blade and ball transforms at contact time")
		return

	var rejected = history_script.new()
	rejected.record(1000, &"blue_1", Vector3.ZERO, Vector3.RIGHT, Vector3(0.8, 0.22, 0.0), Vector3(4.0, 0.22, 0.0), &"")
	if rejected.can_hit(&"blue_1", 1000):
		fail("Lag compensation must not invent contact when the historical ball was outside the blade sweep")
		return
	if history.can_hit(&"blue_1", 600):
		fail("Hit validation must reject requests older than its bounded rewind window")
		return

	for index in 90:
		history.record(1200 + index * 16, &"blue_1", Vector3.ZERO, Vector3.RIGHT, Vector3.ZERO, Vector3.ZERO, &"")
	if history.sample_count() > history_script.MAX_SAMPLES:
		fail("Host transform history must remain bounded for phone and web memory budgets")
		return

	print("Lag-compensated hit history validates delayed contact without false positives.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
