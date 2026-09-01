class_name ShotChargeFeedback
extends RefCounted

const BallSimulationScript = preload("res://scripts/simulation/ball_simulation.gd")
const CHARGING_COLOR := Color("ffa31a")
const PERFECT_COLOR := Color("fff1a8")
const OVERCHARGED_COLOR := Color("ff526d")


static func for_charge(normalized_charge: float) -> Dictionary:
	var charge := clampf(normalized_charge, 0.0, 2.0)
	if BallSimulationScript.is_perfect_charge(charge):
		return {"label": "PERFECT!", "state": &"perfect", "color": PERFECT_COLOR}
	if charge > 1.0:
		var remaining_power := roundi((2.0 - charge) * 100.0)
		return {"label": "OVERCHARGE %d%%" % remaining_power, "state": &"overcharged", "color": OVERCHARGED_COLOR}
	return {"label": "SHOT %d%%" % roundi(charge * 100.0), "state": &"charging", "color": CHARGING_COLOR}
