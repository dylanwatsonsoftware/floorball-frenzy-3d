extends MeshInstance3D

const BallSimulationScript = preload("res://scripts/simulation/ball_simulation.gd")
const MatchSimulationScript = preload("res://scripts/simulation/match_simulation.gd")
const BallInteractionScript = preload("res://scripts/simulation/ball_interaction.gd")
const StickSlapScript = preload("res://scripts/simulation/stick_slap.gd")
const OneTouchScript = preload("res://scripts/simulation/one_touch.gd")
const DashStealScript = preload("res://scripts/simulation/dash_steal.gd")
const ParryScript = preload("res://scripts/simulation/parry.gd")
const ShotChargeFeedbackScript = preload("res://scripts/presentation/shot_charge_feedback.gd")
const ShotImpactFeedbackScript = preload("res://scripts/presentation/shot_impact_feedback.gd")
const SquadLogicScript = preload("res://scripts/simulation/squad_logic.gd")
const ShotAimIndicatorScript = preload("res://scripts/presentation/shot_aim_indicator.gd")
const MAX_CHARGE_SECONDS := 0.8
const SHOOT_RANGE := 2.35
const TRAIL_SPEED_THRESHOLD := 10.0
const TRAIL_MIN_LENGTH := 0.55
const TRAIL_MAX_LENGTH := 1.75
const NORMAL_TRAIL_COLOR := Color(1.0, 0.3, 0.04, 0.58)
const NORMAL_TRAIL_EMISSION := Color("ff5a00")
const BOLT_TRAIL_COLOR := Color(0.18, 0.72, 1.0, 0.76)
const BOLT_TRAIL_EMISSION := Color("42b8ff")
const SCOOP_TRAIL_COLOR := Color(0.48, 0.92, 1.0, 0.78)
const SCOOP_TRAIL_EMISSION := Color("7deaff")
const PARRY_TRAIL_COLOR := Color(1.0, 0.86, 0.25, 0.86)
const PARRY_TRAIL_EMISSION := Color("ffd83f")
const SCOOP_FEEDBACK_SECONDS := 0.8
const STEAL_FEEDBACK_SECONDS := 0.38
const STEAL_COLOR := Color("7dff6a")
const BLUE_STEAL_COLOR := Color("58a8ff")
const AI_GOAL := Vector2(-16.5, 0.0)
const AI_SHOOT_DISTANCE := 7.0
const AI_SHOT_CHARGE_SECONDS := 0.55
const PASSER_PICKUP_LOCK_SECONDS := 0.38

var ball_velocity := Vector3.ZERO
var _charge_seconds := 0.0
var _player: CharacterBody3D
var _opponent: CharacterBody3D
var _field_players: Array[CharacterBody3D] = []
var _charge_label: Label
var _shot_trail: MeshInstance3D
var _slap_elapsed := -1.0
var _slap_actor: CharacterBody3D
var _pending_slap_charge := 0.0
var _pending_slap_direction := Vector2.RIGHT
var _pending_one_touch := false
var _pending_bolt := false
var _pending_pass := false
var _pending_soft_pass := false
var _scoop_remaining := 0.0
var _last_touch_actor: StringName = &""
var _last_touch_age := INF
var _dash_steal_consumed := {0: false, 1: false}
var _steal_feedback_remaining := 0.0
var _control_owner := -1
var _ai_possession_seconds := 0.0
var _ai_shot_seconds := 0.0
var _ai_shot_actor: CharacterBody3D
var _pass_index := 0
var _ai_pass_cooldown := 0.0
var _aim_arrow_actor: CharacterBody3D
var _charge_cancelled_until_release := false
var _human_control_actor_id: StringName = &"red_1"
var _blue_human_control_actor_id: StringName = &"blue_1"
var _network_blue_charge := 0.0
var _network_blue_was_shooting := false
var _pickup_lock_actor_id: StringName = &""
var _pickup_lock_seconds := 0.0

signal goal_scored(scorer: StringName)


func _ready() -> void:
	_player = get_parent().get_node("Player") as CharacterBody3D
	_refresh_field_players()
	_charge_label = get_node("../../HUD/ChargeLabel") as Label
	_shot_trail = get_node_or_null("ShotTrail") as MeshInstance3D


