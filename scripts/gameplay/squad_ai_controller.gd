extends CharacterBody3D

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RinkCollisionScript = preload("res://scripts/simulation/rink_collision.gd")
const SquadLogicScript = preload("res://scripts/simulation/squad_logic.gd")
const StickSwingPoseScript = preload("res://scripts/presentation/stick_swing_pose.gd")
const RINK_HALF_LENGTH := 19.1
const RINK_HALF_WIDTH := 9.1
const DASH_STREAK_SECONDS := 0.18
const OPENING_GRACE_SECONDS := 2.0

var _facing_direction := Vector3.RIGHT
var _ball: Node3D
var _mobile_controls: Control
var _shot_aim_locked := false
var _control_ring: MeshInstance3D
var _dash_cooldown := 0.0
var _dash_streak_remaining := 0.0
var _dash_direction := Vector3.RIGHT
var _dash_streak: Node3D
var _opening_grace_remaining := OPENING_GRACE_SECONDS


func _ready() -> void:
	_ball = get_parent().get_node("Ball") as Node3D
	_mobile_controls = get_node_or_null("../../HUD/MobileControls") as Control
	_facing_direction = Vector3.RIGHT if get_team() == &"red" else Vector3.LEFT
	rotation.y = atan2(_facing_direction.x, _facing_direction.z)
	_control_ring = get_node_or_null("ControlRing") as MeshInstance3D
	_dash_streak = get_node_or_null("DashStreak") as Node3D


func _physics_process(delta: float) -> void:
	if _control_ring == null:
		_control_ring = get_node_or_null("ControlRing") as MeshInstance3D
	if _control_ring != null:
		_control_ring.visible = is_human_controlled()
	if not _ball.is_physics_processing():
		velocity = Vector3.ZERO
		_dash_streak_remaining = 0.0
		if _dash_streak != null:
			_dash_streak.visible = false
		return
	_opening_grace_remaining = maxf(0.0, _opening_grace_remaining - delta)
	var movement := _human_movement() if is_human_controlled() else Vector2.ZERO if get_team() == &"blue" and _opening_grace_remaining > 0.0 else _ai_movement()
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_dash_streak_remaining = maxf(0.0, _dash_streak_remaining - delta)
	_update_dash_feedback()
	var human_dash_pressed := Input.is_action_just_pressed("dash")
	if is_human_controlled() and OnlineMatch.is_authority() and get_team() == &"blue":
		human_dash_pressed = OnlineMatch.remote_dash
	if is_human_controlled() and human_dash_pressed:
		try_dash(movement)
		if OnlineMatch.is_authority() and get_team() == &"blue":
			OnlineMatch.remote_dash = false
	if is_dashing():
		velocity = _dash_direction * PlayerMotorScript.DASH_SPEED
	else:
		var has_ball := _ball.has_method("is_controlled_by_actor") and bool(_ball.call("is_controlled_by_actor", get_actor_id()))
		var speed_multiplier := PlayerMotorScript.movement_speed_multiplier(is_human_controlled(), has_ball)
		velocity = PlayerMotorScript.step_velocity(velocity, movement, delta, speed_multiplier)
	move_and_slide()
	var boundary := RinkCollisionScript.constrain_body(global_position, velocity, RINK_HALF_LENGTH, RINK_HALF_WIDTH, 1.8)
	global_position = boundary.position
	velocity = boundary.velocity
	var facing_planar := movement
	if not is_human_controlled():
		var owner_team: StringName = _ball.call("get_control_owner_team") if _ball.has_method("get_control_owner_team") else &""
		facing_planar = SquadLogicScript.tactical_facing(Vector2(global_position.x, global_position.z), movement, _ball.global_position, owner_team == get_team())
	if (is_human_controlled() or not _shot_aim_locked) and not facing_planar.is_zero_approx():
		rotation.y = PlayerMotorScript.step_facing_rotation(rotation.y, facing_planar, delta)
		_facing_direction = PlayerMotorScript.facing_from_rotation(rotation.y)
	if is_human_controlled() and _mobile_controls != null and _mobile_controls.has_method("set_dash_cooldown_ratio"):
		_mobile_controls.call("set_dash_cooldown_ratio", get_dash_cooldown_ratio())
	if is_human_controlled() and OnlineMatch.is_authority() and get_team() == &"blue":
		OnlineMatch.call("mark_remote_command_simulated")


func _human_movement() -> Vector2:
	var online_match := get_node_or_null("/root/OnlineMatch")
	if online_match != null and bool(online_match.get("enabled")) and bool(online_match.call("is_authority")) and get_team() == &"blue":
		return online_match.get("remote_input")
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch := Vector2.ZERO
	if _mobile_controls != null and _mobile_controls.has_method("get_movement_vector"):
		touch = _mobile_controls.call("get_movement_vector")
	return PlayerMotorScript.combine_inputs(keyboard, touch)


