extends MeshInstance3D

const BallSimulationScript = preload("res://scripts/simulation/ball_simulation.gd")
const MatchSimulationScript = preload("res://scripts/simulation/match_simulation.gd")
const MAX_CHARGE_SECONDS := 0.8
const SHOOT_RANGE := 2.35

var ball_velocity := Vector3.ZERO
var _charge_seconds := 0.0
var _player: CharacterBody3D
var _charge_label: Label

signal goal_scored(scorer: StringName)


func _ready() -> void:
	_player = get_parent().get_node("Player") as CharacterBody3D
	_charge_label = get_node("../../HUD/ChargeLabel") as Label


func _physics_process(delta: float) -> void:
	var previous_position := position
	var next_state := BallSimulationScript.step(position, ball_velocity, delta)
	position = next_state.position
	ball_velocity = next_state.velocity
	var scorer := MatchSimulationScript.detect_goal(previous_position, position, ball_velocity)
	if scorer != &"":
		ball_velocity = Vector3.ZERO
		_charge_seconds = 0.0
		_charge_label.text = ""
		set_physics_process(false)
		goal_scored.emit(scorer)
		return
	_update_spin(delta)
	_update_shot_charge(delta)


func launch(planar_direction: Vector2, charge: float) -> void:
	ball_velocity = BallSimulationScript.shot_velocity(planar_direction, charge)


func reset_for_faceoff() -> void:
	position = Vector3(0.0, BallSimulationScript.BALL_RADIUS, 0.0)
	ball_velocity = Vector3.ZERO
	_charge_seconds = 0.0
	_charge_label.text = ""
	set_physics_process(true)


func _update_shot_charge(delta: float) -> void:
	var in_range := _planar_distance_to_player() <= SHOOT_RANGE
	if Input.is_action_pressed("shoot") and in_range:
		_charge_seconds = minf(MAX_CHARGE_SECONDS, _charge_seconds + delta)
		var percentage := roundi(100.0 * _charge_seconds / MAX_CHARGE_SECONDS)
		_charge_label.text = "SHOT %d%%" % percentage
	elif Input.is_action_just_released("shoot"):
		if _charge_seconds > 0.0 and in_range:
			var facing: Vector3 = _player.call("get_facing_direction")
			launch(Vector2(facing.x, facing.z), _charge_seconds / MAX_CHARGE_SECONDS)
		_charge_seconds = 0.0
		_charge_label.text = ""
	elif not Input.is_action_pressed("shoot"):
		_charge_label.text = ""


func _planar_distance_to_player() -> float:
	var offset := global_position - _player.global_position
	return Vector2(offset.x, offset.z).length()


func _update_spin(delta: float) -> void:
	var planar_speed := Vector2(ball_velocity.x, ball_velocity.z).length()
	if planar_speed > 0.05:
		rotate_x(planar_speed * delta / BallSimulationScript.BALL_RADIUS)