func _physics_process(delta: float) -> void:
	if OnlineMatch.enabled and OnlineMatch.is_authority():
		_update_network_blue_actions(delta)
	_pickup_lock_seconds = maxf(0.0, _pickup_lock_seconds - delta)
	if _pickup_lock_seconds <= 0.0:
		_pickup_lock_actor_id = &""
	if Input.is_action_just_pressed("switch_player"):
		switch_human_player()
	if Input.is_action_just_pressed("pass"):
		pass_to_closest_teammate()
	_last_touch_age += delta
	_update_scoop_feedback(delta)
	_update_steal_feedback(delta)
	_advance_slap(delta)
	var previous_position := position
	var next_state := BallSimulationScript.step(position, ball_velocity, delta)
	var previous_control_owner := _control_owner
	var interaction_state := BallInteractionScript.step(next_state.position, next_state.velocity, _interaction_participants(), delta, _control_owner)
	position = interaction_state.position
	ball_velocity = interaction_state.velocity
	_control_owner = interaction_state.controller
	_update_human_control_from_possession(previous_control_owner)
	_update_ai_pass(delta)
	_update_dash_steal_latches()
	if not _apply_parry(interaction_state.body_controller):
		_apply_dash_steal(interaction_state.body_controller)
	var scorer := MatchSimulationScript.detect_goal(previous_position, position, ball_velocity)
	if scorer != &"":
		ball_velocity = Vector3.ZERO
		_charge_seconds = 0.0
		_cancel_slap()
		_clear_charge_feedback()
		_set_trail_visible(false)
		set_physics_process(false)
		goal_scored.emit(scorer)
		return
	_update_spin(delta)
	_update_shot_trail()
	_update_shot_charge(delta)
	_record_body_touch(interaction_state.body_controller)


func launch(planar_direction: Vector2, charge: float, inherited_velocity: Vector3 = Vector3.ZERO, one_touch: bool = false, shooter: StringName = &"", bolt: bool = false) -> void:
	if _charge_seconds > 0.0:
		_cancel_active_charge(true)
	_control_owner = -1
	_ai_possession_seconds = 0.0
	_reset_ai_shot()
	var plan: Dictionary = BallSimulationScript.shot_plan(planar_direction, charge, inherited_velocity, one_touch, bolt)
	ball_velocity = plan.velocity
	_scoop_remaining = SCOOP_FEEDBACK_SECONDS if plan.is_scoop else 0.0
	_set_shot_trail_style(bolt, plan.is_scoop, false)
	if plan.is_scoop and _charge_label != null:
		_charge_label.text = "SCOOP!"
		_charge_label.add_theme_color_override("font_color", SCOOP_TRAIL_EMISSION)
	if shooter != &"":
		record_touch(shooter)
		if BallSimulationScript.is_perfect_charge(charge):
			_award_heat(shooter, 30.0)


func _launch_pass(planar_direction: Vector2, inherited_velocity: Vector3, passer: StringName, soft_touch: bool = false) -> void:
	_pickup_lock_actor_id = _slap_actor.call("get_actor_id") if _slap_actor != null else &""
	_pickup_lock_seconds = PASSER_PICKUP_LOCK_SECONDS
	_control_owner = -1
	_ai_possession_seconds = 0.0
	_reset_ai_shot()
	ball_velocity = BallSimulationScript.soft_touch_velocity(planar_direction, inherited_velocity) if soft_touch else BallSimulationScript.pass_velocity(planar_direction, inherited_velocity)
	_scoop_remaining = 0.0
	_set_shot_trail_style(false, false, false)
	record_touch(passer)


func reset_for_faceoff() -> void:
	position = Vector3(0.0, BallSimulationScript.BALL_RADIUS, 0.0)
	reset_physics_interpolation()
	ball_velocity = Vector3.ZERO
	_charge_seconds = 0.0
	_cancel_slap()
	_last_touch_actor = &""
	_last_touch_age = INF
	_dash_steal_consumed = {0: false, 1: false}
	_pickup_lock_actor_id = &""
	_pickup_lock_seconds = 0.0
	_steal_feedback_remaining = 0.0
	_scoop_remaining = 0.0
	_control_owner = -1
	_ai_possession_seconds = 0.0
	_reset_ai_shot()
	_ai_pass_cooldown = 0.0
	_charge_cancelled_until_release = false
	_clear_charge_feedback()
	_set_trail_visible(false)
	_set_shot_trail_style(false, false, false)
	set_physics_process(true)


