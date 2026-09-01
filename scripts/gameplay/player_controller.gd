extends CharacterBody3D

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RINK_HALF_LENGTH := 18.1
const RINK_HALF_WIDTH := 8.6

var _facing_direction := Vector3.RIGHT
var _mobile_controls: Control


func _ready() -> void:
	_mobile_controls = get_node_or_null("../../HUD/MobileControls") as Control


func _physics_process(delta: float) -> void:
	var keyboard_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch_input := Vector2.ZERO
	if _mobile_controls != null and _mobile_controls.has_method("get_movement_vector"):
		touch_input = _mobile_controls.call("get_movement_vector")
	var input_vector: Vector2 = PlayerMotorScript.combine_inputs(keyboard_input, touch_input)
	velocity = PlayerMotorScript.step_velocity(velocity, input_vector, delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, -RINK_HALF_LENGTH, RINK_HALF_LENGTH)
	global_position.z = clampf(global_position.z, -RINK_HALF_WIDTH, RINK_HALF_WIDTH)

	if velocity.length_squared() > 0.04:
		_facing_direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(_facing_direction.x, _facing_direction.z), minf(1.0, delta * 12.0))


func get_facing_direction() -> Vector3:
	return _facing_direction
