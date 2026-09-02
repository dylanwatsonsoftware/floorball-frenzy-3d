extends Node3D

const BASE_HEIGHT := 1.75
const BOB_DISTANCE := 0.11
const BOB_SPEED := 4.2

var _phase := 0.0


func _ready() -> void:
	_phase = float(get_parent().get_instance_id() % 17) * 0.21


func _process(_delta: float) -> void:
	var actor := get_parent()
	visible = _is_local_human(actor)
	var ring := actor.get_node_or_null("ControlRing") as MeshInstance3D
	if ring != null:
		ring.visible = visible
	if visible:
		position.y = BASE_HEIGHT + sin(Time.get_ticks_msec() * 0.001 * BOB_SPEED + _phase) * BOB_DISTANCE


func _is_local_human(actor: Node) -> bool:
	if not actor.has_method("is_human_controlled") or not bool(actor.call("is_human_controlled")):
		return false
	return not OnlineMatch.enabled or actor.call("get_team") == OnlineMatch.local_team()
