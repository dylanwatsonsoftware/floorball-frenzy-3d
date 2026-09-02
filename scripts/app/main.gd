extends Node3D


func _ready() -> void:
	var editor_preview := get_node_or_null("EditorPreview")
	if editor_preview != null:
		editor_preview.queue_free()
	print("Floorball Frenzy 3D ready")
