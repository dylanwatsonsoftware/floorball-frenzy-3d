class_name OneTouch
extends RefCounted

const WINDOW_SECONDS := 0.3


static func is_eligible(last_actor: StringName, touch_age: float, shooter: StringName) -> bool:
	return last_actor != &"" and last_actor != shooter and touch_age < WINDOW_SECONDS


static func actor_for_controller(controller: int) -> StringName:
	match controller:
		0:
			return &"red"
		1:
			return &"blue"
		_:
			return &""
