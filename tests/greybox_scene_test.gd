extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var packed := load("res://scenes/app/main.tscn") as PackedScene
	if packed == null:
		fail("Main scene could not be loaded")
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var required_nodes := [
		"Arena/RinkFloor",
		"Arena/Player",
		"Arena/Player/StickRig/Shaft",
		"Arena/Player/StickRig/Blade",
		"Arena/Player/StickRig/BladeToe",
		"Arena/Player/DashStreak",
		"Arena/Player/DashStreak/DashRing",
		"Arena/Opponent/StickRig/Shaft",
		"Arena/Opponent/StickRig/Blade",
		"Arena/Opponent/StickRig/BladeToe",
		"Arena/Ball",
		"Arena/Ball/ShotTrail",
		"Arena/LeftGoal",
		"Arena/RightGoal",
		"Arena/LeftGoal/TopSideNet",
		"Arena/LeftGoal/BottomSideNet",
		"Arena/RightGoal/TopSideNet",
		"Arena/RightGoal/BottomSideNet",
		"Arena/BroadcastCamera",
		"HUD/CameraLabel",
		"HUD/MobileControls",
		"HUD/WebDisplayControls/FullscreenButton",
		"HUD/WebDisplayControls/OrientationHint",
		"HUD/ScoreLabel",
		"HUD/MessageLabel",
		"HUD/GoalFlash",
		"MatchFlow",
	]
	for path in required_nodes:
		if scene.get_node_or_null(path) == null:
			fail("Missing greybox node: %s" % path)
			return
	var fullscreen_button := scene.get_node("HUD/WebDisplayControls/FullscreenButton") as Button
	if fullscreen_button.text != "FULLSCREEN":
		fail("Fullscreen label must use portable web-font characters")
		return
	var goal_flash := scene.get_node("HUD/GoalFlash") as ColorRect
	if goal_flash.visible:
		fail("Goal flash must remain hidden before a goal")
		return
	var camera := scene.get_node("Arena/BroadcastCamera") as Camera3D
	if not camera.current:
		fail("Broadcast camera must be active by default")
		return
	var opponent := scene.get_node("Arena/Opponent")
	if not opponent.has_method("is_ai_controlled"):
		fail("Blue opponent must be controlled by the local-match AI")
		return
	var player_stick := scene.get_node("Arena/Player/StickRig") as Node3D
	if player_stick.position.x >= 0.0 or player_stick.rotation.y >= -0.2:
		fail("The stick must angle across the body toward the player's right")
		return
	var dash_streak := scene.get_node("Arena/Player/DashStreak") as Node3D
	if dash_streak.visible:
		fail("The dash streak must remain hidden until a dash starts")
		return
	var player := scene.get_node("Arena/Player")
	if not player.has_method("get_dash_cooldown_ratio"):
		fail("The player must expose dash cooldown feedback")
		return
	var dash_start: Vector3 = player.position
	if not player.call("try_dash", Vector2.RIGHT):
		fail("A ready player dash must start")
		return
	if not dash_streak.visible or player.call("get_dash_cooldown_ratio") <= 0.0:
		fail("Starting a dash must reveal its streak and cooldown feedback; visible=%s cooldown=%s" % [dash_streak.visible, player.call("get_dash_cooldown_ratio")])
		return
	for frame in 8:
		await physics_frame
	if not player.has_method("is_dashing") or not player.call("is_dashing") or player.position.distance_to(dash_start) < 1.65:
		fail("Dash movement must sustain its burst speed; displacement=%s" % player.position.distance_to(dash_start))
		return
	for frame in 4:
		await physics_frame
	var player_blade := scene.get_node("Arena/Player/StickRig/Blade") as MeshInstance3D
	if player_blade.position.z <= 0.5 or player_blade.position.x >= 0.0 or player_blade.global_position.y > 0.3:
		fail("The stick blade must finish grounded, forward, and to the player's right")
		return
	if not player.has_method("set_stick_slap_angle"):
		fail("The player must expose physical slap-stick animation")
		return

	var ball := scene.get_node("Arena/Ball")
	if not ball.has_method("launch"):
		fail("Ball must expose deterministic launch behavior")
		return
	if not ball.has_method("reset_for_faceoff") or not ball.has_signal("goal_scored"):
		fail("Ball must integrate with scoring and faceoff flow")
		return
	if not ball.has_method("begin_slap") or not ball.has_method("get_slap_phase"):
		fail("Ball gameplay must expose the timed physical slap sequence")
		return
	var shot_trail := scene.get_node("Arena/Ball/ShotTrail") as MeshInstance3D
	if shot_trail.visible:
		fail("The ball trail must remain hidden at faceoff")
		return
	if scene.get_node_or_null("HUD/ChargeLabel") == null:
		fail("HUD must expose shot charging feedback")
		return
	var mobile_controls := scene.get_node("HUD/MobileControls")
	if not mobile_controls.has_method("get_movement_vector"):
		fail("Mobile controls must expose a movement vector")
		return
	if scene.get_node_or_null("HUD/MobileControls/MoveBase") == null:
		fail("Mobile controls must show a movement joystick")
		return
	if scene.get_node_or_null("HUD/MobileControls/ShootButton") == null:
		fail("Mobile controls must show a shoot button")
		return
	if scene.get_node_or_null("HUD/MobileControls/DashButton") == null:
		fail("Mobile controls must show a dash button")
		return
	player.position = Vector3(-5.0, 0.75, 0.0)
	player.velocity = Vector3.ZERO
	ball.position = Vector3(-4.1, 0.22, 0.75)
	ball.ball_velocity = Vector3.ZERO
	ball.begin_slap(Vector2.RIGHT, 1.0)
	if ball.get_slap_phase() != &"backswing" or not ball.ball_velocity.is_zero_approx():
		fail("Starting a slap must begin with a neutral-ball backswing")
		return
	for frame in 5:
		await physics_frame
	if ball.ball_velocity.length() >= 10.0:
		fail("The ball must not receive its shot impulse during backswing")
		return
	for frame in 12:
		await physics_frame
	if ball.ball_velocity.x <= 10.0 or ball.position.y <= 0.22:
		fail("Forward blade contact must launch the ball with lift; velocity=%s position=%s" % [ball.ball_velocity, ball.position])
		return
	if not shot_trail.visible:
		fail("A fast charged shot must reveal the ball trail")
		return
	var match_flow := scene.get_node("MatchFlow")
	match_flow.call("_on_goal_scored", &"red")
	if not goal_flash.visible or goal_flash.color.r <= goal_flash.color.b or goal_flash.color.a <= 0.0:
		fail("A red goal must trigger a visible red celebration flash")
		return
	match_flow.call("_reset_faceoff")
	if goal_flash.visible:
		fail("Faceoff reset must clear any remaining goal flash")
		return

	print("Greybox scene contract is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
