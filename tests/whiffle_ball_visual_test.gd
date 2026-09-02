extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	if not ResourceLoader.exists("res://assets/models/whiffle_ball.glb"):
		fail("The white whiffle ball must be exported as an authored game asset")
		return
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var ball := scene.get_node("Arena/Ball") as MeshInstance3D
	if not bool(ball.get_meta("authored_ball", false)) or not ball.mesh is ArrayMesh:
		fail("The runtime ball must use authored Blender geometry")
		return
	var vertices := (ball.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if vertices.size() < 500:
		fail("The whiffle ball needs modeled perforations rather than a primitive sphere")
		return
	var material := ball.material_override as StandardMaterial3D
	if material.albedo_color.get_luminance() < 0.85 or material.albedo_color.a < 0.99:
		fail("The floorball must be opaque white; color=%s" % material.albedo_color)
		return
	var displayed_size := ball.get_aabb().size * ball.scale
	if displayed_size.x < 0.40 or displayed_size.x > 0.46:
		fail("The authored ball must retain the readable in-game diameter; size=%s" % displayed_size)
		return
	if not ball.has_method("launch") or ball.get_node_or_null("ShotTrail") == null:
		fail("Replacing the mesh must preserve ball gameplay and shot feedback")
		return
	print("The authored white whiffle ball is valid.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
