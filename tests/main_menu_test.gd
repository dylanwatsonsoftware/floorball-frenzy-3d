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
	menu.call("_set_gameplay_enabled", false)
	menu.call("start_solo_match")
	if Input.is_action_just_released("shoot") or Input.is_action_just_released("dash"):
		fail("Starting Solo must not synthesize gameplay release edges before the first resumed physics frame")
		return
	if menu.visible or not (scene.get_node("HUD") as CanvasLayer).visible:
		fail("Starting a solo match must dismiss the menu and reveal the gameplay HUD")
		return
	var ball := scene.get_node("Arena/Ball")
	if not ball.is_physics_processing():
		fail("Starting Solo after the menu freeze must resume ball physics")
		return
	for actor in scene.get_node("Arena").call("get_field_players"):
		if not actor.is_physics_processing():
			fail("Starting Solo must resume every player controller; frozen actor=%s mode=%s" % [actor.name, actor.process_mode])
			return
	var player := scene.get_node("Arena/Player") as CharacterBody3D
	var start_position := player.position
	Input.action_press("move_right")
	for frame in 8:
		await physics_frame
	Input.action_release("move_right")
	if player.position.distance_to(start_position) < 0.08:
		fail("The resumed Solo match must advance real player physics after leaving the menu")
		return
	print("Responsive original-style main menu is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
