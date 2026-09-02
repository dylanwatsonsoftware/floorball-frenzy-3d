extends SceneTree


func _init() -> void:
	var camera_logic := load("res://scripts/presentation/action_camera.gd")
	if camera_logic == null:
		fail("Action-camera framing logic is missing")
		return
	if not camera_logic.has_method("display_position"):
		fail("Frame-based camera tracking must sample interpolated physics positions")
		return

	var neutral: Dictionary = camera_logic.frame(Vector3(8.0, 0.2, 3.0), Vector3(7.0, 0.75, 2.0), false, 0.0)
	if neutral.target.x < 5.0 or neutral.target.z < 1.0:
		fail("The normal camera must follow the live action instead of staying at rink centre; target=%s" % neutral.target)
		return
	if neutral.fov < 46.0 or neutral.position.y < 20.0:
		fail("The width-preserving normal camera must remain wide enough to read teammates and pressure; position=%s fov=%s" % [neutral.position, neutral.fov])
		return

	var charged: Dictionary = camera_logic.frame(Vector3(8.0, 0.2, 3.0), Vector3(7.0, 0.75, 2.0), true, 1.0)
	if charged.position.y <= neutral.position.y + 4.0 or charged.fov <= neutral.fov + 5.0:
		fail("Charging must visibly pull the camera wider; neutral=%s/%s charged=%s/%s" % [neutral.position.y, neutral.fov, charged.position.y, charged.fov])
		return
	if absf(charged.target.x) > 0.5 or charged.fov < 56.0:
		fail("A full charge must centre and widen enough to reveal both goals; target=%s fov=%s" % [charged.target, charged.fov])
		return
	var neutral_view: Vector3 = (neutral.target - neutral.position).normalized()
	var charged_view: Vector3 = (charged.target - charged.position).normalized()
	if neutral_view.dot(charged_view) < 0.9999:
		fail("Charge pullback must preserve the camera angle so screen-space shot direction does not rotate; neutral=%s charged=%s" % [neutral_view, charged_view])
		return

	if not camera_logic.has_method("follow_target") or not camera_logic.has_method("transition_blend"):
		fail("Action tracking needs explicit dead-zone and transition timing behavior")
		return
	var current_target := Vector3(2.0, 0.3, 1.0)
	var tiny_motion: Vector3 = camera_logic.follow_target(current_target, current_target + Vector3(0.45, 0.0, 0.25))
	if not tiny_motion.is_equal_approx(current_target):
		fail("Small action movement must remain inside a natural camera dead-zone instead of being tracked mechanically; got %s" % tiny_motion)
		return
	var large_motion: Vector3 = camera_logic.follow_target(current_target, current_target + Vector3(4.0, 0.0, 0.0))
	if large_motion.x <= current_target.x or large_motion.x >= current_target.x + 4.0:
		fail("Large action movement must pull the camera after consuming the dead-zone; got %s" % large_motion)
		return
	var old_snap_blend := 1.0 - exp(-0.1 * 4.8)
	var charge_blend: float = camera_logic.transition_blend(0.1, true)
	if charge_blend >= old_snap_blend * 0.65:
		fail("Charge pullback must be substantially slower than the old jarring camera transition; old=%s new=%s" % [old_snap_blend, charge_blend])
		return

	var clamped: Dictionary = camera_logic.frame(Vector3(30.0, 0.2, 20.0), Vector3(30.0, 0.75, 20.0), false, 0.0)
	if clamped.target.x > 13.5 or clamped.target.z > 5.5:
		fail("Camera tracking must stay inside safe rink framing bounds; target=%s" % clamped.target)
		return

	print("Action camera follows play and widens for charged shots.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
