extends CharacterBody3D

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RinkCollisionScript = preload("res://scripts/simulation/rink_collision.gd")
const HeatSystemScript = preload("res://scripts/simulation/heat_system.gd")
const SquadLogicScript = preload("res://scripts/simulation/squad_logic.gd")
const StickSwingPoseScript = preload("res://scripts/presentation/stick_swing_pose.gd")
const RINK_HALF_LENGTH := 19.1
const RINK_HALF_WIDTH := 9.1
const DASH_STREAK_SECONDS := 0.18
const BOLT_WINDOW_SECONDS := 0.2
const PARRY_WINDOW_SECONDS := 0.15

var _facing_direction := Vector3.RIGHT
var _mobile_controls: Control
var _dash_cooldown := 0.0
var _dash_streak_remaining := 0.0
var _dash_streak: Node3D
var _dash_direction := Vector3.RIGHT
var _recent_dash_remaining := 0.0
var _parry_window_remaining := 0.0
var _heat := 0.0
var _fuego_remaining := 0.0
var _fuego_aura: MeshInstance3D
var _heat_bar: ProgressBar
var _shot_aim_locked := false
var _ball: Node3D
var _control_ring: MeshInstance3D


func _ready() -> void:
	rotation.y = atan2(_facing_direction.x, _facing_direction.z)
	_mobile_controls = get_node_or_null("../../HUD/MobileControls") as Control
	_dash_streak = get_node_or_null("DashStreak") as Node3D
	_fuego_aura = get_node_or_null("FuegoAura") as MeshInstance3D
	_heat_bar = get_node_or_null("../../HUD/RedHeatBar") as ProgressBar
	_ball = get_parent().get_node_or_null("Ball") as Node3D
	_control_ring = get_node_or_null("ControlRing") as MeshInstance3D


func _physics_process(delta: float) -> void:
	if _ball == null:
		_ball = get_parent().get_node_or_null("Ball") as Node3D
	if _control_ring == null:
		_control_ring = get_node_or_null("ControlRing") as MeshInstance3D
	if _control_ring != null:
		_control_ring.visible = is_human_controlled()
	_step_heat(delta)
	var input_vector: Vector2 = _human_movement() if is_human_controlled() else _ai_movement()
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_dash_streak_remaining = maxf(0.0, _dash_streak_remaining - delta)
	_recent_dash_remaining = maxf(0.0, _recent_dash_remaining - delta)
	_parry_window_remaining = maxf(0.0, _parry_window_remaining - delta)
	if _dash_streak != null:
		_dash_streak.visible = _dash_streak_remaining > 0.0
		if _dash_streak.visible:
			var burst_progress := 1.0 - _dash_streak_remaining / DASH_STREAK_SECONDS
			_dash_streak.scale = Vector3.ONE * lerpf(1.0, 1.42, burst_progress)
	if is_human_controlled() and Input.is_action_just_pressed("dash"):
		try_dash(input_vector)
	if is_dashing():
		velocity = _dash_direction * PlayerMotorScript.DASH_SPEED
	else:
		var has_ball := _ball != null and _ball.has_method("is_controlled_by_actor") and bool(_ball.call("is_controlled_by_actor", get_actor_id()))
		var speed_multiplier := PlayerMotorScript.movement_speed_multiplier(is_human_controlled(), has_ball, HeatSystemScript.speed_multiplier(_fuego_remaining))
		velocity = PlayerMotorScript.step_velocity(velocity, input_vector, delta, speed_multiplier)
	move_and_slide()
	var boundary := RinkCollisionScript.constrain_body(global_position, velocity, RINK_HALF_LENGTH, RINK_HALF_WIDTH, 1.8)
	global_position = boundary.position
	velocity = boundary.velocity

	if velocity.length_squared() > 0.04:
		var facing_planar := Vector2(velocity.x, velocity.z).normalized()
		if not is_human_controlled():
			var owner_team: StringName = _ball.call("get_control_owner_team") if _ball.has_method("get_control_owner_team") else &""
			facing_planar = SquadLogicScript.tactical_facing(Vector2(global_position.x, global_position.z), facing_planar, _ball.global_position, owner_team == get_team())
		rotation.y = PlayerMotorScript.step_facing_rotation(rotation.y, facing_planar, delta)
		_facing_direction = PlayerMotorScript.facing_from_rotation(rotation.y)
	if _mobile_controls != null and _mobile_controls.has_method("set_dash_cooldown_ratio"):
		_mobile_controls.call("set_dash_cooldown_ratio", get_dash_cooldown_ratio())


func _human_movement() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch := Vector2.ZERO
	if _mobile_controls != null and _mobile_controls.has_method("get_movement_vector"):
		touch = _mobile_controls.call("get_movement_vector")
	return PlayerMotorScript.combine_inputs(keyboard, touch)


