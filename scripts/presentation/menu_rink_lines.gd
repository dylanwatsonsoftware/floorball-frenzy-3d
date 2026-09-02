extends Control

const LINE_COLOR := Color(0.21, 0.70, 0.28, 0.16)
const SOFT_LINE_COLOR := Color(0.21, 0.70, 0.28, 0.09)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var rink := Rect2(Vector2(42.0, 38.0), size - Vector2(84.0, 76.0))
	draw_style_box(_outline_style(LINE_COLOR, 2), rink)
	draw_line(Vector2(size.x * 0.5, rink.position.y), Vector2(size.x * 0.5, rink.end.y), SOFT_LINE_COLOR, 2.0)
	draw_arc(size * 0.5, minf(88.0, size.y * 0.14), 0.0, TAU, 64, LINE_COLOR, 2.0)
	var crease_height := minf(110.0, rink.size.y * 0.2)
	draw_rect(Rect2(rink.position.x, size.y * 0.5 - crease_height * 0.5, 58.0, crease_height), SOFT_LINE_COLOR, false, 2.0)
	draw_rect(Rect2(rink.end.x - 58.0, size.y * 0.5 - crease_height * 0.5, 58.0, crease_height), SOFT_LINE_COLOR, false, 2.0)
	draw_circle(size * 0.5, minf(280.0, size.y * 0.38), Color(0.13, 0.52, 0.19, 0.035))


func _outline_style(color: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(52)
	return style
