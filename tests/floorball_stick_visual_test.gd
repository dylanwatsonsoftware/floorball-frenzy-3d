extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var players: Array = scene.get_node("Arena").call("get_field_players")
	for actor in players:
		if StringName(actor.get_meta("role", &"field")) == &"goalkeeper":
			if actor.get_node_or_null("StickRig") != null:
				fail("Floorball goalkeepers must not carry sticks")
				return
			continue
		var rig := actor.get_node_or_null("StickRig") as Node3D
		if rig == null:
			fail("Every field player needs a floorball stick")
			return
		var shaft := rig.get_node_or_null("Shaft") as MeshInstance3D
		var grip := rig.get_node_or_null("Grip") as MeshInstance3D
		var end_cap := rig.get_node_or_null("EndCap") as MeshInstance3D
		if shaft == null or not shaft.mesh is CylinderMesh or grip == null or end_cap == null:
			fail("The stick must use a round shaft with a taped grip and capped top")
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
			if child is MeshInstance3D and child.name.begins_with("Blade"):
				blade_parts.append(child)
		if blade_parts.size() > 2:
			fail("The blade must read as one clean curved silhouette rather than repeated H-shaped rails and ribs; parts=%d" % blade_parts.size())
			return
		var blade := rig.get_node("Blade") as MeshInstance3D
		if not blade.mesh is ArrayMesh or (blade.mesh as ArrayMesh).get_surface_count() != 1:
			fail("The floorball blade must use a single lightweight curved mesh")
			return
		var blade_pocket := rig.get_node_or_null("BladePocket") as Marker3D
		if blade_pocket == null:
			fail("The modeled blade needs an authored toe pocket shared with ball possession")
			return
		var neck := rig.get_node_or_null("BladeNeck") as MeshInstance3D
		if neck == null:
			fail("The shaft must plug into the blade through a molded hosel")
			return
		var blade_size: Vector3 = blade.get_aabb().size
		var blade_bounds := blade.get_aabb()
		var neck_in_blade := blade.to_local(neck.global_position)
		if neck_in_blade.z > blade_bounds.position.z + 0.14 or neck_in_blade.x < blade_bounds.end.x - 0.09:
			fail("The hosel must join the upper heel edge instead of entering near the blade middle; hosel=%s bounds=%s" % [neck_in_blade, blade_bounds])
			return
		if blade_size.z < blade_size.x * 1.6:
			fail("The blade's long axis must continue along the shaft rather than sit across it at right angles; size=%s" % blade_size)
			return
		var shaft_length := (shaft.mesh as CylinderMesh).height
		if blade_size.x < 0.16 or blade_size.x > 0.32 or blade_size.z < 0.48 or blade_size.z > shaft_length * 0.43:
			fail("The blade must be a short, shallow 25–35 cm-equivalent head rather than a rake-sized paddle; shaft=%.3f blade=%s" % [shaft_length, blade_size])
			return
		if blade_size.y < 0.055 or blade_size.y > 0.16:
			fail("The plastic blade must hook gently sideways like a shallow spoon; depth=%.3f" % blade_size.y)
			return
		var pocket_in_blade := blade.to_local(blade_pocket.global_position)
		if pocket_in_blade.z < blade.get_aabb().end.z - 0.18:
			fail("The ball pocket must sit at the curled blade toe rather than near the shaft or blade centre; pocket=%s blade_end=%s" % [pocket_in_blade, blade.get_aabb().end])
			return
		if pocket_in_blade.y > blade_bounds.position.y - 0.16:
			fail("The carried ball centre must sit beyond the blade's playable front face instead of overlapping the blade; pocket=%s front=%s" % [pocket_in_blade, blade_bounds.position.y])
			return
		var blade_face_normal := blade.global_basis.y.normalized()
		var blade_height_axis := blade.global_basis.x.normalized()
		if absf(blade_face_normal.dot(Vector3.UP)) > 0.16 or blade_height_axis.dot(Vector3.UP) < 0.94:
			fail("The lattice face must stand vertically on its narrow lower edge; normal=%s height_axis=%s" % [blade_face_normal, blade_height_axis])
			return
		var blade_min_y := INF
		var blade_max_y := -INF
		for x in [blade_bounds.position.x, blade_bounds.end.x]:
			for y in [blade_bounds.position.y, blade_bounds.end.y]:
				for z in [blade_bounds.position.z, blade_bounds.end.z]:
					var corner_y := blade.to_global(Vector3(x, y, z)).y
					blade_min_y = minf(blade_min_y, corner_y)
					blade_max_y = maxf(blade_max_y, corner_y)
		if blade_min_y < 0.035 or blade_max_y > 0.46 or blade_max_y - blade_min_y < 0.16:
			fail("The blade must stand above the rink without passing through it; min_y=%.3f max_y=%.3f" % [blade_min_y, blade_max_y])
			return
		var blade_vertices := (blade.mesh as ArrayMesh).surface_get_arrays(0)[ArrayMesh.ARRAY_VERTEX] as PackedVector3Array
		var heel_min_depth := INF
		var heel_max_depth := -INF
		for vertex in blade_vertices:
			if vertex.z < blade_bounds.position.z + 0.09:
				heel_min_depth = minf(heel_min_depth, vertex.y)
				heel_max_depth = maxf(heel_max_depth, vertex.y)
		if heel_max_depth - heel_min_depth < 0.025:
			fail("The molded blade needs visible 2–3 cm-equivalent thickness even before its spoon curvature; heel_depth=%.3f" % (heel_max_depth - heel_min_depth))
			return
		var toe_min_x := INF
		var toe_max_x := -INF
		for vertex in blade_vertices:
			if vertex.z > blade_bounds.end.z - 0.075:
				toe_min_x = minf(toe_min_x, vertex.x)
				toe_max_x = maxf(toe_max_x, vertex.x)
		if toe_max_x - toe_min_x < 0.10:
			fail("The outer frame must sweep around a visibly rounded toe instead of ending in a point; toe_span=%.3f" % (toe_max_x - toe_min_x))
			return
		var spine_toe := rig.get_node_or_null("CentreSpineToe") as Marker3D
		if spine_toe == null or blade.to_local(spine_toe.global_position).z < blade_bounds.end.z - 0.08:
			fail("The centre spine must continue into the rounded outer toe instead of stopping inside the blade")
			return
		var blade_center_in_actor: Vector3 = rig.transform * blade.transform * blade.get_aabb().get_center()
		var grip_center_in_actor: Vector3 = rig.transform * grip.position
		if blade_center_in_actor.x <= 0.15 or blade_center_in_actor.z <= 0.35:
			fail("The blade must sit forward and on the player's right rather than trailing backwards; center=%s" % blade_center_in_actor)
			return
		if grip_center_in_actor.y <= blade_center_in_actor.y + 0.75:
			fail("The grip must be visibly above the grounded blade; grip=%s blade=%s" % [grip_center_in_actor, blade_center_in_actor])
			return
		var blade_material := blade.material_override as StandardMaterial3D
		var blade_color := blade_material.albedo_color
		if actor.call("get_team") == &"red":
			if blade_color.g <= blade_color.r * 1.5 or blade_color.g <= blade_color.b * 1.2:
				fail("Lambs sticks must have recognisable green blades; color=%s" % blade_color)
				return
		elif blade_color.b <= blade_color.r * 1.5 or blade_color.b <= blade_color.g * 1.25:
			fail("Pirates sticks must have recognisable navy blades; color=%s" % blade_color)
			return
	print("All six players carry recognizable lightweight floorball sticks.")
	scene.queue_free()
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
