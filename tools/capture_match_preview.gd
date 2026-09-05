extends SceneTree


func _init() -> void:
	call_deferred("capture")


func capture() -> void:
	var scene := (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for frame in 5:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png("/tmp/floorball-character-preview.png")
	quit()
