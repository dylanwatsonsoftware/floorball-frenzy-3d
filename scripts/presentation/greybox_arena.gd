extends Node3D

const CameraPresetsScript = preload("res://scripts/presentation/camera_presets.gd")
const ActionCameraScript = preload("res://scripts/presentation/action_camera.gd")
const RINK_LENGTH := 40.0
const RINK_WIDTH := 20.0
const BOARD_HEIGHT := 0.5
const BOARD_CORNER_RADIUS := 2.15
# Regulation paint is 4-5 cm wide. At the mobile broadcast scale that falls
# below one pixel, so the visual mesh is doubled while retaining exact centres.
const LINE_WIDTH := 0.10
const GOAL_LINE_X := 16.5

var _camera_presets: Array[Dictionary] = CameraPresetsScript.all()
var _camera: Camera3D
var _camera_label: Label
var _shot_impact: MeshInstance3D
var _shot_impact_tween: Tween
var _camera_kick_tween: Tween
var _field_players: Array[CharacterBody3D] = []
var _follow_action_camera := true
var _camera_follow_target := Vector3.ZERO
var _camera_look_target := Vector3.ZERO
var _camera_tracking_initialized := false
var _camera_charge_pullback := 0.0


func _ready() -> void:
	_build_world()
	_camera_label = get_node("../HUD/CameraLabel")
	_apply_camera_preset(0)


func _process(delta: float) -> void:
	if not _follow_action_camera or _camera == null:
		return
	var ball := get_node_or_null("Ball") as MeshInstance3D
	if ball == null:
		return
	var action_actor := _action_actor(ball)
	var actor_position := ball.global_position if action_actor == null else action_actor.global_position
	var charge_ratio := float(ball.call("get_shot_charge_ratio")) if ball.has_method("get_shot_charge_ratio") else 0.0
	var pulling_back := charge_ratio > _camera_charge_pullback
	_camera_charge_pullback = lerpf(_camera_charge_pullback, charge_ratio, ActionCameraScript.transition_blend(delta, pulling_back))
	var frame: Dictionary = ActionCameraScript.frame(ball.global_position, actor_position, _camera_charge_pullback > 0.001, _camera_charge_pullback)
	if not _camera_tracking_initialized:
		_camera_follow_target = frame.target
		_camera_look_target = frame.target
		_camera_tracking_initialized = true
	var dead_zone_target: Vector3 = ActionCameraScript.follow_target(_camera_follow_target, frame.target)
	var blend: float = ActionCameraScript.transition_blend(delta, false)
	_camera_follow_target = _camera_follow_target.lerp(dead_zone_target, blend)
	var offset: Vector3 = frame.position - frame.target
	frame.target = _camera_follow_target
	frame.position = _camera_follow_target + offset
	_camera.global_position = _camera.global_position.lerp(frame.position, blend)
	_camera.fov = lerpf(_camera.fov, float(frame.fov), blend)
	_camera_look_target = _camera_look_target.lerp(frame.target, blend)
	_camera.look_at(_camera_look_target, Vector3.UP)


func _action_actor(ball: MeshInstance3D) -> CharacterBody3D:
	var owner_id: StringName = ball.call("get_control_owner_actor_id") if ball.has_method("get_control_owner_actor_id") else &""
	var nearest: CharacterBody3D
	var nearest_distance := INF
	for actor in _field_players:
		if owner_id != &"" and actor.call("get_actor_id") == owner_id:
			return actor
		var distance := actor.global_position.distance_squared_to(ball.global_position)
		if distance < nearest_distance:
			nearest = actor
			nearest_distance = distance
	return nearest


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_apply_camera_preset(0)
			KEY_2:
				_follow_action_camera = false
				_apply_camera_preset(1)
			KEY_3:
				_follow_action_camera = false
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
	var floor := _add_box("RinkFloor", Vector3(RINK_LENGTH, 0.2, RINK_WIDTH), Vector3(0.0, -0.1, 0.0), Color("c99250"))
	floor.material_override = _wood_floor_material()
	_build_markings()
	_build_boards()
	_build_goal("LeftGoal", -GOAL_LINE_X, Color("168a45"))
	_build_goal("RightGoal", GOAL_LINE_X, Color("75d4ed"))
	_build_player()
	_build_ball()
	_build_shot_impact()
	_build_opponent()
	_build_support_player("RedTeammate2", &"red_2", &"red", 1, Vector3(-7.0, 0.75, -4.0), Color("e34b62"))
	_build_support_player("RedTeammate3", &"red_3", &"red", 2, Vector3(-7.0, 0.75, 4.0), Color("c92749"))
	_build_support_player("BlueTeammate2", &"blue_2", &"blue", 1, Vector3(7.0, 0.75, -4.0), Color("3d75ed"))
	_build_support_player("BlueTeammate3", &"blue_3", &"blue", 2, Vector3(7.0, 0.75, 4.0), Color("1f55c8"))
	_build_lighting()
	_build_camera()


