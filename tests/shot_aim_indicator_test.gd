extends SceneTree


func _init() -> void:
	var indicator := load("res://scripts/presentation/shot_aim_indicator.gd")
	if indicator == null:
		fail("Charged-shot aim indicator model is missing")
		return
	var early: Dictionary = indicator.for_charge(0.1)
	var half: Dictionary = indicator.for_charge(0.5)
	var full: Dictionary = indicator.for_charge(1.0)
	if early.length >= half.length or half.length >= full.length:
		fail("The aiming arrow must grow longer as shot power increases")
		return
	if early.width >= half.width or half.width >= full.width:
		fail("The aiming arrow must grow thicker as shot power increases")
		return
	if full.color.r <= early.color.r or full.color.g >= early.color.g:
		fail("The aiming arrow must shift from warm yellow toward urgent red at full charge")
		return
	if early.color.a <= 0.2 or full.color.a >= 0.9:
		fail("The aiming arrow must remain readable but translucent throughout charging")
		return
	var held: Dictionary = indicator.for_charge(1.5)
	if not is_equal_approx(held.length, full.length) or not held.color.is_equal_approx(full.color):
		fail("The aiming arrow must remain stable at full power while Shoot stays held")
		return
	print("Charged-shot aiming indicator is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
