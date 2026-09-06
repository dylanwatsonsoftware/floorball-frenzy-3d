class_name StickSlap
extends RefCounted

const BACKSWING_SECONDS := 0.20
const FORWARD_SECONDS := 0.16
const RECOVERY_SECONDS := 0.16
const CONTACT_SECONDS := BACKSWING_SECONDS + FORWARD_SECONDS * 0.72
const TOTAL_SECONDS := BACKSWING_SECONDS + FORWARD_SECONDS + RECOVERY_SECONDS
const BACKSWING_ANGLE := -82.0
const CONTACT_ANGLE := 42.0
const FORWARD_STEP_DISTANCE := 0.30
const NETWORK_CONTACT_GUARD_SECONDS := 1.0 / 120.0


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


static func forward_step_at(elapsed: float) -> float:
	if elapsed <= BACKSWING_SECONDS:
		return 0.0
	var progress := clampf((elapsed - BACKSWING_SECONDS) / FORWARD_SECONDS, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	return FORWARD_STEP_DISTANCE * eased


static func body_pose_at(elapsed: float) -> Dictionary:
	if elapsed < 0.0 or elapsed >= TOTAL_SECONDS:
		return _body_pose()
	if elapsed <= BACKSWING_SECONDS:
		var load := _smoothstep(elapsed / BACKSWING_SECONDS)
		return _body_pose(0.86 * load, -0.82 * load, -0.48 * load, -0.68 * load, 0.0, 0.0, load, 0.0)
	if elapsed <= CONTACT_SECONDS:
		var drive := _smoothstep((elapsed - BACKSWING_SECONDS) / (CONTACT_SECONDS - BACKSWING_SECONDS))
		return _body_pose(
			lerpf(0.86, 0.48, drive),
			lerpf(-0.82, 0.62, drive),
			lerpf(-0.48, 0.74, drive),
			lerpf(-0.68, 0.52, drive),
			drive,
			0.0,
			1.0 - drive,
			_smoothstep(inverse_lerp(0.72, 1.0, drive))
		)
	if elapsed <= BACKSWING_SECONDS + FORWARD_SECONDS:
		var finish := _smoothstep((elapsed - CONTACT_SECONDS) / (BACKSWING_SECONDS + FORWARD_SECONDS - CONTACT_SECONDS))
		return _body_pose(
			lerpf(0.48, 0.28, finish),
			lerpf(0.62, 0.86, finish),
			lerpf(0.74, 0.92, finish),
			lerpf(0.52, 0.88, finish),
			1.0,
			finish,
			0.0,
			1.0 - finish
		)
	var recover := _smoothstep((elapsed - BACKSWING_SECONDS - FORWARD_SECONDS) / RECOVERY_SECONDS)
	return _body_pose(
		lerpf(0.28, 0.0, recover),
		lerpf(0.86, 0.0, recover),
		lerpf(0.92, 0.0, recover),
		lerpf(0.88, 0.0, recover),
		1.0 - recover,
		1.0 - recover
	)


static func _body_pose(crouch := 0.0, weight_shift := 0.0, hip_turn := 0.0, chest_turn := 0.0, plant := 0.0, follow_through := 0.0, anticipation := 0.0, contact_accent := 0.0) -> Dictionary:
	return {
		"crouch": crouch,
		"weight_shift": weight_shift,
		"hip_turn": hip_turn,
		"chest_turn": chest_turn,
		"plant": plant,
		"follow_through": follow_through,
		"anticipation": anticipation,
		"contact_accent": contact_accent,
	}


static func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func network_start_elapsed(action_type: StringName, estimated_one_way_seconds: float) -> float:
	var transit := clampf(estimated_one_way_seconds, 0.0, 0.12)
	var base := BACKSWING_SECONDS if action_type == &"shot" else 0.0
	return minf(CONTACT_SECONDS - NETWORK_CONTACT_GUARD_SECONDS, base + transit)
