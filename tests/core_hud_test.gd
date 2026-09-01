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
	if "CONTROL FOLLOWS RED POSSESSION" not in camera_label.text:
		fail("The 3v3 HUD must explain that human control follows the red ball carrier")
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
