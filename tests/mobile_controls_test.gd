extends SceneTree


func _init() -> void:
	var controls := load("res://scripts/gameplay/mobile_controls.gd")
	if controls == null:
		fail("Mobile controls script is missing")
		return

	var inside_deadzone: Vector2 = controls.calculate_stick_vector(Vector2(10.0, 0.0), 80.0, 0.2)
	if not inside_deadzone.is_zero_approx():
		fail("Joystick movement inside the dead zone must be zero")
		return

	var halfway: Vector2 = controls.calculate_stick_vector(Vector2(48.0, 0.0), 80.0, 0.2)
	if not is_equal_approx(halfway.x, 0.5) or not is_zero_approx(halfway.y):
		fail("Joystick movement must scale after the dead zone; got %s" % halfway)
		return

	var clamped: Vector2 = controls.calculate_stick_vector(Vector2(160.0, 0.0), 80.0, 0.2)
	if not clamped.is_equal_approx(Vector2.RIGHT):
		fail("Joystick movement must clamp to unit length; got %s" % clamped)
		return

	if not controls.should_show_mobile_controls(true, false, true):
		fail("Web browser touch detection must show mobile controls when Godot touch detection is unavailable")
		return
	if controls.should_show_mobile_controls(true, false, false):
		fail("Desktop web browsers must not show mobile controls")
		return
	if not controls.should_show_mobile_controls(false, true, false):
		fail("Native touchscreen builds must show mobile controls")
		return
	if controls.should_show_control_hint(true) or not controls.should_show_control_hint(false):
		fail("Text control hints must hide on mobile and remain visible on desktop")
		return

	var action: StringName = controls.action_at_position(Vector2(926.0, 386.0), Vector2(1000.0, 600.0))
	if action != &"pass":
		fail("The mobile HUD secondary button must trigger the core pass action")
		return
	var switch_action: StringName = controls.action_at_position(Vector2(934.0, 282.0), Vector2(1000.0, 600.0))
	if switch_action != &"switch_player":
		fail("The mobile HUD needs a dedicated player-switch button")
		return
	var viewport_size := Vector2(844.0, 390.0)
	if not controls.can_start_floating_stick(Vector2(200.0, 180.0), viewport_size):
		fail("Touches on the left side must start the floating joystick")
		return
	if controls.can_start_floating_stick(Vector2(700.0, 180.0), viewport_size):
		fail("Touches on the right side must not start the movement joystick")
		return

	var clamped_origin: Vector2 = controls.clamp_floating_origin(Vector2(25.0, 370.0), viewport_size, 76.0, 20.0)
	if not clamped_origin.is_equal_approx(Vector2(96.0, 294.0)):
		fail("Floating joystick must remain fully visible near screen edges; got %s" % clamped_origin)
		return

	var initial_touch: Vector2 = controls.calculate_floating_drag(Vector2(25.0, 370.0), Vector2(25.0, 370.0), 76.0, 0.2)
	if not initial_touch.is_zero_approx():
		fail("A new floating joystick touch must begin at neutral movement")
		return

	if not controls.has_method("centered_text_baseline"):
		fail("Mobile action labels need a font-metric centering helper")
		return
	var button_center := Vector2(300.0, 180.0)
	var baseline: Vector2 = controls.centered_text_baseline(button_center, 50.0, 15.0, 5.0)
	if not baseline.is_equal_approx(Vector2(275.0, 185.0)):
		fail("Button text must be centred using font ascent and descent; got %s" % baseline)
		return

	print("Mobile control math is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
