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
	var player: AnimatedSprite2D = scene.get_node("Island/Shepherd")
	var routine: Node = scene.get_node("DayRoutineManager")
	var tasks: Node = scene.get_node("DailyTaskManager")
	var story: Node = scene.get_node("StoryEventManager")
	var panel: Control = scene.get_node("HUD/BuildingInteractionPanel")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.fired_events.clear()
	story.current_event = {}

	if (
		not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
		or not scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD)
	):
		_fail("Could not prepare clear land for upgrade testing")
		return
	if (
		not controller.try_place_building(&"dog_house", Vector2(910, 250))
		or not controller.try_place_building(&"lamb_shelter", Vector2(1060, 380))
		or not controller.try_place_building(&"shepherd_house", Vector2(640, 700))
	):
		_fail("Could not place all three upgradeable houses")
		return
	dogs.sync_dogs()
	var dog_house: Node2D = controller.get_buildings_by_type(&"dog_house")[0]
	var shelter: Node2D = controller.get_buildings_by_type(&"lamb_shelter")[0]
	var shepherd_house: Node2D = controller.get_buildings_by_type(&"shepherd_house")[0]

	hud.restore_save_data({"money": hud.get_money(), "day": 19, "day_progress": 0.55})
	var locked_money: int = hud.get_money()
	var locked_result: Dictionary = controller.try_upgrade_building(shelter)
	if locked_result.success or hud.get_money() != locked_money or controller.get_building_level(shelter) != 1:
		_fail("Building upgrade unlocked before day 20 or charged money while locked")
		return

	hud.restore_save_data({"money": hud.get_money(), "day": 20, "day_progress": 0.55})
	story._on_day_changed(20)
	if not story.is_event_fired(&"day_20_building_upgrades"):
		_fail("Day-20 old-shepherd letter did not unlock its story")
		return
	var day_twenty_pool: Array[Dictionary] = tasks._build_feasible_pool(20)
	if not day_twenty_pool.any(func(task: Dictionary) -> bool: return task.type == &"upgrade_building"):
		_fail("Day-20 feasible task pool did not include building upgrades")
		return
	var upgrade_task: Dictionary = tasks._make_task(&"upgrade_building", "整修牧场建筑", "升级一座已有小屋", 1, 160)
	upgrade_task.id = "upgrade_test"
	upgrade_task.state = tasks.TaskState.ACTIVE
	tasks.tasks.clear()
	tasks.tasks.append(upgrade_task)

	var capacity_before: int = scene.get_sheep_capacity()
	var money_before_shelter: int = hud.get_money()
	var shelter_level_two: Dictionary = controller.try_upgrade_building(shelter)
	if (
		not shelter_level_two.success
		or hud.get_money() != money_before_shelter - 600
		or scene.get_sheep_capacity() != capacity_before + 2
		or not is_equal_approx(scene.get_lamb_sickness_chance(), 0.028)
		or int(tasks.get_task("upgrade_test").state) != tasks.TaskState.COMPLETED
		or not story.is_event_fired(&"first_building_upgrade")
	):
		_fail("Level-two lamb shelter did not apply cost, capacity, health, task, or story effects")
		return
	var shelter_badge := shelter.get_node_or_null("LevelBadge") as Label
	if not shelter_badge or not shelter_badge.visible or shelter_badge.text != "Lv.2":
		_fail("Upgraded building did not show its level badge")
		return
	if not controller.try_upgrade_building(shelter).success:
		_fail("Lamb shelter could not reach level three")
		return
	if scene.get_sheep_capacity() != capacity_before + 4 or not is_equal_approx(scene.get_lamb_sickness_chance(), 0.02):
		_fail("Level-three lamb shelter effects are incorrect")
		return
	if controller.try_upgrade_building(shelter).success:
		_fail("Max-level shelter accepted a fourth upgrade")
		return

	if not controller.try_upgrade_building(dog_house).success or not controller.try_upgrade_building(dog_house).success:
		_fail("Dog house could not reach level three")
		return
	var dog: AnimatedSprite2D = dogs.get_dogs()[0]
	dog.consume_stamina(80.0)
	dogs.wake_all()
	if dog.get_stamina_percent() != 75 or dogs.get_total_night_defense_points() != 14:
		_fail("Level-three dog house did not improve dawn recovery and tired defense")
		return

	if not controller.try_upgrade_building(shepherd_house).success or not controller.try_upgrade_building(shepherd_house).success:
		_fail("Shepherd house could not reach level three")
		return
	player.consume_stamina(80.0)
	routine._on_day_changed(21)
	if player.get_stamina_percent() != 75 or not is_equal_approx(routine._get_auto_roundup_progress(), 0.64):
		_fail("Level-three shepherd house did not improve recovery and roundup timing")
		return

	panel.open_for_building(shelter)
	if "Lv.3" not in panel.level_label.text or not panel.upgrade_button.disabled or "最高等级" not in panel.upgrade_button.text:
		_fail("Building interaction panel did not show max-level state")
		return
	var save_data: Dictionary = scene.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Building levels could not be restored")
		return
	var restored_controller: Node = restored.get_node("BuildController")
	for item_id: StringName in [&"dog_house", &"shepherd_house", &"lamb_shelter"]:
		var restored_building: Node2D = restored_controller.get_buildings_by_type(item_id)[0]
		if restored_controller.get_building_level(restored_building) != 3 or not restored_building.get_node("LevelBadge").visible:
			_fail("Restored %s lost its level or badge" % item_id)
			return
	if restored.get_sheep_capacity() != scene.get_sheep_capacity():
		_fail("Restored shelter level lost its capacity effect")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: day-20 unlock, three house upgrades, costs, effects, badges, tasks, story, UI, and save")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
