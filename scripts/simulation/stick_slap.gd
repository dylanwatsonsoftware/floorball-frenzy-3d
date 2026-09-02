class_name StickSlap
extends RefCounted

const BACKSWING_SECONDS := 0.20
const FORWARD_SECONDS := 0.16
const RECOVERY_SECONDS := 0.16
const CONTACT_SECONDS := BACKSWING_SECONDS + FORWARD_SECONDS * 0.72
const TOTAL_SECONDS := BACKSWING_SECONDS + FORWARD_SECONDS + RECOVERY_SECONDS
const BACKSWING_ANGLE := -78.0
const CONTACT_ANGLE := 42.0


static func phase_at(elapsed: float) -> StringName:
	if elapsed < BACKSWING_SECONDS:
		return &"backswing"
	if elapsed < BACKSWING_SECONDS + FORWARD_SECONDS:
		return &"forward"
	if elapsed < TOTAL_SECONDS:
		return &"recovery"
	return &"idle"


static func crossed_contact(previous_elapsed: float, current_elapsed: float) -> bool:
	return previous_elapsed < CONTACT_SECONDS and current_elapsed >= CONTACT_SECONDS


static func angle_at(elapsed: float) -> float:
	if elapsed < BACKSWING_SECONDS:
		var t := clampf(elapsed / BACKSWING_SECONDS, 0.0, 1.0)
		return lerpf(-2.0, BACKSWING_ANGLE, t * t)
	if elapsed < BACKSWING_SECONDS + FORWARD_SECONDS:
		if elapsed <= CONTACT_SECONDS:
			var t := clampf((elapsed - BACKSWING_SECONDS) / (CONTACT_SECONDS - BACKSWING_SECONDS), 0.0, 1.0)
			return lerpf(BACKSWING_ANGLE, 0.0, 1.0 - pow(1.0 - t, 2.0))
		var t := clampf((elapsed - CONTACT_SECONDS) / (BACKSWING_SECONDS + FORWARD_SECONDS - CONTACT_SECONDS), 0.0, 1.0)
		return lerpf(0.0, CONTACT_ANGLE, t)
	if elapsed < TOTAL_SECONDS:
		var t := clampf((elapsed - BACKSWING_SECONDS - FORWARD_SECONDS) / RECOVERY_SECONDS, 0.0, 1.0)
		return lerpf(CONTACT_ANGLE, 0.0, t)
	return 0.0
