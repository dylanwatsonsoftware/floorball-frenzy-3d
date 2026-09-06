extends Node3D

const MAX_SPEED := 9.0

var _animation_tree: AnimationTree
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _swing_angle := 0.0
var _hand_ik_solvers: Array[SkeletonIK3D] = []


func _ready() -> void:
	process_priority = 100
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_setup_animation_tree()
	call_deferred("_setup_hand_targets")


func _process(_delta: float) -> void:
	var actor := get_parent() as CharacterBody3D
	if actor == null or _animation_tree == null:
		return
	if StringName(actor.get_meta("role", &"field")) == &"goalkeeper":
		apply_goalkeeper_pose()
		return
	var planar_velocity := Vector2(actor.velocity.x, actor.velocity.z)
	var facing := Vector2(sin(actor.rotation.y), cos(actor.rotation.y))
	var right := Vector2(facing.y, -facing.x)
	var blend := Vector2(planar_velocity.dot(right), planar_velocity.dot(facing)) / MAX_SPEED
	_animation_tree.set("parameters/Locomotion/blend_position", blend.limit_length(1.0))
	position.y = absf(sin(Time.get_ticks_msec() * 0.012)) * 0.018 * minf(1.0, planar_velocity.length() / MAX_SPEED)
	_apply_torso_swing_pose()
	for solver in _hand_ik_solvers:
		solver.start(true)


func _setup_animation_tree() -> void:
	if _animation_player == null or _skeleton == null:
		return
	_animation_tree = AnimationTree.new()
	_animation_tree.name = "AnimationTree"
	add_child(_animation_tree)
	_animation_tree.anim_player = _animation_tree.get_path_to(_animation_player)
	var graph := AnimationNodeBlendTree.new()
	var locomotion := AnimationNodeBlendSpace2D.new()
	locomotion.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE_CARRY
	locomotion.add_blend_point(_clip(&"idle"), Vector2.ZERO, -1, "Idle")
	locomotion.add_blend_point(_clip(&"run"), Vector2(0.0, 1.0), -1, "Run")
	locomotion.add_blend_point(_clip(&"backpedal"), Vector2(0.0, -1.0), -1, "Backpedal")
	locomotion.add_blend_point(_clip(&"strafe_left"), Vector2(-1.0, 0.0), -1, "StrafeLeft")
	locomotion.add_blend_point(_clip(&"strafe_right"), Vector2(1.0, 0.0), -1, "StrafeRight")
	graph.add_node("Locomotion", locomotion, Vector2(0.0, 80.0))
	graph.add_node("SlapAnimation", _clip(&"slap_shot"), Vector2(0.0, 220.0))
	var slap_layer := AnimationNodeOneShot.new()
	slap_layer.fadein_time = 0.08
	slap_layer.fadeout_time = 0.14
	slap_layer.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD
	_filter_upper_body(slap_layer)
	graph.add_node("SlapShot", slap_layer, Vector2(240.0, 100.0))
	graph.connect_node("SlapShot", 0, "Locomotion")
	graph.connect_node("SlapShot", 1, "SlapAnimation")
	graph.connect_node("output", 0, "SlapShot")
	_animation_tree.tree_root = graph
	_animation_tree.active = true
	set_meta("upper_body_animation_layer", true)


