class_name CameraPresets
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"name": "Broadcast",
			"position": Vector3(4.5, 25.0, 25.5),
			"target": Vector3.ZERO,
			"fov": 40.0,
		},
		{
			"name": "Toy Box",
			"position": Vector3(2.0, 31.0, 22.0),
			"target": Vector3.ZERO,
			"fov": 36.0,
		},
		{
			"name": "Action",
			"position": Vector3(7.0, 19.0, 25.0),
			"target": Vector3.ZERO,
			"fov": 48.0,
		},
	]
