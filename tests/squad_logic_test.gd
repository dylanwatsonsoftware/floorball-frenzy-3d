extends SceneTree


func _init() -> void:
	var squad := load("res://scripts/simulation/squad_logic.gd")
	if squad == null:
		fail("6v6 squad logic is missing")
		return

	if squad.human_actor_id(&"red_2", &"red") != &"red_2":
		fail("Human control must follow the red player who owns the ball")
		return
	if squad.human_actor_id(&"blue_1", &"blue") != &"":
		fail("A local human must never take control of a blue player")
		return
	if squad.human_actor_id(&"", &"") != &"":
		fail("All red players must remain AI-controlled while the ball is loose")
		return

	var upper_support: Vector2 = squad.support_target(&"red", 1, Vector3.ZERO, true)
	var lower_support: Vector2 = squad.support_target(&"red", 2, Vector3.ZERO, true)
	if upper_support.y >= -2.5 or lower_support.y <= 2.5 or upper_support.x <= 0.0 or lower_support.x <= 0.0:
		fail("Red off-ball players must spread into distinct forward support lanes")
		return
	var defensive_support: Vector2 = squad.support_target(&"red", 1, Vector3.ZERO, false)
	if defensive_support.x > -5.5 or defensive_support.y > -4.5:
		fail("Off-ball defenders must hold a genuinely separated lane instead of swarming the ball; target=%s" % defensive_support)
		return
	var switch_target: StringName = squad.next_human_actor_id(
		&"red_1",
		[
			{"actor_id": &"red_1", "position": Vector3(8.0, 0.75, 0.0)},
			{"actor_id": &"red_2", "position": Vector3(1.0, 0.75, 0.0)},
			{"actor_id": &"red_3", "position": Vector3(4.0, 0.75, 0.0)},
		],
		Vector3.ZERO
	)
	if switch_target != &"red_2":
		fail("Switch control must advance from the current player to the closest teammate to the ball; got %s" % switch_target)
		return
	var next_switch: StringName = squad.next_human_actor_id(&"red_2", [
		{"actor_id": &"red_1", "position": Vector3(8.0, 0.75, 0.0)},
		{"actor_id": &"red_2", "position": Vector3(1.0, 0.75, 0.0)},
		{"actor_id": &"red_3", "position": Vector3(4.0, 0.75, 0.0)},
	], Vector3.ZERO)
	if next_switch != &"red_3":
		fail("A second switch must advance to the next-closest teammate; got %s" % next_switch)
		return
	var nearest_teammate: Dictionary = squad.closest_teammate(
		&"red_1",
		Vector3.ZERO,
		[
			{"actor_id": &"red_1", "position": Vector3.ZERO},
			{"actor_id": &"red_2", "position": Vector3(5.0, 0.75, 0.0)},
			{"actor_id": &"red_3", "position": Vector3(2.0, 0.75, 1.0)},
		]
	)
	if nearest_teammate.is_empty() or nearest_teammate.actor_id != &"red_3":
		fail("Human Pass must target the nearest other teammate; got %s" % nearest_teammate)
		return

	var pass_decision: Dictionary = squad.pass_plan(
		Vector3(2.0, 0.75, 0.0),
		[
			{"actor_id": &"blue_2", "position": Vector3(-1.0, 0.75, -4.0)},
			{"actor_id": &"blue_3", "position": Vector3(-3.0, 0.75, 3.0)},
		],
		[Vector3(1.2, 0.75, 0.2)],
		&"blue",
		2
	)
	if not pass_decision.wants_pass or pass_decision.target_actor == &"" or pass_decision.direction.is_zero_approx():
		fail("A pressured blue carrier must sometimes use an available teammate")
		return
	var exact_direction := (Vector2(pass_decision.target_position.x, pass_decision.target_position.z) - Vector2(2.0, 0.0)).normalized()
	if absf(pass_decision.direction.cross(exact_direction)) < 0.01:
		fail("AI passes must include small deterministic error instead of being mechanically perfect")
		return

	var unpressured: Dictionary = squad.pass_plan(
		Vector3(2.0, 0.75, 0.0),
		[{"actor_id": &"blue_2", "position": Vector3(-1.0, 0.75, -4.0)}],
		[Vector3(10.0, 0.75, 8.0)],
		&"blue",
		0
	)
	if unpressured.wants_pass:
		fail("An unpressured carrier must be allowed to keep dribbling instead of always passing")
		return

	print("6v6 squad decisions are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
