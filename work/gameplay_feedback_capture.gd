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
	story.event_queue.clear()
	story.current_event = {}
	var right_panel: Control = scene.get_node("HUD/RightSidePanel")
	if right_panel.visible:
		right_panel.close_panel()
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")
	toolbar.select_tab(&"help")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://work/gameplay_help_capture.png")

	scene.get_node("HUD/HelpMenu").hide()
	toolbar.selected_index = -1
	toolbar._update_button_visuals()
	var hud: Control = scene.get_node("HUD/TopHUD")
	hud.restore_save_data({"money": 20000, "day": 12, "day_progress": 0.90})
	scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
	scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD)
	var controller: Node = scene.get_node("BuildController")
	controller.try_place_building(&"dog_house", Vector2(980, 280))
	controller.try_place_building(&"dog_house", Vector2(1120, 430))
	controller.try_place_fence(Vector2(520, 230), Vector2(600, 310))
	var routine: Node = scene.get_node("DayRoutineManager")
	routine._try_discover_wolf_den()
	var dogs: Node = scene.get_node("DogManager")
	scene.select_entity(dogs.get_dogs()[1])
	var wolf_manager: Node = scene.get_node("WolfManager")
	wolf_manager._sync_night_pack()
	var wolves: Array[AnimatedSprite2D] = wolf_manager.get_active_wolves()
	for index in wolves.size():
		wolves[index].global_position = Vector2(850 + index * 52, 410 + index * 24)
		wolves[index].set_meta("retreating", true)
	for frame in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://work/gameplay_wolf_capture.png")
	Engine.time_scale = 1.0
	paused = false
	quit(0)