func _clip(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node


func _filter_upper_body(layer: AnimationNodeOneShot) -> void:
	var animation := _animation_player.get_animation(&"slap_shot")
	if animation == null:
		return
	layer.filter_enabled = true
	for track_index in animation.get_track_count():
		var path := animation.track_get_path(track_index)
		var path_text := String(path)
		if ["Spine", "Chest", "Neck", "Head", "Arm", "Forearm", "Hand"].any(func(fragment: String) -> bool: return path_text.contains(fragment)):
			layer.set_filter_path(path, true)


func _setup_hand_targets() -> void:
	var actor := get_parent() as CharacterBody3D
	var stick_rig: Node3D = actor.get_node_or_null("StickRig") as Node3D if actor != null else null
	if stick_rig == null or _skeleton == null:
		return
	var pocket := stick_rig.get_node_or_null("BladePocket") as Marker3D
	var shaft := stick_rig.get_node_or_null("Shaft") as MeshInstance3D
	if pocket == null or shaft == null:
		return
	var shaft_bottom := pocket.global_position
	var shaft_box := shaft.mesh.get_aabb()
	var long_axis := 0
	if shaft_box.size.y > shaft_box.size.x and shaft_box.size.y > shaft_box.size.z:
		long_axis = 1
	elif shaft_box.size.z > shaft_box.size.x:
		long_axis = 2
	var top_local := shaft_box.get_center()
	top_local[long_axis] += shaft_box.size[long_axis] * 0.5
	var bottom_local := shaft_box.get_center()
	bottom_local[long_axis] -= shaft_box.size[long_axis] * 0.5
	var endpoint_a := shaft.to_global(top_local)
	var endpoint_b := shaft.to_global(bottom_local)
	var shaft_top := endpoint_a if endpoint_a.distance_to(shaft_bottom) > endpoint_b.distance_to(shaft_bottom) else endpoint_b
	for target_data in [["RightHandIKTarget", 0.94, "UpperArm.R", "Hand.R"], ["LeftHandIKTarget", 0.64, "UpperArm.L", "Hand.L"]]:
		var target := Marker3D.new()
		target.name = target_data[0]
		stick_rig.add_child(target)
		target.position = stick_rig.to_local(shaft_bottom.lerp(shaft_top, float(target_data[1])))
		target.set_meta("rest_position", target.position)
		var ik := SkeletonIK3D.new()
		ik.name = "%sIK" % String(target_data[0]).trim_suffix("Target")
		ik.root_bone = StringName(target_data[2])
		ik.tip_bone = StringName(target_data[3])
		_skeleton.add_child(ik)
		ik.target_node = ik.get_path_to(target)
		ik.influence = 1.0
		_hand_ik_solvers.append(ik)
		_attach_visible_hand(target, "RightHand" if String(target_data[0]).begins_with("Right") else "LeftHand")
	set_meta("hand_ik_ready", true)


func _attach_visible_hand(target: Marker3D, authored_hand_name: String) -> void:
	var authored_hand := find_child(authored_hand_name, true, false) as MeshInstance3D
	if authored_hand == null:
		return
	authored_hand.visible = false
	var grip_hand := MeshInstance3D.new()
	grip_hand.name = "GripHand"
	var mitt := SphereMesh.new()
	mitt.radius = 0.095
	mitt.height = 0.18
	mitt.radial_segments = 12
	mitt.rings = 6
	grip_hand.mesh = mitt
	grip_hand.material_override = authored_hand.get_active_material(0)
	grip_hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	target.add_child(grip_hand)


func set_swing_pose(stick_angle_degrees: float) -> void:
	_swing_angle = stick_angle_degrees
	rotation.y = 0.0
	var actor := get_parent() as CharacterBody3D
	var stick_rig := actor.get_node_or_null("StickRig") as Node3D if actor != null else null
	if stick_rig != null:
		var top_hand := stick_rig.get_node_or_null("RightHandIKTarget") as Marker3D
		var lower_hand := stick_rig.get_node_or_null("LeftHandIKTarget") as Marker3D
		if top_hand != null and lower_hand != null:
			var lower_rest: Vector3 = lower_hand.get_meta("rest_position", lower_hand.position)
			var windup := clampf(-_swing_angle / 82.0, 0.0, 1.0)
			lower_hand.position = lower_rest.lerp(top_hand.position, windup * 0.30)
			stick_rig.force_update_transform()
			top_hand.force_update_transform()
			lower_hand.force_update_transform()


func _apply_torso_swing_pose() -> void:
	if _skeleton == null:
		return
	var swing_ratio := clampf(_swing_angle / 82.0, -1.0, 1.0)
	var chest_twist := deg_to_rad(-44.0 * swing_ratio)
	var spine_twist := deg_to_rad(-14.0 * swing_ratio)
	var backward_lean := deg_to_rad(-4.0 * maxf(0.0, -swing_ratio) + 2.0 * maxf(0.0, swing_ratio))
	rotation.x = backward_lean
	rotation.z = 0.0
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("Spine"), Quaternion(Vector3.UP, spine_twist))
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("Chest"), Quaternion(Vector3.UP, chest_twist))


func apply_goalkeeper_pose() -> void:
	if _animation_tree != null:
		_animation_tree.set("parameters/Locomotion/blend_position", Vector2.ZERO)
	position.y = -0.28
