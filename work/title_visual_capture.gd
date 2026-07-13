extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("res://work/title_screen_capture.png")
	quit(0)
