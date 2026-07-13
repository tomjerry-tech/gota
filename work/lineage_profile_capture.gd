extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var story: Node = scene.get_node("StoryEventManager")
	story.automatic_presentation_enabled = false
	var right_panel: Control = scene.get_node("HUD/RightSidePanel")
	if right_panel.visible:
		right_panel.close_panel()
	story.event_queue.clear()
	story.current_event = {}
	Engine.time_scale = 1.0
	paused = false
	var mother: Node = scene.sheep_group.get_child(0)
	var father: Node = scene.sheep_group.get_child(1)
	var lamb: Node = scene.add_lamb(false)
	lamb.set_lineage(mother.get_sheep_id(), father.get_sheep_id(), 1)
	lamb.set_sheep_name("星芽")
	scene.open_sheep_profile(lamb)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://work/lineage_profile_capture.png")
	Engine.time_scale = 1.0
	paused = false
	quit(0)
