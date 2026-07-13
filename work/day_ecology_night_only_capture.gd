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
	var commission: Control = scene.get_node("HUD/NewbieCommission")
	var controller: Node = scene.get_node("BuildController")
	hud.restore_save_data({"money": 20000, "day": 12, "day_progress": 0.90})
	commission.restore_save_data({"sufficient_grass_days": 7, "finished": true, "succeeded": true})
	scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
	controller.try_place_building(&"shepherd_house", Vector2(1024, 350))
	var building: Node2D = controller.get_buildings_by_type(&"shepherd_house")[0]
	scene.select_entity(building)
	await process_frame
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://work/day_ecology_night_only_capture.png")
	Engine.time_scale = 1.0
	paused = false
	quit(0)
