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
	if defensive_support.x < -8.0 or defensive_support.x > -3.0 or defensive_support.y > -4.5:
		fail("Off-ball defenders must hold a separated midfield lane instead of swarming the ball or crease; target=%s" % defensive_support)
		return
	var attacking_targets := []
	var attacking_depths := {}
	for slot in 5:
		var target: Vector2 = squad.support_target(&"red", slot, Vector3.ZERO, true, Vector3(5.0, 0.0, 2.0))
		attacking_targets.append(target)
		attacking_depths[snappedf(target.x, 0.1)] = true
	if attacking_depths.size() < 4 or _minimum_separation(attacking_targets) < 4.0:
		fail("Attackers need distinct lanes and depths so they move as individuals; targets=%s" % attacking_targets)
		return
	var static_runner: Vector2 = squad.support_target(&"red", 1, Vector3.ZERO, true, Vector3.ZERO)
	var leading_runner: Vector2 = squad.support_target(&"red", 1, Vector3.ZERO, true, Vector3(6.0, 0.0, 3.0))
	if leading_runner.distance_to(static_runner) < 0.75:
		fail("Forward support players must lead the moving ball rather than track it in tandem")
		return
	var defensive_targets := []
	for slot in 5:
		defensive_targets.append(squad.support_target(&"red", slot, Vector3(3.0, 0.0, 1.0), false))
	if _minimum_separation(defensive_targets) < 3.5:
		fail("The five field defenders must occupy a loose, asymmetric dice-five shell; targets=%s" % [defensive_targets])
		return
	var opponents := [
		{"position": Vector3(-1.0, 0.0, -6.0)},
		{"position": Vector3(0.0, 0.0, -3.0)},
		{"position": Vector3(2.0, 0.0, 0.0)},
		{"position": Vector3(1.0, 0.0, 3.0)},
		{"position": Vector3(-2.0, 0.0, 6.0)},
	]
	var marked_targets := []
	for slot in 5:
		marked_targets.append(squad.support_target(&"red", slot, Vector3(-10.0, 0.0, 0.0), false, Vector3.ZERO, opponents))
	if _minimum_separation(marked_targets) < 1.5:
		fail("Man-marking must preserve the loose dice-five spacing instead of collapsing defenders; targets=%s" % [marked_targets])
		return
	var matchup_indices := [2, 0, 4, 1, 3]
	for slot in 5:
		var target: Vector2 = marked_targets[slot]
		var matchup_index: int = matchup_indices[slot]
		var assigned := Vector2(opponents[matchup_index].position.x, opponents[matchup_index].position.z)
		var unmarked: Vector2 = squad.support_target(&"red", slot, Vector3(-10.0, 0.0, 0.0), false)
		if target.distance_to(assigned) >= unmarked.distance_to(assigned) or target.x < -14.0:
			fail("Each defender must stay goal-side of a distinct matchup without crowding the crease; slot=%d target=%s" % [slot, target])
			return
	var danger_ball := Vector3(-12.0, 0.0, 3.0)
	var block_target: Vector2 = squad.pressure_target(&"red", danger_ball, Vector3(-3.0, 0.0, 0.0))
	if block_target.x >= danger_ball.x or absf(block_target.y) >= absf(danger_ball.z):
		fail("The nearest defender must get goal-side of a dangerous ball to block the shot; target=%s" % block_target)
		return
	var retreat := Vector2.LEFT
	var watching_ball: Vector2 = squad.tactical_facing(Vector2.ZERO, retreat, Vector3(6.0, 0.0, 0.0), false)
	if watching_ball.dot(retreat) > -0.9:
		fail("A retreating defender must backpedal while watching the ball; facing=%s movement=%s" % [watching_ball, retreat])
		return
	var attacking_facing: Vector2 = squad.tactical_facing(Vector2.ZERO, Vector2(0.4, 0.9), Vector3(-6.0, 0.0, 0.0), true)
	if attacking_facing.dot(Vector2(0.4, 0.9).normalized()) < 0.99:
		fail("An attacking support player should continue facing the direction of the run")
		return
	var arrived: Vector2 = squad.arrival_movement(Vector2(4.0, -2.0), Vector2(4.08, -2.04))
	if not arrived.is_zero_approx():
		fail("AI must settle at nearby targets instead of flipping direction every frame; movement=%s" % arrived)
		return
	var approaching: Vector2 = squad.arrival_movement(Vector2.ZERO, Vector2(1.0, 0.0))
	if approaching.x <= 0.0 or approaching.x >= 1.0:
		fail("AI must ease into support positions instead of overshooting them at full speed; movement=%s" % approaching)
		return
	var travelling: Vector2 = squad.arrival_movement(Vector2.ZERO, Vector2(8.0, 0.0))
	if not travelling.is_equal_approx(Vector2.RIGHT):
		fail("AI must retain full movement speed when meaningfully far from its target; movement=%s" % travelling)
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
	var circulation_teammates := [
		{"actor_id": &"blue_top", "position": Vector3(0.0, 0.75, -6.0)},
		{"actor_id": &"blue_left", "position": Vector3(-6.0, 0.75, 0.0)},
		{"actor_id": &"blue_bottom", "position": Vector3(0.0, 0.75, 6.0)},
	]
	var anticlockwise: Dictionary = squad.pass_plan(Vector3(6.0, 0.75, 0.0), circulation_teammates, [], &"blue", 0)
	var occasional_clockwise: Dictionary = squad.pass_plan(Vector3(6.0, 0.75, 0.0), circulation_teammates, [], &"blue", 3)
	if anticlockwise.target_actor != &"blue_top" or occasional_clockwise.target_actor != &"blue_bottom":
		fail("AI passing must usually circulate anti-clockwise and occasionally reverse; anti=%s reverse=%s" % [anticlockwise, occasional_clockwise])
		return

	var unpressured: Dictionary = squad.pass_plan(
		Vector3(2.0, 0.75, 0.0),
		[{"actor_id": &"blue_2", "position": Vector3(-1.0, 0.75, -4.0)}],
		[Vector3(10.0, 0.75, 8.0)],
		&"blue",
		0
	)
	if not unpressured.wants_pass:
		fail("An unpressured carrier must keep the wide passing circuit moving")
		return

	print("6v6 squad decisions are valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)


func _minimum_separation(points: Array) -> float:
	var result := INF
	for first in points.size():
		for second in range(first + 1, points.size()):
			result = minf(result, points[first].distance_to(points[second]))
	return result
