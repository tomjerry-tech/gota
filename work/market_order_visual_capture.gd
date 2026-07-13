extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var story: Node = scene.get_node("StoryEventManager")
	var right_panel: Control = scene.get_node("HUD/RightSidePanel")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.current_event = {}
	if right_panel.visible:
		right_panel.close_panel()
	var sheep_menu: Control = scene.get_node("HUD/SheepMenu")
	scene.get_node("HUD/BottomToolbar").select_tab(&"sheep")
	sheep_menu.open_market_page()
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://work/market_order_capture.png")
	var report: Control = scene.get_node("HUD/DailyReport")
	report.restore_save_data({
		"bought_today": 2,
		"sold_today": 2,
		"born_today": 1,
		"normal_sale_income_today": 320,
		"order_income_today": 840,
		"expired_orders_today": 1,
	})
	report.show_daily_report(1)
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://work/market_daily_report_capture.png")
	Engine.time_scale = 1.0
	paused = false
	quit(0)
