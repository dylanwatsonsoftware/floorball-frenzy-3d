extends Control

const STICK_RADIUS := 76.0
const STICK_DEADZONE := 0.2
const EDGE_MARGIN := 28.0
const SHOOT_RADIUS := 58.0

var _movement_touch := -1
var _shoot_touch := -1
var _movement_vector := Vector2.ZERO
var _stick_knob_offset := Vector2.ZERO


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	set_process_input(true)
	resized.connect(queue_redraw)


func get_movement_vector() -> Vector2:
	return _movement_vector


static func calculate_stick_vector(offset: Vector2, radius: float, deadzone: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var normalized_length := minf(1.0, offset.length() / radius)
	if normalized_length <= deadzone:
		return Vector2.ZERO
	var scaled_length := (normalized_length - deadzone) / (1.0 - deadzone)
	return offset.normalized() * scaled_length


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
		if _shoot_touch == -1 and event.position.distance_to(_shoot_center()) <= SHOOT_RADIUS * 1.35:
			_shoot_touch = event.index
			Input.action_press("shoot")
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif _movement_touch == -1 and event.position.x < size.x * 0.55:
			_movement_touch = event.index
			_update_stick(event.position)
			get_viewport().set_input_as_handled()
	elif event.index == _movement_touch:
		_movement_touch = -1
		_movement_vector = Vector2.ZERO
		_stick_knob_offset = Vector2.ZERO
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.index == _shoot_touch:
		_shoot_touch = -1
		Input.action_release("shoot")
		queue_redraw()
		get_viewport().set_input_as_handled()


func _update_stick(touch_position: Vector2) -> void:
	var raw_offset := touch_position - _stick_center()
	_stick_knob_offset = raw_offset.limit_length(STICK_RADIUS)
	_movement_vector = calculate_stick_vector(raw_offset, STICK_RADIUS, STICK_DEADZONE)
	queue_redraw()


func _stick_center() -> Vector2:
	return Vector2(EDGE_MARGIN + STICK_RADIUS, size.y - EDGE_MARGIN - STICK_RADIUS)


func _shoot_center() -> Vector2:
	return Vector2(size.x - EDGE_MARGIN - SHOOT_RADIUS, size.y - EDGE_MARGIN - SHOOT_RADIUS)


func _draw() -> void:
	var stick_center := _stick_center()
	var shoot_center := _shoot_center()
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


func _exit_tree() -> void:
	if _shoot_touch != -1:
		Input.action_release("shoot")
