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
	var hud: Control = scene.get_node("HUD/TopHUD")
	hud.restore_save_data({"money": 28640, "day": 24, "day_progress": 0.42})
	var controller: Node = scene.get_node("BuildController")
	scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
	controller.try_place_fence(Vector2(880, 230), Vector2(1040, 390))
	var fence: Node2D = controller.get_fence_roots()[0]
	controller.try_upgrade_building(fence)
	controller.try_upgrade_building(fence)
	var progression: Node = scene.get_node("PastureProgressionManager")
	progression.restore_save_data({
		"reputation": 330,
		"pasture_level": 3,
		"current_chapter": 3,
		"unlocked_achievements": ["first_order", "flock_keeper", "safe_guard"],
		"stats": {
			"orders_completed": 5, "bloodline_orders": 1, "merchant_chains": 1,
			"lambs_born": 7, "first_generation_born": 3, "max_generation": 1,
			"buildings_upgraded": 1, "wolf_patrols": 1, "rescues_completed": 1,
			"best_safe_night_streak": 2, "chapters_completed": 2,
		},
	})
	var commission: Control = scene.get_node("HUD/NewbieCommission")
	commission.restore_save_data({"sufficient_grass_days": 7, "finished": true, "succeeded": true})
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://work/pasture_chapter_capture.png")
	right_panel.show_records(progression)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://work/pasture_records_capture.png")
	Engine.time_scale = 1.0
	paused = false
	quit(0)
