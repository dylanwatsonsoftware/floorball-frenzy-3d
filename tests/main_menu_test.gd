extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var menu_source := FileAccess.get_file_as_string("res://scripts/presentation/main_menu.gd")
	if "No open Godot games" in menu_source:
		fail("Player-facing matchmaking copy must not expose the engine name")
		return
	if "func _on_lobby_posted" not in menu_source:
		fail("Online scene transition must wait for lobby registration to complete")
		return
	var menu := (load("res://scenes/app/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	for path in ["Screen/RinkLines", "Screen/Content/Logo", "Screen/Content/SoloButton", "Screen/Content/OnlineButton"]:
		if menu.get_node_or_null(path) == null:
			fail("The ported menu is missing its original-game presentation element: %s" % path)
			return
	var logo := menu.get_node("Screen/Content/Logo") as TextureRect
	if logo.texture == null:
		fail("The ported menu must display the original Floorball Frenzy identity")
		return
	var online_button := menu.get_node("Screen/Content/OnlineButton") as Button
	if online_button.disabled or "COMING SOON" in online_button.text:
		fail("Online play must open the ported matchmaking lobby")
		return
	if not menu.has_method("show_online_lobby"):
		fail("The main menu must expose the online matchmaking flow")
		return
	var solo_button := menu.get_node("Screen/Content/SoloButton") as Button
	if solo_button.disabled:
		fail("Solo Match must be the active path into the current 6v6 game")
		return
	if "⚡" in solo_button.text or "🌐" in online_button.text:
		fail("Menu buttons must not use emoji glyphs that render as codepoint boxes in the web font")
		return
	if "AI" in solo_button.text or "6v6" in solo_button.text:
		fail("The Solo button should stay clean without the awkward AI/6v6 subtitle; text=%s" % solo_button.text)
		return
	menu.call("start_solo_match")
	await process_frame
	await process_frame
	var loaded_match := current_scene
	if loaded_match == null or loaded_match.scene_file_path != "res://scenes/match/match.tscn":
		fail("Solo Match must replace the menu with a fresh standalone match scene")
		return
	if loaded_match.get_node_or_null("Arena/Ball") == null or loaded_match.get_node_or_null("HUD") == null:
		fail("The loaded match must initialize its arena and gameplay HUD")
		return
	for actor in loaded_match.get_node("Arena").call("get_field_players"):
		if not actor.is_physics_processing():
			fail("A newly loaded match must start every player controller; frozen actor=%s" % actor.name)
			return
	print("Standalone main menu loads a fresh 6v6 match.")
	loaded_match.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
