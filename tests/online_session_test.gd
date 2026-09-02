extends SceneTree


const OnlineSessionScript = preload("res://scripts/network/online_session.gd")


func _init() -> void:
	var session := OnlineSessionScript.new()
	if session.local_team_for_role(&"host") != &"red" or session.local_team_for_role(&"client") != &"blue":
		fail("Online roles must deterministically assign Lambs to host and Pirates to client")
		return
	if session.ai_count_for_team(&"red", &"red") != 5 or session.ai_count_for_team(&"blue", &"red") != 5:
		fail("Each peer must control one player while the other five members of that side remain AI")
		return
	if session.accept_input_sequence(12) != true or session.accept_input_sequence(11) != false or session.accept_input_sequence(12) != false:
		fail("The host must reject stale or duplicate remote input packets")
		return
	if session.accept_snapshot_sequence(7) != true or session.accept_snapshot_sequence(6) != false:
		fail("The client must reject stale authoritative snapshots")
		return
	var room := session.make_room_id(Callable(self, "_fixed_random"))
	if room.length() != 6 or room != room.to_upper():
		fail("Shareable room codes must be short, uppercase, and predictable in shape; got %s" % room)
		return
	print("Online session roles, AI composition, and packet sequencing are deterministic.")
	quit(0)


func _fixed_random() -> int:
	return 3


func fail(message: String) -> void:
	push_error(message)
	quit(1)
