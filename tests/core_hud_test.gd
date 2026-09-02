extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	for path in ["HUD/RedHeatBar", "HUD/BlueHeatBar", "HUD/RedHeatLabel", "HUD/BlueHeatLabel"]:
		if (scene.get_node(path) as Control).visible:
			fail("Special-mechanic HUD must stay hidden while the core floorball loop is being tuned: %s" % path)
			return
	var camera_label := scene.get_node("HUD/CameraLabel") as Label
	var score_label := scene.get_node("HUD/ScoreLabel") as Label
	var score_bug := scene.get_node_or_null("HUD/BroadcastScoreBug") as Control
	if score_bug == null:
		fail("The match HUD must present the score as a broadcast-style score bug")
		return
	for logo_path in ["LambsPanel/LambsLogo", "PiratesPanel/PiratesLogo"]:
		var logo := score_bug.get_node_or_null(logo_path) as TextureRect
		if logo == null or logo.texture == null:
			fail("The broadcast score bug must display the supplied team mark: %s" % logo_path)
			return
	var live_label := score_bug.get_node_or_null("CentrePanel/LiveLabel") as Label
	if live_label == null or "LIVE" not in live_label.text:
		fail("The broadcast score bug must clearly identify the live match presentation")
		return
	var lambs_name := score_bug.get_node_or_null("LambsPanel/LambsName") as Label
	var pirates_name := score_bug.get_node_or_null("PiratesPanel/PiratesName") as Label
	if lambs_name == null or pirates_name == null or lambs_name.text != "LAMBS" or pirates_name.text != "PIRATES":
		fail("The match presentation must identify the local Lambs versus Pirates matchup")
		return
	if "—" not in score_label.text:
		fail("The broadcast score must remain readable independently of the team-name panels")
		return
	if "CONTROL FOLLOWS LAMBS POSSESSION" not in camera_label.text:
		fail("The 6v6 HUD must explain that human control follows the Lambs ball carrier")
		return
	if "DASH" not in camera_label.text:
		fail("The core HUD must make the restored desktop dash control discoverable")
		return
	print("Core-only match HUD is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
