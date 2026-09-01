extends SceneTree


func _init() -> void:
	var heat_system := load("res://scripts/simulation/heat_system.gd")
	if heat_system == null:
		fail("Heat simulation is missing")
		return
	var gained: Dictionary = heat_system.add_heat(40.0, 0.0, 30.0)
	if not is_equal_approx(gained.heat, 70.0) or gained.activated:
		fail("Heat rewards must accumulate without activating early")
		return
	var decayed: Dictionary = heat_system.step(gained.heat, gained.fuego_remaining, 2.0)
	if not is_equal_approx(decayed.heat, 66.0):
		fail("Inactive heat must decay at the original two points per second")
		return
	var activated: Dictionary = heat_system.add_heat(80.0, 0.0, 30.0)
	if activated.heat != 100.0 or not activated.activated or not is_equal_approx(activated.fuego_remaining, 8.0):
		fail("Reaching 100 heat must activate the original eight-second En Fuego state")
		return
	var ignored: Dictionary = heat_system.add_heat(activated.heat, activated.fuego_remaining, 50.0)
	if ignored.heat != 100.0 or ignored.activated:
		fail("Heat rewards must not retrigger while already En Fuego")
		return
	var active_step: Dictionary = heat_system.step(100.0, 8.0, 3.0)
	if active_step.heat != 100.0 or not is_equal_approx(active_step.fuego_remaining, 5.0):
		fail("Heat must stay full while the powered timer counts down")
		return
	var expired: Dictionary = heat_system.step(active_step.heat, active_step.fuego_remaining, 5.0)
	if expired.heat != 0.0 or expired.fuego_remaining != 0.0:
		fail("Heat must reset when En Fuego expires")
		return
	if not is_equal_approx(heat_system.speed_multiplier(1.0), 1.2) or heat_system.speed_multiplier(0.0) != 1.0:
		fail("En Fuego must apply the original 20% movement-speed boost")
		return
	print("Heat and En Fuego simulation is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
