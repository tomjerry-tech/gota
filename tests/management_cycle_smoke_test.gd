extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var controller: Node2D = scene.get_node("BuildController")
	var hud: Control = scene.get_node("HUD/TopHUD")
	var time_controls: Control = scene.get_node("HUD/TimeControls")
	var commission: Control = scene.get_node("HUD/NewbieCommission")
	var report: Control = scene.get_node("HUD/DailyReport")
	var sheep_group: Node = scene.get_node("Island/Sheep")

	if scene.get_sheep_capacity() != 10 or scene.get_available_sheep_capacity() != 4:
		_fail("Base land does not provide 10 pasture capacity")
		return
	if time_controls.buttons.size() != 4 or time_controls.buttons.any(func(button: Button) -> bool: return button.disabled):
		_fail("All four time controls should be available from the start")
		return
	if (
		time_controls.get_node_or_null("Ribbon") == null
		or time_controls.get_node("Ribbon/Title").text != "时间"
		or not time_controls.buttons[0].get_theme_stylebox("normal") is StyleBoxTexture
		or time_controls.buttons[2].get_node_or_null("LockBadge") != null
		or time_controls.buttons[3].get_node_or_null("LockBadge") != null
	):
		_fail("Time controls are missing the Tiny Swords visuals or still show lock badges")
		return
	if not time_controls.set_speed(4.0) or not is_equal_approx(Engine.time_scale, 4.0) or not time_controls.buttons[3].button_pressed:
		_fail("4x speed was not immediately selectable or highlighted")
		return
	time_controls.set_speed(1.0)

	if not controller.try_place_building(&"lamb_shelter", Vector2(720, 500)):
		_fail("Lamb shelter could not be placed for capacity test")
		return
	if scene.get_sheep_capacity() != 14 or not is_equal_approx(scene.get_lamb_sickness_chance(), 0.04):
		_fail("Lamb shelter did not add capacity and halve sickness risk")
		return
	if not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD):
		_fail("Test setup could not add homestead land")
		return

	hud.add_money(1000)
	if not controller.try_place_building(&"dog_house", Vector2(960, 300)):
		_fail("Dog house could not be placed for recall test")
		return
	if not controller.try_place_building(&"shepherd_house", Vector2(1080, 400)):
		_fail("Shepherd house could not be placed")
		return
	await process_frame
	if time_controls.buttons[2].disabled or time_controls.buttons[3].disabled:
		_fail("Building a shepherd house unexpectedly disabled fast speeds")
		return
	if not time_controls.set_speed(2.0) or not is_equal_approx(Engine.time_scale, 2.0):
		_fail("2x speed could not be activated")
		return
	if not time_controls.set_speed(0.0) or not paused:
		_fail("Pause control did not pause the scene tree")
		return
	if not time_controls.set_speed(1.0) or paused or not is_equal_approx(Engine.time_scale, 1.0):
		_fail("1x control did not resume the scene tree")
		return

	var first_sheep: Node2D = sheep_group.get_child(0)
	first_sheep.global_position = Vector2.ZERO
	if scene.recall_stray_sheep() != 1 or not scene.is_point_on_land(first_sheep.global_position, 18.0):
		_fail("Dog house recall did not return a stray sheep to owned land")
		return

	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Fence could not be placed for grazing-area test")
		return
	var grazing_areas: Array[Rect2] = scene.get_grazing_areas()
	if grazing_areas.size() != 1:
		_fail("Fence did not register one grazing area")
		return
	var test_random := RandomNumberGenerator.new()
	test_random.seed = 42
	var grazing_target: Vector2 = scene.get_random_land_position(test_random, grazing_areas[0].get_center())
	if not grazing_areas[0].has_point(grazing_target):
		_fail("Fenced sheep wander target escaped the grazing area")
		return

	for new_day in range(2, 9):
		commission._on_day_changed(new_day)
	if not commission.finished or not commission.succeeded:
		_fail("Seven-day commission did not complete with healthy adults and sufficient grass")
		return

	report.show_daily_report(1)
	if not report.visible or not paused:
		_fail("Daily report did not open and pause the game")
		return
	if "羊群变化" not in report.report_text.text or "草场情况" not in report.report_text.text or "收入支出" not in report.report_text.text or "风险提醒" not in report.report_text.text:
		_fail("Daily report is missing required summary sections")
		return
	report.close_report()
	if paused:
		_fail("Closing the daily report did not resume the game")
		return

	print("PASS: capacity, building effects, grazing area, time controls, commission, and daily report")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
