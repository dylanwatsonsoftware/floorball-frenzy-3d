extends SceneTree


func _init() -> void:
	var one_touch := load("res://scripts/simulation/one_touch.gd")
	if one_touch == null:
		fail("One-touch timing model is missing")
		return
	if not one_touch.is_eligible(&"blue", 0.20, &"red"):
		fail("A player must earn one-touch within 300 ms of the opponent's touch")
		return
	if one_touch.is_eligible(&"blue", 0.31, &"red"):
		fail("One-touch eligibility must expire after the original 300 ms window")
		return
	if one_touch.is_eligible(&"red", 0.10, &"red"):
		fail("A player's own previous touch must not create a one-touch bonus")
		return
	if one_touch.actor_for_controller(0) != &"red" or one_touch.actor_for_controller(1) != &"blue":
		fail("Ball controller indices must map deterministically to both teams")
		return
	print("One-touch timing is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
