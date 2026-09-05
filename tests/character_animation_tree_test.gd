extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
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
		if rig.find_child("Skeleton3D", true, false) == null or not bool(rig.get_meta("hand_ik_ready", false)):
			fail("%s must expose the shared skeleton and stick-hand IK contract" % actor.name)
			return
	print("Every player uses locomotion blending, layered slap actions, and the hand-IK contract.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