func _update_shot_charge(delta: float) -> void:
	if _slap_elapsed >= 0.0:
		return
	var input_actor := _red_input_actor()
	if Input.is_action_pressed("shoot"):
		if _charge_cancelled_until_release:
			return
		if _charge_seconds <= 0.0:
			_slap_actor = input_actor
			_slap_actor.call("set_shot_aim_locked", true)
		elif input_actor != _slap_actor:
			_cancel_active_charge(true)
			return
		_charge_seconds = minf(MAX_CHARGE_SECONDS * 2.0, _charge_seconds + delta)
		var charge_ratio := _charge_seconds / MAX_CHARGE_SECONDS
		var backswing_ratio := minf(1.0, charge_ratio)
		_slap_actor.call("set_stick_slap_angle", lerpf(-2.0, StickSlapScript.BACKSWING_ANGLE, backswing_ratio * backswing_ratio))
		_show_aim_arrow(_slap_actor, charge_ratio)
		_apply_charge_feedback(charge_ratio)
	elif Input.is_action_just_released("shoot"):
		_charge_cancelled_until_release = false
		_hide_aim_arrow()
		if _charge_seconds > 0.0 and _slap_actor != null:
			var facing: Vector3 = _slap_actor.call("get_facing_direction")
			_release_charged_slap(Vector2(facing.x, facing.z), _charge_seconds / MAX_CHARGE_SECONDS)
		_charge_seconds = 0.0
		if _slap_elapsed < 0.0 and _slap_actor != null:
			_clear_charge_feedback()
			_slap_actor.call("set_stick_slap_angle", 0.0)
	elif not Input.is_action_pressed("shoot"):
		_charge_cancelled_until_release = false
		_hide_aim_arrow()
		input_actor.call("set_shot_aim_locked", false)
		if _steal_feedback_remaining <= 0.0 and _scoop_remaining <= 0.0:
			_clear_charge_feedback()
		input_actor.call("set_stick_slap_angle", 0.0)


func _red_input_actor() -> CharacterBody3D:
	var human_actor_id := get_human_control_actor_id()
	for actor in _field_players:
		if actor.call("get_actor_id") == human_actor_id:
			return actor
	return _player


func _show_aim_arrow(actor: CharacterBody3D, normalized_charge: float) -> void:
	_hide_other_aim_arrows(actor)
	_aim_arrow_actor = actor
	var arrow := actor.get_node_or_null("AimArrow") as Node3D
	if arrow == null:
		return
	var presentation: Dictionary = ShotAimIndicatorScript.for_charge(normalized_charge)
	var shaft := arrow.get_node("Shaft") as MeshInstance3D
	var shaft_mesh := shaft.mesh as QuadMesh
	shaft_mesh.size = Vector2(presentation.width, presentation.length)
	shaft.position.z = 0.85 + presentation.length * 0.5
	var head := arrow.get_node("Head") as MeshInstance3D
	var head_length := 0.46 + float(presentation.width) * 0.7
	head.scale = Vector3(float(presentation.width) * 3.4, 1.0, head_length)
	head.position.z = 0.85 + float(presentation.length) + head_length * 0.5
	for mesh_instance in [shaft, head]:
		var material := mesh_instance.material_override as StandardMaterial3D
		material.albedo_color = presentation.color
		material.emission = Color(presentation.color.r, presentation.color.g, presentation.color.b, 1.0)
	arrow.visible = true


func _hide_aim_arrow() -> void:
	_hide_other_aim_arrows(null)
	_aim_arrow_actor = null


func _hide_other_aim_arrows(exception: CharacterBody3D) -> void:
	_refresh_field_players()
	for actor in _field_players:
		if actor == exception:
			continue
		var arrow := actor.get_node_or_null("AimArrow") as Node3D
		if arrow != null:
			arrow.visible = false


func _cancel_active_charge(wait_for_release: bool) -> void:
	_hide_aim_arrow()
	_charge_seconds = 0.0
	_charge_cancelled_until_release = wait_for_release
	if _slap_actor != null:
		_slap_actor.call("set_stick_slap_angle", 0.0)
		_slap_actor.call("set_shot_aim_locked", false)
	_slap_actor = null
	_clear_charge_feedback()


func _planar_distance_to_player() -> float:
	var offset := global_position - _player.global_position
	return Vector2(offset.x, offset.z).length()


func _interaction_participants() -> Array:
	_refresh_field_players()
	var participants := []
	for actor in _field_players:
		var participant := {
			"position": actor.global_position,
			"velocity": actor.velocity,
			"facing": actor.call("get_facing_direction"),
			"slap_phase": _current_slap_phase() if actor == _slap_actor else &"idle",
			"actor_id": actor.call("get_actor_id"),
			"team": actor.call("get_team"),
			"pickup_blocked": actor.call("get_actor_id") == _pickup_lock_actor_id and _pickup_lock_seconds > 0.0,
			"shot_protected": actor == _slap_actor and _current_slap_phase() in [&"backswing", &"forward"],
		}
		var blade_pocket := actor.get_node_or_null("StickRig/BladePocket") as Marker3D
		if blade_pocket != null:
			blade_pocket.force_update_transform()
			participant.blade_target = blade_pocket.global_position
		participants.append(participant)
	return participants


func _refresh_field_players() -> void:
	if get_parent().has_method("get_field_players"):
		_field_players = get_parent().call("get_field_players")
	if _field_players.is_empty() and _player != null:
		_field_players = [_player]
	if _opponent == null:
		_opponent = get_parent().get_node_or_null("Opponent") as CharacterBody3D


