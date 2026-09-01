extends Node3D

const CameraPresetsScript = preload("res://scripts/presentation/camera_presets.gd")
const RINK_LENGTH := 38.0
const RINK_WIDTH := 19.0
const BOARD_HEIGHT := 1.0

var _camera_presets: Array[Dictionary] = CameraPresetsScript.all()
var _camera: Camera3D
var _camera_label: Label


func _ready() -> void:
	_build_world()
	_camera_label = get_node("../HUD/CameraLabel")
	_apply_camera_preset(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_apply_camera_preset(0)
			KEY_2:
				_apply_camera_preset(1)
			KEY_3:
				_apply_camera_preset(2)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("101724")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("c7d8ef")
	environment_resource.ambient_light_energy = 0.65
	environment.environment = environment_resource
	add_child(environment)

	_add_box("ArenaBase", Vector3(45.0, 0.5, 27.0), Vector3(0.0, -0.45, 0.0), Color("172334"))
	_add_box("RinkFloor", Vector3(RINK_LENGTH, 0.2, RINK_WIDTH), Vector3(0.0, -0.1, 0.0), Color("dce8e8"))
	_build_markings()
	_build_boards()
	_build_goal("LeftGoal", -16.0, Color("dd3155"))
	_build_goal("RightGoal", 16.0, Color("2b64e8"))
	_build_player()
	_build_ball()
	_build_opponent()
	_build_lighting()
	_build_camera()


func _build_markings() -> void:
	_add_box("CenterLine", Vector3(0.08, 0.012, RINK_WIDTH - 0.6), Vector3(0.0, 0.012, 0.0), Color("d74962"), false)
	_add_box("LeftGoalLine", Vector3(0.07, 0.013, 5.0), Vector3(-16.0, 0.013, 0.0), Color("d74962"), false)
	_add_box("RightGoalLine", Vector3(0.07, 0.013, 5.0), Vector3(16.0, 0.013, 0.0), Color("d74962"), false)
	var center_circle := MeshInstance3D.new()
	center_circle.name = "CenterCircle"
	var ring := TorusMesh.new()
	ring.inner_radius = 1.88
	ring.outer_radius = 1.94
	ring.rings = 32
	ring.ring_segments = 8
	center_circle.mesh = ring
	center_circle.position.y = 0.025
	center_circle.material_override = _material(Color("d74962"), 0.7)
	add_child(center_circle)


func _build_boards() -> void:
	var board_color := Color("f5f8fa")
	_add_box("FarBoard", Vector3(RINK_LENGTH + 1.0, BOARD_HEIGHT, 0.35), Vector3(0.0, BOARD_HEIGHT * 0.5, -RINK_WIDTH * 0.5), board_color)
	_add_box("NearBoard", Vector3(RINK_LENGTH + 1.0, 0.48, 0.28), Vector3(0.0, 0.24, RINK_WIDTH * 0.5), Color(0.75, 0.84, 0.88, 0.55))
	_add_box("LeftBoard", Vector3(0.35, BOARD_HEIGHT, RINK_WIDTH), Vector3(-RINK_LENGTH * 0.5, BOARD_HEIGHT * 0.5, 0.0), board_color)
	_add_box("RightBoard", Vector3(0.35, BOARD_HEIGHT, RINK_WIDTH), Vector3(RINK_LENGTH * 0.5, BOARD_HEIGHT * 0.5, 0.0), board_color)


func _build_goal(goal_name: String, x_position: float, color: Color) -> void:
	var goal := Node3D.new()
	goal.name = goal_name
	goal.position.x = x_position
	add_child(goal)
	var direction := -1.0 if x_position < 0.0 else 1.0
	_add_goal_post(goal, "TopPost", Vector3(0.0, 0.75, -1.25), Vector3(0.12, 1.5, 0.12), color)
	_add_goal_post(goal, "BottomPost", Vector3(0.0, 0.75, 1.25), Vector3(0.12, 1.5, 0.12), color)
	_add_goal_post(goal, "Crossbar", Vector3(0.0, 1.48, 0.0), Vector3(0.12, 0.12, 2.6), color)
	_add_goal_post(goal, "Backbar", Vector3(direction * 1.35, 0.65, 0.0), Vector3(0.1, 1.3, 2.6), Color(color, 0.45))
	_add_goal_post(goal, "TopSideNet", Vector3(direction * 0.675, 0.72, -1.25), Vector3(1.35, 1.44, 0.05), Color(color, 0.2))
	_add_goal_post(goal, "BottomSideNet", Vector3(direction * 0.675, 0.72, 1.25), Vector3(1.35, 1.44, 0.05), Color(color, 0.2))


func _add_goal_post(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = _material(color, 0.45)
	parent.add_child(mesh_instance)


func _build_player() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(-5.0, 0.75, 0.0)
	player.set_script(load("res://scripts/gameplay/player_controller.gd"))
	add_child(player)

	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.52
	capsule_shape.height = 1.5
	shape.shape = capsule_shape
	player.add_child(shape)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.52
	capsule.height = 1.5
	body.mesh = capsule
	body.material_override = _material(Color("dd3155"), 0.42)
	player.add_child(body)
	_add_stick(player, Color("202a38"))
	_add_dash_streak(player)


func _build_opponent() -> void:
	var opponent := CharacterBody3D.new()
	opponent.name = "Opponent"
	opponent.position = Vector3(5.0, 0.75, 0.0)
	opponent.set_script(load("res://scripts/gameplay/opponent_controller.gd"))
	add_child(opponent)
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.52
	capsule_shape.height = 1.5
	shape.shape = capsule_shape
	opponent.add_child(shape)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.52
	capsule.height = 1.5
	body.mesh = capsule
	body.material_override = _material(Color("2b64e8"), 0.42)
	opponent.add_child(body)
	_add_stick(opponent, Color("202a38"))


func _add_stick(parent: Node3D, color: Color) -> void:
	var rig := Node3D.new()
	rig.name = "StickRig"
	rig.position = Vector3(0.18, -0.18, 0.0)
	rig.rotation_degrees = Vector3(12.0, 28.0, -5.0)
	parent.add_child(rig)

	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.075, 0.075, 1.55)
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0.0, 0.0, 0.35)
	shaft.material_override = _material(color, 0.65)
	rig.add_child(shaft)

	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.48, 0.11, 0.13)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.18, 0.0, 1.08)
	blade.rotation_degrees.y = -12.0
	blade.material_override = _material(color, 0.58)
	rig.add_child(blade)


