extends CharacterBody3D

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RINK_HALF_LENGTH := 18.1
const RINK_HALF_WIDTH := 8.6
const DASH_STREAK_SECONDS := 0.18
const STICK_BASE_Y_ANGLE := -28.0

var _facing_direction := Vector3.RIGHT
var _mobile_controls: Control
var _dash_cooldown := 0.0
var _dash_streak_remaining := 0.0
var _dash_streak: Node3D


func _ready() -> void:
	_mobile_controls = get_node_or_null("../../HUD/MobileControls") as Control
	_dash_streak = get_node_or_null("DashStreak") as Node3D


func _physics_process(delta: float) -> void:
	var keyboard_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch_input := Vector2.ZERO
	if _mobile_controls != null and _mobile_controls.has_method("get_movement_vector"):
		touch_input = _mobile_controls.call("get_movement_vector")
	var input_vector: Vector2 = PlayerMotorScript.combine_inputs(keyboard_input, touch_input)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_dash_streak_remaining = maxf(0.0, _dash_streak_remaining - delta)
	if _dash_streak != null:
		_dash_streak.visible = _dash_streak_remaining > 0.0
	if Input.is_action_just_pressed("dash"):
		try_dash(input_vector)
	else:
		velocity = PlayerMotorScript.step_velocity(velocity, input_vector, delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, -RINK_HALF_LENGTH, RINK_HALF_LENGTH)
	global_position.z = clampf(global_position.z, -RINK_HALF_WIDTH, RINK_HALF_WIDTH)

	if velocity.length_squared() > 0.04:
		_facing_direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(_facing_direction.x, _facing_direction.z), minf(1.0, delta * 12.0))
	if _mobile_controls != null and _mobile_controls.has_method("set_dash_cooldown_ratio"):
		_mobile_controls.call("set_dash_cooldown_ratio", get_dash_cooldown_ratio())


func get_facing_direction() -> Vector3:
	return _facing_direction


func get_dash_cooldown_ratio() -> float:
	return clampf(_dash_cooldown / PlayerMotorScript.DASH_COOLDOWN, 0.0, 1.0)


func try_dash(input_vector: Vector2 = Vector2.ZERO) -> bool:
	if _dash_streak == null:
		_dash_streak = get_node_or_null("DashStreak") as Node3D
	var dash: Dictionary = PlayerMotorScript.start_dash(input_vector, _dash_cooldown, _facing_direction)
	if not dash.started:
		return false
	velocity = dash.velocity
	_dash_cooldown = dash.cooldown
	_dash_streak_remaining = DASH_STREAK_SECONDS
	if _dash_streak != null:
		_dash_streak.visible = true
	return true


func set_stick_slap_angle(angle_degrees: float) -> void:
	var stick_rig := get_node_or_null("StickRig") as Node3D
	if stick_rig != null:
		stick_rig.rotation_degrees.y = STICK_BASE_Y_ANGLE + angle_degrees
