extends SceneTree


func _init() -> void:
	var slap := load("res://scripts/simulation/stick_slap.gd")
	if slap == null:
		fail("Stick slap simulation is missing")
		return
	if slap.phase_at(0.05) != &"backswing":
		fail("A slap must begin with a backswing")
		return
	if slap.phase_at(slap.BACKSWING_SECONDS + 0.02) != &"forward":
		fail("Backswing must transition into a forward swing")
		return
	if not slap.crossed_contact(slap.CONTACT_SECONDS - 0.01, slap.CONTACT_SECONDS + 0.01):
		fail("The forward swing must emit one deterministic contact crossing")
		return
	if slap.crossed_contact(slap.CONTACT_SECONDS + 0.01, slap.CONTACT_SECONDS + 0.03):
		fail("Contact must not repeat after the blade passes the ball")
		return
	if slap.angle_at(0.0) >= 0.0 or absf(slap.angle_at(slap.CONTACT_SECONDS)) > 0.01 or slap.angle_at(slap.CONTACT_SECONDS + 0.02) <= 0.0:
		fail("The stick must meet the carried ball at neutral angle before following through")
		return
	if slap.BACKSWING_SECONDS < 0.18 or slap.BACKSWING_ANGLE > -70.0:
		fail("The backswing must be long and deep enough to read clearly in gameplay")
		return
	if not slap.has_method("forward_step_at"):
		fail("A full slap needs a synchronized forward step profile")
		return
	var before_contact: float = slap.forward_step_at(slap.BACKSWING_SECONDS)
	var at_contact: float = slap.forward_step_at(slap.CONTACT_SECONDS)
	var completed: float = slap.forward_step_at(slap.BACKSWING_SECONDS + slap.FORWARD_SECONDS)
	if before_contact > 0.01 or at_contact < 0.12 or completed < 0.24:
		fail("The player must stay planted during wind-up, then step through contact; step=%s/%s/%s" % [before_contact, at_contact, completed])
		return
	if not slap.has_method("body_pose_at"):
		fail("The slap simulation must expose a deterministic biomechanical body pose")
		return
	var loaded: Dictionary = slap.body_pose_at(slap.BACKSWING_SECONDS)
	var contact: Dictionary = slap.body_pose_at(slap.CONTACT_SECONDS)
	var follow: Dictionary = slap.body_pose_at(slap.BACKSWING_SECONDS + slap.FORWARD_SECONDS)
	var recovered: Dictionary = slap.body_pose_at(slap.TOTAL_SECONDS)
	if float(loaded.crouch) < 0.75 or float(loaded.weight_shift) > -0.65 or float(loaded.hip_turn) > -0.35:
		fail("The backswing must crouch, load the rear leg, and close the hips before the drive; pose=%s" % loaded)
		return
	if float(loaded.get("anticipation", 0.0)) < 0.85:
		fail("The fully loaded backswing needs a readable anticipation hold; pose=%s" % loaded)
		return
	if float(contact.weight_shift) < 0.45 or float(contact.hip_turn) < float(contact.chest_turn) or float(contact.plant) < 0.75:
		fail("At contact the lead leg must plant and the hips must lead the chest; pose=%s" % contact)
		return
	if float(contact.get("contact_accent", 0.0)) < 0.9 or float(loaded.get("contact_accent", 0.0)) > 0.05:
		fail("Contact needs a sharp one-frame visual accent without leaking into the loaded pose; loaded=%s contact=%s" % [loaded, contact])
		return
	if float(follow.follow_through) < 0.9 or float(follow.weight_shift) < 0.7:
		fail("The shot must finish with committed forward weight and a readable follow-through; pose=%s" % follow)
		return
	if absf(float(recovered.weight_shift)) > 0.01 or float(recovered.crouch) > 0.01 or float(recovered.follow_through) > 0.01:
		fail("The biomechanical pose must settle cleanly back to neutral; pose=%s" % recovered)
		return
	var compensated_pass_start: float = slap.network_start_elapsed(&"pass", 0.075)
	var compensated_shot_start: float = slap.network_start_elapsed(&"shot", 0.075)
	if slap.CONTACT_SECONDS - compensated_pass_start > 0.25:
		fail("A remote pass should compensate for measured one-way transit before host contact")
		return
	if slap.CONTACT_SECONDS - compensated_shot_start > 0.05:
		fail("A remote shot release should not repeat network transit as extra forward-swing delay")
		return
	if slap.network_start_elapsed(&"pass", 1.0) >= slap.CONTACT_SECONDS:
		fail("Network compensation must never skip authoritative stick contact")
		return
	print("Stick slap timing is valid.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
