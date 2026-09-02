extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var menu := scene.get_node_or_null("MainMenu") as CanvasLayer
	if menu == null or not menu.visible:
		fail("The game must open on a visible main menu")
		return
	for path in ["Screen/RinkLines", "Screen/Content/Logo", "Screen/Content/SoloButton", "Screen/Content/OnlineButton"]:
		if menu.get_node_or_null(path) == null:
			fail("The ported menu is missing its original-game presentation element: %s" % path)
			return
	var logo := menu.get_node("Screen/Content/Logo") as TextureRect
	if logo.texture == null:
		fail("The ported menu must display the original Floorball Frenzy identity")
		return
	var online_button := menu.get_node("Screen/Content/OnlineButton") as Button
	if not online_button.disabled or "COMING SOON" not in online_button.text:
		fail("Online play must be presented honestly as unavailable until networking is ported")
		return
	var solo_button := menu.get_node("Screen/Content/SoloButton") as Button
	if solo_button.disabled:
		fail("Solo Match must be the active path into the current 6v6 game")
		return
	menu.call("start_solo_match")
	if menu.visible or not (scene.get_node("HUD") as CanvasLayer).visible:
		fail("Starting a solo match must dismiss the menu and reveal the gameplay HUD")
		return
	print("Responsive original-style main menu is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
