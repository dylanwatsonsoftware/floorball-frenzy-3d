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
	if perfect.label != "PERFECT!" or perfect.state != &"perfect":
		fail("The sweet spot must have unmistakable perfect-shot feedback")
		return
	var overcharged: Dictionary = feedback.for_charge(1.5)
	if overcharged.label != "OVERCHARGE 50%" or overcharged.state != &"overcharged":
		fail("Overcharge feedback must show the remaining power")
		return
	print("Shot charge feedback is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
