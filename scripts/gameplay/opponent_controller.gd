extends CharacterBody3D

const SimpleAIScript = preload("res://scripts/simulation/simple_ai.gd")
const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RinkCollisionScript = preload("res://scripts/simulation/rink_collision.gd")
const HeatSystemScript = preload("res://scripts/simulation/heat_system.gd")
const PlayerContactScript = preload("res://scripts/simulation/player_contact.gd")
const SquadLogicScript = preload("res://scripts/simulation/squad_logic.gd")
const RINK_HALF_LENGTH := 19.1
const RINK_HALF_WIDTH := 9.1
const SHOT_CHARGE_SECONDS := 0.55
const SHOT_COOLDOWN_SECONDS := 0.8
const DASH_STREAK_SECONDS := 0.18
const PARRY_WINDOW_SECONDS := 0.15
const OPENING_GRACE_SECONDS := 2.0
const ACTIVE_PLAYER_GRACE_SECONDS := 0.5

var _facing_direction := Vector3.LEFT
var _shot_charge := 0.0
var _shot_cooldown := 0.0
var _ball: MeshInstance3D
var _player: CharacterBody3D
var _dash_cooldown := 0.0
var _dash_streak_remaining := 0.0
var _dash_direction := Vector3.LEFT
var _parry_window_remaining := 0.0
var _dash_streak: Node3D
var _heat := 0.0
var _fuego_remaining := 0.0
var _fuego_aura: MeshInstance3D
var _heat_bar: ProgressBar
var _opening_grace_remaining := OPENING_GRACE_SECONDS


func _ready() -> void:
	_ball = get_parent().get_node("Ball") as MeshInstance3D
	_player = get_parent().get_node("Player") as CharacterBody3D
	_dash_streak = get_node_or_null("DashStreak") as Node3D
	_fuego_aura = get_node_or_null("FuegoAura") as MeshInstance3D
	_heat_bar = get_node_or_null("../../HUD/BlueHeatBar") as ProgressBar


func _physics_process(delta: float) -> void:
	_step_heat(delta)
	_parry_window_remaining = maxf(0.0, _parry_window_remaining - delta)
	if not _ball.is_physics_processing():
		velocity = Vector3.ZERO
		_dash_streak_remaining = 0.0
		if _dash_streak != null:
			_dash_streak.visible = false
		return

	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_opening_grace_remaining = maxf(0.0, _opening_grace_remaining - delta)
	if _player.velocity.length_squared() > 0.04:
		_opening_grace_remaining = minf(_opening_grace_remaining, ACTIVE_PLAYER_GRACE_SECONDS)
	_dash_streak_remaining = maxf(0.0, _dash_streak_remaining - delta)
	_update_dash_streak()
	var has_possession := _ball.has_method("is_controlled_by") and bool(_ball.call("is_controlled_by", &"blue"))
	var decision := SimpleAIScript.decide(
		global_position,
		_ball.global_position,
		_player.global_position,
		_ball.ball_velocity,
		_dash_cooldown <= 0.0,
		has_possession,
		_opening_grace_remaining > 0.0
	)
	var teammates := []
	for actor in get_parent().call("get_team_players", &"blue"):
		teammates.append({"actor_id": actor.call("get_actor_id"), "position": actor.global_position})
	var owner_team: StringName = _ball.call("get_control_owner_team") if _ball.has_method("get_control_owner_team") else &""
	var owner_actor: StringName = _ball.call("get_control_owner_actor_id") if _ball.has_method("get_control_owner_actor_id") else &""
	var should_press := owner_team != &"blue" and SquadLogicScript.is_closest_to_ball(get_actor_id(), global_position, teammates, _ball.global_position)
	if owner_actor != get_actor_id() and not should_press:
		var support_target := SquadLogicScript.support_target(&"blue", 0, _ball.global_position, owner_team == &"blue")
		decision.movement = (support_target - Vector2(global_position.x, global_position.z)).normalized()
		decision.wants_dash = false
	if decision.wants_dash:
		try_dash(decision.movement)
	if is_dashing():
		velocity = _dash_direction * PlayerMotorScript.DASH_SPEED
	else:
		var speed_multiplier := HeatSystemScript.speed_multiplier(_fuego_remaining)
		if _ball.has_method("is_controlled_by_actor") and bool(_ball.call("is_controlled_by_actor", get_actor_id())):
			speed_multiplier *= PlayerMotorScript.BALL_CARRIER_SPEED_MULTIPLIER
		velocity = PlayerMotorScript.step_velocity(velocity, decision.movement, delta, speed_multiplier)
	move_and_slide()
	var boundary := RinkCollisionScript.constrain_body(global_position, velocity, RINK_HALF_LENGTH, RINK_HALF_WIDTH, 1.8)
	global_position = boundary.position
	velocity = boundary.velocity
	_resolve_player_contact()

	var facing_planar: Vector2 = decision.shot_direction if decision.wants_shot else decision.movement
	if not facing_planar.is_zero_approx():
		_facing_direction = Vector3(facing_planar.x, 0.0, facing_planar.y).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(_facing_direction.x, _facing_direction.z), minf(1.0, delta * 10.0))

	_update_shot(decision, delta)


