extends Node

signal progression_changed
signal level_changed(level: int)
signal chapter_completed(chapter: int, reward: int)
signal achievement_unlocked(achievement_id: StringName, title: String, reward: int)

const LEVEL_THRESHOLDS := [0, 100, 250, 450, 700]
const CHAPTER_REWARDS := [800, 1400, 2200, 3200, 5000]
const CHAPTER_TITLES := [
	"打稳根基", "血统起步", "稳固牧场", "本岛血统", "岛屿牧场",
]
const ACHIEVEMENTS := {
	&"first_order": {"title": "第一笔订单", "description": "完成 1 份市场订单", "reward": 120},
	&"flock_keeper": {"title": "成群结队", "description": "同时拥有 20 只羊", "reward": 240},
	&"safe_guard": {"title": "连续平安夜", "description": "连续 3 晚安全度过狼窝风险", "reward": 260},
	&"second_generation": {"title": "家系延续", "description": "培育出第 2 代羊", "reward": 320},
	&"master_builder": {"title": "牧场整修师", "description": "拥有 3 座满级建筑", "reward": 360},
	&"wolf_scout": {"title": "狼迹专家", "description": "完成 5 次牧羊犬巡查", "reward": 300},
	&"island_builder": {"title": "岛屿开拓者", "description": "拥有 6 块土地", "reward": 420},
	&"wealthy": {"title": "家底丰厚", "description": "金币余额达到 50000", "reward": 500},
}

@onready var world_controller: Node = get_parent()
@onready var top_hud: Control = get_node("../HUD/TopHUD")
@onready var daily_task_manager: Node = get_node("../DailyTaskManager")
@onready var market_manager: Node = get_node("../MarketOrderManager")
@onready var build_controller: Node = get_node("../BuildController")
@onready var medical_menu: Control = get_node("../HUD/MedicalMenu")
@onready var roundup_manager: Control = get_node("../HUD/RoundupStatus")
@onready var day_routine_manager: Node = get_node("../DayRoutineManager")
@onready var lost_sheep_manager: Node = get_node("../LostSheepManager")

var reputation := 0
var pasture_level := 1
var current_chapter := 1
var unlocked_achievements: Dictionary = {}
var stats: Dictionary = {
	&"tasks_claimed": 0,
	&"orders_completed": 0,
	&"bloodline_orders": 0,
	&"merchant_chains": 0,
	&"lambs_born": 0,
	&"first_generation_born": 0,
	&"max_generation": 0,
	&"buildings_built": 0,
	&"buildings_upgraded": 0,
	&"fences_built": 0,
	&"lands_expanded": 0,
	&"sheep_treated": 0,
	&"sheep_sold": 0,
	&"roundups_completed": 0,
	&"wolf_patrols": 0,
	&"rescues_completed": 0,
	&"safe_night_streak": 0,
	&"best_safe_night_streak": 0,
	&"money_earned": 0,
	&"chapters_completed": 0,
}
var restoring := false


func _ready() -> void:
	daily_task_manager.task_reward_claimed.connect(_on_task_reward_claimed)
	market_manager.order_completed.connect(_on_order_completed)
	market_manager.merchant_chain_completed.connect(_on_merchant_chain_completed)
	build_controller.building_placed.connect(_on_building_placed)
	build_controller.building_upgraded.connect(_on_building_upgraded)
	build_controller.fence_placed.connect(_on_fence_placed)
	build_controller.land_expanded.connect(_on_land_expanded)
	medical_menu.sheep_treated.connect(_on_sheep_treated)
	world_controller.lamb_born.connect(_on_lamb_born)
	world_controller.sheep_added.connect(_on_sheep_added)
	world_controller.sheep_sold.connect(_on_sheep_sold)
	roundup_manager.roundup_succeeded.connect(_on_roundup_succeeded)
	day_routine_manager.wolf_patrol_completed.connect(_on_wolf_patrol_completed)
	lost_sheep_manager.mission_completed.connect(_on_rescue_completed)
	top_hud.day_changed.connect(_on_day_changed)
	top_hud.money_changed.connect(_on_money_changed)
	call_deferred("evaluate_progress")


