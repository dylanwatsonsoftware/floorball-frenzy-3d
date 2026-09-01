extends SceneTree


func _init() -> void:
	var slap := load("res://scripts/simulation/stick_slap.gd")
	if slap == null:
		fail("Stick slap simulation is missing")
		return
	if slap.phase_at(0.05) != &"backswing":
		fail("A slap must begin with a backswing")
		return
	if slap.phase_at(slap.BACKSWING_SECONDS + 0.02) != &"forward":
		fail("Backswing must transition into a forward swing")
		return
	if not slap.crossed_contact(slap.CONTACT_SECONDS - 0.01, slap.CONTACT_SECONDS + 0.01):
		fail("The forward swing must emit one deterministic contact crossing")
		return
	if slap.crossed_contact(slap.CONTACT_SECONDS + 0.01, slap.CONTACT_SECONDS + 0.03):
		fail("Contact must not repeat after the blade passes the ball")
		return
	if slap.angle_at(0.0) >= 0.0 or absf(slap.angle_at(slap.CONTACT_SECONDS)) > 0.01 or slap.angle_at(slap.CONTACT_SECONDS + 0.02) <= 0.0:
		fail("The stick must meet the carried ball at neutral angle before following through")
		return
	print("Stick slap timing is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
