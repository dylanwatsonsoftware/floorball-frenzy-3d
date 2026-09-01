extends CharacterBody3D

const SimpleAIScript = preload("res://scripts/simulation/simple_ai.gd")
const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RinkCollisionScript = preload("res://scripts/simulation/rink_collision.gd")
const RINK_HALF_LENGTH := 18.1
const RINK_HALF_WIDTH := 8.6
const SHOT_CHARGE_SECONDS := 0.55
const SHOT_COOLDOWN_SECONDS := 0.8

var _facing_direction := Vector3.LEFT
var _shot_charge := 0.0
var _shot_cooldown := 0.0
var _ball: MeshInstance3D
var _player: CharacterBody3D


func _ready() -> void:
	_ball = get_parent().get_node("Ball") as MeshInstance3D
	_player = get_parent().get_node("Player") as CharacterBody3D


func _physics_process(delta: float) -> void:
	if not _ball.is_physics_processing():
		velocity = Vector3.ZERO
		return

	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	var decision := SimpleAIScript.decide(global_position, _ball.global_position, _player.global_position, _ball.ball_velocity)
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
			_ball.call("launch", decision.shot_direction, 0.72)
			_shot_charge = 0.0
			_shot_cooldown = SHOT_COOLDOWN_SECONDS
	else:
		_shot_charge = 0.0


func get_facing_direction() -> Vector3:
	return _facing_direction


func is_ai_controlled() -> bool:
	return true