func begin_slap(direction: Vector2, charge: float) -> void:
	_slap_actor = _red_input_actor()
	_configure_slap(direction, charge, 0.0)
	_slap_actor.call("set_stick_slap_angle", StickSlapScript.angle_at(0.0))


func pass_to_closest_teammate() -> bool:
	if _slap_elapsed >= 0.0:
		return false
	var carrier := _actor_for_controller(_control_owner)
	if carrier == null or carrier.call("get_team") != &"red" or carrier.call("get_actor_id") != get_human_control_actor_id():
		return false
	_refresh_field_players()
	var teammates := []
	for actor in _field_players:
		if actor.call("get_team") == &"red":
			teammates.append({"actor_id": actor.call("get_actor_id"), "position": actor.global_position})
	var facing: Vector3 = carrier.call("get_facing_direction")
	var target: Dictionary = SquadLogicScript.forward_teammate(carrier.call("get_actor_id"), carrier.global_position, facing, teammates)
	_cancel_active_charge(false)
	_slap_actor = carrier
	var offset := Vector2(facing.x, facing.z) if target.is_empty() else Vector2(target.position.x - carrier.global_position.x, target.position.z - carrier.global_position.z)
	_configure_slap(offset, 0.38, 0.0, true)
	_pending_soft_pass = target.is_empty()
	_slap_actor.call("set_stick_slap_angle", StickSlapScript.angle_at(0.0))
	return true


func _release_charged_slap(direction: Vector2, charge: float) -> void:
	_configure_slap(direction, charge, StickSlapScript.BACKSWING_SECONDS)


func _configure_slap(direction: Vector2, charge: float, start_elapsed: float, is_pass: bool = false) -> void:
	_slap_elapsed = start_elapsed
	_pending_slap_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_pending_slap_charge = clampf(charge, 0.0, 2.0)
	_pending_pass = is_pass
	_pending_soft_pass = false
	_pending_one_touch = not is_pass and is_one_touch_ready(&"red")
	_pending_bolt = not is_pass and _slap_actor.has_method("has_recent_dash") and bool(_slap_actor.call("has_recent_dash"))
	if _pending_pass:
		_charge_label.text = "PASS!"
	elif _pending_one_touch and _pending_bolt:
		_charge_label.text = "ONE TOUCH BOLT!"
	elif _pending_one_touch:
		_charge_label.text = "ONE TOUCH!"
	elif _pending_bolt:
		_charge_label.text = "BOLT!"
	else:
		_charge_label.text = "SLAP!"
	if _pending_one_touch or _pending_bolt:
		_charge_label.add_theme_color_override("font_color", Color("70f7ff"))


func get_slap_phase() -> StringName:
	return _current_slap_phase()


func _advance_slap(delta: float) -> void:
	if _slap_elapsed < 0.0:
		return
	var previous_elapsed := _slap_elapsed
	_slap_elapsed += delta
	_slap_actor.call("set_stick_slap_angle", StickSlapScript.angle_at(_slap_elapsed))
	var previous_step: float = StickSlapScript.forward_step_at(previous_elapsed)
	var current_step: float = StickSlapScript.forward_step_at(_slap_elapsed)
	var step_distance := current_step - previous_step
	if step_distance > 0.0:
		var step_direction := Vector3(_pending_slap_direction.x, 0.0, _pending_slap_direction.y)
		if not step_direction.is_zero_approx():
			_slap_actor.global_position += step_direction.normalized() * step_distance
	if StickSlapScript.crossed_contact(previous_elapsed, _slap_elapsed) and _ball_in_slap_actor_blade():
		var slap_team: StringName = _slap_actor.call("get_team")
		if _pending_pass:
			_launch_pass(_pending_slap_direction, _slap_actor.velocity, slap_team, _pending_soft_pass)
		else:
			launch(_pending_slap_direction, _pending_slap_charge, _slap_actor.velocity, _pending_one_touch, slap_team, _pending_bolt)
		_play_contact_feedback(_pending_slap_charge, _pending_bolt)
	if _slap_elapsed >= StickSlapScript.TOTAL_SECONDS:
		_cancel_slap()


func _cancel_slap() -> void:
	_hide_aim_arrow()
	_slap_elapsed = -1.0
	_pending_slap_charge = 0.0
	_pending_one_touch = false
	_pending_bolt = false
	_pending_pass = false
	_pending_soft_pass = false
	if _slap_actor != null:
		_slap_actor.call("set_stick_slap_angle", 0.0)
		_slap_actor.call("set_shot_aim_locked", false)
	if _charge_label != null and _charge_label.text in ["PASS!", "SLAP!", "ONE TOUCH!", "BOLT!", "ONE TOUCH BOLT!"]:
		_clear_charge_feedback()


