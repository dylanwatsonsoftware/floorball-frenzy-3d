extends MeshInstance3D

const BallSimulationScript = preload("res://scripts/simulation/ball_simulation.gd")
const MatchSimulationScript = preload("res://scripts/simulation/match_simulation.gd")
const BallInteractionScript = preload("res://scripts/simulation/ball_interaction.gd")
const StickSlapScript = preload("res://scripts/simulation/stick_slap.gd")
const OneTouchScript = preload("res://scripts/simulation/one_touch.gd")
const ShotChargeFeedbackScript = preload("res://scripts/presentation/shot_charge_feedback.gd")
const ShotImpactFeedbackScript = preload("res://scripts/presentation/shot_impact_feedback.gd")
const MAX_CHARGE_SECONDS := 0.8
const SHOOT_RANGE := 2.35
const TRAIL_SPEED_THRESHOLD := 10.0
const TRAIL_MIN_LENGTH := 0.55
const TRAIL_MAX_LENGTH := 1.75

var ball_velocity := Vector3.ZERO
var _charge_seconds := 0.0
var _player: CharacterBody3D
var _opponent: CharacterBody3D
var _charge_label: Label
var _shot_trail: MeshInstance3D
var _slap_elapsed := -1.0
var _pending_slap_charge := 0.0
var _pending_slap_direction := Vector2.RIGHT
var _pending_one_touch := false
var _last_touch_actor: StringName = &""
var _last_touch_age := INF

signal goal_scored(scorer: StringName)


func _ready() -> void:
	_player = get_parent().get_node("Player") as CharacterBody3D
	_charge_label = get_node("../../HUD/ChargeLabel") as Label
	_shot_trail = get_node_or_null("ShotTrail") as MeshInstance3D


func _physics_process(delta: float) -> void:
	_last_touch_age += delta
	_advance_slap(delta)
	var previous_position := position
	var next_state := BallSimulationScript.step(position, ball_velocity, delta)
	var interaction_state := BallInteractionScript.step(next_state.position, next_state.velocity, _interaction_participants(), delta)
	position = interaction_state.position
	ball_velocity = interaction_state.velocity
	var scorer := MatchSimulationScript.detect_goal(previous_position, position, ball_velocity)
	if scorer != &"":
		ball_velocity = Vector3.ZERO
		_charge_seconds = 0.0
		_cancel_slap()
		_clear_charge_feedback()
		_set_trail_visible(false)
		set_physics_process(false)
		goal_scored.emit(scorer)
		return
	_update_spin(delta)
	_update_shot_trail()
	_update_shot_charge(delta)
	_record_body_touch(interaction_state.body_controller)


func launch(planar_direction: Vector2, charge: float, inherited_velocity: Vector3 = Vector3.ZERO, one_touch: bool = false, shooter: StringName = &"") -> void:
	ball_velocity = BallSimulationScript.shot_velocity(planar_direction, charge, inherited_velocity, one_touch)
	if shooter != &"":
		record_touch(shooter)


func reset_for_faceoff() -> void:
	position = Vector3(0.0, BallSimulationScript.BALL_RADIUS, 0.0)
	ball_velocity = Vector3.ZERO
	_charge_seconds = 0.0
	_cancel_slap()
	_last_touch_actor = &""
	_last_touch_age = INF
	_clear_charge_feedback()
	_set_trail_visible(false)
	set_physics_process(true)


func _update_shot_charge(delta: float) -> void:
	if _slap_elapsed >= 0.0:
		return
	var in_range := _planar_distance_to_player() <= SHOOT_RANGE
	if Input.is_action_pressed("shoot") and in_range:
		_charge_seconds = minf(MAX_CHARGE_SECONDS * 2.0, _charge_seconds + delta)
		var charge_ratio := _charge_seconds / MAX_CHARGE_SECONDS
		var backswing_ratio := minf(1.0, charge_ratio)
		_player.call("set_stick_slap_angle", lerpf(-2.0, StickSlapScript.BACKSWING_ANGLE, backswing_ratio * backswing_ratio))
		_apply_charge_feedback(charge_ratio)
	elif Input.is_action_just_released("shoot"):
		if _charge_seconds > 0.0 and in_range:
			var facing: Vector3 = _player.call("get_facing_direction")
			_release_charged_slap(Vector2(facing.x, facing.z), _charge_seconds / MAX_CHARGE_SECONDS)
		_charge_seconds = 0.0
		if _slap_elapsed < 0.0:
			_clear_charge_feedback()
			_player.call("set_stick_slap_angle", 0.0)
	elif not Input.is_action_pressed("shoot"):
		_clear_charge_feedback()
		_player.call("set_stick_slap_angle", 0.0)


func _planar_distance_to_player() -> float:
	var offset := global_position - _player.global_position
	return Vector2(offset.x, offset.z).length()


func _interaction_participants() -> Array:
	if _opponent == null:
		_opponent = get_parent().get_node_or_null("Opponent") as CharacterBody3D
	var participants := [{
		"position": _player.global_position,
		"velocity": _player.velocity,
		"facing": _player.call("get_facing_direction"),
		"slap_phase": _current_slap_phase(),
	}]
	if _opponent != null:
		participants.append({
			"position": _opponent.global_position,
			"velocity": _opponent.velocity,
			"facing": _opponent.call("get_facing_direction"),
		})
	return participants


