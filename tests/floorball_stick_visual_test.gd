extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var players: Array = scene.get_node("Arena").call("get_field_players")
	for actor in players:
		var rig := actor.get_node_or_null("StickRig") as Node3D
		if rig == null:
			fail("Every field player needs a floorball stick")
			return
		var shaft := rig.get_node_or_null("Shaft") as MeshInstance3D
		var grip := rig.get_node_or_null("Grip") as MeshInstance3D
		if shaft == null or not shaft.mesh is CylinderMesh or grip == null:
			fail("The stick must use a round shaft with a distinct hand grip")
			return
		if (shaft.mesh as CylinderMesh).height < 1.65:
			fail("The floorball shaft must be visibly long enough to reach from the hands to the rink")
			return
		var shaft_axis: Vector3 = (rig.transform.basis * shaft.transform.basis.y).normalized()
		if absf(shaft_axis.dot(Vector3.UP)) < 0.72:
			fail("The floorball shaft must rise steeply from the grounded blade toward the player's hands; axis=%s" % shaft_axis)
			return
		var blade_parts := []
		for child in rig.get_children():
			if child.name.begins_with("Blade"):
				blade_parts.append(child)
		if blade_parts.size() > 2:
			fail("The blade must read as one clean curved silhouette rather than repeated H-shaped rails and ribs; parts=%d" % blade_parts.size())
			return
		var blade := rig.get_node("Blade") as MeshInstance3D
		if not blade.mesh is ArrayMesh or (blade.mesh as ArrayMesh).get_surface_count() != 1:
			fail("The floorball blade must use a single lightweight curved mesh")
			return
		var blade_center_in_actor: Vector3 = rig.transform * blade.get_aabb().get_center()
		var grip_center_in_actor: Vector3 = rig.transform * grip.position
		if blade_center_in_actor.x <= 0.15 or blade_center_in_actor.z <= 0.35:
			fail("The blade must sit forward and on the player's right rather than trailing backwards; center=%s" % blade_center_in_actor)
			return
		if grip_center_in_actor.y <= blade_center_in_actor.y + 0.75:
			fail("The grip must be visibly above the grounded blade; grip=%s blade=%s" % [grip_center_in_actor, blade_center_in_actor])
			return
		var blade_material := blade.material_override as StandardMaterial3D
		if blade_material.albedo_color.get_luminance() < 0.55:
			fail("The small floorball blade needs a bright contrasting color at gameplay camera distance")
			return
	print("All six players carry recognizable lightweight floorball sticks.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
