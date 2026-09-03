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
	_lobby.name = "LobbyOverlay"
	_lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_lobby)
	var arena_glow := ColorRect.new()
	arena_glow.name = "ArenaGlow"
	arena_glow.color = Color("07162b")
	arena_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby.add_child(arena_glow)
	var lambs_glow := ColorRect.new()
	lambs_glow.color = Color(0.05, 0.72, 0.28, 0.17)
	lambs_glow.anchor_right = 0.48
	lambs_glow.anchor_bottom = 1.0
	lambs_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby.add_child(lambs_glow)
	var pirates_glow := ColorRect.new()
	pirates_glow.color = Color(0.05, 0.42, 0.95, 0.18)
	pirates_glow.anchor_left = 0.52
	pirates_glow.anchor_right = 1.0
	pirates_glow.anchor_bottom = 1.0
	pirates_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby.add_child(pirates_glow)
	var panel := PanelContainer.new()
	panel.name = "LobbyPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-380.0, -330.0)
	panel.size = Vector2(760.0, 660.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0b1424"), Color("55d77a"), 24, 3))
	_lobby.add_child(panel)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 12)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 26)
	panel.add_child(layout)
	var header := VBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 2)
	layout.add_child(header)
	var eyebrow := Label.new()
	eyebrow.text = "LIVE ONLINE  /  6v6 FLOORBALL"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", Color("69f59a"))
	eyebrow.add_theme_font_size_override("font_size", 14)
	header.add_child(eyebrow)
	var title := Label.new()
	title.text = "FIND YOUR NEXT MATCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 31)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ONE PLAYER CAPTAIN + FIVE AI TEAMMATES ON EACH SIDE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("aab9d1"))
	subtitle.add_theme_font_size_override("font_size", 13)
	header.add_child(subtitle)
	var team_strip := HBoxContainer.new()
	team_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	team_strip.add_theme_constant_override("separation", 8)
	header.add_child(team_strip)
	team_strip.add_child(_team_chip("LAMBS", "HOME / GREEN", Color("19ad51")))
	var versus := Label.new()
	versus.text = "VS"
	versus.add_theme_color_override("font_color", Color("ffcc52"))
	versus.add_theme_font_size_override("font_size", 14)
	team_strip.add_child(versus)
	team_strip.add_child(_team_chip("PIRATES", "AWAY / NAVY", Color("2587ee")))
	var create_card := PanelContainer.new()
	create_card.name = "CreateCard"
	create_card.add_theme_stylebox_override("panel", _panel_style(Color("10291d"), Color("2de36d"), 14, 2))
	layout.add_child(create_card)
	var create_body := VBoxContainer.new()
	create_body.name = "Body"
	create_body.add_theme_constant_override("separation", 7)
	create_card.add_child(create_body)
	var create_heading := Label.new()
	create_heading.text = "HOST A NEW GAME"
	create_heading.add_theme_color_override("font_color", Color("7cffaa"))
	create_heading.add_theme_font_size_override("font_size", 18)
	create_body.add_child(create_heading)
	var name_input := LineEdit.new()
	name_input.name = "GameName"
	name_input.placeholder_text = "Give your game a name"
	name_input.max_length = 30
	name_input.text = "Friday Night Floorball"
	name_input.custom_minimum_size.y = 52.0
	name_input.add_theme_font_size_override("font_size", 17)
	create_body.add_child(name_input)
	var create_button := Button.new()
	create_button.name = "CreateGame"
	create_button.text = "CREATE GAME  +  INVITE AN OPPONENT"
	create_button.custom_minimum_size.y = 58.0
	_style_button(create_button, Color("16a84d"), Color("43e67a"), 18)
	create_button.pressed.connect(func() -> void: _create_online_game(name_input.text))
	create_body.add_child(create_button)
	var open_card := PanelContainer.new()
	open_card.name = "OpenGamesCard"
	open_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	open_card.add_theme_stylebox_override("panel", _panel_style(Color("0d203d"), Color("318df2"), 14, 2))
	layout.add_child(open_card)
	var open_body := VBoxContainer.new()
	open_body.name = "Body"
	open_body.add_theme_constant_override("separation", 7)
	open_card.add_child(open_body)
	var open_heading := Label.new()
	open_heading.text = "JOIN AN OPEN GAME"
	open_heading.add_theme_color_override("font_color", Color("74baff"))
	open_heading.add_theme_font_size_override("font_size", 18)
	open_body.add_child(open_heading)
	_lobby_status = Label.new()
	_lobby_status.name = "LobbyStatus"
	_lobby_status.text = "Loading open games…"
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_status.add_theme_color_override("font_color", Color("d4e6ff"))
	_lobby_status.add_theme_font_size_override("font_size", 15)
	open_body.add_child(_lobby_status)
	var scroll := ScrollContainer.new()
	scroll.name = "GameScroll"
	scroll.custom_minimum_size.y = 130.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	open_body.add_child(scroll)
	_lobby_list = VBoxContainer.new()
	_lobby_list.name = "GameList"
	_lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_lobby_list)
	var actions := HBoxContainer.new()
	actions.name = "Footer"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)
	var refresh := Button.new()
	refresh.name = "RefreshGames"
	refresh.text = "REFRESH GAMES"
	refresh.custom_minimum_size = Vector2(210.0, 50.0)
	_style_button(refresh, Color("174b84"), Color("2d8ced"), 16)
	refresh.pressed.connect(_refresh_lobby)
	actions.add_child(refresh)
	var back := Button.new()
	back.name = "Back"
	back.text = "BACK TO MENU"
	back.custom_minimum_size = Vector2(210.0, 50.0)
	_style_button(back, Color("293344"), Color("52617a"), 16)
	back.pressed.connect(_close_lobby)
	actions.add_child(back)
	_refresh_lobby()