func _current_slap_phase() -> StringName:
	if _slap_elapsed >= 0.0:
		return StickSlapScript.phase_at(_slap_elapsed)
	if _charge_seconds > 0.0:
		return &"backswing"
	return &"idle"


func _ball_in_slap_actor_blade() -> bool:
	var participant := {
		"position": _slap_actor.global_position,
		"velocity": _slap_actor.velocity,
		"facing": _slap_actor.call("get_facing_direction"),
	}
	var blade_pocket := _slap_actor.get_node_or_null("StickRig/BladePocket") as Marker3D
	if blade_pocket != null:
		blade_pocket.force_update_transform()
		participant.blade_target = blade_pocket.global_position
	return BallInteractionScript.is_in_blade_pocket(global_position, participant)


func _play_contact_feedback(charge: float, bolt: bool = false) -> void:
	var arena := get_parent()
	if arena.has_method("play_shot_impact"):
		arena.call("play_shot_impact", global_position, ShotImpactFeedbackScript.for_charge(charge, bolt))


func record_touch(actor: StringName) -> void:
	_last_touch_actor = actor
	_last_touch_age = 0.0


func is_one_touch_ready(shooter: StringName = &"red") -> bool:
	return OneTouchScript.is_eligible(_last_touch_actor, _last_touch_age, shooter)


func is_scoop_active() -> bool:
	return _scoop_remaining > 0.0


func is_controlled_by(team: StringName) -> bool:
	return get_control_owner_team() == team


func is_controlled_by_actor(actor_id: StringName) -> bool:
	return get_control_owner_actor_id() == actor_id


func get_control_owner_actor_id() -> StringName:
	var actor := _actor_for_controller(_control_owner)
	return actor.call("get_actor_id") if actor != null else &""


func get_control_owner_team() -> StringName:
	var actor := _actor_for_controller(_control_owner)
	return actor.call("get_team") if actor != null else &""


func get_human_control_actor_id() -> StringName:
	_refresh_field_players()
	for actor in _field_players:
		if actor.call("get_actor_id") == _human_control_actor_id and actor.call("get_team") == &"red":
			return _human_control_actor_id
	_human_control_actor_id = &"red_1"
	return _human_control_actor_id


func get_human_control_actor_id_for_team(team: StringName) -> StringName:
	return get_human_control_actor_id() if team == &"red" else _blue_human_control_actor_id


func _update_human_control_from_possession(previous_controller: int) -> void:
	if _control_owner == previous_controller:
		return
	var new_owner := _actor_for_controller(_control_owner)
	if new_owner == null:
		return
	var new_actor_id: StringName = new_owner.call("get_actor_id")
	var team: StringName = new_owner.call("get_team")
	if team == &"blue":
		_blue_human_control_actor_id = new_actor_id
		return
	if new_actor_id == _human_control_actor_id:
		return
	_human_control_actor_id = new_actor_id
	if _charge_seconds > 0.0:
		_cancel_active_charge(true)


func switch_human_player() -> StringName:
	return switch_human_player_for_team(&"red")


func switch_human_player_for_team(team: StringName) -> StringName:
	_refresh_field_players()
	var current := get_human_control_actor_id_for_team(team)
	var team_players := []
	for actor in _field_players:
		if actor.call("get_team") == team:
			team_players.append({"actor_id": actor.call("get_actor_id"), "position": actor.global_position})
	var next_actor: StringName = SquadLogicScript.next_human_actor_id(current, team_players, global_position)
	if next_actor == &"":
		return current
	if team == &"red":
		_human_control_actor_id = next_actor
	else:
		_blue_human_control_actor_id = next_actor
	if _charge_seconds > 0.0:
		_cancel_active_charge(true)
	return get_human_control_actor_id_for_team(team)


func apply_network_control_state(owner_id: StringName, red_human: StringName, blue_human: StringName) -> void:
	_human_control_actor_id = red_human
	_blue_human_control_actor_id = blue_human
	_control_owner = -1
	for index in _field_players.size():
		if _field_players[index].call("get_actor_id") == owner_id:
			_control_owner = index
			break


