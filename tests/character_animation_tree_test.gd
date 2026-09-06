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
	var field_players: Array = scene.get_node("Arena").call("get_field_players")
	var locomotion_paces := {}
	for actor in field_players:
		var rig := actor.get_node("BodyRig") as Node3D
		var animation_tree := rig.get_node_or_null("AnimationTree") as AnimationTree
		var animation_player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animation_tree == null or not animation_tree.active or not animation_tree.tree_root is AnimationNodeBlendTree:
			fail("%s must drive its shared skeleton through an active AnimationTree" % actor.name)
			return
		var blend_tree := animation_tree.tree_root as AnimationNodeBlendTree
		if not blend_tree.has_node("Locomotion") or not blend_tree.has_node("SlapShot"):
			fail("%s needs locomotion blending and a layered slap-shot action" % actor.name)
			return
		var locomotion := blend_tree.get_node("Locomotion") as AnimationNodeBlendSpace2D
		if locomotion.blend_mode != AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED:
			fail("%s must blend directional locomotion continuously instead of snapping between clips" % actor.name)
			return
		if not blend_tree.has_node("LocomotionPace"):
			fail("%s must vary locomotion timing so the whole team does not move in lockstep" % actor.name)
			return
		for animation_name in [&"backpedal", &"strafe_left", &"strafe_right"]:
			var animation := animation_player.get_animation(animation_name)
			var track_paths: Array[String] = []
			for track_index in animation.get_track_count():
				track_paths.append(String(animation.track_get_path(track_index)))
			if not track_paths.any(func(path: String) -> bool: return path.contains("Hips")):
				fail("%s must include a planted hip posture instead of only reversing the run cycle" % animation_name)
				return
			if maximum_bone_rotation(animation, "Hips") < 0.05:
				fail("%s must animate a readable planted hip posture" % animation_name)
				return
			if animation_name == &"backpedal" and not track_paths.any(func(path: String) -> bool: return path.contains("Shin")):
				fail("Backpedalling must bend the knees for short defensive recovery steps")
				return
		locomotion_paces[snappedf(float(animation_tree.get("parameters/LocomotionPace/scale")), 0.001)] = true
		var skeleton := rig.find_child("Skeleton3D", true, false) as Skeleton3D
		if actor.name == "Player":
			actor.velocity = Vector3(8.0, 0.0, 3.0)
			rig.call("_process", 1.0 / 60.0)
			var acceleration_lean := Vector2(rig.rotation.x, rig.rotation.z).length()
			if acceleration_lean < 0.025 or acceleration_lean > 0.16:
				fail("Acceleration must produce a subtle readable planted body lean; lean=%s" % acceleration_lean)
				return
			if rig.position.y > -0.01:
				fail("Acceleration must briefly compress the player's stance; body_y=%s" % rig.position.y)
				return
			var ball := scene.get_node("Arena/Ball")
			ball.call("apply_network_control_state", actor.call("get_actor_id"), actor.call("get_actor_id"), &"")
			if not ball.call("is_controlled_by_actor", actor.call("get_actor_id")):
				fail("Possession test must assign the ball to the player")
				return
			actor.velocity = Vector3(4.0, 0.0, 0.0)
			for frame in 20:
				rig.call("_process", 1.0 / 60.0)
			if rig.position.y > -0.035:
				fail("A ball carrier must settle into a visibly lower protective stance; body_y=%s" % rig.position.y)
				return
			if float(animation_tree.get("parameters/LocomotionPace/scale")) < 1.05:
				fail("Possession locomotion should use shorter, quicker-looking steps")
				return
		if StringName(actor.get_meta("role", &"field")) != &"goalkeeper":
			var ik_count := 0
			for child in skeleton.get_children():
				if child is SkeletonIK3D:
					ik_count += 1
			if ik_count != 2 or not bool(rig.get_meta("hand_ik_ready", false)):
				fail("%s must expose two stick-hand IK chains; count=%d" % [actor.name, ik_count])
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
				if alignment_error > 0.06:
					fail("%s must place %s on its stick grip; alignment error=%.3f" % [actor.name, hand_data[0], alignment_error])
					return
	if locomotion_paces.size() < 3:
		fail("The squad needs several subtle locomotion pace variants; got %s" % locomotion_paces.keys())
		return
	print("Every player uses locomotion blending, varied timing, layered slap actions, and the hand-IK contract.")
	quit(0)


func maximum_bone_rotation(animation: Animation, bone_name: String) -> float:
	var maximum := 0.0
	for track_index in animation.get_track_count():
		if not String(animation.track_get_path(track_index)).contains(bone_name):
			continue
		for key_index in animation.track_get_key_count(track_index):
			var value: Variant = animation.track_get_key_value(track_index, key_index)
			if value is Quaternion:
				maximum = maxf(maximum, (value as Quaternion).get_angle())
	return maximum


func fail(message: String) -> void:
	push_error(message)
	quit(1)
