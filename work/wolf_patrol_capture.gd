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
	var hud: Control = scene.get_node("HUD/TopHUD")
	hud.restore_save_data({"money": 20000, "day": 12, "day_progress": 0.30})
	scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
	scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD)
	var controller: Node = scene.get_node("BuildController")
	controller.try_place_building(&"dog_house", Vector2(960, 300))
	var dogs: Node = scene.get_node("DogManager")
	dogs.sync_dogs()
	var routine: Node = scene.get_node("DayRoutineManager")
	routine._try_discover_wolf_den()
	var dog: AnimatedSprite2D = dogs.get_dogs()[0]
	dog.global_position = Vector2(900, 350)
	scene.select_entity(dog)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://work/wolf_patrol_capture.png")
	Engine.time_scale = 1.0
	paused = false
	quit(0)