func _update_shot(decision: Dictionary, delta: float) -> void:
	if decision.wants_shot and _shot_cooldown <= 0.0:
		_shot_charge += delta
		if _shot_charge >= SHOT_CHARGE_SECONDS:
			_ball.call("launch", decision.shot_direction, 0.72, Vector3.ZERO, false, &"blue")
			_shot_charge = 0.0
			_shot_cooldown = SHOT_COOLDOWN_SECONDS
	else:
		_shot_charge = 0.0


func _resolve_player_contact() -> void:
	var contact: Dictionary = PlayerContactScript.resolve(
		_player.global_position,
		_player.velocity,
		global_position,
		velocity
	)
	_player.global_position = contact.position_a
	_player.velocity = contact.velocity_a
	global_position = contact.position_b
	velocity = contact.velocity_b


func get_facing_direction() -> Vector3:
	return _facing_direction


func get_actor_id() -> StringName:
	return StringName(get_meta("actor_id", &"blue_1"))


func get_team() -> StringName:
	return StringName(get_meta("team", &"blue"))


func get_squad_slot() -> int:
	return int(get_meta("squad_slot", 0))


func is_human_controlled() -> bool:
	return false


func is_ai_controlled() -> bool:
	return true


func reset_for_faceoff() -> void:
	_opening_grace_remaining = OPENING_GRACE_SECONDS
	_shot_charge = 0.0
	_shot_cooldown = 0.0
	_dash_streak_remaining = 0.0
	_parry_window_remaining = 0.0
	if _dash_streak != null:
		_dash_streak.visible = false


func is_dashing() -> bool:
	return _dash_streak_remaining > 0.0


func get_dash_cooldown_ratio() -> float:
	return clampf(_dash_cooldown / PlayerMotorScript.DASH_COOLDOWN, 0.0, 1.0)


func has_parry_window() -> bool:
	return _parry_window_remaining > 0.0001


func try_dash(input_vector: Vector2) -> bool:
	if _dash_streak == null:
		_dash_streak = get_node_or_null("DashStreak") as Node3D
	var dash: Dictionary = PlayerMotorScript.start_dash(input_vector, _dash_cooldown, _facing_direction)
	if not dash.started:
		return false
	velocity = dash.velocity
	_dash_direction = dash.velocity.normalized()
	_dash_cooldown = dash.cooldown
	_dash_streak_remaining = DASH_STREAK_SECONDS
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
		_heat_bar = get_node_or_null("../../HUD/BlueHeatBar") as ProgressBar
	if _fuego_aura != null:
		_fuego_aura.visible = is_en_fuego()
		if _fuego_aura.visible:
			var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.09
			_fuego_aura.scale = Vector3.ONE * pulse
	if _heat_bar != null:
		_heat_bar.value = _heat
		_heat_bar.modulate = Color("ffbd38") if is_en_fuego() else Color("609dff")


func _update_dash_streak() -> void:
	if _dash_streak == null:
		return
	_dash_streak.visible = is_dashing()
	if _dash_streak.visible:
		var burst_progress := 1.0 - _dash_streak_remaining / DASH_STREAK_SECONDS
		_dash_streak.scale = Vector3.ONE * lerpf(1.0, 1.42, burst_progress)
