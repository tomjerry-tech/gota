extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var hud: Control = scene.get_node("HUD/TopHUD")
	var controller: Node = scene.get_node("BuildController")
	var dogs: Node = scene.get_node("DogManager")
	var routine: Node = scene.get_node("DayRoutineManager")
	var report: Control = scene.get_node("HUD/DailyReport")
	var story: Node = scene.get_node("StoryEventManager")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.current_event = {}

	if (
		not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
		or not scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD)
	):
		_fail("Could not prepare three land chunks for wolf discovery")
		return
	hud.restore_save_data({"money": 20000, "day": 12, "day_progress": 0.90})
	routine._try_discover_wolf_den()
	if not routine.wolf_den_found or routine.wolf_den_discovered_day != 12:
		_fail("Wolf den discovery did not record its discovery day")
		return

	var money_before_breach: int = hud.get_money()
	report.show_daily_report(12)
	var breach: Dictionary = routine.last_wolf_risk_result
	if (
		breach.get("outcome", "") != "breach"
		or int(breach.get("score", -1)) != 0
		or int(breach.get("strayed_count", 0)) != 2
		or int(breach.get("money_loss", 0)) != 360
		or hud.get_money() != money_before_breach - 360
	):
		_fail("Unprotected pasture did not produce the expected one-time breach result")
		return
	if "夜间防护" not in report.report_text.text or "2 只羊走散" not in report.report_text.text:
		_fail("Daily report did not explain the wolf breach")
		return
	var money_after_breach: int = hud.get_money()
	routine.evaluate_wolf_night_risk(12)
	if hud.get_money() != money_after_breach:
		_fail("Repeated evaluation charged the same wolf incident twice")
		return

	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Could not prepare a closed enclosure for defense scoring")
		return
	if not controller.try_place_building(&"dog_house", Vector2(960, 300)):
		_fail("Could not prepare a dog house for defense scoring")
		return
	dogs.sync_dogs()
	if dogs.get_active_dog_count() != 1:
		_fail("Dog house did not contribute one active guard dog")
		return
	var fence: Node2D = controller.get_fence_roots()[0]
	var enclosure: Rect2 = fence.get_meta("grazing_rect") as Rect2
	var center := enclosure.get_center()
	for index in scene.sheep_group.get_child_count():
		scene.sheep_group.get_child(index).global_position = center + Vector2((index % 3 - 1) * 8, (index / 3 - 0.5) * 10)
	controller.set_gate_open(fence, false)
	hud.restore_save_data({"money": hud.get_money(), "day": 13, "day_progress": 0.90})
	var money_before_safe: int = hud.get_money()
	var safe: Dictionary = routine.evaluate_wolf_night_risk(13)
	if safe.get("outcome", "") != "safe" or int(safe.get("score", 0)) != 90 or hud.get_money() != money_before_safe:
		_fail("Closed enclosure and one dog did not produce a safe 90-point result")
		return

	for index in scene.sheep_group.get_child_count():
		if index < 3:
			scene.sheep_group.get_child(index).global_position = center + Vector2((index - 1) * 8, 0)
		else:
			scene.sheep_group.get_child(index).global_position = Vector2(930 + index * 8, 410)
	hud.restore_save_data({"money": hud.get_money(), "day": 14, "day_progress": 0.90})
	var money_before_warning: int = hud.get_money()
	var warning: Dictionary = routine.evaluate_wolf_night_risk(14)
	if (
		warning.get("outcome", "") != "warning"
		or int(warning.get("score", 0)) != 60
		or int(warning.get("frightened_count", 0)) != 1
		or hud.get_money() != money_before_warning
	):
		_fail("Partial enclosure did not produce a no-loss warning result")
		return

	var save_data: Dictionary = scene.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Wolf risk state could not be restored")
		return
	var restored_hud: Control = restored.get_node("HUD/TopHUD")
	var restored_routine: Node = restored.get_node("DayRoutineManager")
	var restored_money: int = restored_hud.get_money()
	var restored_result: Dictionary = restored_routine.evaluate_wolf_night_risk(14)
	if (
		int(restored_result.get("day", -1)) != 14
		or restored_result.get("outcome", "") != "warning"
		or restored_hud.get_money() != restored_money
	):
		_fail("Restored wolf result was missing or charged a second time")
		return

	if report.visible:
		report.close_report()
	Engine.time_scale = 1.0
	paused = false
	print("PASS: wolf defense score, safe/warning/breach outcomes, report, one-time loss, and save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
