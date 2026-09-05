extends SceneTree


func _init() -> void:
	var controllers := [
		"res://scripts/gameplay/player_controller.gd",
		"res://scripts/gameplay/opponent_controller.gd",
		"res://scripts/gameplay/squad_ai_controller.gd",
		"res://scripts/gameplay/goalkeeper_controller.gd",
	]
	for path in controllers:
		var source := FileAccess.get_file_as_string(path)
		if not source.contains("PlayerMotorScript.step_command_state"):
			fail("Every authoritative player wrapper must execute the shared command simulation; missing in %s" % path)
			return
		if source.contains("PlayerMotorScript.step_velocity"):
			fail("Authoritative wrappers must not retain a divergent velocity-only movement path; found in %s" % path)
			return
	print("All authoritative actor wrappers use the shared deterministic command simulation.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
