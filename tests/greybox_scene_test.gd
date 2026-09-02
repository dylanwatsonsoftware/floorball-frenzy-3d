extends SceneTree

const StickSlapScript = preload("res://scripts/simulation/stick_slap.gd")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var packed := load("res://scenes/match/match.tscn") as PackedScene
	if packed == null:
		fail("Main scene could not be loaded")
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var required_nodes := [
		"Arena/RinkFloor",
		"Arena/FarLeftCornerBoard",
		"Arena/FarRightCornerBoard",
		"Arena/NearLeftCornerBoard",
		"Arena/NearRightCornerBoard",
		"Arena/Player",
		"Arena/Player/StickRig/Shaft",
		"Arena/Player/StickRig/Blade",
		"Arena/Player/DashStreak",
		"Arena/Player/DashStreak/DashRing",
		"Arena/Player/FuegoAura",
		"Arena/Opponent/StickRig/Shaft",
		"Arena/Opponent/StickRig/Blade",
		"Arena/Opponent/DashStreak",
		"Arena/Opponent/DashStreak/DashRing",
		"Arena/Opponent/FuegoAura",
		"Arena/Ball",
		"Arena/Ball/ShotTrail",
		"Arena/ShotImpact",
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
		"HUD/MobileControls/SwitchButton",
		"HUD/ScoreLabel",
		"HUD/MessageLabel",
		"HUD/GoalFlash",
		"HUD/RedHeatBar",
		"HUD/BlueHeatBar",
		"HUD/RedHeatLabel",
		"HUD/BlueHeatLabel",
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
	if camera.keep_aspect != Camera3D.KEEP_WIDTH:
		fail("Broadcast camera must preserve horizontal framing so portrait and landscape screens both fit the action width")
		return
	if camera.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
		fail("The frame-driven broadcast camera must not receive a second automatic interpolation pass")
		return
	var opponent := scene.get_node("Arena/Opponent")
	if not opponent.has_method("is_ai_controlled"):
		fail("Blue opponent must be controlled by the local-match AI")
		return
	if not opponent.has_method("try_dash") or not opponent.has_method("is_dashing"):
		fail("Blue AI must expose the same sustained dash mechanics as the player")
		return
	if not opponent.has_method("add_heat") or not opponent.has_method("is_en_fuego"):
		fail("Blue AI must participate in the shared Heat and En Fuego system")
		return
	var opponent_dash_start: Vector3 = opponent.position
	if not opponent.call("try_dash", Vector2.LEFT):
		fail("A ready blue AI dash must start")
		return
	var opponent_dash_streak := scene.get_node("Arena/Opponent/DashStreak") as Node3D
	if not opponent_dash_streak.visible:
		fail("Blue AI dash must reveal its team-colored streak")
		return
	var ai_dash_ball := scene.get_node("Arena/Ball")
	ai_dash_ball.position = opponent.position + Vector3(-0.35, -0.53, 0.0)
	ai_dash_ball.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	var ai_steal_label := scene.get_node("HUD/ChargeLabel") as Label
	if ai_dash_ball.ball_velocity.x >= opponent.velocity.x or ai_steal_label.text != "PIRATES STEAL!":
		fail("Blue AI body contact during dash must use the same physical steal; velocity=%s label=%s" % [ai_dash_ball.ball_velocity, ai_steal_label.text])
		return
	if opponent.call("get_heat_ratio") < 0.19 or (scene.get_node("HUD/BlueHeatBar") as ProgressBar).value < 19.0:
		fail("Blue dash and steal rewards must feed the visible Heat meter")
		return
	ai_dash_ball.reset_for_faceoff()
	for frame in 8:
		await physics_frame
	if not opponent.call("is_dashing") or opponent.position.distance_to(opponent_dash_start) < 1.65:
		fail("Blue AI dash must sustain the same movement burst; displacement=%s" % opponent.position.distance_to(opponent_dash_start))
		return
	opponent.position = Vector3(5.0, 0.75, 0.0)
	opponent.velocity = Vector3.ZERO
	var player_stick := scene.get_node("Arena/Player/StickRig") as Node3D
	var stick_actor := player_stick.get_parent() as CharacterBody3D
	var stick_pocket := player_stick.get_node("BladePocket") as Marker3D
	var pocket_offset := stick_pocket.global_position - stick_actor.global_position
	var stick_facing: Vector3 = stick_actor.call("get_facing_direction")
	var stick_right := Vector3(-stick_facing.z, 0.0, stick_facing.x)
	if pocket_offset.dot(stick_facing) < 0.5 or pocket_offset.dot(stick_right) < 0.5:
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
	if not player.has_method("has_recent_dash"):
		fail("The player must expose the original short Bolt-shot timing window")
		return
	if not player.has_method("add_heat") or not player.has_method("is_en_fuego"):
		fail("Red player must participate in the shared Heat and En Fuego system")
		return
	var dash_start: Vector3 = player.position
	if not player.call("try_dash", Vector2.RIGHT):
		fail("A ready player dash must start")
		return
	if not dash_streak.visible or player.call("get_dash_cooldown_ratio") <= 0.0:
		fail("Starting a dash must reveal its streak and cooldown feedback; visible=%s cooldown=%s" % [dash_streak.visible, player.call("get_dash_cooldown_ratio")])
		return
	if not player.call("has_recent_dash"):
		fail("A new dash must immediately arm a Bolt shot")
		return
	var bolt_probe := scene.get_node("Arena/Ball")
	bolt_probe.position = player.position + Vector3(0.35, -0.53, 0.0)
	bolt_probe.ball_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	var steal_label := scene.get_node("HUD/ChargeLabel") as Label
	if bolt_probe.ball_velocity.x <= player.velocity.x or steal_label.text != "STEAL!":
		fail("Dashing through the ball must produce a strong one-hit steal poke and feedback; velocity=%s label=%s" % [bolt_probe.ball_velocity, steal_label.text])
		return
	if player.call("get_heat_ratio") < 0.19 or (scene.get_node("HUD/RedHeatBar") as ProgressBar).value < 19.0:
		fail("Red dash and steal rewards must feed the visible Heat meter")
		return
	bolt_probe.position = player.position + Vector3(0.9, -0.53, 0.75)
	bolt_probe.ball_velocity = Vector3.ZERO
	bolt_probe.begin_slap(Vector2.RIGHT, 0.5)
	var bolt_label := scene.get_node("HUD/ChargeLabel") as Label
	if bolt_label.text != "BOLT!":
		fail("Releasing during the dash window must show unmistakable Bolt feedback")
		return
	bolt_probe.reset_for_faceoff()
	for frame in 8:
		await physics_frame
	if not player.has_method("is_dashing") or not player.call("is_dashing") or player.position.distance_to(dash_start) < 1.65:
		fail("Dash movement must sustain its burst speed; displacement=%s" % player.position.distance_to(dash_start))
		return
	for frame in 5:
		await physics_frame
	if player.call("has_recent_dash"):
		fail("Bolt eligibility must expire after the original 200 ms timing window")
		return
	var player_blade := scene.get_node("Arena/Player/StickRig/Blade") as MeshInstance3D
	var blade_bounds := player_blade.get_aabb()
	var blade_world_center := player_blade.to_global(blade_bounds.get_center())
	var blade_size := blade_bounds.size
	var blade_long_axis := maxf(blade_size.x, maxf(blade_size.y, blade_size.z))
	if blade_long_axis < 0.36 or blade_world_center.y > 0.35:
		fail("The stick blade must finish grounded, forward, and to the player's right")
		return
	if not player.has_method("set_stick_slap_angle"):
		fail("The player must expose physical slap-stick animation")
		return
	if not player.has_method("set_shot_aim_locked") or not player.has_method("is_shot_aim_locked"):
		fail("Holding a shot must be able to lock aim independently from retreating movement")
		return
	var locked_aim: Vector3 = player.call("get_facing_direction")
	player.call("set_shot_aim_locked", true)
	player.velocity = -locked_aim * 8.0
	if not player.call("is_shot_aim_locked") or player.call("get_facing_direction").dot(locked_aim) < 0.99:
		fail("Retreating during a held shot must preserve the locked stick aim")
		return
	player.velocity = Vector3.ZERO
	player.call("set_shot_aim_locked", false)

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
	if not ball.has_method("record_touch") or not ball.has_method("is_one_touch_ready"):
		fail("Ball gameplay must track the original one-touch timing window")
		return
	if not ball.has_method("is_scoop_active"):
		fail("Ball gameplay must expose the original retreating quick-release scoop state")
		return
	ball.rotation = Vector3.ZERO
	ball.ball_velocity = Vector3(6.0, 0.0, 0.0)
	ball.call("_update_spin", 0.1)
	if absf(ball.rotation.z) <= 0.05 or absf(ball.rotation.x) > 0.01:
		fail("A ball moving along X must visibly roll around its perpendicular Z axis; rotation=%s" % ball.rotation)
		return
	ball.rotation = Vector3.ZERO
	ball.ball_velocity = Vector3.ZERO
	var shot_trail := scene.get_node("Arena/Ball/ShotTrail") as MeshInstance3D
	if shot_trail.visible:
		fail("The ball trail must remain hidden at faceoff")
		return
	if not shot_trail.mesh is ArrayMesh or shot_trail.get_node_or_null("TrailCore") == null:
		fail("Fast balls need a tapered, layered graphic streak instead of a solid box or cylinder")
		return
	var aim_arrow := player.get_node("AimArrow") as Node3D
	if not (aim_arrow.get_node("Shaft") as MeshInstance3D).mesh is QuadMesh or not (aim_arrow.get_node("Head") as MeshInstance3D).mesh is ArrayMesh:
		fail("The charged-shot guide must use flat 2D-style shaft and arrowhead geometry")
		return
	var arrow_head := aim_arrow.get_node("Head") as MeshInstance3D
	var arrow_head_material := arrow_head.material_override as StandardMaterial3D
	if arrow_head_material.cull_mode != BaseMaterial3D.CULL_DISABLED:
		fail("The flat charged-shot arrowhead must render from both sides at every camera angle")
		return
	if scene.get_node_or_null("HUD/ChargeLabel") == null:
		fail("HUD must expose shot charging feedback")
		return
	ball.launch(Vector2.RIGHT, 0.2, Vector3(-4.0, 0.0, 0.0), false, &"red")
	if not ball.call("is_scoop_active") or ball.ball_velocity.y < 8.0 or (scene.get_node("HUD/ChargeLabel") as Label).text != "SCOOP!":
		fail("A retreating quick release must create a high, clearly labelled scoop; velocity=%s" % ball.ball_velocity)
		return
	await physics_frame
	if (scene.get_node("HUD/ChargeLabel") as Label).text != "SCOOP!":
		fail("Scoop feedback must remain readable beyond its launch frame")
		return
	ball.reset_for_faceoff()
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
	if scene.get_node_or_null("HUD/MobileControls/PassButton") == null:
		fail("Mobile controls must show an automatic pass button")
		return
	player.position = Vector3(-5.0, 0.75, 0.0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	var slap_blade_pocket := player.get_node("StickRig/BladePocket") as Marker3D
	slap_blade_pocket.force_update_transform()
	ball.position = Vector3(slap_blade_pocket.global_position.x, 0.22, slap_blade_pocket.global_position.z)
	ball.ball_velocity = Vector3.ZERO
	ball.reset_physics_interpolation()
	ball.record_touch(&"blue")
	await physics_frame
	await physics_frame
	ball.ball_velocity = Vector3.ZERO
	if not ball.is_one_touch_ready(&"red"):
		fail("A recent blue touch must arm red's one-touch opportunity")
		return
	ball.begin_slap(Vector2.RIGHT, 1.0)
	var charge_label := scene.get_node("HUD/ChargeLabel") as Label
	if charge_label.text != "ONE TOUCH!":
		fail("One-touch release must show unmistakable mobile-readable feedback")
		return
	if ball.get_slap_phase() != &"backswing" or not ball.ball_velocity.is_zero_approx():
		fail("Starting a slap must begin with a neutral-ball backswing")
		return
	for frame in 5:
		await physics_frame
	if ball.ball_velocity.length() >= 10.0:
		fail("The ball must not receive its shot impulse during backswing")
		return
	var contact_frames := ceili(StickSlapScript.CONTACT_SECONDS * float(Engine.physics_ticks_per_second)) + 2
	for frame in contact_frames - 5:
		await physics_frame
	if ball.ball_velocity.x <= 10.0 or ball.position.y <= 0.22:
		fail("Forward blade contact must launch the ball with lift; velocity=%s position=%s" % [ball.ball_velocity, ball.position])
		return
	if not shot_trail.visible:
		fail("A fast charged shot must reveal the ball trail")
		return
	var shot_impact := scene.get_node("Arena/ShotImpact") as MeshInstance3D
	if not shot_impact.visible or shot_impact.scale.x <= 0.35:
		fail("Physical stick contact must create an expanding shot impact burst")
		return
	var match_flow := scene.get_node("MatchFlow")
	match_flow.call("_on_goal_scored", &"red")
	if not goal_flash.visible or goal_flash.color.g <= goal_flash.color.r or goal_flash.color.a <= 0.0:
		fail("A Lambs goal must trigger a visible green celebration flash")
		return
	await physics_frame
	var red_fuego_aura := scene.get_node("Arena/Player/FuegoAura") as MeshInstance3D
	if not player.call("is_en_fuego") or not red_fuego_aura.visible or (scene.get_node("HUD/RedHeatBar") as ProgressBar).value < 99.0:
		fail("Perfect-shot and goal rewards must activate visible Red En Fuego")
		return
	if player.call("get_dash_cooldown_ratio") > 0.0:
		fail("En Fuego must instantly recharge the player's dash")
		return
	match_flow.call("_reset_faceoff")
	if goal_flash.visible:
		fail("Faceoff reset must clear any remaining goal flash")
		return
	if not player.call("is_en_fuego"):
		fail("En Fuego must persist across ordinary goal faceoffs")
		return
	for goal_index in 4:
		match_flow.call("_on_goal_scored", &"red")
	match_flow.call("_reset_faceoff")
	if player.call("is_en_fuego") or player.call("get_heat_ratio") > 0.0:
		fail("Starting a new match after first-to-five must reset Heat")
		return

	if not player.has_method("has_parry_window") or not opponent.has_method("has_parry_window"):
		fail("Both local players must expose the original post-dash perfect-parry window")
		return
	player.call("add_heat", 100.0)
	await physics_frame
	player.call("reset_heat")
	if not player.call("try_dash", Vector2.LEFT) or not player.call("has_parry_window"):
		fail("Red's dash must arm its 150 ms parry window")
		return
	ball.position = player.position + Vector3(0.6, -0.53, 0.0)
	ball.ball_velocity = Vector3(-14.0, 0.0, 0.0)
	await physics_frame
	if ball.ball_velocity.x < 20.0 or charge_label.text != "PARRY!":
		fail("Red must reflect a fast incoming body shot at 1.5x speed; velocity=%s label=%s" % [ball.ball_velocity, charge_label.text])
		return
	if not player.call("is_en_fuego") or player.call("get_heat_ratio") < 0.99:
		fail("A red perfect parry must instantly award the original full-Heat En Fuego payoff")
		return

	ball.reset_for_faceoff()
	opponent.call("add_heat", 100.0)
	await physics_frame
	opponent.call("reset_heat")
	if not opponent.call("try_dash", Vector2.RIGHT) or not opponent.call("has_parry_window"):
		fail("Blue's dash must arm the same 150 ms parry window")
		return
	ball.position = opponent.position + Vector3(-0.6, -0.53, 0.0)
	ball.ball_velocity = Vector3(14.0, 0.0, 0.0)
	await physics_frame
	if ball.ball_velocity.x > -20.0 or charge_label.text != "PIRATES PARRY!":
		fail("Blue must reflect a fast incoming body shot at 1.5x speed; velocity=%s label=%s" % [ball.ball_velocity, charge_label.text])
		return
	if not opponent.call("is_en_fuego") or opponent.call("get_heat_ratio") < 0.99:
		fail("A blue perfect parry must receive the same full-Heat En Fuego payoff")
		return
	ball.set_physics_process(false)
	opponent.call("_physics_process", 0.2)
	if opponent.call("has_parry_window"):
		fail("Blue's parry window must expire while play is stopped between goals")
		return
	ball.set_physics_process(true)

	print("Greybox scene contract is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
