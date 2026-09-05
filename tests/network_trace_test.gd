extends SceneTree


func _init() -> void:
	var trace_script = load("res://scripts/network/network_trace.gd")
	if trace_script == null:
		fail("Repeatable network diagnosis needs a portable trace recorder")
		return
	var trace = trace_script.new(4)
	var command := {"seq": 1, "tick": 20, "move": Vector2.RIGHT, "facing": Vector2.RIGHT, "dash_pressed": false, "delta": 0.1, "speed_multiplier": 1.0}
	trace.record_command(command, 1000)
	trace.record_snapshot({"seq": 8, "input_ack": 1, "actors": [{"id": "blue_1", "p": [0.42, 0.75, 0.0], "v": [4.2, 0.0, 0.0]}], "ball": [1.0, 0.22, 0.0]}, 1080)
	var encoded: String = trace.to_json()
	var restored = trace_script.from_json(encoded)
	if restored == null or restored.entry_count() != 2:
		fail("Network traces must survive a JSON round trip; encoded=%s" % encoded)
		return
	var replayed: Dictionary = restored.replay_commands({"position": Vector3.ZERO, "velocity": Vector3.ZERO, "rotation": 0.0, "dash_cooldown": 0.0, "dash_remaining": 0.0, "dash_direction": Vector3.RIGHT})
	if not replayed.position.is_equal_approx(Vector3(0.42, 0.0, 0.0)) or not replayed.velocity.is_equal_approx(Vector3(4.2, 0.0, 0.0)):
		fail("Imported commands must replay through the shared player simulation; got %s" % replayed)
		return
	for sequence in range(2, 7):
		var next_command := command.duplicate()
		next_command.seq = sequence
		trace.record_command(next_command, 1000 + sequence)
	if trace.entry_count() != 4 or int(trace.entries()[0].data.seq) != 3:
		fail("Long captures must remain bounded while retaining the newest evidence; got %s" % trace.entries())
		return
	print("Portable network traces round-trip and replay deterministically.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
