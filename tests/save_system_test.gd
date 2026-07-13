extends SceneTree

const TEST_SAVE_PATH := "user://save_v1_test.json"

var save_manager: Node


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	save_manager = root.get_node("SaveManager")
	save_manager.set_save_path_for_tests(TEST_SAVE_PATH)
	save_manager.delete_save()
	var source: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(source)
	await process_frame
	await process_frame
	var hud: Control = source.get_node("HUD/TopHUD")
	var controller: Node = source.get_node("BuildController")
	var medical: Control = source.get_node("HUD/MedicalMenu")
	var tasks: Node = source.get_node("DailyTaskManager")
	var market: Node = source.get_node("MarketOrderManager")
	var story: Node = source.get_node("StoryEventManager")
	var commission: Control = source.get_node("HUD/NewbieCommission")
	var report: Control = source.get_node("HUD/DailyReport")
	var time_controls: Control = source.get_node("HUD/TimeControls")

	if not source.add_land_chunk(Vector2i.RIGHT, source.LAND_TYPE_HOMESTEAD):
		_fail("Could not prepare homestead land for save test")
		return
	hud.add_money(2000)
	if not controller.try_place_building(&"shepherd_house", Vector2(1024, 350)):
		_fail("Could not prepare a building for save test")
		return
	if not controller.try_place_fence(Vector2(880, 190), Vector2(1160, 510)):
		_fail("Could not prepare a fence for save test")
		return
	hud.restore_save_data({
		"money": 2345, "day": 5, "day_progress": 0.62,
		"daily_income": 170, "daily_expense": 96,
	})
	medical.restore_save_data({"medicine_inventory": 3})
	commission.restore_save_data({"sufficient_grass_days": 4, "finished": false, "succeeded": false})
	report.restore_save_data({
		"bought_today": 2, "sold_today": 1, "born_today": 1,
		"normal_sale_income_today": 320, "order_income_today": 420, "expired_orders_today": 1,
	})
	var expected_market_price: int = market.get_normal_market_price()
	var expected_market_order_id: String = market.get_orders()[0].id
	var first_task: Dictionary = tasks.get_tasks()[0]
	tasks.accept_task(first_task.id)
	var expected_task_state: int = int(tasks.get_task(first_task.id).state)
	story.queue_event(&"first_land_expansion")
	var first_sheep: Node = source.sheep_group.get_child(0)
	var sheep_data: Dictionary = first_sheep.get_save_data()
	sheep_data.name = "存档羊"
	sheep_data.sex = "female"
	sheep_data.age_days = 23
	sheep_data.sick = true
	sheep_data.hunger = 47.0
	sheep_data.pregnant = true
	sheep_data.pregnancy_days = 2
	sheep_data.expected_lamb_count = 4
	sheep_data.breeding_cooldown_days = 3
	sheep_data.position = [690.0, 320.0]
	first_sheep.restore_save_data(sheep_data)
	var first_grass: Node = source._get_world_grass()[0]
	var saved_grass_position: Vector2 = first_grass.global_position
	first_grass.restore_save_data({"growth_state": first_grass.GrowthState.SPROUT, "growth_time": 11.5})
	time_controls.set_speed(4.0)
	if not save_manager.save_game(source) or not FileAccess.file_exists(TEST_SAVE_PATH):
		_fail("SaveManager did not create a valid save")
		return

	root.remove_child(source)
	source.free()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await process_frame
	if not save_manager.load_game_into(restored):
		_fail("SaveManager could not restore a valid save")
		return
	await process_frame
	var restored_hud: Control = restored.get_node("HUD/TopHUD")
	var restored_controller: Node = restored.get_node("BuildController")
	var restored_medical: Control = restored.get_node("HUD/MedicalMenu")
	var restored_tasks: Node = restored.get_node("DailyTaskManager")
	var restored_market: Node = restored.get_node("MarketOrderManager")
	var restored_story: Node = restored.get_node("StoryEventManager")
	var restored_sheep: Node = restored.sheep_group.get_child(0)
	if restored_hud.get_money() != 2345 or restored_hud.get_day() != 5 or absf(restored_hud.day_progress - 0.62) > 0.01:
		_fail("Money, day, or day progress did not survive the round trip")
		return
	if restored.get_land_type(Vector2i.RIGHT) != restored.LAND_TYPE_HOMESTEAD:
		_fail("Land coordinates or land type did not survive the round trip")
		return
	if restored_controller.get_save_data().size() != 2 or restored.get_grazing_areas().size() != 1:
		_fail("Building or fence data did not survive the round trip")
		return
	if restored_medical.get_medicine_inventory() != 3:
		_fail("Medicine inventory did not survive the round trip")
		return
	if (
		restored_market.get_normal_market_price() != expected_market_price
		or restored_market.get_order(expected_market_order_id).is_empty()
	):
		_fail("Market price or active orders did not survive the full save round trip")
		return
	var restored_report: Control = restored.get_node("HUD/DailyReport")
	if (
		restored_report.normal_sale_income_today != 320
		or restored_report.order_income_today != 420
		or restored_report.expired_orders_today != 1
	):
		_fail("Daily market report counters did not survive the save round trip")
		return
	if (
		restored_sheep.get_sheep_name() != "存档羊"
		or restored_sheep.get_sex() != restored_sheep.SEX_FEMALE
		or restored_sheep.get_age_days() != 23
		or restored_sheep.is_healthy()
		or restored_sheep.get_hunger_percent() != 47
		or not restored_sheep.is_pregnant()
		or restored_sheep.get_pregnancy_days() != 2
		or restored_sheep.get_expected_lamb_count() != 4
		or restored_sheep.get_breeding_cooldown_days() != 3
	):
		_fail("Sheep identity, health, hunger, or breeding data did not survive the round trip")
		return
	var restored_grass: Node = null
	for grass in restored._get_world_grass():
		if grass.global_position.distance_to(saved_grass_position) < 0.1:
			restored_grass = grass
			break
	if not restored_grass or restored_grass.growth_state != restored_grass.GrowthState.SPROUT or absf(restored_grass.growth_time - 11.5) > 0.1:
		_fail("Grass growth data did not survive the round trip")
		return
	var restored_task: Dictionary = restored_tasks.get_task(first_task.id)
	if restored_task.is_empty() or int(restored_task.state) != expected_task_state:
		_fail("Daily task state did not survive the round trip")
		return
	if not restored_story.is_event_fired(&"first_land_expansion"):
		_fail("Fired story events did not survive the round trip")
		return
	if not is_equal_approx(Engine.time_scale, 4.0):
		_fail("Selected time speed did not survive the round trip")
		return

	var system_menu: Control = restored.get_node("HUD/SystemMenu")
	if not system_menu.open_menu() or not paused:
		_fail("System menu did not pause the game")
		return
	if not system_menu.save_game():
		_fail("System menu could not save the game")
		return
	system_menu.close_menu()
	if paused or not is_equal_approx(Engine.time_scale, 4.0):
		_fail("System menu did not restore the previous game speed")
		return

	save_manager.delete_save()
	var broken := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	broken.store_string("{broken json")
	broken.close()
	if save_manager.has_valid_save() or save_manager.load_game_into(restored):
		_fail("Corrupted save data was treated as valid")
		return
	save_manager.delete_save()
	save_manager.reset_save_path()
	Engine.time_scale = 1.0
	paused = false
	print("PASS: save round trip, world reconstruction, corruption handling, and system menu")
	quit(0)


func _fail(message: String) -> void:
	if save_manager:
		save_manager.delete_save()
		save_manager.reset_save_path()
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