func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 10
	return style


func _style_button(button: Button, normal_color: Color, hover_color: Color, font_size: int) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(normal_color, normal_color.lightened(0.22), 10, 2))
	button.add_theme_stylebox_override("hover", _panel_style(hover_color, hover_color.lightened(0.22), 10, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(hover_color.darkened(0.12), Color("ffcf55"), 10, 2))


func _team_chip(team_name: String, descriptor: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(190.0, 42.0)
	chip.add_theme_stylebox_override("panel", _panel_style(color.darkened(0.48), color, 9, 1))
	var label := Label.new()
	label.text = "%s  ·  %s" % [team_name, descriptor]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	chip.add_child(label)
	return chip


func _refresh_lobby() -> void:
	if _lobby_status == null:
		return
	_lobby_status.text = "SCANNING FOR OPEN GAMES…"
	_lobby_status.add_theme_color_override("font_color", Color("ffcf55"))
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	request.request_completed.connect(_on_lobby_loaded.bind(request))
	var error := request.request(ApiEndpointScript.current_base() + "/lobby")
	if error != OK:
		_lobby_status.text = "MATCHMAKING IS OFFLINE — TRY AGAIN"
		_lobby_status.add_theme_color_override("font_color", Color("ff7582"))
		request.queue_free()


func _on_lobby_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	if _lobby_list == null or not is_instance_valid(_lobby_list):
		return
	for child in _lobby_list.get_children():
		child.queue_free()
	if response_code != 200:
		_lobby_status.text = "COULD NOT LOAD GAMES — CHECK YOUR CONNECTION"
		_lobby_status.add_theme_color_override("font_color", Color("ff7582"))
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Array:
		_lobby_status.text = "MATCHMAKING SENT AN INVALID RESPONSE"
		_lobby_status.add_theme_color_override("font_color", Color("ff7582"))
		return
	var compatible: Array = (parsed as Array).filter(func(entry: Variant) -> bool:
		return entry is Dictionary and String(entry.get("hostName", "")).begins_with("[G2] ")
	)
	_lobby_status.text = "NO OPEN GAMES — BE THE FIRST TO HOST" if compatible.is_empty() else "%d OPEN %s — PICK YOUR OPPONENT" % [compatible.size(), "GAME" if compatible.size() == 1 else "GAMES"]
	_lobby_status.add_theme_color_override("font_color", Color("b9d9ff") if compatible.is_empty() else Color("73f59f"))
	for entry: Dictionary in compatible:
		var row := Button.new()
		var game_name := String(entry.get("hostName", "Game")).trim_prefix("[G2] ")
		row.text = "JOIN MATCH     %s" % game_name.to_upper()
		row.custom_minimum_size.y = 54.0
		row.tooltip_text = "Join %s" % game_name
		_style_button(row, Color("174b84"), Color("287ed2"), 16)
		var room_id := String(entry.get("roomId", ""))
		row.pressed.connect(func() -> void: _join_online_game(room_id))
		_lobby_list.add_child(row)


func _create_online_game(game_name: String) -> void:
	var room_id := OnlineSessionScript.new().make_room_id()
	var clean_name := game_name.strip_edges() if not game_name.strip_edges().is_empty() else "Game"
	_lobby_status.text = "BUILDING YOUR ARENA…"
	_lobby_status.add_theme_color_override("font_color", Color("ffcf55"))
	_post_lobby(
		{"action": "register", "roomId": room_id, "hostName": "[G2] %s" % clean_name},
		&"host",
		room_id,
		clean_name
	)


func _join_online_game(room_id: String) -> void:
	_lobby_status.text = "JOINING THE MATCH…"
	_lobby_status.add_theme_color_override("font_color", Color("ffcf55"))
	_post_lobby({"action": "join", "roomId": room_id}, &"client", room_id)


func _post_lobby(payload: Dictionary, role: StringName, room_id: String, host_name: String = "") -> void:
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	request.request_completed.connect(_on_lobby_posted.bind(request, role, room_id, host_name))
	var error := request.request(ApiEndpointScript.current_base() + "/lobby", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		_lobby_status.text = "COULD NOT REACH MATCHMAKING — TRY AGAIN"
		_lobby_status.add_theme_color_override("font_color", Color("ff7582"))


func _on_lobby_posted(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, request: HTTPRequest, role: StringName, room_id: String, host_name: String) -> void:
	request.queue_free()
	if response_code < 200 or response_code >= 300:
		if _lobby_status != null and is_instance_valid(_lobby_status):
			_lobby_status.text = "Could not %s game. Try again." % ("create" if role == &"host" else "join")
		return
	OnlineMatch.start(role, room_id, host_name)
	get_tree().change_scene_to_file(MATCH_SCENE)


func _close_lobby() -> void:
	if _lobby != null:
		_lobby.queue_free()
	_lobby = null
	_lobby_list = null
	_lobby_status = null
