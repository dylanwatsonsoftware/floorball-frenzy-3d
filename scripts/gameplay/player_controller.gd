extends CharacterBody3D

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RinkCollisionScript = preload("res://scripts/simulation/rink_collision.gd")
const RINK_HALF_LENGTH := 18.1
const RINK_HALF_WIDTH := 8.6
const DASH_STREAK_SECONDS := 0.18
const BOLT_WINDOW_SECONDS := 0.2
const STICK_BASE_Y_ANGLE := -28.0

var _facing_direction := Vector3.RIGHT
var _mobile_controls: Control
var _dash_cooldown := 0.0
var _dash_streak_remaining := 0.0
var _dash_streak: Node3D
var _dash_direction := Vector3.RIGHT
var _recent_dash_remaining := 0.0


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
	_recent_dash_remaining = maxf(0.0, _recent_dash_remaining - delta)
	if _dash_streak != null:
		_dash_streak.visible = _dash_streak_remaining > 0.0
		if _dash_streak.visible:
			var burst_progress := 1.0 - _dash_streak_remaining / DASH_STREAK_SECONDS
			_dash_streak.scale = Vector3.ONE * lerpf(1.0, 1.42, burst_progress)
	if Input.is_action_just_pressed("dash"):
		try_dash(input_vector)
	if is_dashing():
		velocity = _dash_direction * PlayerMotorScript.DASH_SPEED
	else:
		velocity = PlayerMotorScript.step_velocity(velocity, input_vector, delta)
	move_and_slide()
	var boundary := RinkCollisionScript.constrain_body(global_position, velocity, RINK_HALF_LENGTH, RINK_HALF_WIDTH, 1.8)
	global_position = boundary.position
	velocity = boundary.velocity

	if velocity.length_squared() > 0.04:
		_facing_direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(_facing_direction.x, _facing_direction.z), minf(1.0, delta * 12.0))
	if _mobile_controls != null and _mobile_controls.has_method("set_dash_cooldown_ratio"):
		_mobile_controls.call("set_dash_cooldown_ratio", get_dash_cooldown_ratio())


func get_facing_direction() -> Vector3:
	return _facing_direction


func get_dash_cooldown_ratio() -> float:
	return clampf(_dash_cooldown / PlayerMotorScript.DASH_COOLDOWN, 0.0, 1.0)


func is_dashing() -> bool:
	return _dash_streak_remaining > 0.0


func has_recent_dash() -> bool:
	return _recent_dash_remaining > 0.0001


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
	if _dash_streak != null:
		_dash_streak.scale = Vector3.ONE
		_dash_streak.visible = true
	return true


func set_stick_slap_angle(angle_degrees: float) -> void:
	var stick_rig := get_node_or_null("StickRig") as Node3D
	if stick_rig != null:
		stick_rig.rotation_degrees.y = STICK_BASE_Y_ANGLE + angle_degrees