func _build_markings() -> void:
	var line_color := Color("f4f7f8")
	_add_painted_box("CenterLine", Vector3(LINE_WIDTH, 0.024, RINK_WIDTH), Vector3(0.0, 0.024, 0.0), line_color)
	var center_spot := MeshInstance3D.new()
	center_spot.name = "CenterSpot"
	var spot_mesh := CylinderMesh.new()
	spot_mesh.top_radius = 0.15
	spot_mesh.bottom_radius = 0.15
	spot_mesh.height = 0.02
	spot_mesh.radial_segments = 20
	center_spot.mesh = spot_mesh
	center_spot.position.y = 0.032
	center_spot.material_override = _marking_material(line_color)
	add_child(center_spot)
	_add_rectangle_marking("LeftGoalCrease", -17.15, 1.0, 4.0, 5.0, line_color)
	_add_rectangle_marking("RightGoalCrease", 17.15, -1.0, 4.0, 5.0, line_color)
	_add_rectangle_marking("LeftGoalkeeperArea", -16.5, 1.0, 1.0, 2.5, line_color)
	_add_rectangle_marking("RightGoalkeeperArea", 16.5, -1.0, 1.0, 2.5, line_color)
	_add_faceoff_cross("FaceOffLeftTop", Vector2(-GOAL_LINE_X, -8.5), line_color)
	_add_faceoff_cross("FaceOffLeftBottom", Vector2(-GOAL_LINE_X, 8.5), line_color)
	_add_faceoff_cross("FaceOffCenterTop", Vector2(0.0, -8.5), line_color)
	_add_faceoff_cross("FaceOffCenterBottom", Vector2(0.0, 8.5), line_color)
	_add_faceoff_cross("FaceOffRightTop", Vector2(GOAL_LINE_X, -8.5), line_color)
	_add_faceoff_cross("FaceOffRightBottom", Vector2(GOAL_LINE_X, 8.5), line_color)
	_add_goal_post_marks("Left", -GOAL_LINE_X, line_color)
	_add_goal_post_marks("Right", GOAL_LINE_X, line_color)


func _add_rectangle_marking(prefix: String, rear_x: float, direction: float, length: float, width: float, color: Color) -> void:
	var front_x := rear_x + direction * length
	_add_painted_box(prefix + "Rear", Vector3(LINE_WIDTH, 0.025, width), Vector3(rear_x, 0.025, 0.0), color)
	_add_painted_box(prefix + "Front", Vector3(LINE_WIDTH, 0.025, width), Vector3(front_x, 0.025, 0.0), color)
	var center_x := (rear_x + front_x) * 0.5
	_add_painted_box(prefix + "Top", Vector3(length, 0.025, LINE_WIDTH), Vector3(center_x, 0.025, -width * 0.5), color)
	_add_painted_box(prefix + "Bottom", Vector3(length, 0.025, LINE_WIDTH), Vector3(center_x, 0.025, width * 0.5), color)


func _add_faceoff_cross(cross_name: String, planar_position: Vector2, color: Color) -> void:
	var cross := Node3D.new()
	cross.name = cross_name
	cross.position = Vector3(planar_position.x, 0.021, planar_position.y)
	add_child(cross)
	var first := _add_painted_box_to(cross, "StrokeA", Vector3(0.30, 0.026, LINE_WIDTH), Vector3.ZERO, color)
	first.rotation_degrees.y = 45.0
	var second := _add_painted_box_to(cross, "StrokeB", Vector3(0.30, 0.026, LINE_WIDTH), Vector3.ZERO, color)
	second.rotation_degrees.y = -45.0


func _add_goal_post_marks(side: String, goal_line_x: float, color: Color) -> void:
	_add_painted_box(side + "GoalPostTopMark", Vector3(0.34, 0.027, LINE_WIDTH), Vector3(goal_line_x, 0.027, -0.8), color)
	_add_painted_box(side + "GoalPostBottomMark", Vector3(0.34, 0.027, LINE_WIDTH), Vector3(goal_line_x, 0.027, 0.8), color)


