class_name PredictedBallAction
extends RefCounted


const BallSimulationScript = preload("res://scripts/simulation/ball_simulation.gd")
const StickSlapScript = preload("res://scripts/simulation/stick_slap.gd")

var action_sequence := 0
var action_type: StringName = &""
var elapsed := 0.0
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var direction := Vector2.RIGHT
var inherited_velocity := Vector3.ZERO
var charge := 0.0
var attached := false
var active := false


func begin(sequence: int, type: StringName, initial_position: Vector3, aim: Vector2, actor_velocity: Vector3, action_charge: float, begin_forward_swing: bool = false) -> void:
	action_sequence = sequence
	action_type = type
	elapsed = StickSlapScript.BACKSWING_SECONDS if begin_forward_swing else 0.0
	position = initial_position
	velocity = actor_velocity
	direction = aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
	inherited_velocity = actor_velocity
	charge = clampf(action_charge, 0.0, 1.0)
	attached = true
	active = true


func step(delta: float, blade_position: Vector3) -> Dictionary:
	if not active:
		return state()
	var step_delta := maxf(delta, 0.0)
	var previous_elapsed := elapsed
	elapsed += step_delta
	if attached:
		position = blade_position
		velocity = inherited_velocity
		if StickSlapScript.crossed_contact(previous_elapsed, elapsed):
			attached = false
			velocity = BallSimulationScript.pass_velocity(direction, inherited_velocity) if action_type == &"pass" else BallSimulationScript.shot_velocity(direction, charge, inherited_velocity)
			var remaining := maxf(0.0, elapsed - StickSlapScript.CONTACT_SECONDS)
			if remaining > 0.0:
				var released: Dictionary = BallSimulationScript.step(position, velocity, remaining)
				position = released.position
				velocity = released.velocity
	else:
		var simulated: Dictionary = BallSimulationScript.step(position, velocity, step_delta)
		position = simulated.position
		velocity = simulated.velocity
	return state()


func state() -> Dictionary:
	return {"position": position, "velocity": velocity, "attached": attached, "active": active, "elapsed": elapsed, "action_seq": action_sequence, "action_type": action_type}


func should_accept_snapshot(snapshot: Dictionary) -> bool:
	if StringName(snapshot.get("phase", "play")) != &"play" or StringName(snapshot.get("ball_state", "loose")) in [&"dead", &"faceoff"]:
		return true
	var authoritative_sequence := int(snapshot.get("action_seq", 0))
	if authoritative_sequence < action_sequence:
		return false
	if authoritative_sequence > action_sequence:
		return true
	var authoritative_state := StringName(snapshot.get("ball_state", "loose"))
	return (action_type == &"pass" and authoritative_state == &"passing") or (action_type == &"shot" and authoritative_state == &"shot")


func finish() -> void:
	active = false
