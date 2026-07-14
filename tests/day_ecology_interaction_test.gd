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
	var command_bar: Control = scene.get_node("HUD/DogCommandBar")
	var info_panel: Control = scene.get_node("HUD/ContextInfoPanel")
	var building_panel: Control = scene.get_node("HUD/BuildingInteractionPanel")
	var routine: Node = scene.get_node("DayRoutineManager")
	var story: Node = scene.get_node("StoryEventManager")
	var tasks: Node = scene.get_node("DailyTaskManager")
	var commission: Control = scene.get_node("HUD/NewbieCommission")

	if hud.get_money() != 20000 or tasks.get_tasks().size() != 2:
		_fail("New economy did not start with 20000 coins and two daily tasks")
		return
	if not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD):
		_fail("Could not add the first clear interaction land")
		return
	if not controller.try_place_building(&"dog_house", Vector2(1024, 350)):
		_fail("First ten-day cycle did not allow one dog house")
		return
	await process_frame
	if dogs.get_active_dog_count() != 1 or command_bar.visible:
		_fail("One dog house did not create exactly one dog or command bar started visible")
		return
	if controller.try_place_building(&"dog_house", Vector2(1100, 470)):
		_fail("Day one allowed more than one dog house")
		return

	hud.restore_save_data({"money": hud.get_money(), "day": 11, "day_progress": 0.55})
	if not scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD):
		_fail("Could not add the second clear interaction land")
		return
	if not controller.try_place_building(&"dog_house", Vector2(600, 700)):
		_fail("Second ten-day cycle did not unlock a second dog house")
		return
	await process_frame
	await physics_frame
	if dogs.get_active_dog_count() != 2:
		_fail("Two dog houses did not create two independent dogs")
		return
	var second_dog: AnimatedSprite2D = dogs.get_dogs()[1]
	scene.select_entity(second_dog)
	if not command_bar.visible or command_bar.dog != second_dog or "牧羊犬 2" not in info_panel.title_label.text:
		_fail("Click selection did not bind the command and information bars to dog two")
		return

	scene.select_entity(player)
	var player_start := player.global_position
	if not player.set_move_target(Vector2(760, 500)):
		_fail("Selected shepherd rejected a land click target")
		return
	for step in 30:
		player._physics_process(0.1)
	if player.global_position.distance_to(Vector2(760, 500)) >= player_start.distance_to(Vector2(760, 500)):
		_fail("Click-to-move did not move the shepherd toward the selected point")
		return
	if command_bar.visible:
		_fail("Selecting the shepherd did not hide the dog command bar")
		return

	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Could not prepare a fence for gate and routine interaction")
		return
	var fence: Node2D = controller.get_fence_roots()[0]
	var gate: Node2D = fence.get_node("Gate")
	var gate_sprite: Sprite2D = gate.get_node("Sprite")
	if not gate_sprite.texture.resource_path.ends_with("fence_gate.png"):
		_fail("Fence gate still uses the ordinary fence sprite")
		return
	if not controller.toggle_gate_at(gate.global_position + Vector2(18, 0)) or not bool(fence.get_meta("gate_open", false)):
		_fail("Clicking the visible gate did not open it")
		return
	if not controller.toggle_gate_at(gate.global_position + Vector2(18, 0)) or bool(fence.get_meta("gate_open", false)):
		_fail("Clicking the visible gate a second time did not close it")
		return

	if not controller.try_place_building(&"shepherd_house", Vector2(760, 700)):
		_fail("Could not prepare a shepherd house for night interaction")
		return
	var shepherd_house: Node2D = controller.get_buildings_by_type(&"shepherd_house")[0]
	hud.day_progress = 0.90
	hud._update_phase()
	scene.select_entity(shepherd_house)
	if not building_panel.visible or building_panel.rest_button.disabled:
		_fail("Night building click did not open an enabled rest panel")
		return
	var rest_result: Dictionary = routine.assign_building_rest(shepherd_house)
	if not rest_result.success or not player.going_to_rest:
		_fail("Shepherd house did not assign the shepherd to rest")
		return
	routine._on_day_changed(12)
	if player.resting or not player.visible:
		_fail("Dawn did not wake the shepherd")
		return

	hud.restore_save_data({"money": hud.get_money(), "day": 12, "day_progress": 0.75})
	routine.auto_roundup_day = 0
	routine._try_start_auto_roundup()
	if routine.auto_roundup_day != 12 or player.auto_roundup_fence != fence:
		_fail("Dusk did not start shepherd-assisted automatic roundup")
		return
	for dog in dogs.get_dogs():
		if dog.command_mode != dog.CommandMode.DRIVE or not dog.has_command_target:
			_fail("Automatic roundup did not assign all dogs to drive mode")
			return

	routine._try_discover_wolf_den()
	if not routine.wolf_den_found or not is_instance_valid(routine.wolf_den_node):
		_fail("Day-12 three-land pasture did not discover the edge wolf den")
		return
	if not story.is_event_fired(&"wolf_den_discovered"):
		_fail("Wolf den discovery did not queue its one-time warning story")
		return
	commission.restore_save_data({"sufficient_grass_days": 7, "finished": true, "succeeded": true})
	if not commission.visible or "牧场 Lv." not in commission.title_label.text:
		_fail("Finished seven-day commission was not replaced by pasture progression")
		return

	var day_one_pool: Array[Dictionary] = tasks._build_feasible_pool(1)
	var day_fifteen_pool: Array[Dictionary] = tasks._build_feasible_pool(15)
	var day_one_buy := day_one_pool.filter(func(task: Dictionary) -> bool: return task.type == &"buy_lamb")
	var day_fifteen_buy := day_fifteen_pool.filter(func(task: Dictionary) -> bool: return task.type == &"buy_lamb")
	if day_one_buy.is_empty() or day_fifteen_buy.is_empty() or day_fifteen_buy[0].target <= day_one_buy[0].target or day_fifteen_buy[0].reward <= day_one_buy[0].reward:
		_fail("Later daily tasks did not become harder and more rewarding")
		return

	var save_data: Dictionary = scene.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("New day-ecology state could not be restored")
		return
	if restored.get_node("DogManager").get_active_dog_count() != 2 or not restored.get_node("DayRoutineManager").wolf_den_found:
		_fail("Multiple dogs or wolf den state did not survive save restore")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: multi-dog cycles, selection UI, click movement, gate clicks, night rest, dusk routine, wolf story, tasks, commission, and save")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