func _add_painted_box(node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	return _add_painted_box_to(self, node_name, size, position, color)


func _add_painted_box_to(parent: Node, node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var marking := _add_box_to(parent, node_name, size, position, color, false)
	marking.material_override = _marking_material(color)
	return marking


func _marking_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.32, color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _build_boards() -> void:
	var board_color := Color("f5f8fa")
	var straight_length := RINK_LENGTH - BOARD_CORNER_RADIUS * 2.0
	var straight_width := RINK_WIDTH - BOARD_CORNER_RADIUS * 2.0
	_add_box("FarBoard", Vector3(straight_length, BOARD_HEIGHT, 0.35), Vector3(0.0, BOARD_HEIGHT * 0.5, -RINK_WIDTH * 0.5), board_color)
	_add_box("NearBoard", Vector3(straight_length, 0.48, 0.28), Vector3(0.0, 0.24, RINK_WIDTH * 0.5), Color(0.75, 0.84, 0.88, 0.55))
	_add_box("LeftBoard", Vector3(0.35, BOARD_HEIGHT, straight_width), Vector3(-RINK_LENGTH * 0.5, BOARD_HEIGHT * 0.5, 0.0), board_color)
	_add_box("RightBoard", Vector3(0.35, BOARD_HEIGHT, straight_width), Vector3(RINK_LENGTH * 0.5, BOARD_HEIGHT * 0.5, 0.0), board_color)
	_build_corner_board("FarLeftCornerBoard", -1.0, -1.0, BOARD_HEIGHT, board_color)
	_build_corner_board("FarRightCornerBoard", 1.0, -1.0, BOARD_HEIGHT, board_color)
	_build_corner_board("NearLeftCornerBoard", -1.0, 1.0, 0.56, Color(0.75, 0.84, 0.88, 0.62))
	_build_corner_board("NearRightCornerBoard", 1.0, 1.0, 0.56, Color(0.75, 0.84, 0.88, 0.62))


func _build_corner_board(node_name: String, sign_x: float, sign_z: float, height: float, color: Color) -> void:
	var corner := Node3D.new()
	corner.name = node_name
	add_child(corner)
	var center := Vector2(sign_x * (RINK_LENGTH * 0.5 - BOARD_CORNER_RADIUS), sign_z * (RINK_WIDTH * 0.5 - BOARD_CORNER_RADIUS))
	var segment_length := BOARD_CORNER_RADIUS * PI / 6.0 + 0.08
	for index in 3:
		var angle := deg_to_rad(15.0 + index * 30.0)
		var outward := Vector2(sign_x * cos(angle), sign_z * sin(angle))
		var tangent := Vector2(-sign_x * sin(angle), sign_z * cos(angle))
		var segment := _add_box_to(corner, "Segment%d" % (index + 1), Vector3(segment_length, height, 0.34), Vector3(center.x + outward.x * BOARD_CORNER_RADIUS, height * 0.5, center.y + outward.y * BOARD_CORNER_RADIUS), color)
		segment.rotation.y = -atan2(tangent.y, tangent.x)


func _build_goal(goal_name: String, x_position: float, color: Color) -> void:
	var goal := Node3D.new()
	goal.name = goal_name
	goal.position.x = x_position
	add_child(goal)
	var direction := -1.0 if x_position < 0.0 else 1.0
	_add_goal_post(goal, "TopPost", Vector3(0.0, 0.575, -0.8), Vector3(0.1, 1.15, 0.1), color)
	_add_goal_post(goal, "BottomPost", Vector3(0.0, 0.575, 0.8), Vector3(0.1, 1.15, 0.1), color)
	_add_goal_post(goal, "Crossbar", Vector3(0.0, 1.15, 0.0), Vector3(0.1, 0.1, 1.7), color)
	_add_goal_post(goal, "Backbar", Vector3(direction * 1.35, 0.55, 0.0), Vector3(0.08, 1.1, 1.7), Color(color, 0.45))
	_add_goal_post(goal, "TopSideNet", Vector3(direction * 0.675, 0.55, -0.8), Vector3(1.35, 1.1, 0.04), Color(color, 0.2))
	_add_goal_post(goal, "BottomSideNet", Vector3(direction * 0.675, 0.55, 0.8), Vector3(1.35, 1.1, 0.04), Color(color, 0.2))


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
	player.set_meta("actor_id", &"red_1")
	player.set_meta("team", &"red")
	player.set_meta("squad_slot", 0)
	player.set_meta("faceoff_position", player.position)
	add_child(player)
	_field_players.append(player)

	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.52
	capsule_shape.height = 1.5
	shape.shape = capsule_shape
	player.add_child(shape)

	_add_humanoid(player, &"red", 0)
	_add_stick(player, Color("202a38"))
	_add_control_ring(player)
	_add_aim_arrow(player)
	_add_dash_streak(player, Color(0.18, 0.78, 0.35, 0.78))
	_add_player_marker(player)
	_add_fuego_aura(player, Color("ff7a24"))


func _build_opponent() -> void:
	var opponent := CharacterBody3D.new()
	opponent.name = "Opponent"
	opponent.position = Vector3(5.0, 0.75, 0.0)
	opponent.set_script(load("res://scripts/gameplay/opponent_controller.gd"))
	opponent.set_meta("actor_id", &"blue_1")
	opponent.set_meta("team", &"blue")
	opponent.set_meta("squad_slot", 0)
	opponent.set_meta("faceoff_position", opponent.position)
	add_child(opponent)
	_field_players.append(opponent)
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.52
	capsule_shape.height = 1.5
	shape.shape = capsule_shape
	opponent.add_child(shape)
	_add_humanoid(opponent, &"blue", 0)
	_add_stick(opponent, Color("202a38"))
	_add_dash_streak(opponent, Color(0.35, 0.78, 0.94, 0.78))
	_add_fuego_aura(opponent, Color("ffb52e"))


func _build_support_player(node_name: String, actor_id: StringName, team: StringName, slot: int, start_position: Vector3, color: Color) -> void:
	var actor := CharacterBody3D.new()
	actor.name = node_name
	actor.position = start_position
	actor.set_meta("actor_id", actor_id)
	actor.set_meta("team", team)
	actor.set_meta("squad_slot", slot)
	actor.set_meta("faceoff_position", start_position)
	actor.set_script(load("res://scripts/gameplay/squad_ai_controller.gd"))
	add_child(actor)
	_field_players.append(actor)
	var shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.52
	capsule_shape.height = 1.5
	shape.shape = capsule_shape
	actor.add_child(shape)
	_add_humanoid(actor, team, slot)
	_add_stick(actor, Color("202a38"))
	_add_dash_streak(actor, Color(0.18, 0.78, 0.35, 0.78) if team == &"red" else Color(0.35, 0.78, 0.94, 0.78))
	if team == &"red":
		_add_control_ring(actor)
		_add_aim_arrow(actor)
		_add_player_marker(actor)


func _add_humanoid(parent: Node3D, team: StringName, slot: int) -> void:
	var rig := Node3D.new()
	rig.name = "BodyRig"
	rig.set_script(load("res://scripts/presentation/humanoid_player_visual.gd"))
	rig.set_meta("variant_signature", "%s_%d" % ["lamb" if team == &"red" else "pirate", slot])
	parent.add_child(rig)
	var lamb_jerseys := [Color("168a45"), Color("24a653"), Color("0d6f38")]
	var pirate_jerseys := [Color("171c25"), Color("242a34"), Color("0e1118")]
	var jersey_color: Color = lamb_jerseys[slot] if team == &"red" else pirate_jerseys[slot]
	var pirate_fur_colors: Array[Color] = [Color("66727f"), Color("9aa2aa"), Color("454c58")]
	var hand_color: Color = Color("f1f1e8") if team == &"red" else pirate_fur_colors[slot]
	_add_capsule_part(rig, "Torso", Vector3(0.0, 0.12, 0.0), 0.35, 0.72, jersey_color)
	_add_box_part(rig, "JerseyStripe", Vector3(0.0, 0.15, 0.337), Vector3(0.11, 0.48, 0.025), Color("f5f7fb") if team == &"red" else Color("75d4ed"))
	_add_box_part(rig, "Shorts", Vector3(0.0, -0.22, 0.0), Vector3(0.58, 0.24, 0.4), Color("17243a"))
	_add_limb(rig, "LeftArm", Vector3(-0.34, 0.35, 0.02), 0.12, 0.58, jersey_color, hand_color, true)
	_add_limb(rig, "RightArm", Vector3(0.34, 0.35, 0.02), 0.12, 0.58, jersey_color, hand_color, true)
	var sock_color: Color = Color("f1f1e8") if team == &"red" else Color("75d4ed")
	_add_limb(rig, "LeftLeg", Vector3(-0.17, -0.27, 0.0), 0.14, 0.65, sock_color, hand_color, false)
	_add_limb(rig, "RightLeg", Vector3(0.17, -0.27, 0.0), 0.14, 0.65, sock_color, hand_color, false)
	if team == &"red":
		_add_lamb_head(rig, slot)
	else:
		_add_pirate_head(rig, slot)


func _add_lamb_head(rig: Node3D, slot: int) -> void:
	var wool_colors := [Color("fafaf2"), Color("e8e5da"), Color("d2d5cf")]
	var wool: Color = wool_colors[slot]
	_add_sphere_part(rig, "Head", Vector3(0.0, 0.74, 0.0), 0.27, wool)
	var wool_root := Node3D.new()
	wool_root.name = "LambWool"
	rig.add_child(wool_root)
	for index in 5:
		var angle := TAU * float(index) / 5.0
		_add_sphere_part(wool_root, "Curl%d" % index, Vector3(cos(angle) * 0.18, 0.87 + sin(angle) * 0.09, -0.03), 0.13, wool)
	var left_ear := _add_sphere_part(rig, "LeftLambEar", Vector3(-0.31, 0.78, 0.0), 0.15, wool.darkened(0.08))
	left_ear.scale = Vector3(1.65, 0.55, 0.7)
	left_ear.rotation_degrees.z = -18.0
	var right_ear := _add_sphere_part(rig, "RightLambEar", Vector3(0.31, 0.78, 0.0), 0.15, wool.darkened(0.08))
	right_ear.scale = Vector3(1.65, 0.55, 0.7)
	right_ear.rotation_degrees.z = 18.0
	var muzzle := _add_sphere_part(rig, "Muzzle", Vector3(0.0, 0.68, 0.235), 0.15, Color("ded9ce"))
	muzzle.scale = Vector3(0.85, 0.7, 0.65)
	_add_mascot_eyes(rig, 0.77, Color("15191c"))
	_add_sphere_part(rig, "LambNose", Vector3(0.0, 0.69, 0.33), 0.045, Color("25292c"))
	if slot == 0:
		_add_torus_part(rig, "LambVariant0", Vector3(-0.24, 0.88, -0.04), 0.09, 0.14, Color("bca77b"), Vector3(90.0, 0.0, 0.0))
	elif slot == 1:
		var forelock := _add_sphere_part(rig, "LambVariant1", Vector3(0.0, 0.98, 0.05), 0.13, Color("242a2d"))
		forelock.scale = Vector3(0.8, 1.1, 0.8)
	else:
		_add_box_part(rig, "LambVariant2", Vector3(0.34, 0.76, 0.02), Vector3(0.06, 0.13, 0.04), Color("5bd06c"))


func _add_pirate_head(rig: Node3D, slot: int) -> void:
	var fur_colors := [Color("4d5966"), Color("8b9298"), Color("303844")]
	var fur: Color = fur_colors[slot]
	_add_sphere_part(rig, "Head", Vector3(0.0, 0.74, 0.0), 0.27, fur)
	_add_cone_part(rig, "LeftPirateEar", Vector3(-0.17, 0.98, -0.01), 0.12, 0.28, fur)
	_add_cone_part(rig, "RightPirateEar", Vector3(0.17, 0.98, -0.01), 0.12, 0.28, fur)
	var muzzle := _add_sphere_part(rig, "Muzzle", Vector3(0.0, 0.67, 0.235), 0.16, Color("dfe4e5"))
	muzzle.scale = Vector3(0.95, 0.68, 0.65)
	_add_mascot_eyes(rig, 0.78, Color("eef5f6"))
	_add_sphere_part(rig, "PirateNose", Vector3(0.0, 0.70, 0.34), 0.052, Color("101318"))
	_add_box_part(rig, "PirateBandana", Vector3(0.0, 0.89, 0.12), Vector3(0.52, 0.11, 0.16), Color("72d2eb"))
	var patch := _add_sphere_part(rig, "PirateEyePatch", Vector3(-0.095, 0.78, 0.252), 0.085, Color("080a0d"))
	patch.scale = Vector3(1.0, 0.75, 0.28)
	var strap := _add_box_part(rig, "EyePatchStrap", Vector3(0.0, 0.82, 0.25), Vector3(0.49, 0.035, 0.025), Color("080a0d"))
	strap.rotation_degrees.z = -10.0
	if slot == 0:
		var bandana_tail := _add_box_part(rig, "PirateVariant0", Vector3(0.26, 0.91, -0.02), Vector3(0.10, 0.31, 0.08), Color("72d2eb"))
		bandana_tail.rotation_degrees.z = -25.0
	elif slot == 1:
		_add_torus_part(rig, "PirateVariant1", Vector3(0.27, 0.74, 0.0), 0.045, 0.068, Color("e8c451"), Vector3(90.0, 0.0, 0.0))
	else:
		var crest := _add_box_part(rig, "PirateVariant2", Vector3(0.0, 1.06, -0.02), Vector3(0.12, 0.25, 0.10), Color("f3f5f5"))
		crest.rotation_degrees.z = 8.0


func _add_mascot_eyes(rig: Node3D, eye_y: float, color: Color) -> void:
	_add_sphere_part(rig, "LeftEye", Vector3(-0.095, eye_y, 0.245), 0.055, color)
	_add_sphere_part(rig, "RightEye", Vector3(0.095, eye_y, 0.245), 0.055, color)


func _add_limb(parent: Node3D, limb_name: String, pivot_position: Vector3, radius: float, length: float, color: Color, end_color: Color, is_arm: bool) -> void:
	var pivot := Node3D.new()
	pivot.name = limb_name
	pivot.position = pivot_position
	parent.add_child(pivot)
	_add_capsule_part(pivot, "Limb", Vector3(0.0, -length * 0.5, 0.0), radius, length, color)
	if is_arm:
		_add_sphere_part(pivot, "Hand", Vector3(0.0, -length - 0.03, 0.0), radius * 0.88, end_color)
	else:
		_add_box_part(pivot, "Shoe", Vector3(0.0, -length - 0.05, 0.09), Vector3(radius * 1.7, 0.15, 0.35), Color("111827"))


func _add_capsule_part(parent: Node3D, part_name: String, part_position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	part.mesh = mesh
	part.position = part_position
	part.material_override = _material(color, 0.68)
	parent.add_child(part)
	return part


func _add_sphere_part(parent: Node3D, part_name: String, part_position: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	part.mesh = mesh
	part.position = part_position
	part.material_override = _material(color, 0.72)
	parent.add_child(part)
	return part


func _add_box_part(parent: Node3D, part_name: String, part_position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = part_position
	part.material_override = _material(color, 0.72)
	parent.add_child(part)
	return part


func _add_cone_part(parent: Node3D, part_name: String, part_position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	part.mesh = mesh
	part.position = part_position
	part.material_override = _material(color, 0.74)
	parent.add_child(part)
	return part


func _add_torus_part(parent: Node3D, part_name: String, part_position: Vector3, inner_radius: float, outer_radius: float, color: Color, rotation: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 12
	mesh.ring_segments = 6
	part.mesh = mesh
	part.position = part_position
	part.rotation_degrees = rotation
	part.material_override = _material(color, 0.66)
	parent.add_child(part)
	return part


func _add_player_marker(parent: Node3D) -> void:
	var marker := Node3D.new()
	marker.name = "PlayerMarker"
	marker.set_script(load("res://scripts/presentation/active_player_marker.gd"))
	parent.add_child(marker)
	var pointer := MeshInstance3D.new()
	pointer.name = "Pointer"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.28
	cone.bottom_radius = 0.0
	cone.height = 0.58
	cone.radial_segments = 14
	pointer.mesh = cone
	pointer.material_override = _material(Color("ffe24f"), 0.25, Color("ffd83d"))
	marker.add_child(pointer)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.38
	ring.rings = 20
	ring.ring_segments = 8
	halo.mesh = ring
	halo.position.y = 0.36
	halo.material_override = _material(Color(1.0, 0.9, 0.3, 0.82), 0.2, Color("ffd83d"))
	marker.add_child(halo)


func _add_control_ring(parent: Node3D) -> void:
	var indicator := MeshInstance3D.new()
	indicator.name = "ControlRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.66
	ring.outer_radius = 0.78
	ring.rings = 24
	ring.ring_segments = 8
	indicator.mesh = ring
	indicator.position.y = -0.7
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	indicator.material_override = _material(Color(1.0, 0.88, 0.28, 0.88), 0.18, Color("ffd84a"))
	indicator.visible = false
	parent.add_child(indicator)


func _add_aim_arrow(parent: Node3D) -> void:
	var arrow := Node3D.new()
	arrow.name = "AimArrow"
	arrow.position.y = -0.68
	arrow.visible = false
	parent.add_child(arrow)
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.1, 0.035, 1.15)
	shaft.mesh = shaft_mesh
	shaft.position.z = 1.425
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.material_override = _material(Color(0.86, 0.82, 0.2, 0.38), 0.2, Color("d9b72d"))
	arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.2
	head_mesh.height = 0.52
	head_mesh.radial_segments = 12
	head.mesh = head_mesh
	head.position.z = 2.25
	head.rotation_degrees.x = 90.0
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.material_override = _material(Color(0.86, 0.82, 0.2, 0.38), 0.2, Color("d9b72d"))
	arrow.add_child(head)


func get_field_players() -> Array[CharacterBody3D]:
	return _field_players.duplicate()


func get_team_players(team: StringName) -> Array:
	return _field_players.filter(func(actor: CharacterBody3D) -> bool: return actor.call("get_team") == team)


func reset_squads_for_faceoff() -> void:
	for actor in _field_players:
		actor.position = actor.get_meta("faceoff_position", actor.position)
		actor.velocity = Vector3.ZERO
		if actor.has_method("reset_for_faceoff"):
			actor.call("reset_for_faceoff")


func _add_stick(parent: Node3D, color: Color) -> void:
	var rig := Node3D.new()
	rig.name = "StickRig"
	rig.position = Vector3(-0.18, -0.18, 0.0)
	rig.rotation_degrees = Vector3(25.0, -28.0, 5.0)
	parent.add_child(rig)

	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.035
	shaft_mesh.bottom_radius = 0.044
	shaft_mesh.height = 1.78
	shaft_mesh.radial_segments = 10
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0.0, 0.0, 0.25)
	shaft.rotation_degrees.x = 90.0
	shaft.material_override = _material(color, 0.65)
	rig.add_child(shaft)

	var grip := MeshInstance3D.new()
	grip.name = "Grip"
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.052
	grip_mesh.bottom_radius = 0.052
	grip_mesh.height = 0.48
	grip_mesh.radial_segments = 10
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, 0.0, -0.49)
	grip.rotation_degrees.x = 90.0
	grip.material_override = _material(Color("f2f4f7"), 0.82)
	rig.add_child(grip)

	var neck := MeshInstance3D.new()
	neck.name = "BladeNeck"
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.048
	neck_mesh.bottom_radius = 0.065
	neck_mesh.height = 0.26
	neck_mesh.radial_segments = 10
	neck.mesh = neck_mesh
	neck.position = Vector3(-0.025, 0.0, 1.08)
	neck.rotation_degrees = Vector3(90.0, 10.0, 0.0)
	neck.material_override = _material(color, 0.6)
	rig.add_child(neck)

	var blade_color := Color("f4d84a")
	_add_floorball_blade(rig, blade_color)


func _add_floorball_blade(rig: Node3D, color: Color) -> void:
	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	var arrays := []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.02, 0.0, 1.17), Vector3(-0.28, 0.0, 1.14),
		Vector3(-0.58, 0.0, 1.02), Vector3(-0.79, 0.0, 0.82),
		Vector3(-0.66, 0.0, 0.71), Vector3(-0.34, 0.0, 0.90),
		Vector3(0.02, 0.0, 1.00),
	])
	arrays[ArrayMesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 6, 1, 5, 6, 1, 2, 5, 2, 4, 5, 2, 3, 4])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	blade.mesh = mesh
	var material := _material(color, 0.42)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blade.material_override = material
	rig.add_child(blade)


