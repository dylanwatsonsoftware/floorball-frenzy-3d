extends SceneTree


func _init() -> void:
	var command_script = load("res://scripts/simulation/player_command.gd")
	if command_script == null:
		fail("Shared solo/host/guest input needs an explicit PlayerCommand")
		return
	var command = command_script.create(12, 340, Vector2(0.8, -0.2), Vector2.RIGHT, true, 4, 7, 3, true)
	var packet: Dictionary = command.to_network_packet(12345, 84.0)
	for key in ["seq", "tick", "move", "facing", "shoot", "pass_seq", "switch_seq", "dash_seq"]:
		if not packet.has(key):
			fail("PlayerCommand network packet is missing %s; got %s" % [key, packet])
			return
	var simulation: Dictionary = command.to_simulation_step(1.0 / 60.0, 1.08)
	if simulation.move != Vector2(0.8, -0.2) or simulation.facing != Vector2.RIGHT or not simulation.dash_pressed:
		fail("PlayerCommand must feed the same movement, facing, and action edge into prediction and authority; got %s" % simulation)
		return
	if int(command.sequence) != 12 or int(command.simulation_tick) != 340 or not bool(command.shoot_held) or int(command.pass_sequence) != 4 or int(command.switch_sequence) != 7:
		fail("PlayerCommand must retain all ticked action fields")
		return
	print("PlayerCommand carries the complete tick-based human input contract.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
