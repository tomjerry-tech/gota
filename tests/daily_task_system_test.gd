extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var manager: Node = scene.get_node("DailyTaskManager")
	var controller: Node = scene.get_node("BuildController")
	var medical_menu: Control = scene.get_node("HUD/MedicalMenu")
	var top_hud: Control = scene.get_node("HUD/TopHUD")

	if manager.get_tasks().size() != 2:
		_fail("A day did not generate exactly two tasks")
		return
	var generated_types: Dictionary = {}
	for task in manager.get_tasks():
		if generated_types.has(task.type):
			_fail("Generated daily tasks are duplicated")
			return
		generated_types[task.type] = true
		if task.type == &"sell_adult" and task.target > scene.get_adult_sheep_count():
			_fail("Generated sale task is not currently feasible")
			return
		if task.type == &"buy_lamb" and task.target > scene.get_available_sheep_capacity():
			_fail("Generated purchase task exceeds available capacity")
			return
		if task.type == &"treat_sheep" and scene.get_sick_sheep_count() == 0:
			_fail("Generated treatment task without a sick sheep")
			return

	var signal_tasks: Array[Dictionary] = [
		_task("buy", &"buy_lamb", manager.TaskState.AVAILABLE),
		_task("sell", &"sell_adult", manager.TaskState.AVAILABLE),
		_task("house", &"build_house", manager.TaskState.AVAILABLE, &"dog_house"),
		_task("fence", &"build_fence", manager.TaskState.AVAILABLE),
		_task("land", &"expand_land", manager.TaskState.AVAILABLE),
		_task("treat", &"treat_sheep", manager.TaskState.AVAILABLE),
	]
	manager.tasks = signal_tasks

	if not scene.add_lamb() or manager.get_task("buy").progress != 0:
		_fail("Buying before accepting incorrectly advanced a task")
		return
	for task_id in ["buy", "sell", "house", "fence", "land", "treat"]:
		if not manager.accept_task(task_id):
			_fail("A prepared task could not be accepted: %s" % task_id)
			return

	scene.add_lamb()
	if manager.get_task("buy").state != manager.TaskState.COMPLETED:
		_fail("Main.sheep_added did not advance the accepted purchase task")
		return
	if scene.sell_oldest_adults(1) != 1 or manager.get_task("sell").state != manager.TaskState.COMPLETED:
		_fail("Main.sheep_sold did not advance the accepted sale task")
		return
	await process_frame
	if not controller.try_place_building(&"dog_house", Vector2(720, 480)):
		_fail("Task test could not place the target building")
		return
	if manager.get_task("house").state != manager.TaskState.COMPLETED:
		_fail("building_placed did not advance the specified-house task")
		return
	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Task test could not place a fence")
		return
	if manager.get_task("fence").state != manager.TaskState.COMPLETED:
		_fail("fence_placed did not advance the fence task")
		return
	controller.select_build_item(&"land_expand", {"price": 450})
	if not controller.try_expand_land_at(Vector2(1024, 350)):
		_fail("Task test could not expand land")
		return
	if manager.get_task("land").state != manager.TaskState.COMPLETED:
		_fail("land_expanded did not advance the expansion task")
		return
	var sick_sheep: Node = scene.get_node("Island/Sheep").get_child(0)
	sick_sheep.make_sick()
	if not medical_menu.buy_medicine() or not medical_menu.treat_sheep(sick_sheep):
		_fail("Task test could not complete a treatment")
		return
	if manager.get_task("treat").state != manager.TaskState.COMPLETED:
		_fail("sheep_treated did not advance the treatment task")
		return

	var money_before_reward: int = top_hud.get_money()
	if not manager.claim_task("buy") or top_hud.get_money() != money_before_reward + 80:
		_fail("Completed task reward was not paid")
		return
	if manager.claim_task("buy") or top_hud.get_money() != money_before_reward + 80:
		_fail("A task reward could be claimed more than once")
		return
	var previous_ids: Array = manager.get_tasks().map(func(task: Dictionary) -> String: return task.id)
	manager.regenerate_tasks(2)
	if manager.get_tasks().size() != 2:
		_fail("New date did not replace old tasks with two new tasks")
		return
	if manager.get_tasks().any(func(task: Dictionary) -> bool: return previous_ids.has(task.id)):
		_fail("Old tasks survived the date change")
		return

	print("PASS: feasible daily generation, acceptance boundary, signal progress, expiry, and one-time rewards")
	quit(0)


func _task(id: String, type: StringName, state: int, item_id: StringName = &"") -> Dictionary:
	return {
		"id": id,
		"type": type,
		"title": id,
		"description": id,
		"target": 1,
		"progress": 0,
		"reward": 80,
		"state": state,
		"item_id": item_id,
	}


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
