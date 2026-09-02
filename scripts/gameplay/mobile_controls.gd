extends Control

const STICK_RADIUS := 76.0
const STICK_DEADZONE := 0.2
const EDGE_MARGIN := 28.0
const SHOOT_RADIUS := 58.0
const PASS_RADIUS := 46.0
const SWITCH_RADIUS := 40.0

var _movement_touch := -1
var _shoot_touch := -1
var _pass_touch := -1
var _switch_touch := -1
var _movement_vector := Vector2.ZERO
var _stick_knob_offset := Vector2.ZERO
var _stick_origin := Vector2.ZERO
var _movement_origin := Vector2.ZERO


func _ready() -> void:
	visible = should_show_mobile_controls(OS.has_feature("web"), DisplayServer.is_touchscreen_available(), _browser_touch_available())
	var control_hint := get_node_or_null("../CameraLabel") as Label
	if control_hint != null:
		control_hint.visible = should_show_control_hint(visible)
	set_process_input(true)
	resized.connect(queue_redraw)


func get_movement_vector() -> Vector2:
	return _movement_vector


func set_dash_cooldown_ratio(_value: float) -> void:
	# Dash remains available to keyboard/controller players, but the limited
	# mobile action slot is now dedicated to the more fundamental Pass action.
	return


static func normalize_cooldown_ratio(value: float) -> float:
	return clampf(value, 0.0, 1.0)


