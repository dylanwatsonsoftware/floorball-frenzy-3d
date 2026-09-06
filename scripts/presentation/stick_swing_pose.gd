class_name StickSwingPose
extends RefCounted

const UPPER_HAND_BODY_ORBIT_RATIO := 0.55


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
	stick_rig.transform = Transform3D(
		orbit * rest_transform.basis,
		moving_pivot + orbit * (rest_transform.origin - pivot)
	)
