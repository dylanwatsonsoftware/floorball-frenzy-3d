extends SceneTree


func _init() -> void:
	var camera_logic := load("res://scripts/presentation/action_camera.gd")
	if camera_logic == null:
		fail("Action-camera framing logic is missing")
		return

	var neutral: Dictionary = camera_logic.frame(Vector3(8.0, 0.2, 3.0), Vector3(7.0, 0.75, 2.0), false, 0.0)
	if neutral.target.x < 5.0 or neutral.target.z < 1.0:
		fail("The normal camera must follow the live action instead of staying at rink centre; target=%s" % neutral.target)
		return
	if neutral.position.y >= 24.0 or neutral.fov >= 40.0:
		fail("The normal action view must be tighter than the old static broadcast camera; position=%s fov=%s" % [neutral.position, neutral.fov])
		return

	var charged: Dictionary = camera_logic.frame(Vector3(8.0, 0.2, 3.0), Vector3(7.0, 0.75, 2.0), true, 1.0)
	if charged.position.y <= neutral.position.y + 4.0 or charged.fov <= neutral.fov + 5.0:
		fail("Charging must visibly pull the camera wider; neutral=%s/%s charged=%s/%s" % [neutral.position.y, neutral.fov, charged.position.y, charged.fov])
		return
	if charged.target.x >= neutral.target.x - 5.0:
		fail("A charged red shot must bias framing back toward the red defensive goal; neutral=%s charged=%s" % [neutral.target, charged.target])
		return
	if charged.target.x > -1.0:
		fail("At full charge the framing must include enough of the red half to reveal the player's own goal; target=%s" % charged.target)
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
