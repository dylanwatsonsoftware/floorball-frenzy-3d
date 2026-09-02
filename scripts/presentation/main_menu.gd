extends CanvasLayer


const MATCH_SCENE := "res://scenes/match/match.tscn"


@onready var _solo_button := get_node("Screen/Content/SoloButton") as Button


func _ready() -> void:
	_solo_button.pressed.connect(start_solo_match)


func start_solo_match() -> void:
	_solo_button.disabled = true
	get_tree().change_scene_to_file(MATCH_SCENE)
