class_name ActionCamera
extends RefCounted

const NORMAL_OFFSET := Vector3(4.0, 18.5, 18.0)
const CHARGE_OFFSET := Vector3(2.0, 27.0, 27.5)
const NORMAL_FOV := 34.0
const CHARGE_FOV := 46.0
const RED_GOAL_FRAMING := Vector3(-5.5, 0.3, 0.0)


static func frame(ball_position: Vector3, action_actor_position: Vector3, charging: bool, charge_ratio: float) -> Dictionary:
	var action_focus := ball_position.lerp(action_actor_position, 0.38)
	action_focus = Vector3(
		clampf(action_focus.x, -13.5, 13.5),
		0.3,
		clampf(action_focus.z, -5.5, 5.5)
	)
	var pullback := clampf(charge_ratio, 0.0, 1.0) if charging else 0.0
	pullback = smoothstep(0.0, 1.0, pullback)
	var defensive_goal_focus := Vector3(RED_GOAL_FRAMING.x, RED_GOAL_FRAMING.y, action_focus.z * 0.2)
	var target := action_focus.lerp(defensive_goal_focus, pullback)
	var offset := NORMAL_OFFSET.lerp(CHARGE_OFFSET, pullback)
	return {
		"target": target,
		"position": target + offset,
		"fov": lerpf(NORMAL_FOV, CHARGE_FOV, pullback),
	}
