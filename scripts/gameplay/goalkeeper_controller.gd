extends CharacterBody3D

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const GoalkeeperAIScript = preload("res://scripts/simulation/goalkeeper_ai.gd")
const SquadLogicScript = preload("res://scripts/simulation/squad_logic.gd")
const KEEPER_SPEED_MULTIPLIER := 0.62

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
	_constrain_to_goal_area()
	if not movement.is_zero_approx():
		rotation.y = PlayerMotorScript.step_facing_rotation(rotation.y, movement, delta)
		_facing_direction = PlayerMotorScript.facing_from_rotation(rotation.y)
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
	var owner_team: StringName = _ball.call("get_control_owner_team")
	var loose_ball := owner_team == &""
	var target := GoalkeeperAIScript.target(get_team(), _ball.global_position, loose_ball)
	return SquadLogicScript.arrival_movement(Vector2(global_position.x, global_position.z), target)


func _constrain_to_goal_area() -> void:
	var constrained := GoalkeeperAIScript.constrain_to_goal_area(get_team(), Vector2(global_position.x, global_position.z))
	global_position.x = constrained.x
	global_position.z = constrained.y
	global_position.y = float(get_meta("faceoff_position", global_position).y)


func get_facing_direction() -> Vector3:
	return _facing_direction


func apply_network_rotation(rotation_y: float) -> void:
	rotation.y = rotation_y
	_facing_direction = PlayerMotorScript.facing_from_rotation(rotation_y)


func set_shot_aim_locked(value: bool) -> void:
	_shot_aim_locked = value


func is_shot_aim_locked() -> bool:
	return _shot_aim_locked


func set_stick_slap_angle(angle_degrees: float) -> void:
	set_meta("stick_slap_angle", angle_degrees)


func get_actor_id() -> StringName:
	return StringName(get_meta("actor_id", &""))


func get_team() -> StringName:
	return StringName(get_meta("team", &""))


func get_squad_slot() -> int:
	return int(get_meta("squad_slot", 5))


func is_goalkeeper() -> bool:
	return true


func is_human_controlled() -> bool:
	return _ball != null and _ball.has_method("get_human_control_actor_id_for_team") and _ball.call("get_human_control_actor_id_for_team", get_team()) == get_actor_id()


func try_dash(_input_vector: Vector2 = Vector2.ZERO) -> bool:
	return false


func is_dashing() -> bool:
	return false


func get_dash_cooldown_ratio() -> float:
	return 1.0


func get_network_dash_state() -> Dictionary:
	return {"cooldown": PlayerMotorScript.DASH_COOLDOWN, "remaining": 0.0, "direction": _facing_direction}


func apply_network_dash_state(_cooldown: float, _remaining: float, _direction: Vector3) -> void:
	pass


func reset_for_faceoff() -> void:
	velocity = Vector3.ZERO
	_shot_aim_locked = false
