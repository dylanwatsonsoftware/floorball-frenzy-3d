extends Node

const MatchSimulationScript = preload("res://scripts/simulation/match_simulation.gd")
const GOAL_PAUSE_SECONDS := 1.6
const WIN_PAUSE_SECONDS := 3.0
const PLAYER_FACEOFF_POSITION := Vector3(-5.0, 0.75, 0.0)
const OPPONENT_FACEOFF_POSITION := Vector3(5.0, 0.75, 0.0)
const RED_GOAL_FLASH := Color(0.10, 0.65, 0.30, 0.34)
const BLUE_GOAL_FLASH := Color(0.35, 0.78, 0.94, 0.34)
const GOAL_FLASH_SECONDS := 0.72

var score := {"red": 0, "blue": 0}
var _pause_remaining := 0.0
var _winner: StringName = &""
var _ball: Node3D
var _player: CharacterBody3D
var _opponent: Node3D
var _score_label: Label
var _message_label: Label
var _goal_flash: ColorRect
var _goal_flash_tween: Tween
var _arena: Node3D


func _ready() -> void:
	_ball = get_node("../Arena/Ball") as Node3D
	_arena = get_node("../Arena") as Node3D
	_player = get_node("../Arena/Player") as CharacterBody3D
	_opponent = get_node("../Arena/Opponent") as Node3D
	_score_label = get_node("../HUD/ScoreLabel") as Label
	_message_label = get_node("../HUD/MessageLabel") as Label
	_goal_flash = get_node("../HUD/GoalFlash") as ColorRect
	_ball.connect("goal_scored", _on_goal_scored)
	_update_score_label()


func _process(delta: float) -> void:
	if _pause_remaining <= 0.0:
		return
	_pause_remaining = maxf(0.0, _pause_remaining - delta)
	if _pause_remaining <= 0.0:
		_reset_faceoff()


func _on_goal_scored(scorer: StringName) -> void:
	var result := MatchSimulationScript.apply_goal(score, scorer)
	score.red = result.red
	score.blue = result.blue
	_winner = result.winner
	_update_score_label()
	_show_goal_flash(scorer)
	_award_goal_heat(scorer)

	if _winner != &"":
		_message_label.text = "%s WINS!" % _team_name(_winner)
		_pause_remaining = WIN_PAUSE_SECONDS
	else:
		_message_label.text = "%s GOAL!" % _team_name(scorer)
		_pause_remaining = GOAL_PAUSE_SECONDS


func _reset_faceoff() -> void:
	_clear_goal_flash()
	if _winner != &"":
		score.red = 0
		score.blue = 0
		_winner = &""
		if _player.has_method("reset_heat"):
			_player.call("reset_heat")
		if _opponent.has_method("reset_heat"):
			_opponent.call("reset_heat")
		_update_score_label()

	if _arena.has_method("reset_squads_for_faceoff"):
		_arena.call("reset_squads_for_faceoff")
	else:
		_player.position = PLAYER_FACEOFF_POSITION
		_player.velocity = Vector3.ZERO
		_opponent.position = OPPONENT_FACEOFF_POSITION
		if _opponent is CharacterBody3D:
			(_opponent as CharacterBody3D).velocity = Vector3.ZERO
		if _opponent.has_method("reset_for_faceoff"):
			_opponent.call("reset_for_faceoff")
	_ball.call("reset_for_faceoff")
	_message_label.text = ""


func _update_score_label() -> void:
	_score_label.text = "%d  —  %d" % [score.red, score.blue]


func apply_network_score(red_score: int, blue_score: int) -> void:
	score.red = red_score
	score.blue = blue_score
	_update_score_label()


func _team_name(team: StringName) -> String:
	return "LAMBS" if team == &"red" else "PIRATES"


func _award_goal_heat(scorer: StringName) -> void:
	var actor := _player if scorer == &"red" else _opponent
	if actor != null and actor.has_method("add_heat"):
		actor.call("add_heat", 50.0)


func _show_goal_flash(scorer: StringName) -> void:
	if _goal_flash_tween != null and _goal_flash_tween.is_valid():
		_goal_flash_tween.kill()
	_goal_flash.color = RED_GOAL_FLASH if scorer == &"red" else BLUE_GOAL_FLASH
	_goal_flash.visible = true
	_goal_flash_tween = create_tween()
	_goal_flash_tween.tween_property(_goal_flash, "color:a", 0.0, GOAL_FLASH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_goal_flash_tween.tween_callback(_hide_goal_flash)


func _hide_goal_flash() -> void:
	_goal_flash.visible = false


func _clear_goal_flash() -> void:
	if _goal_flash_tween != null and _goal_flash_tween.is_valid():
		_goal_flash_tween.kill()
	_goal_flash.visible = false
