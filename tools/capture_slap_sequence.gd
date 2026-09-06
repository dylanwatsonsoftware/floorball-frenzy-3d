extends SceneTree

const StickSlapScript = preload("res://scripts/simulation/stick_slap.gd")


func _init() -> void:
	call_deferred("capture")


func capture() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for frame in 5:
		await process_frame
	var arena := scene.get_node("Arena")
	arena.set("_follow_action_camera", false)
	arena.set_process(false)
	var player := arena.get_node("Player") as CharacterBody3D
	for actor in arena.call("get_field_players"):
		actor.visible = actor == player
		actor.set_physics_process(false)
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	var ball := arena.get_node("Ball")
	ball.set_physics_process(false)
	var blade := player.get_node("StickRig/BladePocket") as Marker3D
	ball.global_position = blade.global_position
	var camera := arena.get_node("BroadcastCamera") as Camera3D
	camera.global_position = Vector3(4.8, 4.0, -5.5)
	camera.fov = 40.0
	camera.look_at(Vector3(0.0, 0.45, 0.0), Vector3.UP)
	scene.get_node("HUD").visible = false
	var phases := {
		"loaded": StickSlapScript.BACKSWING_SECONDS,
		"contact": StickSlapScript.CONTACT_SECONDS,
		"follow": StickSlapScript.BACKSWING_SECONDS + StickSlapScript.FORWARD_SECONDS,
		"recovered": StickSlapScript.TOTAL_SECONDS,
	}
	for phase_name in phases:
		var elapsed: float = phases[phase_name]
		player.call("set_stick_slap_pose", StickSlapScript.angle_at(elapsed), elapsed)
		ball.global_position = blade.global_position
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var path := "/tmp/floorball-slap-%s.png" % phase_name
		var error := image.save_png(path)
		if error != OK:
			push_error("Could not save %s" % path)
			quit(1)
			return
	quit(0)
