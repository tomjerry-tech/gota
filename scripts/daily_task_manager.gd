extends Node

signal tasks_changed
signal task_reward_claimed(task_id: String, reward: int)

enum TaskState {
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	CLAIMED,
}

const TASKS_PER_DAY := 2

const LAND_EXPANSION_PRICE := 450
const MINIMUM_FENCE_PRICE := 32
const HOUSE_DATA := {
	&"dog_house": {"name": "牧羊犬小屋", "price": 180, "reward": 100},
	&"shepherd_house": {"name": "牧民小屋", "price": 320, "reward": 140},
	&"lamb_shelter": {"name": "小羊棚", "price": 240, "reward": 120},
}

@onready var world_controller: Node = get_parent()
@onready var top_hud: Control = get_node("../HUD/TopHUD")
@onready var build_controller: Node = get_node("../BuildController")
@onready var medical_menu: Control = get_node("../HUD/MedicalMenu")
@onready var dog_manager: Node = get_node("../DogManager")
@onready var roundup_manager: Control = get_node("../HUD/RoundupStatus")

var tasks: Array[Dictionary] = []
var task_day := 0


func _ready() -> void:
	world_controller.sheep_added.connect(_on_sheep_added)
	world_controller.sheep_sold.connect(_on_sheep_sold)
	top_hud.day_changed.connect(_on_day_changed)
	build_controller.building_placed.connect(_on_building_placed)
	build_controller.building_upgraded.connect(_on_building_upgraded)
	build_controller.fence_placed.connect(_on_fence_placed)
	build_controller.land_expanded.connect(_on_land_expanded)
	medical_menu.sheep_treated.connect(_on_sheep_treated)
	roundup_manager.dog_roundup_succeeded.connect(_on_dog_roundup_succeeded)
	call_deferred("_generate_tasks", top_hud.get_day())


func get_tasks() -> Array[Dictionary]:
	return tasks


func get_task(task_id: String) -> Dictionary:
	for task in tasks:
		if task.id == task_id:
			return task
	return {}


func get_finished_count() -> int:
	return tasks.filter(
		func(task: Dictionary) -> bool:
			return task.state in [TaskState.COMPLETED, TaskState.CLAIMED]
	).size()


func has_claimable_reward() -> bool:
	return tasks.any(func(task: Dictionary) -> bool: return task.state == TaskState.COMPLETED)


func get_save_data() -> Dictionary:
	var saved_tasks: Array[Dictionary] = []
	for task in tasks:
		var saved_task := task.duplicate(true)
		saved_task.type = String(task.type)
		saved_task.item_id = String(task.get("item_id", &""))
		saved_tasks.append(saved_task)
	return {"task_day": task_day, "tasks": saved_tasks}


func restore_save_data(data: Dictionary) -> void:
	task_day = maxi(1, int(data.get("task_day", top_hud.get_day())))
	tasks.clear()
	var saved_tasks: Variant = data.get("tasks", [])
	if saved_tasks is Array:
		for value in saved_tasks:
			if value is not Dictionary:
				continue
			var task := (value as Dictionary).duplicate(true)
			task.type = StringName(String(task.get("type", "")))
			task.item_id = StringName(String(task.get("item_id", "")))
			task.state = clampi(int(task.get("state", TaskState.AVAILABLE)), TaskState.AVAILABLE, TaskState.CLAIMED)
			task.progress = maxi(0, int(task.get("progress", 0)))
			task.target = maxi(1, int(task.get("target", 1)))
			task.reward = maxi(0, int(task.get("reward", 0)))
			tasks.append(task)
	if tasks.is_empty():
		_generate_tasks(top_hud.get_day())
	else:
		tasks_changed.emit()


func accept_task(task_id: String) -> bool:
	var task := get_task(task_id)
	if task.is_empty() or task.state != TaskState.AVAILABLE:
		return false
	task.state = TaskState.ACTIVE
	_evaluate_condition_task(task)
	tasks_changed.emit()
	return true