func _add_dash_streak(parent: Node3D) -> void:
	var streak := Node3D.new()
	streak.name = "DashStreak"
	streak.position = Vector3(0.0, -0.48, -1.0)
	streak.visible = false
	parent.add_child(streak)
	_add_dash_strip(streak, "CenterTrail", Vector3(0.0, 0.0, -0.25), Vector3(0.18, 0.045, 1.9), Color(1.0, 0.22, 0.34, 0.72))
	_add_dash_strip(streak, "LeftTrail", Vector3(-0.34, 0.0, 0.0), Vector3(0.09, 0.035, 1.3), Color(1.0, 0.55, 0.24, 0.52))
	_add_dash_strip(streak, "RightTrail", Vector3(0.34, 0.0, 0.0), Vector3(0.09, 0.035, 1.3), Color(1.0, 0.55, 0.24, 0.52))


func _add_dash_strip(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, color: Color) -> void:
	var strip := MeshInstance3D.new()
	strip.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	strip.mesh = mesh
	strip.position = local_position
	strip.material_override = _material(color, 0.25, Color(color.r, color.g, color.b))
	parent.add_child(strip)


func _build_ball() -> void:
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 20
	sphere.rings = 10
	ball.mesh = sphere
	ball.position = Vector3(0.0, 0.22, 0.0)
	ball.material_override = _material(Color("ff8a1f"), 0.38, Color("ff5a00"))
	ball.set_script(load("res://scripts/gameplay/ball_controller.gd"))
	add_child(ball)


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = Color("e8f4ff")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "BroadcastCamera"
	_camera.current = true
	add_child(_camera)


func _apply_camera_preset(index: int) -> void:
	if _camera == null:
		return
	var preset: Dictionary = _camera_presets[index]
	_camera.position = preset.position
	_camera.fov = preset.fov
	_camera.look_at(preset.target, Vector3.UP)
	if _camera_label != null:
		_camera_label.text = "CAMERA %d · %s\nMOVE + HOLD SHOOT · KEYBOARD: WASD / SPACE · 1–3 CAMERAS" % [index + 1, preset.name.to_upper()]


func _add_box(node_name: String, size: Vector3, position: Vector3, color: Color, shadow: bool = true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = _material(color, 0.72)
	add_child(mesh_instance)
	return mesh_instance


func _material(color: Color, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.3
	return material
