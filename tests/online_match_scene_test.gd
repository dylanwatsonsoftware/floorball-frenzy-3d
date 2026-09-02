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
	print("Online match composes one human and five AI players per side.")
	match_scene.queue_free()
	root.get_node("OnlineMatch").call("stop")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
