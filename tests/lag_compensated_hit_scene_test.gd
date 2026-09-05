extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var packed := load("res://scenes/match/match.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	var arena := scene.get_node("Arena")
	var ball = arena.get_node("Ball")
	var guest: CharacterBody3D
	for actor in arena.call("get_field_players"):
		actor.set_physics_process(false)
		if actor.call("get_actor_id") == &"blue_1":
			guest = actor
	if guest == null:
		fail("Lag-compensated scene needs the guest-controlled actor")
		return
	var blade := guest.get_node("StickRig/BladePocket") as Marker3D
	blade.force_update_transform()
	ball.call("apply_network_control_state", guest.call("get_actor_id"), &"red_1", guest.call("get_actor_id"))
	ball.global_position = blade.global_position
	ball.ball_velocity = Vector3.ZERO
	ball.call("_record_network_hit_history", 1000)
	ball.global_position = blade.global_position + Vector3(4.0, 0.0, 0.0)
	ball.set("_slap_actor", guest)
	ball.set("_pending_lag_compensated_contact", ball.call("_lag_compensated_network_hit", guest, 150.0, 1075))
	ball.call("_configure_slap", Vector2.RIGHT, 0.8, 0.30)
	ball.call("_advance_slap", 0.03)
	if ball.ball_velocity.length() < 7.5 or ball.call("get_control_owner_actor_id") != &"":
		fail("A delayed but historically valid guest slap must launch authoritatively even after current transforms diverge; velocity=%s owner=%s" % [ball.ball_velocity, ball.call("get_control_owner_actor_id")])
		return
	print("Host lag compensation accepts a historically valid guest slap.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
