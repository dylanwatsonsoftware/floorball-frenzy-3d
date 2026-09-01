extends SceneTree


func _init() -> void:
	var feedback := load("res://scripts/presentation/shot_impact_feedback.gd")
	if feedback == null:
		fail("Shot impact feedback model is missing")
		return
	var normal: Dictionary = feedback.for_charge(0.5)
	var perfect: Dictionary = feedback.for_charge(1.0)
	var overcharged: Dictionary = feedback.for_charge(1.6)
	var bolt: Dictionary = feedback.for_charge(0.5, true)
	if normal.scale >= perfect.scale or normal.kick >= perfect.kick:
		fail("Perfect contact must create the strongest impact feedback")
		return
	if perfect.color.g <= perfect.color.r or perfect.color.b <= perfect.color.r:
		fail("Perfect contact must use a bright cool-colored flash")
		return
	if overcharged.scale >= perfect.scale or overcharged.kick >= perfect.kick:
		fail("Overcharged contact must lose impact feedback with shot power")
		return
	if normal.duration <= 0.0 or perfect.duration <= 0.0:
		fail("Impact feedback must have a visible lifetime")
		return
	if bolt.color.b <= bolt.color.r or bolt.kick <= normal.kick:
		fail("Bolt contact must create a stronger electric-blue impact")
		return
	print("Shot impact feedback is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
