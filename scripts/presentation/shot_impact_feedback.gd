class_name ShotImpactFeedback
extends RefCounted

const BallSimulationScript = preload("res://scripts/simulation/ball_simulation.gd")
const NORMAL_COLOR := Color("ff7424")
const PERFECT_COLOR := Color("70f7ff")
const OVERCHARGED_COLOR := Color("ff426d")


static func for_charge(normalized_charge: float) -> Dictionary:
	var charge := clampf(normalized_charge, 0.0, 2.0)
	var power_fraction := charge if charge <= 1.0 else 2.0 - charge
	var perfect := BallSimulationScript.is_perfect_charge(charge)
	var strength := clampf(0.35 + power_fraction * 0.65, 0.35, 1.0)
	if perfect:
		strength = 1.12
	var color := NORMAL_COLOR
	if perfect:
		color = PERFECT_COLOR
	elif charge > 1.0:
		color = OVERCHARGED_COLOR
	return {
		"scale": lerpf(0.8, 2.15, strength),
		"kick": lerpf(0.018, 0.075, strength),
		"duration": lerpf(0.16, 0.26, strength),
		"color": color,
	}
