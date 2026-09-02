extends SceneTree


func _init() -> void:
	var budgets := {
		"res://assets/models/lamb_player.glb": {"meshes": 24, "triangles": 4000},
		"res://assets/models/pirate_player.glb": {"meshes": 26, "triangles": 4300},
		"res://assets/models/floorball_stick.glb": {"meshes": 3, "triangles": 9000},
		"res://assets/models/whiffle_ball.glb": {"meshes": 1, "triangles": 7000},
	}
	for path: String in budgets:
		var scene := (load(path) as PackedScene).instantiate()
		var stats := {"meshes": 0, "triangles": 0}
		_accumulate(scene, stats)
		scene.free()
		var budget: Dictionary = budgets[path]
		if stats.meshes > budget.meshes or stats.triangles > budget.triangles:
			fail("Mobile model budget exceeded for %s: stats=%s budget=%s" % [path, stats, budget])
			return
	print("All authored models fit the mobile/web rendering budgets.")
	quit(0)


func _accumulate(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		stats.meshes += 1
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			stats.triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	for child in node.get_children():
		_accumulate(child, stats)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
