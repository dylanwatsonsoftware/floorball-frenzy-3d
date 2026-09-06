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
		for part_name in ["Torso", "HeadVisual", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
			var part := rig.find_child(part_name, true, false) as MeshInstance3D
			if part == null or not part.mesh is ArrayMesh:
				fail("%s/%s must be imported modeled geometry, not a Godot primitive" % [actor.name, part_name])
				return
			var arrays := (part.mesh as ArrayMesh).surface_get_arrays(0)
			if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < 40:
				fail("%s/%s needs enough authored topology to read as a modeled character" % [actor.name, part_name])
				return
			if part_name in ["LeftArm", "RightArm"] and not has_blended_arm_weights(arrays):
				fail("%s/%s must blend across upper-arm and forearm bones so the elbow deforms with hand IK" % [actor.name, part_name])
				return
		var skeleton := rig.find_child("Skeleton3D", true, false) as Skeleton3D
		for boot_name in ["LeftBoot", "RightBoot"]:
			var boot := rig.find_child(boot_name, true, false) as MeshInstance3D
			if boot == null or maxf(boot.get_aabb().size.x, maxf(boot.get_aabb().size.y, boot.get_aabb().size.z)) > 0.34:
				fail("%s/%s must use a compact shoe silhouette that cannot protrude behind the body; size=%s" % [actor.name, boot_name, boot.get_aabb().size if boot != null else Vector3.ZERO])
				return
			if not boot.visible:
				fail("%s/%s must use visible planted footwear rather than hiding the previous back-spike artifact" % [actor.name, boot_name])
				return
			var boot_size := boot.get_aabb().size
			if maxf(boot_size.x, maxf(boot_size.y, boot_size.z)) / maxf(0.001, minf(boot_size.x, maxf(boot_size.y, boot_size.z))) > 2.7:
				fail("%s/%s must have a rounded court-shoe silhouette rather than a long pointed last; size=%s" % [actor.name, boot_name, boot_size])
				return
		for clavicle_name in [&"Clavicle.L", &"Clavicle.R"]:
			if skeleton.find_bone(clavicle_name) < 0:
				fail("%s needs %s control for shoulder-led stick movement" % [actor.name, clavicle_name])
				return
		var animation_player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var slap_animation := animation_player.get_animation(&"slap_shot")
		if not animation_has_bone_rotation(slap_animation, "Clavicle.L") or not animation_has_bone_rotation(slap_animation, "Clavicle.R"):
			fail("%s slap shot must animate both clavicles instead of hinging arms directly from the chest" % actor.name)
			return
	var variants := {&"red": {}, &"blue": {}}
	for actor in scene.get_node("Arena").call("get_field_players"):
		if StringName(actor.get_meta("role", &"field")) == &"goalkeeper":
			continue
		var rig := actor.get_node("BodyRig") as Node3D
		var signature := String(rig.get_meta("appearance_variant", ""))
		if signature.is_empty():
			fail("%s needs a deterministic appearance variant" % actor.name)
			return
		variants[actor.call("get_team")][signature] = true
	if variants[&"red"].size() != 5 or variants[&"blue"].size() != 5:
		fail("All five field players per team must look individually distinct; variants=%s" % variants)
		return
	print("Lambs and Pirates use authored 3D character meshes with distinct teammate variants.")
	quit(0)


func has_blended_arm_weights(arrays: Array) -> bool:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var used_bones := {}
	var blended_vertex := false
	for vertex_index in range(bones.size() / 4):
		var positive_weights := 0
		for influence in 4:
			var index := vertex_index * 4 + influence
			if weights[index] > 0.05:
				positive_weights += 1
				used_bones[bones[index]] = true
		blended_vertex = blended_vertex or positive_weights >= 2
	return used_bones.size() >= 2 and blended_vertex


func animation_has_bone_rotation(animation: Animation, bone_name: String) -> bool:
	for track_index in animation.get_track_count():
		if not String(animation.track_get_path(track_index)).contains(bone_name):
			continue
		for key_index in animation.track_get_key_count(track_index):
			var value: Variant = animation.track_get_key_value(track_index, key_index)
			if value is Quaternion and (value as Quaternion).get_angle() > 0.04:
				return true
	return false


func fail(message: String) -> void:
	push_error(message)
	quit(1)
