extends Node3D

const MAX_SPEED := 9.0
const StickSlapScript = preload("res://scripts/simulation/stick_slap.gd")

var _animation_tree: AnimationTree
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _ball: Node3D
var _swing_angle := 0.0
var _previous_swing_angle := 0.0
var _swing_pose_elapsed := StickSlapScript.TOTAL_SECONDS
var _hand_ik_solvers: Array[SkeletonIK3D] = []
var _previous_planar_velocity := Vector2.ZERO
var _locomotion_lean := Vector2.ZERO
var _locomotion_brace := 0.0
var _possession_weight := 0.0
var _base_locomotion_pace := 1.0
var _previous_actor_rotation := 0.0
var _turn_pivot := 0.0
var _dash_weight := 0.0


func _ready() -> void:
	process_priority = 100
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	var actor := get_parent() as CharacterBody3D
	_ball = actor.get_parent().get_node_or_null("Ball") as Node3D if actor != null else null
	_previous_actor_rotation = actor.rotation.y if actor != null else 0.0
	_setup_animation_tree()
	call_deferred("_setup_hand_targets")


func _process(delta: float) -> void:
	var actor := get_parent() as CharacterBody3D
	if actor == null or _animation_tree == null:
		return
	if _ball == null:
		_ball = actor.get_parent().get_node_or_null("Ball") as Node3D
	if StringName(actor.get_meta("role", &"field")) == &"goalkeeper":
		apply_goalkeeper_pose()
		return
	var planar_velocity := Vector2(actor.velocity.x, actor.velocity.z)
	var angular_speed := angle_difference(_previous_actor_rotation, actor.rotation.y) / maxf(delta, 1.0 / 120.0)
	_previous_actor_rotation = actor.rotation.y
	var stationary_weight := 1.0 - clampf(planar_velocity.length() / 4.0, 0.0, 1.0)
	var target_pivot := clampf(angular_speed / 5.0, -1.0, 1.0) * stationary_weight
	_turn_pivot = lerpf(_turn_pivot, target_pivot, minf(1.0, delta * 14.0))
	var has_ball := _ball != null and _ball.has_method("is_controlled_by_actor") and bool(_ball.call("is_controlled_by_actor", actor.call("get_actor_id")))
	_possession_weight = move_toward(_possession_weight, 1.0 if has_ball else 0.0, delta * (8.0 if has_ball else 5.0))
	var dash_active := planar_velocity.length() > MAX_SPEED * 1.25
	_dash_weight = move_toward(_dash_weight, 1.0 if dash_active else 0.0, delta * (14.0 if dash_active else 4.5))
	var facing := Vector2(sin(actor.rotation.y), cos(actor.rotation.y))
	var right := Vector2(facing.y, -facing.x)
	var blend := Vector2(planar_velocity.dot(right), planar_velocity.dot(facing)) / MAX_SPEED
	_animation_tree.set("parameters/Locomotion/blend_position", blend.limit_length(1.0))
	_animation_tree.set("parameters/LocomotionPace/scale", _base_locomotion_pace * lerpf(1.0, 1.12, _possession_weight) * lerpf(1.0, 1.18, _dash_weight))
	var acceleration := (planar_velocity - _previous_planar_velocity) / maxf(delta, 1.0 / 120.0)
	_previous_planar_velocity = planar_velocity
	var target_pitch := clampf(blend.y * 0.075 + acceleration.dot(facing) * 0.0015, -0.13, 0.13)
	var target_roll := clampf(-blend.x * 0.065 - acceleration.dot(right) * 0.0012, -0.11, 0.11)
	_locomotion_lean = _locomotion_lean.lerp(Vector2(target_pitch, target_roll), minf(1.0, delta * 12.0))
	var target_brace := clampf(acceleration.length() / 70.0, 0.0, 1.0)
	_locomotion_brace = lerpf(_locomotion_brace, target_brace, minf(1.0, delta * 14.0))
	var stride_bob := absf(sin(Time.get_ticks_msec() * 0.012)) * 0.018 * minf(1.0, planar_velocity.length() / MAX_SPEED)
	position.y = stride_bob - _locomotion_brace * 0.13 - _dash_weight * 0.055
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
	locomotion.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	locomotion.add_blend_point(_clip(&"idle"), Vector2.ZERO, -1, "Idle")
	locomotion.add_blend_point(_clip(&"run"), Vector2(0.0, 1.0), -1, "Run")
	locomotion.add_blend_point(_clip(&"backpedal"), Vector2(0.0, -1.0), -1, "Backpedal")
	locomotion.add_blend_point(_clip(&"strafe_left"), Vector2(-1.0, 0.0), -1, "StrafeLeft")
	locomotion.add_blend_point(_clip(&"strafe_right"), Vector2(1.0, 0.0), -1, "StrafeRight")
	graph.add_node("Locomotion", locomotion, Vector2(0.0, 80.0))
	var locomotion_phase := AnimationNodeTimeSeek.new()
	graph.add_node("LocomotionPhase", locomotion_phase, Vector2(175.0, 80.0))
	graph.connect_node("LocomotionPhase", 0, "Locomotion")
	var locomotion_pace := AnimationNodeTimeScale.new()
	graph.add_node("LocomotionPace", locomotion_pace, Vector2(350.0, 80.0))
	graph.connect_node("LocomotionPace", 0, "LocomotionPhase")
	graph.add_node("SlapAnimation", _clip(&"slap_shot"), Vector2(0.0, 220.0))
	var slap_layer := AnimationNodeOneShot.new()
	slap_layer.fadein_time = 0.08
	slap_layer.fadeout_time = 0.14
	slap_layer.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD
	_filter_upper_body(slap_layer)
	graph.add_node("SlapShot", slap_layer, Vector2(240.0, 100.0))
	graph.connect_node("SlapShot", 0, "LocomotionPace")
	graph.connect_node("SlapShot", 1, "SlapAnimation")
	graph.connect_node("output", 0, "SlapShot")
	_animation_tree.tree_root = graph
	_animation_tree.active = true
	var actor := get_parent() as CharacterBody3D
	var squad_slot := int(actor.get_meta("squad_slot", 0)) if actor != null else 0
	_base_locomotion_pace = 0.95 + float(posmod(squad_slot, 5)) * 0.025
	_animation_tree.set("parameters/LocomotionPace/scale", _base_locomotion_pace)
	var phase_offset := float(posmod(squad_slot * 3, 7)) * 0.11
	_animation_tree.set("parameters/LocomotionPhase/seek_request", phase_offset)
	set_meta("locomotion_phase_offset", phase_offset)
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
	var shaft_direction_local := (stick_rig.to_local(shaft_top) - stick_rig.to_local(shaft_bottom)).normalized()
	for target_data in [["RightHandIKTarget", 0.94, "UpperArm.R", "Hand.R"], ["LeftHandIKTarget", 0.64, "UpperArm.L", "Hand.L"]]:
		var target := Marker3D.new()
		target.name = target_data[0]
		stick_rig.add_child(target)
		target.position = stick_rig.to_local(shaft_bottom.lerp(shaft_top, float(target_data[1])))
		target.quaternion = Quaternion(Vector3.UP, shaft_direction_local)
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
	var palm := CapsuleMesh.new()
	palm.radius = 0.085
	palm.height = 0.20
	palm.radial_segments = 12
	palm.rings = 6
	var finger_band := TorusMesh.new()
	finger_band.inner_radius = 0.034
	finger_band.outer_radius = 0.078
	finger_band.rings = 10
	finger_band.ring_segments = 8
	var surface := SurfaceTool.new()
	surface.append_from(palm, 0, Transform3D.IDENTITY)
	surface.append_from(finger_band, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.025, 0.0)))
	grip_hand.mesh = surface.commit()
	grip_hand.material_override = authored_hand.get_active_material(0)
	grip_hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	target.add_child(grip_hand)


