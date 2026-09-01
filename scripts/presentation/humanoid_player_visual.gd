extends Node3D

const RUN_CYCLE_RATE := 1.15
const MAX_RUN_SWING := 0.72

var _run_time := 0.0


func _process(delta: float) -> void:
	var actor := get_parent() as CharacterBody3D
	if actor == null:
		return
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	_run_time += delta * maxf(2.4, speed * RUN_CYCLE_RATE)
	var dashing := actor.has_method("is_dashing") and bool(actor.call("is_dashing"))
	apply_movement_pose(speed, _run_time, dashing)


func apply_movement_pose(speed: float, cycle_time: float, dashing: bool) -> void:
	var movement_ratio := clampf(speed / 9.0, 0.0, 1.0)
	var swing := sin(cycle_time) * MAX_RUN_SWING * movement_ratio
	if dashing:
		swing = 0.92
	var left_leg := get_node("LeftLeg") as Node3D
	var right_leg := get_node("RightLeg") as Node3D
	var left_arm := get_node("LeftArm") as Node3D
	var right_arm := get_node("RightArm") as Node3D
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	# Arms stay forward around the stick grip, with enough counter-swing to read
	# as running from the broadcast camera.
	left_arm.rotation.x = -0.58 - swing * 0.18
	right_arm.rotation.x = -0.72 + swing * 0.18
	left_arm.rotation.z = -0.22
	right_arm.rotation.z = 0.35
	var bob := absf(sin(cycle_time)) * 0.045 * movement_ratio
	position.y = bob - (0.05 if dashing else 0.0)
	rotation.x = -0.12 if dashing else 0.0
