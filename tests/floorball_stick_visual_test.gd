extends SceneTree


const LAMB_SHAFT_COLORS := [Color("168a45"), Color("f4f5ed"), Color("171c1f"), Color("0d6f38")]
const PIRATE_SHAFT_COLORS := [Color("111820"), Color("f1f4f7"), Color("17284d"), Color("72c8e6")]
const LAMB_BLADE := Color("20a957")
const PIRATE_BLADE := Color("17284d")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var slap := load("res://scripts/simulation/stick_slap.gd")
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
		var blade := rig.get_node_or_null("Blade") as MeshInstance3D
		if shaft == null or grip == null or blade == null:
			fail("The optimized stick must preserve its authored shaft, grip, and blade groups")
			return
		for modeled_part in [shaft, grip, blade]:
			if not modeled_part.mesh is ArrayMesh:
				fail("Stick parts must come from authored Blender geometry, not Godot primitives")
				return
		if _longest_axis(shaft.get_aabb().size) < 0.95:
			fail("The authored tapered shaft must retain its full playing length")
			return
		if _longest_axis(grip.get_aabb().size) < 0.5:
			fail("The authored grip must cover almost half the usable shaft")
			return
		var blade_size := blade.get_aabb().size
		if _longest_axis(blade_size) < 0.36 or _longest_axis(blade_size) > 0.46:
			fail("The authored blade must retain its approved short floorball proportions; size=%s" % blade_size)
			return
		if minf(blade_size.x, minf(blade_size.y, blade_size.z)) > 0.05:
			fail("The blade face must remain thin relative to the shaft diameter; size=%s" % blade_size)
			return
		if _triangle_count(blade.mesh) < 3000:
			fail("The optimized blade must retain the approved open lattice detail")
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
		if grip_center.y > 0.4 or Vector2(grip_center.x, grip_center.z).length() > 0.65:
			fail("The resting grip must sit in the player's hands instead of floating in front; center=%s" % grip_center)
			return
		var body_rig := actor.get_node("BodyRig") as Node3D
		var resting_grip_world: Vector3 = grip.to_global(grip.get_aabb().get_center())
		actor.call("set_stick_slap_angle", slap.BACKSWING_ANGLE)
		if not is_equal_approx(float(actor.get_meta("stick_slap_angle", 0.0)), slap.BACKSWING_ANGLE):
			fail("Player controllers must expose their current stick pose for network replication")
			return
		grip.force_update_transform()
		var wound_grip_world: Vector3 = grip.to_global(grip.get_aabb().get_center())
		if wound_grip_world.distance_to(resting_grip_world) > 0.18:
			fail("The stick must pivot around the hands instead of sliding the shaft through the torso; rest=%s wound=%s" % [resting_grip_world, wound_grip_world])
			return
		blade.force_update_transform()
		var backswing_blade_center: Vector3 = blade.to_global(blade.get_aabb().get_center())
		var facing: Vector3 = actor.call("get_facing_direction")
		var blade_from_player: Vector3 = backswing_blade_center - actor.global_position
		var local_backswing_blade: Vector3 = actor.to_local(backswing_blade_center)
		if local_backswing_blade.z >= -0.1:
			fail("The wound-up blade must travel behind the player's body; blade=%s facing=%s" % [blade_from_player, facing])
			return
		if absf(body_rig.rotation.y) < 0.30:
			fail("A real backswing must visibly twist the player's torso with the stick")
			return
		actor.call("set_stick_slap_angle", 0.0)
		if absf(body_rig.rotation.y) > 0.01:
			fail("The torso must recover to its neutral pose after the swing")
			return
		var blade_distance := Vector2(blade_center.x, blade_center.z).length()
		var grip_distance := Vector2(grip_center.x, grip_center.z).length()
		if grip_distance >= blade_distance:
			fail("The stick must point across the player's body with its grip closer than its blade; grip=%s blade=%s" % [grip_center, blade_center])
			return
		if rig.scale.x < 1.18:
			fail("The authored stick needs a slightly larger, readable gameplay scale; scale=%s" % rig.scale)
			return
		if blade_center.y < -0.75 or blade_center.y > -0.42 or absf(blade_center.x) < 0.35 or absf(blade_center.z) < 0.35:
			fail("The authored blade must sit grounded at the player's right-front foot; center=%s" % blade_center)
			return
	if variants[&"red"].size() != 5 or variants[&"blue"].size() != 5:
		fail("All five field players per team need distinct stick variants; variants=%s" % variants)
		return
	print("Authored floorball sticks and all Lambs/Pirates colour variants are valid.")
	scene.queue_free()
	quit(0)


func _longest_axis(size: Vector3) -> float:
	return maxf(size.x, maxf(size.y, size.z))


func _triangle_count(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		total += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	return total


func _palette_contains(palette: Array, color: Color) -> bool:
	for allowed: Color in palette:
		if color.is_equal_approx(allowed):
			return true
	return false


func fail(message: String) -> void:
	push_error(message)
	quit(1)