func _add_dash_streak(parent: Node3D, color: Color) -> void:
	var streak := Node3D.new()
	streak.name = "DashStreak"
	streak.position = Vector3(0.0, -0.49, 0.0)
	streak.visible = false
	parent.add_child(streak)
	var ring := MeshInstance3D.new()
	ring.name = "DashRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.68
	ring_mesh.outer_radius = 0.82
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _material(color, 0.2, Color(color))
	streak.add_child(ring)


func _add_fuego_aura(parent: Node3D, color: Color) -> void:
	var aura := MeshInstance3D.new()
	aura.name = "FuegoAura"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.7
	ring.outer_radius = 0.92
	ring.rings = 28
	ring.ring_segments = 10
	aura.mesh = ring
	aura.position = Vector3(0.0, -0.49, 0.0)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.material_override = _material(Color(color, 0.74), 0.15, color)
	aura.visible = false
	parent.add_child(aura)


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
	var trail := MeshInstance3D.new()
	trail.name = "ShotTrail"
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(0.11, 0.11, 1.0)
	trail.mesh = trail_mesh
	trail.material_override = _material(Color(1.0, 0.3, 0.04, 0.58), 0.2, Color("ff5a00"))
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visible = false
	trail.top_level = true
	ball.add_child(trail)
	add_child(ball)


