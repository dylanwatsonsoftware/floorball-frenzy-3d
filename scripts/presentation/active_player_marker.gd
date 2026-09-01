extends Node3D

const BASE_HEIGHT := 1.75
const BOB_DISTANCE := 0.11
const BOB_SPEED := 4.2

var _phase := 0.0


func _ready() -> void:
	_phase = float(get_parent().get_instance_id() % 17) * 0.21


func _process(_delta: float) -> void:
	var actor := get_parent()
	visible = actor.has_method("is_human_controlled") and bool(actor.call("is_human_controlled"))
	if visible:
		position.y = BASE_HEIGHT + sin(Time.get_ticks_msec() * 0.001 * BOB_SPEED + _phase) * BOB_DISTANCE
