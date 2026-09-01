extends CharacterBody3D

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const GoalkeeperAIScript = preload("res://scripts/simulation/goalkeeper_ai.gd")
const KEEPER_SPEED_MULTIPLIER := 0.72

var _ball: Node3D
var _mobile_controls: Control
var _facing_direction := Vector3.RIGHT
var _control_ring: MeshInstance3D
var _shot_aim_locked := false


func _ready() -> void:
	_ball = get_parent().get_node("Ball") as Node3D
	_mobile_controls = get_node_or_null("../../HUD/MobileControls") as Control
	_control_ring = get_node_or_null("ControlRing") as MeshInstance3D
	_facing_direction = Vector3.RIGHT if get_team() == &"red" else Vector3.LEFT


func _physics_process(delta: float) -> void:
	if _control_ring != null:
		_control_ring.visible = is_human_controlled()
	if not _ball.is_physics_processing():
		velocity = Vector3.ZERO
		return
	var movement := _human_movement() if is_human_controlled() else _ai_movement()
	velocity = PlayerMotorScript.step_velocity(velocity, movement, delta, KEEPER_SPEED_MULTIPLIER)
	move_and_slide()
	_constrain_to_crease()
	if not movement.is_zero_approx():
		_facing_direction = Vector3(movement.x, 0.0, movement.y).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(_facing_direction.x, _facing_direction.z), minf(1.0, delta * 10.0))


func _human_movement() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch := Vector2.ZERO
	if _mobile_controls != null and _mobile_controls.has_method("get_movement_vector"):
		touch = _mobile_controls.call("get_movement_vector")
	return PlayerMotorScript.combine_inputs(keyboard, touch)


func _ai_movement() -> Vector2:
	var owner_team: StringName = _ball.call("get_control_owner_team")
	var loose_ball := owner_team == &""
	var target := GoalkeeperAIScript.target(get_team(), _ball.global_position, loose_ball)
	return (target - Vector2(global_position.x, global_position.z)).normalized()


func _constrain_to_crease() -> void:
	var target := GoalkeeperAIScript.target(get_team(), global_position, true)
	global_position.x = target.x
	global_position.z = target.y
	global_position.y = float(get_meta("faceoff_position", global_position).y)


func get_facing_direction() -> Vector3:
	return _facing_direction


func set_shot_aim_locked(value: bool) -> void:
	_shot_aim_locked = value


func is_shot_aim_locked() -> bool:
	return _shot_aim_locked


func set_stick_slap_angle(_angle_degrees: float) -> void:
	pass


func get_actor_id() -> StringName:
	return StringName(get_meta("actor_id", &""))


func get_team() -> StringName:
	return StringName(get_meta("team", &""))


func get_squad_slot() -> int:
	return int(get_meta("squad_slot", 5))


func is_goalkeeper() -> bool:
	return true


func is_human_controlled() -> bool:
	return get_team() == &"red" and _ball != null and _ball.call("get_human_control_actor_id") == get_actor_id()


func try_dash(_input_vector: Vector2 = Vector2.ZERO) -> bool:
	return false


func is_dashing() -> bool:
	return false


func get_dash_cooldown_ratio() -> float:
	return 1.0


func reset_for_faceoff() -> void:
	velocity = Vector3.ZERO
	_shot_aim_locked = false