func _ai_movement() -> Vector2:
	if _ball == null:
		return Vector2.ZERO
	var teammates: Array = []
	for actor in get_parent().call("get_team_players", get_team()):
		if StringName(actor.get_meta("role", &"field")) == &"goalkeeper":
			continue
		teammates.append({"actor_id": actor.call("get_actor_id"), "position": actor.global_position})
	var owner_team: StringName = _ball.call("get_control_owner_team") if _ball.has_method("get_control_owner_team") else &""
	var team_has_possession := owner_team == get_team()
	var opposition_team := &"blue" if get_team() == &"red" else &"red"
	var opponents: Array = []
	for actor in get_parent().call("get_team_players", opposition_team):
		if StringName(actor.get_meta("role", &"field")) != &"goalkeeper":
			opponents.append({"position": actor.global_position})
	var target := SquadLogicScript.support_target(get_team(), get_squad_slot(), _ball.global_position, team_has_possession, _ball.ball_velocity, opponents)
	if not team_has_possession and SquadLogicScript.is_closest_to_ball(get_actor_id(), global_position, teammates, _ball.global_position):
		target = SquadLogicScript.pressure_target(get_team(), _ball.global_position, _ball.ball_velocity)
	return SquadLogicScript.arrival_movement(Vector2(global_position.x, global_position.z), target)


func get_facing_direction() -> Vector3:
	return _facing_direction


func apply_network_rotation(rotation_y: float) -> void:
	rotation.y = rotation_y
	_facing_direction = PlayerMotorScript.facing_from_rotation(rotation_y)


func get_actor_id() -> StringName:
	return StringName(get_meta("actor_id", &"red_1"))


func get_team() -> StringName:
	return StringName(get_meta("team", &"red"))


func get_squad_slot() -> int:
	return int(get_meta("squad_slot", 0))


func is_human_controlled() -> bool:
	if _ball == null:
		_ball = get_parent().find_child("Ball", true, false) as Node3D
	return _ball != null and _ball.has_method("get_human_control_actor_id") and _ball.call("get_human_control_actor_id") == get_actor_id()


func set_shot_aim_locked(value: bool) -> void:
	_shot_aim_locked = value


func is_shot_aim_locked() -> bool:
	return _shot_aim_locked


func get_dash_cooldown_ratio() -> float:
	return clampf(_dash_cooldown / PlayerMotorScript.DASH_COOLDOWN, 0.0, 1.0)


func is_dashing() -> bool:
	return _dash_streak_remaining > 0.0


func has_recent_dash() -> bool:
	return _recent_dash_remaining > 0.0001


func has_parry_window() -> bool:
	return _parry_window_remaining > 0.0001


func try_dash(input_vector: Vector2 = Vector2.ZERO) -> bool:
	if _dash_streak == null:
		_dash_streak = get_node_or_null("DashStreak") as Node3D
	var dash: Dictionary = PlayerMotorScript.start_dash(input_vector, _dash_cooldown, _facing_direction)
	if not dash.started:
		return false
	velocity = dash.velocity
	_dash_direction = dash.velocity.normalized()
	_dash_cooldown = dash.cooldown
	_dash_streak_remaining = DASH_STREAK_SECONDS
	_recent_dash_remaining = BOLT_WINDOW_SECONDS
	_parry_window_remaining = PARRY_WINDOW_SECONDS
	add_heat(5.0)
	if _dash_streak != null:
		_dash_streak.scale = Vector3.ONE
		_dash_streak.visible = true
	return true


func add_heat(amount: float) -> bool:
	var result := HeatSystemScript.add_heat(_heat, _fuego_remaining, amount)
	_heat = result.heat
	_fuego_remaining = result.fuego_remaining
	_update_heat_presentation()
	return result.activated


func get_heat_ratio() -> float:
	return clampf(_heat / HeatSystemScript.MAX_HEAT, 0.0, 1.0)


func is_en_fuego() -> bool:
	return _fuego_remaining > 0.0


func activate_en_fuego() -> void:
	var result := HeatSystemScript.activate()
	_heat = result.heat
	_fuego_remaining = result.fuego_remaining
	_dash_cooldown = 0.0
	_update_heat_presentation()


func reset_heat() -> void:
	_heat = 0.0
	_fuego_remaining = 0.0
	_update_heat_presentation()


func _step_heat(delta: float) -> void:
	var result := HeatSystemScript.step(_heat, _fuego_remaining, delta)
	_heat = result.heat
	_fuego_remaining = result.fuego_remaining
	if is_en_fuego():
		_dash_cooldown = 0.0
	_update_heat_presentation()


func _update_heat_presentation() -> void:
	if _fuego_aura == null:
		_fuego_aura = get_node_or_null("FuegoAura") as MeshInstance3D
	if _heat_bar == null:
		_heat_bar = get_node_or_null("../../HUD/RedHeatBar") as ProgressBar
	if _fuego_aura != null:
		_fuego_aura.visible = is_en_fuego()
		if _fuego_aura.visible:
			var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.09
			_fuego_aura.scale = Vector3.ONE * pulse
	if _heat_bar != null:
		_heat_bar.value = _heat
		_heat_bar.modulate = Color("ffb12e") if is_en_fuego() else Color("ff765c")


func set_stick_slap_angle(angle_degrees: float) -> void:
	set_meta("stick_slap_angle", angle_degrees)
	var stick_rig := get_node_or_null("StickRig") as Node3D
	if stick_rig != null:
		StickSwingPoseScript.apply(stick_rig, angle_degrees)
	var body_rig := get_node_or_null("BodyRig") as Node3D
	if body_rig != null and body_rig.has_method("set_swing_pose"):
		body_rig.call("set_swing_pose", angle_degrees)
