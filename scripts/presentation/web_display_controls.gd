extends Control

@onready var _fullscreen_button: Button = $FullscreenButton
@onready var _orientation_hint: Label = $OrientationHint


func _ready() -> void:
	_fullscreen_button.visible = OS.has_feature("web")
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	get_viewport().size_changed.connect(_update_orientation_hint)
	_update_orientation_hint()


static func should_show_orientation_hint(window_size: Vector2, touchscreen_available: bool) -> bool:
	return touchscreen_available and window_size.y > window_size.x


static func web_fullscreen_script() -> String:
	return """
(() => {
	const root = document.documentElement;
	if (document.fullscreenElement && document.exitFullscreen) {
		document.exitFullscreen().catch(() => {});
		return;
	}
	const request = root.requestFullscreen
		? root.requestFullscreen({ navigationUI: 'hide' })
		: Promise.reject(new Error('Fullscreen is unavailable'));
	request
		.then(() => {
			if (screen.orientation && screen.orientation.lock) {
				return screen.orientation.lock('landscape');
			}
		})
		.catch(() => {});
})();
"""


func _toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(web_fullscreen_script())
	else:
		var current_mode := DisplayServer.window_get_mode()
		var next_mode := DisplayServer.WINDOW_MODE_WINDOWED if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(next_mode)


func _update_orientation_hint() -> void:
	var window_size := Vector2(DisplayServer.window_get_size())
	var touch_available := DisplayServer.is_touchscreen_available() or _browser_touch_available()
	_orientation_hint.visible = should_show_orientation_hint(window_size, touch_available)


static func _browser_touch_available() -> bool:
	if not OS.has_feature("web"):
		return false
	var detected: Variant = JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || window.matchMedia('(pointer: coarse)').matches", true)
	return bool(detected)
