extends Node3D

const MAX_SPEED := 9.0

var _animation_tree: AnimationTree
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _swing_angle := 0.0
var _slap_requested := false


func _ready() -> void:
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
	for target_data in [["LeftHandIKTarget", 0.94, "UpperArm.L", "Hand.L"], ["RightHandIKTarget", 0.40, "UpperArm.R", "Hand.R"]]:
		var target := Marker3D.new()
		target.name = target_data[0]
		stick_rig.add_child(target)
		target.position = stick_rig.to_local(shaft_bottom.lerp(shaft_top, float(target_data[1])))
		var ik := SkeletonIK3D.new()
		ik.name = "%sIK" % String(target_data[0]).trim_suffix("Target")
		ik.root_bone = StringName(target_data[2])
		ik.tip_bone = StringName(target_data[3])
		_skeleton.add_child(ik)
		ik.target_node = ik.get_path_to(target)
		ik.interpolation = 0.82
		ik.start()
	set_meta("hand_ik_ready", true)


func set_swing_pose(stick_angle_degrees: float) -> void:
	var was_resting := absf(_swing_angle) < 2.0
	_swing_angle = stick_angle_degrees
	rotation.y = deg_to_rad(clampf(_swing_angle * 0.46, -38.0, 38.0))
	if _animation_tree != null and was_resting and absf(_swing_angle) >= 2.0 and not _slap_requested:
		_animation_tree.set("parameters/SlapShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_slap_requested = true
	if absf(_swing_angle) < 2.0:
		_slap_requested = false


func apply_goalkeeper_pose() -> void:
	if _animation_tree != null:
		_animation_tree.set("parameters/Locomotion/blend_position", Vector2.ZERO)
	position.y = -0.28
