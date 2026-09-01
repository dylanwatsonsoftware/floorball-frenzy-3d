extends SceneTree


func _init() -> void:
	var feedback := load("res://scripts/presentation/shot_charge_feedback.gd")
	if feedback == null:
		fail("Shot charge feedback model is missing")
		return
	var charging: Dictionary = feedback.for_charge(0.5)
	if charging.label != "SHOT 50%" or charging.state != &"charging":
		fail("Normal charge must show readable progress")
		return
	var perfect: Dictionary = feedback.for_charge(1.0)
	if perfect.label != "SHOT 100%" or perfect.state != &"ready":
		fail("Full charge feedback must describe a reliable ready shot without a timing minigame")
		return
	var overcharged: Dictionary = feedback.for_charge(1.5)
	if overcharged.label != "SHOT 100%" or overcharged.state != &"ready":
		fail("Holding after full charge must remain clearly ready instead of implying a weaker shot")
		return
	print("Shot charge feedback is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