func get_reputation() -> int:
	return reputation


func get_level() -> int:
	return pasture_level


func get_current_chapter() -> int:
	return current_chapter


func get_chapter_title() -> String:
	if current_chapter > CHAPTER_TITLES.size():
		return "全部章节完成"
	return "第 %d 章 · %s" % [current_chapter, CHAPTER_TITLES[current_chapter - 1]]


func get_level_progress_text() -> String:
	if pasture_level >= LEVEL_THRESHOLDS.size():
		return "声望 %d · 已满级" % reputation
	return "声望 %d / %d" % [reputation, LEVEL_THRESHOLDS[pasture_level]]


func get_chapter_objectives() -> Array[Dictionary]:
	match current_chapter:
		1:
			return [
				_objective("羊群规模", world_controller.get_sheep_count(), 10),
				_objective("木围栏", build_controller.get_fence_roots().size(), 1),
				_objective("牧羊犬小屋", world_controller.get_building_count(&"dog_house"), 1),
			]
		2:
			return [
				_objective("第 1 代幼羊", get_stat(&"first_generation_born"), 1),
				_objective("完成市场订单", get_stat(&"orders_completed"), 3),
				_objective("土地数量", world_controller.get_land_chunk_count(), 3),
			]
		3:
			return [
				_objective("升级建筑", get_stat(&"buildings_upgraded"), 2),
				_objective("连续安全守夜", get_stat(&"best_safe_night_streak"), 3),
				_objective("狼迹巡查", get_stat(&"wolf_patrols"), 2),
			]
		4:
			return [
				_objective("最高羊群世代", get_stat(&"max_generation"), 2),
				_objective("完成血统订单", get_stat(&"bloodline_orders"), 1),
				_objective("牧场等级", pasture_level, 4),
			]
		5:
			return [
				_objective("健康羊数量", _get_healthy_sheep_count(), 30),
				_objective("土地数量", world_controller.get_land_chunk_count(), 6),
				_objective("牧场等级", pasture_level, 5),
			]
	return []


func get_stat(stat_id: StringName) -> int:
	return int(stats.get(stat_id, 0))


func get_unlocked_achievement_count() -> int:
	return unlocked_achievements.size()


func get_achievement_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for achievement_id: StringName in ACHIEVEMENTS:
		var definition: Dictionary = ACHIEVEMENTS[achievement_id]
		rows.append({
			"id": achievement_id,
			"title": definition.title,
			"description": definition.description,
			"reward": int(definition.reward),
			"unlocked": unlocked_achievements.has(achievement_id),
		})
	return rows


func get_save_data() -> Dictionary:
	var saved_stats := {}
	for stat_id: StringName in stats:
		saved_stats[String(stat_id)] = int(stats[stat_id])
	return {
		"reputation": reputation,
		"pasture_level": pasture_level,
		"current_chapter": current_chapter,
		"unlocked_achievements": unlocked_achievements.keys().map(func(value: Variant) -> String: return String(value)),
		"stats": saved_stats,
	}


func restore_save_data(data: Dictionary) -> void:
	restoring = true
	reputation = maxi(0, int(data.get("reputation", 0)))
	pasture_level = clampi(int(data.get("pasture_level", _calculate_level())), 1, LEVEL_THRESHOLDS.size())
	current_chapter = clampi(int(data.get("current_chapter", 1)), 1, CHAPTER_TITLES.size() + 1)
	unlocked_achievements.clear()
	var saved_achievements: Variant = data.get("unlocked_achievements", [])
	if saved_achievements is Array:
		for achievement_id in saved_achievements:
			var normalized := StringName(String(achievement_id))
			if ACHIEVEMENTS.has(normalized):
				unlocked_achievements[normalized] = true
	var saved_stats: Variant = data.get("stats", {})
	if saved_stats is Dictionary:
		for stat_id: StringName in stats:
			stats[stat_id] = maxi(0, int(saved_stats.get(String(stat_id), stats[stat_id])))
	restoring = false
	evaluate_progress()
	progression_changed.emit()


