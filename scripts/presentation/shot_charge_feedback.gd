class_name ShotChargeFeedback
extends RefCounted

const CHARGING_COLOR := Color("ffa31a")
const READY_COLOR := Color("fff1a8")


static func for_charge(normalized_charge: float) -> Dictionary:
	var charge := clampf(normalized_charge, 0.0, 1.0)
	return {
		"label": "SHOT %d%%" % roundi(charge * 100.0),
		"state": &"ready" if charge >= 1.0 else &"charging",
		"color": READY_COLOR if charge >= 1.0 else CHARGING_COLOR,
	}
