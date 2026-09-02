extends CanvasLayer


@onready var _arena := get_node("../Arena")
@onready var _hud := get_node("../HUD") as CanvasLayer
@onready var _match_flow := get_node("../MatchFlow")
@onready var _solo_button := get_node("Screen/Content/SoloButton") as Button


func _ready() -> void:
	_solo_button.pressed.connect(start_solo_match)
	_hud.visible = false
	if DisplayServer.get_name() != "headless":
		_set_gameplay_enabled(false)


func start_solo_match() -> void:
	visible = false
	_hud.visible = true
	_set_gameplay_enabled(true)
	if _arena.has_method("reset_squads_for_faceoff"):
		_arena.call("reset_squads_for_faceoff")
	var ball := _arena.get_node_or_null("Ball")
	if ball != null and ball.has_method("reset_for_faceoff"):
		ball.call("reset_for_faceoff")
	Input.action_release("shoot")
	Input.action_release("dash")


func _set_gameplay_enabled(enabled: bool) -> void:
	var mode := Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	_arena.process_mode = mode
	_hud.process_mode = mode
	_match_flow.process_mode = mode