func claim_task(task_id: String) -> bool:
	var task := get_task(task_id)
	if task.is_empty() or task.state != TaskState.COMPLETED:
		return false
	task.state = TaskState.CLAIMED
	top_hud.add_money(task.reward)
	task_reward_claimed.emit(task.id, task.reward)
	tasks_changed.emit()
	return true


func regenerate_tasks(day: int) -> void:
	_generate_tasks(day)


func _generate_tasks(day: int) -> void:
	task_day = day
	tasks.clear()
	var pool := _build_feasible_pool(day)
	var random := RandomNumberGenerator.new()
	random.seed = day * 104729 + world_controller.get_sheep_count() * 97 + top_hud.get_money()
	while tasks.size() < TASKS_PER_DAY and not pool.is_empty():
		var index := random.randi_range(0, pool.size() - 1)
		var task: Dictionary = pool.pop_at(index)
		task.id = "day_%d_%s" % [day, task.type]
		tasks.append(task)
	if tasks.size() < TASKS_PER_DAY:
		push_warning("当前牧场状态只能生成 %d 个可完成的每日任务" % tasks.size())
	tasks_changed.emit()


func _build_feasible_pool(day: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var difficulty := floori(float(day - 1) / 7.0)
	var money: int = top_hud.get_money()
	var capacity: int = world_controller.get_available_sheep_capacity()
	var buy_limit := mini(mini(3, capacity), money / 200)
	if buy_limit >= 1:
		var quantity := mini(buy_limit, 1 + difficulty)
		pool.append(_make_task(
			&"buy_lamb", "购买幼羊", "购买 %d 只幼羊" % quantity,
			quantity, _scaled_reward(70 + quantity * 20, difficulty)
		))
	var adult_count: int = world_controller.get_sellable_adult_count()
	if adult_count >= 1:
		var quantity := mini(mini(3, 1 + difficulty), adult_count)
		pool.append(_make_task(
			&"sell_adult", "出售成年羊", "出售 %d 只成年羊" % quantity,
			quantity, _scaled_reward(70 + quantity * 25, difficulty)
		))

	var feasible_houses: Array[StringName] = []
	for item_id: StringName in HOUSE_DATA:
		if item_id == &"dog_house" and world_controller.get_building_count(item_id) >= build_controller.get_allowed_dog_house_count():
			continue
		if money >= int(HOUSE_DATA[item_id].price):
			feasible_houses.append(item_id)
	if not feasible_houses.is_empty():
		var house_id := feasible_houses[day % feasible_houses.size()]
		var house: Dictionary = HOUSE_DATA[house_id]
		var house_task := _make_task(
			&"build_house", "建造指定小屋", "建造 1 座%s" % house.name,
			1, _scaled_reward(house.reward, difficulty)
		)
		house_task.item_id = house_id
		house_task.id_suffix = String(house_id)
		pool.append(house_task)

	var fence_target := mini(2, 1 + floori(float(difficulty) / 2.0))
	if money >= MINIMUM_FENCE_PRICE * fence_target:
		pool.append(_make_task(
			&"build_fence", "圈定放牧区", "建造 %d 圈木围栏" % fence_target,
			fence_target, _scaled_reward(80 + (fence_target - 1) * 50, difficulty)
		))
	if money >= LAND_EXPANSION_PRICE:
		pool.append(_make_task(&"expand_land", "扩充土地", "扩充一块新土地", 1, _scaled_reward(180, difficulty)))
	if world_controller.get_sick_sheep_count() > 0:
		var treatment_target := mini(1 + floori(float(difficulty) / 2.0), world_controller.get_sick_sheep_count())
		pool.append(_make_task(
			&"treat_sheep", "照料病羊", "治疗 %d 只生病的羊" % treatment_target,
			treatment_target, _scaled_reward(100 + (treatment_target - 1) * 40, difficulty)
		))
	if (
		world_controller.get_sick_sheep_count() == 0
		or medical_menu.get_medicine_inventory() > 0
		or money >= medical_menu.MEDICINE_PRICE
	):
		pool.append(_make_task(&"end_healthy", "保持羊群健康", "当天结束时没有生病羊", 1, _scaled_reward(80, difficulty)))
	if world_controller.get_total_grass_count() >= world_controller.get_sheep_count() or money >= LAND_EXPANSION_PRICE:
		pool.append(_make_task(&"end_grass", "保持草场充足", "当天结束时草总量不少于羊数量", 1, _scaled_reward(70, difficulty)))
	if dog_manager.has_active_dog() and not build_controller.get_fence_roots().is_empty():
		pool.append(_make_task(&"dog_roundup", "牧羊犬协作", "使用牧羊犬完成一次傍晚回圈", 1, _scaled_reward(140, difficulty)))
	if day >= build_controller.UPGRADE_UNLOCK_DAY:
		var can_afford_upgrade := false
		for item_id: StringName in HOUSE_DATA:
			for building in build_controller.get_buildings_by_type(item_id):
				var price: int = build_controller.get_upgrade_cost(building)
				if price > 0 and money >= price:
					can_afford_upgrade = true
					break
			if can_afford_upgrade:
				break
		if can_afford_upgrade:
			pool.append(_make_task(&"upgrade_building", "整修牧场建筑", "升级一座已有小屋", 1, _scaled_reward(160, difficulty)))
	return pool


func _scaled_reward(base_reward: int, difficulty: int) -> int:
	return roundi(float(base_reward) * (1.0 + minf(1.4, difficulty * 0.28)) / 10.0) * 10


func _make_task(type: StringName, title: String, description: String, target: int, reward: int) -> Dictionary:
	return {
		"id": "",
		"id_suffix": "",
		"type": type,
		"title": title,
		"description": description,
		"target": target,
		"progress": 0,
		"reward": reward,
		"state": TaskState.AVAILABLE,
	}


func _on_day_changed(new_day: int) -> void:
	_evaluate_active_condition_tasks()
	_generate_tasks(new_day)


func _on_sheep_added(count: int) -> void:
	_advance_tasks(&"buy_lamb", count)
	_evaluate_active_condition_tasks()


func _on_sheep_sold(count: int) -> void:
	_advance_tasks(&"sell_adult", count)
	_evaluate_active_condition_tasks()


func _on_building_placed(item_id: StringName) -> void:
	for task in tasks:
		if (
			task.state == TaskState.ACTIVE
			and task.type == &"build_house"
			and task.get("item_id", &"") == item_id
		):
			_advance_task(task, 1)


func _on_building_upgraded(_building: Node, _item_id: StringName, _level: int) -> void:
	_advance_tasks(&"upgrade_building", 1)


func _on_fence_placed() -> void:
	_advance_tasks(&"build_fence", 1)


func _on_land_expanded() -> void:
	_advance_tasks(&"expand_land", 1)
	_evaluate_active_condition_tasks()


func _on_sheep_treated(_sheep: Node) -> void:
	_advance_tasks(&"treat_sheep", 1)
	_evaluate_active_condition_tasks()


func _on_dog_roundup_succeeded(_day: int) -> void:
	_advance_tasks(&"dog_roundup", 1)


func _advance_tasks(type: StringName, amount: int) -> void:
	for task in tasks:
		if task.state == TaskState.ACTIVE and task.type == type:
			_advance_task(task, amount)


func _advance_task(task: Dictionary, amount: int) -> void:
	if task.state != TaskState.ACTIVE:
		return
	task.progress = mini(task.target, task.progress + amount)
	if task.progress >= task.target:
		task.state = TaskState.COMPLETED
	tasks_changed.emit()


func _evaluate_active_condition_tasks() -> void:
	for task in tasks:
		if task.state == TaskState.ACTIVE:
			_evaluate_condition_task(task)


func _evaluate_condition_task(task: Dictionary) -> void:
	if task.state != TaskState.ACTIVE:
		return
	if task.type == &"end_healthy" and world_controller.get_sick_sheep_count() == 0:
		_advance_task(task, 1)
	elif task.type == &"end_grass" and world_controller.get_total_grass_count() >= world_controller.get_sheep_count():
		_advance_task(task, 1)
