extends SceneTree


func _init() -> void:
	var dash_steal := load("res://scripts/simulation/dash_steal.gd")
	if dash_steal == null:
		fail("Dash-steal simulation is missing")
		return
	if not dash_steal.can_steal(0, 0, false):
		fail("A dashing player making body contact must be able to steal")
		return
	if not dash_steal.can_steal(1, 1, false):
		fail("The blue AI must use the same physical dash-steal rule")
		return
	if dash_steal.can_steal(-1, 0, false) or dash_steal.can_steal(0, -1, false):
		fail("Dash steals require both a dash and physical ball contact")
		return
	if dash_steal.can_steal(0, 0, true) or dash_steal.can_steal(1, 0, false):
		fail("One dash must not repeatedly poke the same ball")
		return
	var velocity: Vector3 = dash_steal.poke_velocity(Vector3(12.0, 3.0, -4.0))
	if not velocity.is_equal_approx(Vector3(19.2, 0.0, -6.4)):
		fail("Dash steals must use the original 1.6x planar poke force; got %s" % velocity)
		return
	print("Dash-steal simulation is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
