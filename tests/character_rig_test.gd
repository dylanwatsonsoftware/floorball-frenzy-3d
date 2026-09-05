extends SceneTree


const REQUIRED_BONES := [
	"Root", "Hips", "Spine", "Chest", "Neck", "Head",
	"UpperArm.L", "Forearm.L", "Hand.L", "UpperArm.R", "Forearm.R", "Hand.R",
	"Thigh.L", "Shin.L", "Foot.L", "Thigh.R", "Shin.R", "Foot.R",
]
const REQUIRED_ANIMATIONS := [&"idle", &"run", &"backpedal", &"strafe_left", &"strafe_right", &"slap_shot"]


func _init() -> void:
	for asset_path in ["res://assets/models/lamb_player.glb", "res://assets/models/pirate_player.glb"]:
		var character := (load(asset_path) as PackedScene).instantiate()
		var skeleton := _find_descendant(character, "Skeleton3D") as Skeleton3D
		if skeleton == null:
			fail("%s must contain a real shared Skeleton3D" % asset_path)
			return
		for bone_name in REQUIRED_BONES:
			if skeleton.find_bone(bone_name) < 0:
				fail("%s is missing shared humanoid bone %s" % [asset_path, bone_name])
				return
		var player := _find_descendant(character, "AnimationPlayer") as AnimationPlayer
		if player == null:
			fail("%s must export an AnimationPlayer with authored character clips" % asset_path)
			return
		var available := {}
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				available[StringName(animation_name)] = true
		for animation_name in REQUIRED_ANIMATIONS:
			if not available.has(animation_name):
				fail("%s is missing authored animation %s; available=%s" % [asset_path, animation_name, available.keys()])
				return
		character.free()
	print("Lamb and Pirate share an animatable humanoid skeleton and authored movement set.")
	quit(0)


func _find_descendant(root_node: Node, type_name: String) -> Node:
	if root_node.is_class(type_name):
		return root_node
	for child in root_node.get_children():
		var found := _find_descendant(child, type_name)
		if found != null:
			return found
	return null


func fail(message: String) -> void:
	push_error(message)
	quit(1)