func add_reputation(amount: int, _source: StringName = &"") -> void:
	if amount <= 0:
		return
	reputation += amount
	var previous_level := pasture_level
	pasture_level = _calculate_level()
	if pasture_level != previous_level:
		level_changed.emit(pasture_level)
	evaluate_progress()
	progression_changed.emit()


func record_stat(stat_id: StringName, amount := 1) -> void:
	if amount <= 0 or not stats.has(stat_id):
		return
	stats[stat_id] = int(stats[stat_id]) + amount
	evaluate_progress()
	progression_changed.emit()


func evaluate_progress() -> void:
	if restoring:
		return
	_sync_derived_stats()
	_check_achievements()
	while current_chapter <= CHAPTER_TITLES.size() and _chapter_is_complete():
		var completed := current_chapter
		var reward: int = CHAPTER_REWARDS[completed - 1]
		stats[&"chapters_completed"] = int(stats[&"chapters_completed"]) + 1
		current_chapter += 1
		top_hud.call_deferred("add_money", reward)
		reputation += 60 + completed * 20
		var previous_level := pasture_level
		pasture_level = _calculate_level()
		if pasture_level != previous_level:
			level_changed.emit(pasture_level)
		chapter_completed.emit(completed, reward)
	progression_changed.emit()


func _objective(label: String, current: int, target: int) -> Dictionary:
	return {"label": label, "current": mini(current, target), "target": target, "completed": current >= target}


func _chapter_is_complete() -> bool:
	var objectives := get_chapter_objectives()
	return not objectives.is_empty() and objectives.all(func(objective: Dictionary) -> bool: return objective.completed)


func _calculate_level() -> int:
	var result := 1
	for index in LEVEL_THRESHOLDS.size():
		if reputation >= LEVEL_THRESHOLDS[index]:
			result = index + 1
	return result


func _check_achievements() -> void:
	_try_unlock(&"first_order", get_stat(&"orders_completed") >= 1)
	_try_unlock(&"flock_keeper", world_controller.get_sheep_count() >= 20)
	_try_unlock(&"safe_guard", get_stat(&"best_safe_night_streak") >= 3)
	_try_unlock(&"second_generation", get_stat(&"max_generation") >= 2)
	_try_unlock(&"master_builder", _get_max_level_building_count() >= 3)
	_try_unlock(&"wolf_scout", get_stat(&"wolf_patrols") >= 5)
	_try_unlock(&"island_builder", world_controller.get_land_chunk_count() >= 6)
	_try_unlock(&"wealthy", top_hud.get_money() >= 50000)


func _try_unlock(achievement_id: StringName, condition: bool) -> void:
	if not condition or unlocked_achievements.has(achievement_id):
		return
	var definition: Dictionary = ACHIEVEMENTS[achievement_id]
	unlocked_achievements[achievement_id] = true
	var reward := int(definition.reward)
	top_hud.call_deferred("add_money", reward)
	reputation += 10
	var previous_level := pasture_level
	pasture_level = _calculate_level()
	if pasture_level != previous_level:
		level_changed.emit(pasture_level)
	achievement_unlocked.emit(achievement_id, definition.title, reward)


func _sync_derived_stats() -> void:
	for sheep in world_controller.sheep_group.get_children():
		if sheep.has_method("get_generation"):
			stats[&"max_generation"] = maxi(get_stat(&"max_generation"), sheep.get_generation())
			if sheep.get_generation() >= 1:
				stats[&"first_generation_born"] = maxi(get_stat(&"first_generation_born"), 1)
	var upgrade_steps := 0
	for building in build_controller.buildings_root.get_children():
		upgrade_steps += maxi(0, build_controller.get_building_level(building) - 1)
	stats[&"buildings_upgraded"] = maxi(get_stat(&"buildings_upgraded"), upgrade_steps)
	var completed_orders := 0
	var bloodline_orders := 0
	var completed_chains: Dictionary = {}
	for order in market_manager.get_orders():
		if order.status != market_manager.STATUS_COMPLETED:
			continue
		completed_orders += 1
		if order.type == market_manager.TYPE_BLOODLINE:
			bloodline_orders += 1
		if bool(order.get("special", false)) and int(order.get("chain_step", 0)) == 2:
			completed_chains[String(order.get("chain_id", ""))] = true
	stats[&"orders_completed"] = maxi(get_stat(&"orders_completed"), completed_orders)
	stats[&"bloodline_orders"] = maxi(get_stat(&"bloodline_orders"), bloodline_orders)
	stats[&"merchant_chains"] = maxi(get_stat(&"merchant_chains"), completed_chains.size())


