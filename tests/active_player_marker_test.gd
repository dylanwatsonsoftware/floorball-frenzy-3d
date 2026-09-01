extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var packed := load("res://scenes/app/main.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	var players: Array = scene.get_node("Arena").call("get_team_players", &"red")
	if players.size() != 3:
		fail("The active-player marker contract requires all three controllable Lambs")
		return
	for player in players:
		var marker := player.get_node_or_null("PlayerMarker") as Node3D
		if marker == null:
			fail("Every field player needs an active-player marker anchor; %s has %s" % [player.name, player.get_children().map(func(child: Node) -> String: return child.name)])
			return
		var arrow := marker.get_node_or_null("Arrow2D") as Sprite3D
		if arrow == null:
			fail("The controlled-player arrow must be a flat 2D sprite, not 3D geometry")
			return
		if arrow.billboard != BaseMaterial3D.BILLBOARD_ENABLED or arrow.texture == null:
			fail("The 2D player arrow must remain screen-facing and textured")
			return
		for child in marker.get_children():
			if child is MeshInstance3D:
				fail("The marker must not contain a 3D cone or halo")
				return
	print("Active-player arrows are flat, screen-facing 2D sprites.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
