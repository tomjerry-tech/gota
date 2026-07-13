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
	story.fired_events.clear()
	story.current_event = {}
	Engine.time_scale = 1.0
	paused = false
	var commission: Control = scene.get_node("HUD/NewbieCommission")
	commission.restore_save_data({"sufficient_grass_days": 7, "finished": true, "succeeded": true})
	var hud: Control = scene.get_node("HUD/TopHUD")
	hud.restore_save_data({"money": 20000, "day": 20, "day_progress": 0.58})
	var controller: Node = scene.get_node("BuildController")
	controller.try_place_building(&"lamb_shelter", Vector2(760, 500))
	var shelter: Node2D = controller.get_buildings_by_type(&"lamb_shelter")[0]
	controller.try_upgrade_building(shelter)
	controller.try_upgrade_building(shelter)
	scene.select_entity(shelter)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://work/building_upgrade_capture.png")
	Engine.time_scale = 1.0
	paused = false
	quit(0)