func _get_healthy_sheep_count() -> int:
	return world_controller.sheep_group.get_children().filter(
		func(sheep: Node) -> bool: return sheep.is_healthy() and not sheep.is_lost()
	).size()


func _get_max_level_building_count() -> int:
	var count := 0
	for building in build_controller.buildings_root.get_children():
		if build_controller.get_building_level(building) >= build_controller.MAX_BUILDING_LEVEL:
			count += 1
	return count


func _on_task_reward_claimed(_task_id: String, _reward: int) -> void:
	record_stat(&"tasks_claimed")
	add_reputation(20, &"daily_task")


func _on_order_completed(order_id: String, _count: int, _income: int) -> void:
	record_stat(&"orders_completed")
	var order: Dictionary = market_manager.get_order(order_id)
	if order.get("type", &"") == market_manager.TYPE_BLOODLINE:
		record_stat(&"bloodline_orders")
		add_reputation(15, &"bloodline_order")
	add_reputation(30, &"market_order")


func _on_merchant_chain_completed(_chain_id: String, _income: int) -> void:
	record_stat(&"merchant_chains")
	add_reputation(40, &"merchant_chain")


func _on_building_placed(_item_id: StringName) -> void:
	record_stat(&"buildings_built")


func _on_building_upgraded(_building: Node, _item_id: StringName, _level: int) -> void:
	record_stat(&"buildings_upgraded")
	add_reputation(20, &"building_upgrade")


func _on_fence_placed() -> void:
	record_stat(&"fences_built")


func _on_land_expanded() -> void:
	record_stat(&"lands_expanded")
	add_reputation(10, &"land_expansion")


func _on_sheep_treated(_sheep: Node) -> void:
	record_stat(&"sheep_treated")


func _on_lamb_born(lamb: Node, _mother: Node) -> void:
	record_stat(&"lambs_born")
	if lamb.get_generation() >= 1:
		record_stat(&"first_generation_born")
	stats[&"max_generation"] = maxi(get_stat(&"max_generation"), lamb.get_generation())
	add_reputation(8, &"lamb_born")


func _on_sheep_added(_count: int) -> void:
	evaluate_progress()


func _on_sheep_sold(count: int) -> void:
	record_stat(&"sheep_sold", count)


func _on_roundup_succeeded(_day: int, _reward: int) -> void:
	record_stat(&"roundups_completed")
	add_reputation(10, &"roundup")


func _on_wolf_patrol_completed(_dog: Node, _defense_bonus: int) -> void:
	record_stat(&"wolf_patrols")
	add_reputation(15, &"wolf_patrol")


func _on_rescue_completed(_reward: int) -> void:
	record_stat(&"rescues_completed")
	add_reputation(40, &"rescue")


func _on_day_changed(new_day: int) -> void:
	var risk: Dictionary = day_routine_manager.evaluate_wolf_night_risk(new_day - 1)
	if bool(risk.get("active", false)) and risk.get("outcome", "") == "safe":
		stats[&"safe_night_streak"] = get_stat(&"safe_night_streak") + 1
		stats[&"best_safe_night_streak"] = maxi(get_stat(&"best_safe_night_streak"), get_stat(&"safe_night_streak"))
	elif bool(risk.get("active", false)):
		stats[&"safe_night_streak"] = 0
	evaluate_progress()


func _on_money_changed(delta: int) -> void:
	if delta > 0:
		stats[&"money_earned"] = get_stat(&"money_earned") + delta
	_check_achievements()
	progression_changed.emit()