func _update_network_blue_actions(delta: float) -> void:
	var actor := _actor_by_id(_blue_human_control_actor_id)
	if actor == null or _slap_elapsed >= 0.0:
		_network_blue_was_shooting = OnlineMatch.remote_shoot
		return
	if OnlineMatch.remote_pass:
		_start_network_pass(actor)
		OnlineMatch.remote_pass = false
	if OnlineMatch.remote_shoot:
		_network_blue_charge = minf(MAX_CHARGE_SECONDS * 2.0, _network_blue_charge + delta)
		actor.call("set_shot_aim_locked", true)
		actor.call("set_stick_slap_angle", lerpf(-2.0, StickSlapScript.BACKSWING_ANGLE, pow(minf(1.0, _network_blue_charge / MAX_CHARGE_SECONDS), 2.0)))
	elif _network_blue_was_shooting and _network_blue_charge > 0.0:
		_slap_actor = actor
		var facing: Vector3 = actor.call("get_facing_direction")
		_configure_slap(Vector2(facing.x, facing.z), _network_blue_charge / MAX_CHARGE_SECONDS, StickSlapScript.BACKSWING_SECONDS)
		_network_blue_charge = 0.0
	_network_blue_was_shooting = OnlineMatch.remote_shoot


func _start_network_pass(actor: CharacterBody3D) -> void:
	if _control_owner < 0 or _actor_for_controller(_control_owner) != actor:
		return
	var teammates := []
	for candidate in _field_players:
		if candidate.call("get_team") == &"blue":
			teammates.append({"actor_id": candidate.call("get_actor_id"), "position": candidate.global_position})
	var facing: Vector3 = actor.call("get_facing_direction")
	var target: Dictionary = SquadLogicScript.forward_teammate(actor.call("get_actor_id"), actor.global_position, facing, teammates)
	var direction := Vector2(facing.x, facing.z) if target.is_empty() else Vector2(target.position.x - actor.global_position.x, target.position.z - actor.global_position.z)
	_slap_actor = actor
	_configure_slap(direction, 0.38, 0.0, true)
	_pending_soft_pass = target.is_empty()


func _actor_by_id(actor_id: StringName) -> CharacterBody3D:
	_refresh_field_players()
	for actor in _field_players:
		if actor.call("get_actor_id") == actor_id:
			return actor
	return null


func get_shot_charge_ratio() -> float:
	return clampf(_charge_seconds / MAX_CHARGE_SECONDS, 0.0, 1.0)


func _update_ai_pass(delta: float) -> void:
	_ai_pass_cooldown = maxf(0.0, _ai_pass_cooldown - delta)
	var carrier := _actor_for_controller(_control_owner)
	if carrier == null or carrier.call("get_team") != &"blue":
		_ai_possession_seconds = 0.0
		_reset_ai_shot()
		return
	_ai_possession_seconds += delta
	if StringName(carrier.get_meta("role", &"field")) == &"goalkeeper" and _ai_possession_seconds >= 0.55:
		var clear_direction := (Vector2.ZERO - Vector2(carrier.global_position.x, carrier.global_position.z)).normalized()
		ball_velocity = BallSimulationScript.pass_velocity(clear_direction, carrier.velocity)
		_pickup_lock_actor_id = carrier.call("get_actor_id")
		_pickup_lock_seconds = PASSER_PICKUP_LOCK_SECONDS
		_control_owner = -1
		_ai_possession_seconds = 0.0
		_ai_pass_cooldown = 0.8
		record_touch(&"blue")
		return
	if _ai_carrier_should_shoot(carrier):
		_update_ai_shot(carrier, delta)
		return
	_reset_ai_shot()
	if _ai_possession_seconds < 0.75 or _ai_pass_cooldown > 0.0:
		return
	var teammates: Array = []
	var opponents: Array = []
	for actor in _field_players:
		if actor == carrier:
			continue
		if actor.call("get_team") == &"blue":
			teammates.append({"actor_id": actor.call("get_actor_id"), "position": actor.global_position})
		else:
			opponents.append(actor.global_position)
	var carrier_facing: Vector3 = carrier.call("get_facing_direction")
	var decision: Dictionary = SquadLogicScript.pass_plan(carrier.global_position, teammates, opponents, &"blue", _pass_index, carrier_facing)
	if not decision.wants_pass:
		ball_velocity = BallSimulationScript.soft_touch_velocity(Vector2(carrier_facing.x, carrier_facing.z), carrier.velocity)
		_pickup_lock_actor_id = carrier.call("get_actor_id")
		_pickup_lock_seconds = PASSER_PICKUP_LOCK_SECONDS
		_control_owner = -1
		_ai_possession_seconds = 0.0
		_ai_pass_cooldown = 0.8
		return
	ball_velocity = BallSimulationScript.pass_velocity(decision.direction, carrier.velocity)
	_pickup_lock_actor_id = carrier.call("get_actor_id")
	_pickup_lock_seconds = PASSER_PICKUP_LOCK_SECONDS
	_control_owner = -1
	_ai_possession_seconds = 0.0
	_ai_pass_cooldown = 0.8
	_pass_index += 1
	record_touch(&"blue")


