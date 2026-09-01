extends CharacterBody3D

const PlayerMotorScript = preload("res://scripts/gameplay/player_motor.gd")
const RINK_HALF_LENGTH := 18.1
const RINK_HALF_WIDTH := 8.6


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = PlayerMotorScript.step_velocity(velocity, input_vector, delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, -RINK_HALF_LENGTH, RINK_HALF_LENGTH)
	global_position.z = clampf(global_position.z, -RINK_HALF_WIDTH, RINK_HALF_WIDTH)

	if velocity.length_squared() > 0.04:
		var facing := Vector3(velocity.x, 0.0, velocity.z).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), minf(1.0, delta * 12.0))
