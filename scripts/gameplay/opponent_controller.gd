extends CharacterBody3D

const SimpleAIScript = preload("res://scripts/simulation/simple_ai.gd")
const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RinkCollisionScript = preload("res://scripts/simulation/rink_collision.gd")
const RINK_HALF_LENGTH := 18.1
const RINK_HALF_WIDTH := 8.6
const SHOT_CHARGE_SECONDS := 0.55
const SHOT_COOLDOWN_SECONDS := 0.8
const DASH_STREAK_SECONDS := 0.18

var _facing_direction := Vector3.LEFT
var _shot_charge := 0.0
var _shot_cooldown := 0.0
var _ball: MeshInstance3D
var _player: CharacterBody3D
var _dash_cooldown := 0.0
var _dash_streak_remaining := 0.0
var _dash_direction := Vector3.LEFT
var _dash_streak: Node3D


func _ready() -> void:
	_ball = get_parent().get_node("Ball") as MeshInstance3D
	_player = get_parent().get_node("Player") as CharacterBody3D
	_dash_streak = get_node_or_null("DashStreak") as Node3D


func _physics_process(delta: float) -> void:
	if not _ball.is_physics_processing():
		velocity = Vector3.ZERO
		_dash_streak_remaining = 0.0
		if _dash_streak != null:
			_dash_streak.visible = false
		return

	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_dash_streak_remaining = maxf(0.0, _dash_streak_remaining - delta)
	_update_dash_streak()
	var decision := SimpleAIScript.decide(global_position, _ball.global_position, _player.global_position, _ball.ball_velocity, _dash_cooldown <= 0.0)
	if decision.wants_dash:
		try_dash(decision.movement)
	if is_dashing():
		velocity = _dash_direction * PlayerMotorScript.DASH_SPEED
	else:
		velocity = PlayerMotorScript.step_velocity(velocity, decision.movement, delta)
	move_and_slide()
	var boundary := RinkCollisionScript.constrain_body(global_position, velocity, RINK_HALF_LENGTH, RINK_HALF_WIDTH, 1.8)
	global_position = boundary.position
	velocity = boundary.velocity

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


func get_facing_direction() -> Vector3:
	return _facing_direction


func is_ai_controlled() -> bool:
	return true


func is_dashing() -> bool:
	return _dash_streak_remaining > 0.0


func get_dash_cooldown_ratio() -> float:
	return clampf(_dash_cooldown / PlayerMotorScript.DASH_COOLDOWN, 0.0, 1.0)


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
	if _dash_streak != null:
		_dash_streak.scale = Vector3.ONE
		_dash_streak.visible = true
	return true


func _update_dash_streak() -> void:
	if _dash_streak == null:
		return
	_dash_streak.visible = is_dashing()
	if _dash_streak.visible:
		var burst_progress := 1.0 - _dash_streak_remaining / DASH_STREAK_SECONDS
		_dash_streak.scale = Vector3.ONE * lerpf(1.0, 1.42, burst_progress)
