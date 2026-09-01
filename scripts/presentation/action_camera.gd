class_name ActionCamera
extends RefCounted

const NORMAL_OFFSET := Vector3(4.0, 21.0, 20.5)
const CHARGE_OFFSET := NORMAL_OFFSET * 1.45
const NORMAL_FOV := 48.0
const CHARGE_FOV := 58.0
const FULL_RINK_FRAMING := Vector3(0.0, 0.3, 0.0)
const FOLLOW_DEAD_ZONE := 0.9
const FOLLOW_RATE := 2.8
const CHARGE_PULLBACK_RATE := 2.4


static func frame(ball_position: Vector3, action_actor_position: Vector3, charging: bool, charge_ratio: float) -> Dictionary:
	var action_focus := ball_position.lerp(action_actor_position, 0.38)
	action_focus = Vector3(
		clampf(action_focus.x, -13.5, 13.5),
		0.3,
		clampf(action_focus.z, -5.5, 5.5)
	)
	var pullback := clampf(charge_ratio, 0.0, 1.0) if charging else 0.0
	pullback = smoothstep(0.0, 1.0, pullback)
	var full_rink_focus := Vector3(FULL_RINK_FRAMING.x, FULL_RINK_FRAMING.y, action_focus.z * 0.15)
	var target := action_focus.lerp(full_rink_focus, pullback)
	var offset := NORMAL_OFFSET.lerp(CHARGE_OFFSET, pullback)
	return {
		"target": target,
		"position": target + offset,
		"fov": lerpf(NORMAL_FOV, CHARGE_FOV, pullback),
	}


static func follow_target(current_target: Vector3, desired_target: Vector3) -> Vector3:
	var planar_delta := Vector2(desired_target.x - current_target.x, desired_target.z - current_target.z)
	if planar_delta.length() <= FOLLOW_DEAD_ZONE:
		return Vector3(current_target.x, desired_target.y, current_target.z)
	var overflow := planar_delta.normalized() * (planar_delta.length() - FOLLOW_DEAD_ZONE)
	return Vector3(current_target.x + overflow.x, desired_target.y, current_target.z + overflow.y)


static func transition_blend(delta: float, pulling_back: bool) -> float:
	var rate := CHARGE_PULLBACK_RATE if pulling_back else FOLLOW_RATE
	return 1.0 - exp(-maxf(0.0, delta) * rate)
