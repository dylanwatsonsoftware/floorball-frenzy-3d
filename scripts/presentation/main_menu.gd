extends CanvasLayer


const MATCH_SCENE := "res://scenes/match/match.tscn"
const OnlineSessionScript = preload("res://scripts/network/online_session.gd")
const ApiEndpointScript = preload("res://scripts/network/api_endpoint.gd")


@onready var _solo_button := get_node("Screen/Content/SoloButton") as Button
@onready var _online_button := get_node("Screen/Content/OnlineButton") as Button

var _lobby: Control
var _lobby_list: VBoxContainer
var _lobby_status: Label


func _ready() -> void:
	_solo_button.pressed.connect(start_solo_match)
	_online_button.pressed.connect(show_online_lobby)


func start_solo_match() -> void:
	OnlineMatch.stop()
	_solo_button.disabled = true
	get_tree().change_scene_to_file(MATCH_SCENE)


func show_online_lobby() -> void:
	if _lobby != null:
		_lobby.queue_free()
	_lobby = Control.new()
	_lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_lobby)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.025, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby.add_child(shade)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310.0, -280.0)
	panel.size = Vector2(620.0, 560.0)
	panel.add_theme_constant_override("separation", 14)
	_lobby.add_child(panel)
	var title := Label.new()
	title.text = "ONLINE MATCHMAKING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "1 PLAYER + 5 AI PER SIDE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Game name"
	name_input.max_length = 30
	name_input.text = "Floorball Game"
	panel.add_child(name_input)
	var create_button := Button.new()
	create_button.text = "CREATE NEW GAME"
	create_button.custom_minimum_size.y = 54.0
	create_button.pressed.connect(func() -> void: _create_online_game(name_input.text))
	panel.add_child(create_button)
	_lobby_status = Label.new()
	_lobby_status.text = "Loading open games…"
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_lobby_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 275.0
	panel.add_child(scroll)
	_lobby_list = VBoxContainer.new()
	_lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lobby_list)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(actions)
	var refresh := Button.new()
	refresh.text = "REFRESH"
	refresh.pressed.connect(_refresh_lobby)
	actions.add_child(refresh)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_close_lobby)
	actions.add_child(back)
	_refresh_lobby()


func _refresh_lobby() -> void:
	if _lobby_status == null:
		return
	_lobby_status.text = "Loading open games…"
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_lobby_loaded.bind(request))
	var error := request.request(ApiEndpointScript.current_base() + "/lobby")
	if error != OK:
		_lobby_status.text = "Could not reach matchmaking."
		request.queue_free()


func _on_lobby_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	if _lobby_list == null or not is_instance_valid(_lobby_list):
		return
	for child in _lobby_list.get_children():
		child.queue_free()
	if response_code != 200:
		_lobby_status.text = "Could not load games. Check your connection."
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Array:
		_lobby_status.text = "Matchmaking returned an invalid response."
		return
	var compatible: Array = (parsed as Array).filter(func(entry: Variant) -> bool:
		return entry is Dictionary and String(entry.get("hostName", "")).begins_with("[G2] ")
	)
	_lobby_status.text = "No open games yet — create one!" if compatible.is_empty() else "OPEN GAMES"
	for entry: Dictionary in compatible:
		var row := Button.new()
		row.text = "%s     JOIN" % String(entry.get("hostName", "Game")).trim_prefix("[G2] ")
		row.custom_minimum_size.y = 48.0
		var room_id := String(entry.get("roomId", ""))
		row.pressed.connect(func() -> void: _join_online_game(room_id))
		_lobby_list.add_child(row)


func _create_online_game(game_name: String) -> void:
	var room_id := OnlineSessionScript.new().make_room_id()
	OnlineMatch.start(&"host", room_id, game_name.strip_edges())
	_post_lobby({"action": "register", "roomId": room_id, "hostName": "[G2] %s" % (game_name.strip_edges() if not game_name.strip_edges().is_empty() else "Game")})
	get_tree().change_scene_to_file(MATCH_SCENE)


func _join_online_game(room_id: String) -> void:
	OnlineMatch.start(&"client", room_id)
	_post_lobby({"action": "join", "roomId": room_id})
	get_tree().change_scene_to_file(MATCH_SCENE)


func _post_lobby(payload: Dictionary) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_a: int, _b: int, _c: PackedStringArray, _d: PackedByteArray) -> void: request.queue_free())
	request.request(ApiEndpointScript.current_base() + "/lobby", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))


func _close_lobby() -> void:
	if _lobby != null:
		_lobby.queue_free()
	_lobby = null
	_lobby_list = null
	_lobby_status = null
