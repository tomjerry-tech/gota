extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var manager: Node = scene.get_node("StoryEventManager")
	var right_panel: Control = scene.get_node("HUD/RightSidePanel")
	var task_panel: Control = scene.get_node("HUD/DailyTaskPanel")
	var report: Control = scene.get_node("HUD/DailyReport")
	var time_controls: Control = scene.get_node("HUD/TimeControls")

	manager.event_queue.clear()
	manager.fired_events.clear()
	if not manager.queue_event(&"first_land_expansion") or manager.queue_event(&"first_land_expansion"):
		_fail("A story node could trigger more than once")
		return
	manager.event_queue.clear()
	manager.fired_events.clear()
	manager._on_day_changed(4)
	var first_target: Node = manager.get_day_four_target()
	if not is_instance_valid(first_target) or first_target.is_healthy():
		_fail("Day 4 event did not keep a valid mildly sick target sheep")
		return
	first_target.prepare_for_sale()
	first_target.queue_free()
	await process_frame
	var replacement: Node = manager.get_day_four_target()
	if not is_instance_valid(replacement) or replacement == first_target or replacement.is_healthy():
		_fail("Day 4 event did not replace a sold target sheep")
		return

	manager.event_queue.clear()
	manager.fired_events.clear()
	manager.current_event = {}
	manager.automatic_presentation_enabled = true
	report.show_daily_report(1)
	manager.queue_event(&"welcome")
	await process_frame
	if not report.visible or right_panel.visible or manager.get_current_event_id() != &"":
		_fail("Queued story opened underneath the daily report")
		return
	report.close_report()
	await process_frame
	await process_frame
	if not right_panel.visible or right_panel.get_mode() != &"story":
		_fail("Queued story did not open after report_closed")
		return
	var panel_rect := right_panel.get_global_rect()
	if not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel_rect):
		_fail("Right-side panel escaped the 1280x720 viewport")
		return
	for protected_control_path in ["HUD/TopHUD", "HUD/TimeControls", "HUD/BottomToolbar"]:
		var protected_control: Control = scene.get_node(protected_control_path)
		if panel_rect.intersects(protected_control.get_global_rect()):
			_fail("Right-side panel overlaps %s" % protected_control_path)
			return
	right_panel.close_panel()
	await process_frame

	if not task_panel.open_drawer() or not task_panel.is_drawer_open():
		_fail("Daily task drawer could not open for exclusivity test")
		return
	manager.queue_event(&"first_lamb_shelter")
	await process_frame
	await process_frame
	if right_panel.get_mode() != &"story" or task_panel.is_drawer_open():
		_fail("Story panel did not take priority over the task drawer")
		return
	right_panel.close_panel()
	await process_frame

	if not time_controls.set_speed(2.0):
		_fail("Could not select 2x before opening story")
		return
	manager.queue_event(&"day_2_capacity")
	await process_frame
	await process_frame
	if not paused or not is_equal_approx(time_controls.get_selected_speed(), 0.0):
		_fail("Story panel did not pause the game")
		return
	right_panel.close_panel()
	await process_frame
	if paused or not is_equal_approx(time_controls.get_selected_speed(), 2.0):
		_fail("Closing story did not restore the previous game speed")
		return

	print("PASS: one-shot story queue, valid day-4 target, report priority, shared drawer, and speed restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