func set_swing_pose(stick_angle_degrees: float) -> void:
	_previous_swing_angle = _swing_angle
	_swing_angle = stick_angle_degrees
	_swing_pose_elapsed = _pose_elapsed_for_angle(_swing_angle, _previous_swing_angle)
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


func set_swing_timeline(stick_angle_degrees: float, elapsed: float) -> void:
	set_swing_pose(stick_angle_degrees)
	_swing_pose_elapsed = elapsed


func _apply_torso_swing_pose() -> void:
	if _skeleton == null:
		return
	var pose: Dictionary = StickSlapScript.body_pose_at(_swing_pose_elapsed)
	var chest_twist := deg_to_rad(50.0 * float(pose.chest_turn))
	var spine_twist := deg_to_rad(18.0 * float(pose.chest_turn))
	var hip_twist := deg_to_rad(30.0 * float(pose.hip_turn))
	var contact_accent := float(pose.contact_accent)
	var backward_lean := deg_to_rad(-4.0 * maxf(0.0, -float(pose.weight_shift)) + 3.0 * maxf(0.0, float(pose.weight_shift)) + 2.5 * contact_accent)
	var locomotion_weight := 0.25 if _swing_pose_elapsed < StickSlapScript.TOTAL_SECONDS else 1.0
	rotation.x = backward_lean + (_locomotion_lean.x + _dash_weight * 0.06) * locomotion_weight
	rotation.z = _locomotion_lean.y * locomotion_weight + _turn_pivot * 0.055 * locomotion_weight
	position.x = float(pose.weight_shift) * 0.075
	position.y -= float(pose.crouch) * 0.12 + _possession_weight * 0.075
	position.z = contact_accent * 0.065 + float(pose.follow_through) * 0.018
	var protective_crouch := deg_to_rad(7.0 * _possession_weight)
	var pivot_hip_turn := _turn_pivot * 0.12 * locomotion_weight
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("Hips"), Quaternion(Vector3.RIGHT, protective_crouch) * Quaternion(Vector3.UP, hip_twist + pivot_hip_turn))
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("Spine"), Quaternion(Vector3.UP, spine_twist))
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("Chest"), Quaternion(Vector3.UP, chest_twist))
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("Thigh.L"), Quaternion(Vector3.RIGHT, deg_to_rad(-10.0 * float(pose.plant) - 6.0 * _possession_weight)))
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("Thigh.R"), Quaternion(Vector3.RIGHT, deg_to_rad(8.0 * float(pose.crouch) + 6.0 * _possession_weight)))


func _pose_elapsed_for_angle(angle: float, previous_angle: float) -> float:
	if absf(angle) < 1.0:
		return StickSlapScript.CONTACT_SECONDS if previous_angle < -1.0 and previous_angle > -20.0 else StickSlapScript.TOTAL_SECONDS
	if angle < 0.0:
		var load := sqrt(clampf((absf(angle) - 2.0) / (absf(StickSlapScript.BACKSWING_ANGLE) - 2.0), 0.0, 1.0))
		return StickSlapScript.BACKSWING_SECONDS * load
	var follow := clampf(angle / StickSlapScript.CONTACT_ANGLE, 0.0, 1.0)
	if angle >= previous_angle:
		return lerpf(StickSlapScript.CONTACT_SECONDS, StickSlapScript.BACKSWING_SECONDS + StickSlapScript.FORWARD_SECONDS, follow)
	return lerpf(StickSlapScript.TOTAL_SECONDS, StickSlapScript.BACKSWING_SECONDS + StickSlapScript.FORWARD_SECONDS, follow)


func apply_goalkeeper_pose() -> void:
	if _animation_tree != null:
		_animation_tree.set("parameters/Locomotion/blend_position", Vector2.ZERO)
	position.y = -0.28
