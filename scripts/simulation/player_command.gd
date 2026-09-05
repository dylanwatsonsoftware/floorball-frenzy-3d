class_name PlayerCommand
extends RefCounted


var sequence: int
var simulation_tick: int
var movement: Vector2
var facing: Vector2
var shoot_held: bool
var pass_sequence: int
var switch_sequence: int
var dash_sequence: int
var dash_pressed: bool


static func create(
	command_sequence: int,
	tick: int,
	move_input: Vector2,
	facing_input: Vector2,
	is_shoot_held: bool,
	pass_seq: int,
	switch_seq: int,
	dash_seq: int,
	is_dash_pressed: bool
) -> RefCounted:
	var command = new()
	command.sequence = command_sequence
	command.simulation_tick = tick
	command.movement = move_input.limit_length(1.0)
	command.facing = facing_input.limit_length(1.0)
	command.shoot_held = is_shoot_held
	command.pass_sequence = pass_seq
	command.switch_sequence = switch_seq
	command.dash_sequence = dash_seq
	command.dash_pressed = is_dash_pressed
	return command


func to_network_packet(sent_at_ms: int, round_trip_ms: float) -> Dictionary:
	return {
		"type": "input",
		"seq": sequence,
		"tick": simulation_tick,
		"sent_ms": sent_at_ms,
		"rtt_ms": round_trip_ms,
		"move": [movement.x, movement.y],
		"facing": [facing.x, facing.y],
		"dash": dash_pressed,
		"dash_seq": dash_sequence,
		"shoot": shoot_held,
		"pass_seq": pass_sequence,
		"switch_seq": switch_sequence,
	}


func to_simulation_step(delta: float, speed_multiplier: float) -> Dictionary:
	return {
		"seq": sequence,
		"tick": simulation_tick,
		"move": movement,
		"facing": facing,
		"dash_pressed": dash_pressed,
		"delta": delta,
		"speed_multiplier": speed_multiplier,
	}
