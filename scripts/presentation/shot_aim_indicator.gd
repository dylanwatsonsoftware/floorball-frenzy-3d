class_name ShotAimIndicator
extends RefCounted

const MIN_LENGTH := 1.15
const MAX_LENGTH := 3.8
const MIN_WIDTH := 0.1
const MAX_WIDTH := 0.28
const LOW_COLOR := Color(0.86, 0.82, 0.2, 0.38)
const FULL_COLOR := Color(1.0, 0.18, 0.08, 0.72)


static func for_charge(normalized_charge: float) -> Dictionary:
	var charge := clampf(normalized_charge, 0.0, 1.0)
	var eased := charge * charge * (3.0 - 2.0 * charge)
	return {
		"length": lerpf(MIN_LENGTH, MAX_LENGTH, eased),
		"width": lerpf(MIN_WIDTH, MAX_WIDTH, eased),
		"color": LOW_COLOR.lerp(FULL_COLOR, eased),
	}