func begin_slap(direction: Vector2, charge: float) -> void:
	_configure_slap(direction, charge, 0.0)
	_player.call("set_stick_slap_angle", StickSlapScript.angle_at(0.0))


func _release_charged_slap(direction: Vector2, charge: float) -> void:
	_configure_slap(direction, charge, StickSlapScript.BACKSWING_SECONDS)


func _configure_slap(direction: Vector2, charge: float, start_elapsed: float) -> void:
	_slap_elapsed = start_elapsed
	_pending_slap_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_pending_slap_charge = clampf(charge, 0.0, 2.0)
	_pending_one_touch = is_one_touch_ready(&"red")
	_charge_label.text = "ONE TOUCH!" if _pending_one_touch else "SLAP!"
	if _pending_one_touch:
		_charge_label.add_theme_color_override("font_color", Color("70f7ff"))


func get_slap_phase() -> StringName:
	return _current_slap_phase()


func _advance_slap(delta: float) -> void:
	if _slap_elapsed < 0.0:
		return
	var previous_elapsed := _slap_elapsed
	_slap_elapsed += delta
	_player.call("set_stick_slap_angle", StickSlapScript.angle_at(_slap_elapsed))
	if StickSlapScript.crossed_contact(previous_elapsed, _slap_elapsed) and _ball_in_player_blade():
		launch(_pending_slap_direction, _pending_slap_charge, _player.velocity, _pending_one_touch, &"red")
		_play_contact_feedback(_pending_slap_charge)
	if _slap_elapsed >= StickSlapScript.TOTAL_SECONDS:
		_cancel_slap()


func _cancel_slap() -> void:
	_slap_elapsed = -1.0
	_pending_slap_charge = 0.0
	_pending_one_touch = false
	if _player != null:
		_player.call("set_stick_slap_angle", 0.0)
	if _charge_label != null and (_charge_label.text == "SLAP!" or _charge_label.text == "ONE TOUCH!"):
		_clear_charge_feedback()


func _current_slap_phase() -> StringName:
	if _slap_elapsed >= 0.0:
		return StickSlapScript.phase_at(_slap_elapsed)
	if _charge_seconds > 0.0:
		return &"backswing"
	return &"idle"


func _ball_in_player_blade() -> bool:
	var participant := {
		"position": _player.global_position,
		"velocity": _player.velocity,
		"facing": _player.call("get_facing_direction"),
	}
	return BallInteractionScript.is_in_blade_pocket(global_position, participant)


func _play_contact_feedback(charge: float) -> void:
	var arena := get_parent()
	if arena.has_method("play_shot_impact"):
		arena.call("play_shot_impact", global_position, ShotImpactFeedbackScript.for_charge(charge))


func record_touch(actor: StringName) -> void:
	_last_touch_actor = actor
	_last_touch_age = 0.0


func is_one_touch_ready(shooter: StringName = &"red") -> bool:
	return OneTouchScript.is_eligible(_last_touch_actor, _last_touch_age, shooter)


func _record_body_touch(controller: int) -> void:
	var actor := OneTouchScript.actor_for_controller(controller)
	if actor != &"":
		record_touch(actor)


func _update_spin(delta: float) -> void:
	var planar_speed := Vector2(ball_velocity.x, ball_velocity.z).length()
	if planar_speed > 0.05:
		rotate_x(planar_speed * delta / BallSimulationScript.BALL_RADIUS)


func _update_shot_trail() -> void:
	if _shot_trail == null:
		_shot_trail = get_node_or_null("ShotTrail") as MeshInstance3D
	if _shot_trail == null:
		return
	var speed := ball_velocity.length()
	if speed < TRAIL_SPEED_THRESHOLD:
		_shot_trail.visible = false
		return
	var direction := ball_velocity.normalized()
	var trail_length := clampf(speed * 0.065, TRAIL_MIN_LENGTH, TRAIL_MAX_LENGTH)
	var trail_mesh := _shot_trail.mesh as BoxMesh
	trail_mesh.size.z = trail_length
	_shot_trail.global_position = global_position - direction * trail_length * 0.5
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.94 else Vector3.UP
	_shot_trail.global_basis = Basis.looking_at(-direction, up)
	_shot_trail.visible = true


func _set_trail_visible(value: bool) -> void:
	if _shot_trail == null:
		_shot_trail = get_node_or_null("ShotTrail") as MeshInstance3D
	if _shot_trail != null:
		_shot_trail.visible = value


func _apply_charge_feedback(normalized_charge: float) -> void:
	var feedback := ShotChargeFeedbackScript.for_charge(normalized_charge)
	_charge_label.text = feedback.label
	_charge_label.add_theme_color_override("font_color", feedback.color)


func _clear_charge_feedback() -> void:
	if _charge_label == null:
		return
	_charge_label.text = ""
	_charge_label.add_theme_color_override("font_color", ShotChargeFeedbackScript.CHARGING_COLOR)
