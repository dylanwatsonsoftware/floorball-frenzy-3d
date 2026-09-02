extends Node3D


func _ready() -> void:
	var editor_preview := get_node_or_null("EditorPreview")
	if editor_preview != null:
		editor_preview.queue_free()
	print("Floorball Frenzy 3D ready")
	if OnlineMatch.enabled:
		var online_controller := preload("res://scripts/network/online_match_controller.gd").new()
		online_controller.name = "OnlineMatchController"
		add_child(online_controller)