func _ai_carrier_should_shoot(carrier: CharacterBody3D) -> bool:
	var carrier_position := Vector2(carrier.global_position.x, carrier.global_position.z)
	return carrier_position.distance_to(AI_GOAL) <= AI_SHOOT_DISTANCE and global_position.y <= 0.7 and Vector2(ball_velocity.x, ball_velocity.z).length() <= 8.0


func _update_ai_shot(carrier: CharacterBody3D, delta: float) -> void:
	if _ai_shot_actor != carrier:
		_reset_ai_shot()
		_ai_shot_actor = carrier
	_ai_shot_seconds += delta
	var charge_ratio := clampf(_ai_shot_seconds / AI_SHOT_CHARGE_SECONDS, 0.0, 1.0)
	carrier.call("set_shot_aim_locked", true)
	carrier.call("set_stick_slap_angle", lerpf(-2.0, StickSlapScript.BACKSWING_ANGLE, charge_ratio * charge_ratio))
	if _ai_shot_seconds < AI_SHOT_CHARGE_SECONDS:
		return
	var direction := (AI_GOAL - Vector2(global_position.x, global_position.z)).normalized()
	carrier.call("set_stick_slap_angle", 0.0)
	carrier.call("set_shot_aim_locked", false)
	_ai_shot_actor = null
	_ai_shot_seconds = 0.0
	launch(direction, 0.72, carrier.velocity, false, &"blue")
	_ai_pass_cooldown = 0.8


func _reset_ai_shot() -> void:
	if _ai_shot_actor != null:
		_ai_shot_actor.call("set_stick_slap_angle", 0.0)
		_ai_shot_actor.call("set_shot_aim_locked", false)
	_ai_shot_actor = null
	_ai_shot_seconds = 0.0


func _record_body_touch(controller: int) -> void:
	var team := _team_for_controller(controller)
	if team != &"":
		record_touch(team)


func _apply_dash_steal(body_controller: int) -> void:
	if _control_owner >= 0 and _slap_actor == _actor_for_controller(_control_owner) and _current_slap_phase() in [&"backswing", &"forward"]:
		return
	if body_controller < 0 or body_controller >= _field_players.size():
		return
	var dashing_controller := body_controller if _is_controller_dashing(body_controller) else -1
	if not DashStealScript.can_steal(body_controller, dashing_controller, bool(_dash_steal_consumed.get(body_controller, false))):
		return
	var actor := _actor_for_controller(body_controller)
	var team: StringName = actor.call("get_team")
	ball_velocity = DashStealScript.poke_velocity(actor.velocity)
	_control_owner = -1
	_dash_steal_consumed[body_controller] = true
	record_touch(team)
	_award_heat(team, 20.0)
	_show_steal_feedback(team)
	var feedback_color := STEAL_COLOR if team == &"red" else BLUE_STEAL_COLOR
	var arena := get_parent()
	if arena.has_method("play_shot_impact"):
		arena.call("play_shot_impact", global_position, {
			"scale": 1.65,
			"kick": 0.065,
			"duration": 0.22,
			"color": feedback_color,
		})


func _apply_parry(body_controller: int) -> bool:
	if body_controller < 0 or body_controller >= _field_players.size():
		return false
	var actor := _actor_for_controller(body_controller)
	if actor == null or not actor.has_method("has_parry_window"):
		return false
	if not ParryScript.can_parry(global_position, ball_velocity, actor.global_position, bool(actor.call("has_parry_window"))):
		return false
	var team: StringName = actor.call("get_team")
	ball_velocity = ParryScript.reflected_velocity(ball_velocity)
	_control_owner = -1
	_dash_steal_consumed[body_controller] = true
	record_touch(team)
	if actor.has_method("activate_en_fuego"):
		actor.call("activate_en_fuego")
	_steal_feedback_remaining = STEAL_FEEDBACK_SECONDS
	_charge_label.text = "PARRY!" if team == &"red" else "PIRATES PARRY!"
	_charge_label.add_theme_color_override("font_color", PARRY_TRAIL_EMISSION)
	_set_shot_trail_style(false, false, true)
	var arena := get_parent()
	if arena.has_method("play_shot_impact"):
		arena.call("play_shot_impact", global_position, {
			"scale": 2.2,
			"kick": 0.095,
			"duration": 0.28,
			"color": PARRY_TRAIL_EMISSION,
		})
	return true


func _update_dash_steal_latches() -> void:
	for controller in _field_players.size():
		if not _is_controller_dashing(controller):
			_dash_steal_consumed[controller] = false


func _is_controller_dashing(controller: int) -> bool:
	var actor := _actor_for_controller(controller)
	return actor != null and actor.has_method("is_dashing") and bool(actor.call("is_dashing"))


