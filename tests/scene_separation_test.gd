extends SceneTree


const MENU_SCENE := "res://scenes/app/main_menu.tscn"
const MATCH_SCENE := "res://scenes/match/match.tscn"


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var menu_resource := load(MENU_SCENE) as PackedScene
	var match_resource := load(MATCH_SCENE) as PackedScene
	if menu_resource == null or match_resource == null:
		fail("Menu and match must be independently loadable scenes")
		return
	var menu := menu_resource.instantiate()
	if menu is Node3D or menu.get_node_or_null("Arena") != null or menu.get_node_or_null("HUD") != null:
		fail("The main menu must not instantiate or retain the 3D match")
		return
	if not menu.has_method("start_solo_match"):
		fail("The menu must expose the Solo Match transition")
		return
	var match_scene := match_resource.instantiate()
	if not match_scene is Node3D:
		fail("The match scene must open directly in Godot's 3D editor")
		return
	for path in ["Arena", "HUD", "MatchFlow"]:
		if match_scene.get_node_or_null(path) == null:
			fail("The standalone match is missing %s" % path)
			return
	if match_scene.get_node_or_null("MainMenu") != null:
		fail("The standalone match must not contain the main menu")
		return
	var preview_floor := match_scene.get_node_or_null("EditorPreview/RinkFloor") as MeshInstance3D
	if preview_floor == null or preview_floor.mesh == null:
		fail("The match scene needs authored rink geometry visible in the 3D editor before running")
		return
	print("Menu and match are separate, directly editable scenes.")
	menu.queue_free()
	match_scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
