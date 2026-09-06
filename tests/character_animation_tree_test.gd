extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
	for actor in scene.get_node("Arena").call("get_field_players"):
		var rig := actor.get_node("BodyRig") as Node3D
		var animation_tree := rig.get_node_or_null("AnimationTree") as AnimationTree
		if animation_tree == null or not animation_tree.active or not animation_tree.tree_root is AnimationNodeBlendTree:
			fail("%s must drive its shared skeleton through an active AnimationTree" % actor.name)
			return
		var blend_tree := animation_tree.tree_root as AnimationNodeBlendTree
		if not blend_tree.has_node("Locomotion") or not blend_tree.has_node("SlapShot"):
			fail("%s needs locomotion blending and a layered slap-shot action" % actor.name)
			return
		var skeleton := rig.find_child("Skeleton3D", true, false) as Skeleton3D
		if StringName(actor.get_meta("role", &"field")) != &"goalkeeper":
			var ik_count := 0
			for child in skeleton.get_children():
				if child is SkeletonIK3D and (child as SkeletonIK3D).is_running():
					ik_count += 1
					(child as SkeletonIK3D).start(true)
			if ik_count != 2 or not bool(rig.get_meta("hand_ik_ready", false)):
				fail("%s must expose two running stick-hand IK chains; count=%d" % [actor.name, ik_count])
				return
			var top_hand := actor.get_node("StickRig/RightHandIKTarget") as Marker3D
			var lower_hand := actor.get_node("StickRig/LeftHandIKTarget") as Marker3D
			var pocket := actor.get_node("StickRig/BladePocket") as Marker3D
			var top_distance := top_hand.global_position.distance_to(pocket.global_position)
			var lower_distance := lower_hand.global_position.distance_to(pocket.global_position)
			if top_distance <= 0.0 or lower_distance / top_distance < 0.58 or lower_distance / top_distance > 0.70:
				fail("Stick hands must be separated with one at the top and the lower hand about 40%% down from it; top=%s lower=%s" % [top_distance, lower_distance])
				return
			for hand_data in [["Hand.R", top_hand], ["Hand.L", lower_hand]]:
				var bone_index := skeleton.find_bone(StringName(hand_data[0]))
				var hand_position := skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)
				var target_position := (hand_data[1] as Marker3D).global_position
				var alignment_error := hand_position.distance_to(target_position)
				if alignment_error > 0.14:
					fail("%s must place %s on its stick grip; alignment error=%.3f" % [actor.name, hand_data[0], alignment_error])
					return
	print("Every player uses locomotion blending, layered slap actions, and the hand-IK contract.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