func _ai_movement() -> Vector2:
	var teammates: Array = []
	for actor in get_parent().call("get_team_players", get_team()):
		if StringName(actor.get_meta("role", &"field")) == &"goalkeeper":
			continue
		teammates.append({"actor_id": actor.call("get_actor_id"), "position": actor.global_position})
	var owner_team: StringName = _ball.call("get_control_owner_team") if _ball.has_method("get_control_owner_team") else &""
	var owner_actor: StringName = _ball.call("get_control_owner_actor_id") if _ball.has_method("get_control_owner_actor_id") else &""
	var team_has_possession := owner_team == get_team()
	var opposition_team := &"blue" if get_team() == &"red" else &"red"
	var opponents: Array = []
	for actor in get_parent().call("get_team_players", opposition_team):
		if StringName(actor.get_meta("role", &"field")) != &"goalkeeper":
			opponents.append({"position": actor.global_position})
	var target := SquadLogicScript.support_target(get_team(), get_squad_slot(), _ball.global_position, team_has_possession, _ball.ball_velocity, opponents)
	if owner_actor == get_actor_id():
		target = Vector2(14.0, 0.0) if get_team() == &"red" else Vector2(-14.0, 0.0)
	elif not team_has_possession and SquadLogicScript.is_closest_to_ball(get_actor_id(), global_position, teammates, _ball.global_position):
		target = SquadLogicScript.pressure_target(get_team(), _ball.global_position, _ball.ball_velocity)
	return SquadLogicScript.arrival_movement(Vector2(global_position.x, global_position.z), target)


func get_facing_direction() -> Vector3:
	return _facing_direction


func apply_network_rotation(rotation_y: float) -> void:
	rotation.y = rotation_y
	_facing_direction = PlayerMotorScript.facing_from_rotation(rotation_y)


func set_shot_aim_locked(value: bool) -> void:
	_shot_aim_locked = value


func set_stick_slap_angle(angle_degrees: float) -> void:
	set_meta("stick_slap_angle", angle_degrees)
	var stick_rig := get_node_or_null("StickRig") as Node3D
	if stick_rig != null:
		StickSwingPoseScript.apply(stick_rig, angle_degrees)
	var body_rig := get_node_or_null("BodyRig") as Node3D
	if body_rig != null and body_rig.has_method("set_swing_pose"):
		body_rig.call("set_swing_pose", angle_degrees)


func get_actor_id() -> StringName:
	return StringName(get_meta("actor_id", &""))


func get_team() -> StringName:
	return StringName(get_meta("team", &""))


func get_squad_slot() -> int:
	return int(get_meta("squad_slot", 0))


func is_human_controlled() -> bool:
	return _ball != null and _ball.has_method("get_human_control_actor_id_for_team") and _ball.call("get_human_control_actor_id_for_team", get_team()) == get_actor_id()


func is_dashing() -> bool:
	return _dash_streak_remaining > 0.0


func try_dash(input_vector: Vector2 = Vector2.ZERO) -> bool:
	var dash: Dictionary = PlayerMotorScript.start_dash(input_vector, _dash_cooldown, _facing_direction)
	if not dash.started:
		return false
	_dash_direction = dash.velocity.normalized()
	velocity = dash.velocity
	_dash_cooldown = dash.cooldown
	_dash_streak_remaining = DASH_STREAK_SECONDS
	_update_dash_feedback()
	return true


func get_dash_cooldown_ratio() -> float:
	return clampf(_dash_cooldown / PlayerMotorScript.DASH_COOLDOWN, 0.0, 1.0)


func get_network_dash_state() -> Dictionary:
	return {"cooldown": _dash_cooldown, "remaining": _dash_streak_remaining, "direction": _dash_direction}


func apply_network_dash_state(cooldown: float, remaining: float, direction: Vector3) -> void:
	_dash_cooldown = maxf(0.0, cooldown)
	_dash_streak_remaining = maxf(0.0, remaining)
	if not direction.is_zero_approx():
		_dash_direction = direction.normalized()
	_update_dash_feedback()


func reset_for_faceoff() -> void:
	_opening_grace_remaining = OPENING_GRACE_SECONDS
	velocity = Vector3.ZERO


func _update_dash_feedback() -> void:
	if _dash_streak == null:
		_dash_streak = get_node_or_null("DashStreak") as Node3D
	if _dash_streak == null:
		return
	_dash_streak.visible = is_dashing()
	if _dash_streak.visible:
		var progress := 1.0 - _dash_streak_remaining / DASH_STREAK_SECONDS
		_dash_streak.scale = Vector3.ONE * lerpf(0.9, 1.42, progress)
