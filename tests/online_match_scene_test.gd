extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	root.get_node("OnlineMatch").call("start", &"host", "ABC234", "Test Game")
	var match_scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(match_scene)
	await process_frame
	var arena := match_scene.get_node("Arena")
	var human_by_team := {&"red": 0, &"blue": 0}
	var ai_by_team := {&"red": 0, &"blue": 0}
	for actor in arena.call("get_field_players"):
		var team: StringName = actor.call("get_team")
		if bool(actor.call("is_human_controlled")):
			human_by_team[team] += 1
		else:
			ai_by_team[team] += 1
	if human_by_team[&"red"] != 1 or human_by_team[&"blue"] != 1:
		fail("An online match needs exactly one human-controlled player on each side; got %s" % human_by_team)
		return
	if ai_by_team[&"red"] != 5 or ai_by_team[&"blue"] != 5:
		fail("An online match needs five AI teammates on each side; got %s" % ai_by_team)
		return
	if match_scene.get_node_or_null("OnlineMatchController") == null:
		fail("Online matches must attach their authoritative networking controller")
		return
	match_scene.queue_free()
	await process_frame
	root.get_node("OnlineMatch").call("stop")

	root.get_node("OnlineMatch").call("start", &"client", "ABC234", "Test Game")
	var client_match := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(client_match)
	await process_frame
	await process_frame
	var client_arena := client_match.get_node("Arena")
	var local_actor: CharacterBody3D = client_arena.call("get_local_human_actor")
	if local_actor == null or local_actor.call("get_team") != &"blue":
		fail("A guest must resolve the Pirates human as its locally controlled player")
		return
	for child_name in ["ControlRing", "AimArrow", "PlayerMarker"]:
		if local_actor.get_node_or_null(child_name) == null:
			fail("The guest-controlled player is missing its %s" % child_name)
			return
	if not local_actor.get_node("ControlRing").visible or not local_actor.get_node("PlayerMarker").visible:
		fail("The guest-controlled player must show its coloured ring and overhead arrow")
		return
	var remote_actor: CharacterBody3D
	for actor in client_arena.call("get_field_players"):
		if actor.call("get_team") == &"red" and bool(actor.call("is_human_controlled")):
			remote_actor = actor
			break
	if remote_actor == null or not remote_actor.get_node("PlayerMarker").visible:
		fail("Guests must see which Lambs player their opponent currently controls")
		return
	if remote_actor.get_node("ControlRing").visible:
		fail("Only the local player should receive the ground control ring")
		return
	var camera_actor: CharacterBody3D = client_arena.call("get_camera_actor", client_arena.get_node("Ball"))
	if camera_actor != local_actor:
		fail("The guest camera must follow the locally controlled Pirates player")
		return
	print("Online matches give both host and guest a visible, camera-tracked human player.")
	client_match.queue_free()
	root.get_node("OnlineMatch").call("stop")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