func _actor_for_controller(controller: int) -> CharacterBody3D:
	_refresh_field_players()
	return _field_players[controller] if controller >= 0 and controller < _field_players.size() else null


func _team_for_controller(controller: int) -> StringName:
	var actor := _actor_for_controller(controller)
	return actor.call("get_team") if actor != null else &""


func _show_steal_feedback(team: StringName) -> void:
	_steal_feedback_remaining = STEAL_FEEDBACK_SECONDS
	_charge_label.text = "STEAL!" if team == &"red" else "PIRATES STEAL!"
	_charge_label.add_theme_color_override("font_color", STEAL_COLOR if team == &"red" else BLUE_STEAL_COLOR)


func _award_heat(team: StringName, amount: float) -> void:
	for actor in _field_players:
		if actor.call("get_team") == team and actor.has_method("add_heat"):
			actor.call("add_heat", amount)
			return


func _update_steal_feedback(delta: float) -> void:
	if _steal_feedback_remaining <= 0.0:
		return
	_steal_feedback_remaining = maxf(0.0, _steal_feedback_remaining - delta)
	if _steal_feedback_remaining <= 0.0 and _charge_label.text in ["STEAL!", "PIRATES STEAL!", "PARRY!", "PIRATES PARRY!"]:
		_clear_charge_feedback()


func _update_scoop_feedback(delta: float) -> void:
	if _scoop_remaining <= 0.0:
		return
	_scoop_remaining = maxf(0.0, _scoop_remaining - delta)
	if _scoop_remaining <= 0.0 and _charge_label != null and _charge_label.text == "SCOOP!":
		_clear_charge_feedback()


func _update_spin(delta: float) -> void:
	var planar_velocity := Vector3(ball_velocity.x, 0.0, ball_velocity.z)
	var planar_speed := planar_velocity.length()
	if planar_speed > 0.05:
		var roll_axis := Vector3.UP.cross(planar_velocity.normalized())
		var roll_angle := planar_speed * delta / BallSimulationScript.BALL_RADIUS
		global_basis = Basis(roll_axis, roll_angle) * global_basis


func _update_shot_trail() -> void:
	if _shot_trail == null:
		_shot_trail = get_node_or_null("ShotTrail") as MeshInstance3D
	if _shot_trail == null:
		return
	var speed := ball_velocity.length()
	if speed < TRAIL_SPEED_THRESHOLD:
		_shot_trail.visible = false
		return
	var direction := ball_velocity.normalized()
	var trail_length := clampf(speed * 0.065, TRAIL_MIN_LENGTH, TRAIL_MAX_LENGTH)
	_shot_trail.scale = Vector3(1.0, 1.0, trail_length)
	_shot_trail.global_position = global_position - direction * trail_length * 0.5
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.94 else Vector3.UP
	_shot_trail.global_basis = Basis.looking_at(-direction, up)
	_shot_trail.visible = true


func _set_trail_visible(value: bool) -> void:
	if _shot_trail == null:
		_shot_trail = get_node_or_null("ShotTrail") as MeshInstance3D
	if _shot_trail != null:
		_shot_trail.visible = value


func _set_shot_trail_style(bolt: bool, scoop: bool = false, parry: bool = false) -> void:
	if _shot_trail == null:
		_shot_trail = get_node_or_null("ShotTrail") as MeshInstance3D
	if _shot_trail == null:
		return
	var material := _shot_trail.material_override as StandardMaterial3D
	var trail_color: Color = PARRY_TRAIL_COLOR if parry else BOLT_TRAIL_COLOR if bolt else SCOOP_TRAIL_COLOR if scoop else NORMAL_TRAIL_COLOR
	var trail_emission: Color = PARRY_TRAIL_EMISSION if parry else BOLT_TRAIL_EMISSION if bolt else SCOOP_TRAIL_EMISSION if scoop else NORMAL_TRAIL_EMISSION
	material.albedo_color = trail_color
	material.emission = trail_emission
	var core := _shot_trail.get_node_or_null("TrailCore") as MeshInstance3D
	if core != null:
		var core_material := core.material_override as StandardMaterial3D
		core_material.albedo_color = Color(trail_color.lerp(Color.WHITE, 0.62), minf(0.92, trail_color.a + 0.2))
		core_material.emission = trail_emission.lerp(Color.WHITE, 0.42)


func _apply_charge_feedback(normalized_charge: float) -> void:
	var feedback := ShotChargeFeedbackScript.for_charge(normalized_charge)
	_charge_label.text = feedback.label
	_charge_label.add_theme_color_override("font_color", feedback.color)


func _clear_charge_feedback() -> void:
	if _charge_label == null:
		return
	_charge_label.text = ""
	_charge_label.add_theme_color_override("font_color", ShotChargeFeedbackScript.CHARGING_COLOR)
