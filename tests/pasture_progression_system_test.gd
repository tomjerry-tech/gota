extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var hud: Control = scene.get_node("HUD/TopHUD")
	var progression: Node = scene.get_node("PastureProgressionManager")
	var commission: Control = scene.get_node("HUD/NewbieCommission")
	var right_panel: Control = scene.get_node("HUD/RightSidePanel")
	var controller: Node = scene.get_node("BuildController")

	if progression.get_level() != 1 or progression.get_reputation() != 0 or progression.get_current_chapter() != 1:
		_fail("Pasture progression did not start at level one, zero reputation, and chapter one")
		return
	if progression.get_chapter_objectives().size() != 3:
		_fail("Chapter one did not expose exactly three concrete objectives")
		return

	commission.restore_save_data({"sufficient_grass_days": 7, "finished": true, "succeeded": true})
	hud.restore_save_data({"money": 20000, "day": 8, "day_progress": 0.25})
	commission._refresh()
	if not commission.visible or "牧场 Lv.1" not in commission.title_label.text or "第 1 章" not in commission.adult_goal_label.text:
		_fail("Chapter summary did not replace the finished seven-day commission")
		return
	if not right_panel.show_records(progression) or right_panel.get_mode() != &"records":
		_fail("Pasture records could not open in the shared right-side panel")
		return
	if "牧场档案" not in right_panel.title_label.text or right_panel.content_root.get_child_count() < 4:
		_fail("Pasture records did not show progression and achievement content")
		return
	right_panel.close_panel()

	progression.add_reputation(100, &"test")
	if progression.get_level() != 2 or progression.get_reputation() != 100:
		_fail("Reputation threshold did not raise the pasture to level two")
		return
	progression.record_stat(&"orders_completed", 1)
	if progression.get_stat(&"orders_completed") != 1 or progression.get_unlocked_achievement_count() < 1:
		_fail("Business statistics or the first-order achievement did not update")
		return

	if not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD):
		_fail("Could not prepare chapter-one building space")
		return
	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Could not build the chapter-one fence")
		return
	if not controller.try_place_building(&"dog_house", Vector2(960, 300)):
		_fail("Could not build the chapter-one dog house")
		return
	scene.add_lambs(4)
	progression.evaluate_progress()
	if progression.get_current_chapter() != 2 or progression.get_stat(&"chapters_completed") != 1:
		_fail("Ten sheep, one fence, and one dog house did not complete chapter one")
		return

	var saved: Dictionary = progression.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	var restored_progression: Node = restored.get_node("PastureProgressionManager")
	restored_progression.restore_save_data(saved)
	if (
		restored_progression.get_level() != progression.get_level()
		or restored_progression.get_reputation() != progression.get_reputation()
		or restored_progression.get_current_chapter() != 2
		or restored_progression.get_stat(&"orders_completed") != 1
		or restored_progression.get_unlocked_achievement_count() != progression.get_unlocked_achievement_count()
	):
		_fail("Pasture level, chapter, statistics, or achievements did not survive save restore")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: pasture levels, five-chapter objectives, post-commission UI, achievements, records, and save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
