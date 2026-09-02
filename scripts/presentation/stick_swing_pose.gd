class_name StickSwingPose
extends RefCounted


static func apply(stick_rig: Node3D, angle_degrees: float) -> void:
	if not stick_rig.has_meta("swing_rest_transform"):
		var grip := stick_rig.find_child("Grip", true, false) as MeshInstance3D
		var pivot_in_rig := Vector3.ZERO
		if grip != null:
			pivot_in_rig = stick_rig.to_local(grip.to_global(grip.get_aabb().get_center()))
		stick_rig.set_meta("swing_rest_transform", stick_rig.transform)
		stick_rig.set_meta("swing_pivot", stick_rig.transform * pivot_in_rig)
	var rest_transform: Transform3D = stick_rig.get_meta("swing_rest_transform")
	var pivot: Vector3 = stick_rig.get_meta("swing_pivot")
	var orbit := Basis(Vector3.UP, deg_to_rad(angle_degrees))
	stick_rig.transform = Transform3D(
		orbit * rest_transform.basis,
		pivot + orbit * (rest_transform.origin - pivot)
	)
