extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	for asset_path in ["res://assets/models/lamb_player.glb", "res://assets/models/pirate_player.glb"]:
		if not ResourceLoader.exists(asset_path):
			fail("Character model must be an authored imported 3D asset: %s" % asset_path)
			return
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	for actor in scene.get_node("Arena").call("get_field_players"):
		var rig := actor.get_node("BodyRig") as Node3D
		if not bool(rig.get_meta("authored_mesh", false)):
			fail("%s must use the authored mesh pipeline rather than assembled primitives" % actor.name)
			return
		for part_name in ["Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
			var part := rig.get_node_or_null(part_name) as MeshInstance3D
			if part == null or not part.mesh is ArrayMesh:
				fail("%s/%s must be imported modeled geometry, not a Godot primitive" % [actor.name, part_name])
				return
			var arrays := (part.mesh as ArrayMesh).surface_get_arrays(0)
			if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < 40:
				fail("%s/%s needs enough authored topology to read as a modeled character" % [actor.name, part_name])
				return
	print("Lambs and Pirates use authored 3D character meshes.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
