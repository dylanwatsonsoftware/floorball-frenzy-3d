extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	for team_name in ["lambs", "pirates"]:
		var path := "res://assets/ui/%s-logo.png" % team_name
		var texture := load(path) as Texture2D
		if texture == null:
			fail("The %s badge must use its cleaned transparent PNG" % team_name)
			return
		var image := texture.get_image()
		if image == null or image.get_format() not in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH, Image.FORMAT_RGBA4444]:
			fail("The %s badge must retain an alpha channel" % team_name)
			return
		if image.get_pixel(0, 0).a > 0.02:
			fail("The %s badge background must be transparent" % team_name)
			return
	var match_scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(match_scene)
	await process_frame
	var lambs_path := (match_scene.get_node("HUD/BroadcastScoreBug/LambsPanel/LambsLogo") as TextureRect).texture.resource_path
	var pirates_path := (match_scene.get_node("HUD/BroadcastScoreBug/PiratesPanel/PiratesLogo") as TextureRect).texture.resource_path
	match_scene.free()
	if not lambs_path.ends_with(".png") or not pirates_path.ends_with(".png"):
		fail("The scoreboard must consume the transparent team badges")
		return
	print("Team badges are clean, transparent, and wired into the scoreboard.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
