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
	var commission: Control = scene.get_node("HUD/NewbieCommission")
	commission.restore_save_data({"sufficient_grass_days": 7, "finished": true, "succeeded": true})
	var hud: Control = scene.get_node("HUD/TopHUD")
	hud.restore_save_data({"money": 20000, "day": 12, "day_progress": 0.95})
	scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
	scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD)
	var routine: Node = scene.get_node("DayRoutineManager")
	routine._try_discover_wolf_den()
	var report: Control = scene.get_node("HUD/DailyReport")
	report.show_daily_report(12)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://work/wolf_risk_report_capture.png")
	Engine.time_scale = 1.0
	paused = false
	quit(0)