func _build_shot_impact() -> void:
	_shot_impact = MeshInstance3D.new()
	_shot_impact.name = "ShotImpact"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.28
	ring.outer_radius = 0.39
	ring.rings = 28
	ring.ring_segments = 8
	_shot_impact.mesh = ring
	_shot_impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shot_impact.material_override = _material(Color(1.0, 0.45, 0.12, 0.9), 0.18, Color("ff6b22"))
	_shot_impact.visible = false
	add_child(_shot_impact)


func play_shot_impact(contact_position: Vector3, feedback: Dictionary) -> void:
	if _shot_impact_tween != null and _shot_impact_tween.is_valid():
		_shot_impact_tween.kill()
	_shot_impact.global_position = Vector3(contact_position.x, 0.035, contact_position.z)
	_shot_impact.scale = Vector3.ONE * 0.35
	var material := _shot_impact.material_override as StandardMaterial3D
	var impact_color: Color = feedback.color
	impact_color.a = 0.92
	material.albedo_color = impact_color
	material.emission = Color(feedback.color)
	_shot_impact.visible = true
	_shot_impact_tween = create_tween().set_parallel(true)
	_shot_impact_tween.tween_property(_shot_impact, "scale", Vector3.ONE * float(feedback.scale), float(feedback.duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shot_impact_tween.tween_property(material, "albedo_color:a", 0.0, float(feedback.duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shot_impact_tween.chain().tween_callback(_hide_shot_impact)
	_play_camera_kick(float(feedback.kick), float(feedback.duration))


func _play_camera_kick(strength: float, duration: float) -> void:
	if _camera == null:
		return
	if _camera_kick_tween != null and _camera_kick_tween.is_valid():
		_camera_kick_tween.kill()
	_camera.h_offset = strength
	_camera.v_offset = -strength * 0.55
	_camera_kick_tween = create_tween().set_parallel(true)
	_camera_kick_tween.tween_property(_camera, "h_offset", 0.0, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_camera_kick_tween.tween_property(_camera, "v_offset", 0.0, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _hide_shot_impact() -> void:
	_shot_impact.visible = false


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
	# Preserve horizontal framing as the browser changes shape. Portrait screens
	# gain vertical context instead of cropping the rink and its active players.
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.current = true
	add_child(_camera)


func _apply_camera_preset(index: int) -> void:
	if _camera == null:
		return
	var preset: Dictionary = _camera_presets[index]
	_follow_action_camera = index == 0
	_camera.position = preset.position
	_camera.fov = preset.fov
	_camera.look_at(preset.target, Vector3.UP)
	_camera_follow_target = preset.target
	_camera_look_target = preset.target
	_camera_tracking_initialized = true
	_camera_charge_pullback = 0.0
	if _camera_label != null:
		_camera_label.text = "CAMERA %d · %s\nCONTROL FOLLOWS LAMBS POSSESSION · TAB SWITCH · SHIFT DASH · HOLD SHOOT" % [index + 1, preset.name.to_upper()]


func _add_box(node_name: String, size: Vector3, position: Vector3, color: Color, shadow: bool = true) -> MeshInstance3D:
	return _add_box_to(self, node_name, size, position, color, shadow)


func _add_box_to(parent: Node, node_name: String, size: Vector3, position: Vector3, color: Color, shadow: bool = true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = _material(color, 0.72)
	parent.add_child(mesh_instance)
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


func _wood_floor_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;

void fragment() {
	float plank_rows = 32.0;
	float plank_columns = 12.0;
	float row = floor(UV.y * plank_rows);
	float stagger = mod(row, 2.0) * 0.5;
	vec2 plank_uv = vec2(fract(UV.x * plank_columns + stagger), fract(UV.y * plank_rows));
	float plank_seam = step(plank_uv.x, 0.018) + step(plank_uv.y, 0.045);
	float grain = sin((UV.x * 145.0 + sin(UV.y * 39.0) * 0.8) * 6.28318) * 0.025;
	vec3 wood = vec3(0.67, 0.40, 0.19) + vec3(grain + mod(row, 3.0) * 0.012);
	ALBEDO = mix(wood, vec3(0.24, 0.12, 0.055), clamp(plank_seam, 0.0, 1.0));
	ROUGHNESS = 0.54;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
