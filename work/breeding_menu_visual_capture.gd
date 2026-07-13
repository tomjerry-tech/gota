extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.get_node("StoryEventManager").automatic_presentation_enabled = false
	if scene.get_node("HUD/RightSidePanel").visible:
		scene.get_node("HUD/RightSidePanel").close_panel()
	scene.get_node("HUD/BottomToolbar").select_tab(&"sheep")
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://work/breeding_menu_capture.png")
	quit(0)