static func calculate_stick_vector(offset: Vector2, radius: float, deadzone: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var normalized_length := minf(1.0, offset.length() / radius)
	if normalized_length <= deadzone:
		return Vector2.ZERO
	var scaled_length := (normalized_length - deadzone) / (1.0 - deadzone)
	return offset.normalized() * scaled_length


static func should_show_mobile_controls(is_web: bool, display_touch_available: bool, browser_touch_available: bool) -> bool:
	return display_touch_available or (is_web and browser_touch_available)


static func should_show_control_hint(mobile_controls_visible: bool) -> bool:
	return not mobile_controls_visible


static func can_start_floating_stick(touch_position: Vector2, viewport_size: Vector2) -> bool:
	return touch_position.x >= 0.0 and touch_position.x < viewport_size.x * 0.55


static func clamp_floating_origin(touch_position: Vector2, viewport_size: Vector2, radius: float, margin: float) -> Vector2:
	var padding := radius + margin
	var x := viewport_size.x * 0.5 if viewport_size.x < padding * 2.0 else clampf(touch_position.x, padding, viewport_size.x - padding)
	var y := viewport_size.y * 0.5 if viewport_size.y < padding * 2.0 else clampf(touch_position.y, padding, viewport_size.y - padding)
	return Vector2(x, y)


static func calculate_floating_drag(origin: Vector2, current_position: Vector2, radius: float, deadzone: float) -> Vector2:
	return calculate_stick_vector(current_position - origin, radius, deadzone)


static func action_at_position(touch_position: Vector2, viewport_size: Vector2) -> StringName:
	var shoot_center := Vector2(viewport_size.x - EDGE_MARGIN - SHOOT_RADIUS, viewport_size.y - EDGE_MARGIN - SHOOT_RADIUS)
	if touch_position.distance_to(shoot_center) <= SHOOT_RADIUS * 1.35:
		return &"shoot"
	var pass_center := Vector2(viewport_size.x - EDGE_MARGIN - PASS_RADIUS, shoot_center.y - SHOOT_RADIUS - PASS_RADIUS - 24.0)
	if touch_position.distance_to(pass_center) <= PASS_RADIUS * 1.35:
		return &"pass"
	var switch_center := Vector2(viewport_size.x - EDGE_MARGIN - SWITCH_RADIUS, pass_center.y - PASS_RADIUS - SWITCH_RADIUS - 18.0)
	if touch_position.distance_to(switch_center) <= SWITCH_RADIUS * 1.35:
		return &"switch_player"
	return &""


static func _browser_touch_available() -> bool:
	if not OS.has_feature("web"):
		return false
	var detected: Variant = JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || window.matchMedia('(pointer: coarse)').matches", true)
	return bool(detected)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _movement_touch:
		_update_stick(event.position)
		get_viewport().set_input_as_handled()


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var action := action_at_position(event.position, size)
		if action == &"shoot" and _shoot_touch == -1:
			_shoot_touch = event.index
			Input.action_press("shoot")
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif action == &"pass" and _pass_touch == -1:
			_pass_touch = event.index
			Input.action_press("pass")
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif action == &"switch_player" and _switch_touch == -1:
			_switch_touch = event.index
			Input.action_press("switch_player")
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif _movement_touch == -1 and can_start_floating_stick(event.position, size):
			_movement_touch = event.index
			_movement_origin = event.position
			_stick_origin = clamp_floating_origin(event.position, size, STICK_RADIUS, EDGE_MARGIN)
			_update_stick(event.position)
			get_viewport().set_input_as_handled()
	elif event.index == _movement_touch:
		_movement_touch = -1
		_movement_vector = Vector2.ZERO
		_stick_knob_offset = Vector2.ZERO
		_stick_origin = Vector2.ZERO
		_movement_origin = Vector2.ZERO
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.index == _shoot_touch:
		_shoot_touch = -1
		Input.action_release("shoot")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.index == _pass_touch:
		_pass_touch = -1
		Input.action_release("pass")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.index == _switch_touch:
		_switch_touch = -1
		Input.action_release("switch_player")
		queue_redraw()
		get_viewport().set_input_as_handled()


func _update_stick(touch_position: Vector2) -> void:
	var raw_offset := touch_position - _movement_origin
	_stick_knob_offset = raw_offset.limit_length(STICK_RADIUS)
	_movement_vector = calculate_floating_drag(_movement_origin, touch_position, STICK_RADIUS, STICK_DEADZONE)
	queue_redraw()


func _stick_center() -> Vector2:
	return _stick_origin


func _shoot_center() -> Vector2:
	return Vector2(size.x - EDGE_MARGIN - SHOOT_RADIUS, size.y - EDGE_MARGIN - SHOOT_RADIUS)


func _pass_center() -> Vector2:
	return Vector2(size.x - EDGE_MARGIN - PASS_RADIUS, _shoot_center().y - SHOOT_RADIUS - PASS_RADIUS - 24.0)


func _switch_center() -> Vector2:
	return Vector2(size.x - EDGE_MARGIN - SWITCH_RADIUS, _pass_center().y - PASS_RADIUS - SWITCH_RADIUS - 18.0)


func _draw() -> void:
	var shoot_center := _shoot_center()
	var pass_center := _pass_center()
	var switch_center := _switch_center()
	if _movement_touch != -1:
		var stick_center := _stick_center()
		draw_circle(stick_center, STICK_RADIUS, Color(0.08, 0.12, 0.18, 0.58))
		draw_arc(stick_center, STICK_RADIUS, 0.0, TAU, 48, Color(0.88, 0.94, 1.0, 0.72), 3.0)
		draw_circle(stick_center + _stick_knob_offset, 31.0, Color(0.92, 0.97, 1.0, 0.82))
	var shoot_color := Color(1.0, 0.35, 0.22, 0.92) if _shoot_touch != -1 else Color(0.86, 0.16, 0.28, 0.78)
	draw_circle(shoot_center, SHOOT_RADIUS, shoot_color)
	draw_arc(shoot_center, SHOOT_RADIUS, 0.0, TAU, 48, Color.WHITE, 3.0)
	var font := get_theme_default_font()
	var font_size := 20
	var label := "SHOOT"
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, shoot_center - label_size * 0.5 + Vector2(0.0, label_size.y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	var pass_color := Color(0.25, 0.72, 1.0, 0.96) if _pass_touch != -1 else Color(0.12, 0.48, 0.78, 0.8)
	draw_circle(pass_center, PASS_RADIUS, pass_color)
	draw_arc(pass_center, PASS_RADIUS, 0.0, TAU, 48, Color.WHITE, 3.0)
	var pass_label := "PASS"
	var pass_label_size := font.get_string_size(pass_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, pass_center - pass_label_size * 0.5 + Vector2(0.0, pass_label_size.y), pass_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	var switch_color := Color(0.94, 0.68, 0.18, 0.96) if _switch_touch != -1 else Color(0.72, 0.44, 0.12, 0.82)
	draw_circle(switch_center, SWITCH_RADIUS, switch_color)
	draw_arc(switch_center, SWITCH_RADIUS, 0.0, TAU, 40, Color.WHITE, 3.0)
	var switch_label := "SWITCH"
	var switch_font_size := 15
	var switch_label_size := font.get_string_size(switch_label, HORIZONTAL_ALIGNMENT_LEFT, -1, switch_font_size)
	draw_string(font, switch_center - switch_label_size * 0.5 + Vector2(0.0, switch_label_size.y), switch_label, HORIZONTAL_ALIGNMENT_LEFT, -1, switch_font_size, Color.WHITE)


func _exit_tree() -> void:
	if _shoot_touch != -1:
		Input.action_release("shoot")
	if _pass_touch != -1:
		Input.action_release("pass")
	if _switch_touch != -1:
		Input.action_release("switch_player")
