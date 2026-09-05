extends SceneTree


func _init() -> void:
	var action_script = load("res://scripts/network/predicted_ball_action.gd")
	if action_script == null:
		fail("Guest ball actions need an isolated prediction state machine")
		return
	var action = action_script.new()
	action.begin(8, &"pass", Vector3(1.0, 0.22, 2.0), Vector2.RIGHT, Vector3.ZERO, 0.38)
	var before_contact: Dictionary = action.step(0.10, Vector3(1.3, 0.22, 2.0))
	if not before_contact.attached or not before_contact.position.is_equal_approx(Vector3(1.3, 0.22, 2.0)):
		fail("A predicted pass must stay attached to the moving blade during its backswing; got %s" % before_contact)
		return
	var at_contact: Dictionary = action.step(0.22, Vector3(1.4, 0.22, 2.0))
	if at_contact.attached or at_contact.velocity.x < 8.0:
		fail("A predicted pass must release locally at the slap contact frame; got %s" % at_contact)
		return
	var moving: Dictionary = action.step(1.0 / 60.0, Vector3.ZERO)
	if moving.position.x <= at_contact.position.x:
		fail("A released predicted pass must simulate locally between snapshots; got %s" % moving)
		return
	if action.should_accept_snapshot({"action_seq": 7, "ball_state": "possessed", "owner": "blue_1"}):
		fail("A stale possessed snapshot must not pull a predicted pass back onto the blade")
		return
	if not action.should_accept_snapshot({"action_seq": 8, "ball_state": "passing", "owner": ""}):
		fail("The matching authoritative action generation must confirm local prediction")
		return
	if not action.should_accept_snapshot({"action_seq": 7, "ball_state": "dead", "phase": "goal", "owner": ""}):
		fail("Authoritative goal and faceoff phases must cancel an outstanding local ball prediction")
		return
	print("Guest ball actions predict contact and reject stale possession snapshots.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
