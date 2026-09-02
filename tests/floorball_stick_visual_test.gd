extends SceneTree


const LAMB_SHAFT_COLORS := [Color("168a45"), Color("f4f5ed"), Color("171c1f"), Color("0d6f38")]
const PIRATE_SHAFT_COLORS := [Color("111820"), Color("f1f4f7"), Color("17284d"), Color("72c8e6")]
const LAMB_BLADE := Color("20a957")
const PIRATE_BLADE := Color("17284d")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	if not ResourceLoader.exists("res://assets/models/floorball_stick.glb"):
		fail("The approved Blender floorball stick must be exported as an authored game asset")
		return
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var variants := {&"red": {}, &"blue": {}}
	for actor in scene.get_node("Arena").call("get_field_players"):
		if StringName(actor.get_meta("role", &"field")) == &"goalkeeper":
			if actor.get_node_or_null("StickRig") != null:
				fail("Floorball goalkeepers must not carry sticks")
				return
			continue
		var rig := actor.get_node_or_null("StickRig") as Node3D
		if rig == null or not bool(rig.get_meta("authored_stick", false)):
			fail("Every field player must use the approved authored Blender stick")
			return
		var signature := String(rig.get_meta("stick_variant", ""))
		if signature.is_empty():
			fail("Every field player needs a deterministic team-specific stick colour variant")
			return
		var team: StringName = actor.call("get_team")
		variants[team][signature] = true
		var shaft := rig.get_node_or_null("Shaft") as MeshInstance3D
		var grip := rig.get_node_or_null("Grip") as MeshInstance3D
		var end_cap := rig.get_node_or_null("EndCap") as MeshInstance3D
		var blade := rig.get_node_or_null("Blade") as MeshInstance3D
		var neck := rig.get_node_or_null("BladeNeck") as MeshInstance3D
		if shaft == null or grip == null or end_cap == null or blade == null or neck == null:
			fail("The imported stick must preserve shaft, grip, cap, blade, and socket nodes")
			return
		for modeled_part in [shaft, grip, end_cap, blade, neck]:
			if not modeled_part.mesh is ArrayMesh:
				fail("Stick parts must come from authored Blender geometry, not Godot primitives")
				return
		if _longest_axis(shaft.get_aabb().size) < 1.1:
			fail("The authored tapered shaft must retain its full playing length")
			return
		if _longest_axis(grip.get_aabb().size) < 0.5:
			fail("The authored grip must cover almost half the usable shaft")
			return
		var blade_size := blade.get_aabb().size
		if _longest_axis(blade_size) < 0.36 or _longest_axis(blade_size) > 0.46:
			fail("The authored blade must retain its approved short floorball proportions; size=%s" % blade_size)
			return
		if minf(blade_size.x, minf(blade_size.y, blade_size.z)) > 0.025:
			fail("The blade face must remain thin relative to the shaft diameter; size=%s" % blade_size)
			return
		var lattice_parts := 0
		for child in rig.get_children():
			if child is MeshInstance3D and ("Blade_Rib" in child.name or child.name == "Blade"):
				lattice_parts += 1
		if lattice_parts < 10:
			fail("The approved open blade lattice must survive GLB import; parts=%d" % lattice_parts)
			return
		if rig.get_node_or_null("BladePocket") == null or rig.get_node_or_null("CentreSpineToe") == null:
			fail("The authored stick must preserve its ball-control anchors")
			return
		var blade_material := blade.material_override as StandardMaterial3D
		var shaft_material := shaft.material_override as StandardMaterial3D
		var expected_blade: Color = LAMB_BLADE if team == &"red" else PIRATE_BLADE
		var shaft_palette: Array = LAMB_SHAFT_COLORS if team == &"red" else PIRATE_SHAFT_COLORS
		if not blade_material.albedo_color.is_equal_approx(expected_blade):
			fail("Team blade colour is wrong for %s: %s" % [team, blade_material.albedo_color])
			return
		if not _palette_contains(shaft_palette, shaft_material.albedo_color):
			fail("Shaft colour is outside the approved %s palette: %s" % [team, shaft_material.albedo_color])
			return
		var blade_center: Vector3 = actor.to_local(blade.to_global(blade.get_aabb().get_center()))
		var grip_center: Vector3 = actor.to_local(grip.to_global(grip.get_aabb().get_center()))
		if blade_center.y < -0.75 or blade_center.y > -0.42 or absf(blade_center.x) < 0.35 or absf(blade_center.z) < 0.35:
			fail("The authored blade must sit grounded at the player's right-front foot; center=%s" % blade_center)
			return
		if grip_center.y < 0.25:
			fail("The authored grip must rise into the player's hands; center=%s" % grip_center)
			return
	if variants[&"red"].size() != 5 or variants[&"blue"].size() != 5:
		fail("All five field players per team need distinct stick variants; variants=%s" % variants)
		return
	print("Authored floorball sticks and all Lambs/Pirates colour variants are valid.")
	scene.queue_free()
	quit(0)


func _longest_axis(size: Vector3) -> float:
	return maxf(size.x, maxf(size.y, size.z))


func _palette_contains(palette: Array, color: Color) -> bool:
	for allowed: Color in palette:
		if color.is_equal_approx(allowed):
			return true
	return false


func fail(message: String) -> void:
	push_error(message)
	quit(1)
