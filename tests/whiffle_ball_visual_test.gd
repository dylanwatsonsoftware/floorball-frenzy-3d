extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	if not ResourceLoader.exists("res://assets/models/whiffle_ball.glb"):
		fail("The white whiffle ball must be exported as an authored game asset")
		return
	var authored_scene := (load("res://assets/models/whiffle_ball.glb") as PackedScene).instantiate()
	var authored_mesh := _find_mesh(authored_scene)
	if authored_mesh == null or authored_mesh.get_aabb().size.x < 0.071 or authored_mesh.get_aabb().size.x > 0.073:
		fail("The authored source ball must retain its real 72 mm diameter")
		return
	if authored_mesh.mesh.get_surface_count() != 1:
		fail("The floorball must use one continuous perforated shell, not separate dark dot or recess surfaces")
		return
	authored_scene.free()
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
	var ball_material := ball.material_override as StandardMaterial3D
	if ball_material == null or ball_material.albedo_color.get_luminance() < 0.85:
		fail("The runtime ball must use one clean white shell material so openings read as genuine holes")
		return
	var dark_surfaces := 0
	for surface in ball.mesh.get_surface_count():
		var material := ball.mesh.surface_get_material(surface) as StandardMaterial3D
		if material != null and material.albedo_color.get_luminance() < 0.22:
			dark_surfaces += 1
	if dark_surfaces > 0:
		fail("The ball must not fake perforations with black materials")
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


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var result := _find_mesh(child)
		if result != null:
			return result
	return null
