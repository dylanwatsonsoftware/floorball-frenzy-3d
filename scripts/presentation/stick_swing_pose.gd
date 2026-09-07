class_name StickSwingPose
extends RefCounted

const UPPER_HAND_BODY_ORBIT_RATIO := 0.55
const LOADED_HAND_CLEARANCE := 0.12
const MAX_BACKSWING_LIFT_DEGREES := 18.0


static func apply(stick_rig: Node3D, angle_degrees: float) -> void:
	if not stick_rig.has_meta("swing_rest_transform"):
		var grip := stick_rig.find_child("Grip", true, false) as MeshInstance3D
		var pivot_in_rig := Vector3.ZERO
		var top_hand := stick_rig.get_node_or_null("RightHandIKTarget") as Marker3D
		if top_hand != null:
			pivot_in_rig = top_hand.position
		elif grip != null:
			pivot_in_rig = stick_rig.to_local(grip.to_global(grip.get_aabb().get_center()))
		stick_rig.set_meta("swing_rest_transform", stick_rig.transform)
		stick_rig.set_meta("swing_pivot", stick_rig.transform * pivot_in_rig)
		var blade_pocket := stick_rig.get_node_or_null("BladePocket") as Marker3D
		if blade_pocket != null:
			stick_rig.set_meta("swing_blade_rest", stick_rig.transform * blade_pocket.position)
	var rest_transform: Transform3D = stick_rig.get_meta("swing_rest_transform")
	var pivot: Vector3 = stick_rig.get_meta("swing_pivot")
	var angle_radians := deg_to_rad(angle_degrees)
	var orbit := Basis(Vector3.UP, angle_radians)
	# The upper hand is a hinge on the shaft, not a nail in world space. Carry it
	# around the player's body as the shoulders turn so the shaft follows the
	# outside arc instead of cutting a straight chord through the torso.
	var body_axis := Vector3(0.0, pivot.y, 0.0)
	var hand_orbit := Basis(Vector3.UP, angle_radians * UPPER_HAND_BODY_ORBIT_RATIO)
	var moving_pivot := body_axis + hand_orbit * (pivot - body_axis)
	var radial_direction := (moving_pivot - body_axis).normalized()
	var load_ratio := clampf(absf(angle_degrees) / 90.0, 0.0, 1.0)
	moving_pivot += radial_direction * sin(load_ratio * PI * 0.5) * LOADED_HAND_CLEARANCE
	var lift := Basis.IDENTITY
	if stick_rig.has_meta("swing_blade_rest"):
		var rest_blade: Vector3 = stick_rig.get_meta("swing_blade_rest")
		var yawed_blade_vector := orbit * (rest_blade - pivot)
		var planar_blade_vector := Vector3(yawed_blade_vector.x, 0.0, yawed_blade_vector.z)
		if not planar_blade_vector.is_zero_approx():
			var lift_axis := planar_blade_vector.normalized().cross(Vector3.UP)
			var lift_angle := deg_to_rad(MAX_BACKSWING_LIFT_DEGREES) * smoothstep(0.0, 1.0, load_ratio)
			lift = Basis(lift_axis, lift_angle)
	stick_rig.transform = Transform3D(
		lift * orbit * rest_transform.basis,
		moving_pivot + lift * orbit * (rest_transform.origin - pivot)
	)
