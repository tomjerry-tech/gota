extends Node

signal event_queued(event_id: StringName)
signal event_shown(event_id: StringName)
signal event_finished(event_id: StringName)

@onready var world_controller: Node = get_parent()
@onready var top_hud: Control = get_node("../HUD/TopHUD")
@onready var build_controller: Node = get_node("../BuildController")
@onready var daily_report: Control = get_node("../HUD/DailyReport")
@onready var newbie_commission: Control = get_node("../HUD/NewbieCommission")
@onready var time_controls: Control = get_node("../HUD/TimeControls")
@onready var right_side_panel: Control = get_node("../HUD/RightSidePanel")
@onready var daily_task_panel: Control = get_node("../HUD/DailyTaskPanel")
@onready var bottom_toolbar: Control = get_node("../HUD/BottomToolbar")
@onready var sheep_menu: Control = get_node("../HUD/SheepMenu")
@onready var market_manager: Node = get_node("../MarketOrderManager")
@onready var day_routine_manager: Node = get_node("../DayRoutineManager")
@onready var world_camera: Camera2D = get_node("../WorldCamera")
@onready var player: AnimatedSprite2D = get_node("../Island/Shepherd")
@onready var roundup_manager: Control = get_node("../HUD/RoundupStatus")
@onready var dog_manager: Node = get_node("../DogManager")

var fired_events: Dictionary = {}
var event_queue: Array[Dictionary] = []
var current_event: Dictionary = {}
var day_four_target: Variant
var pending_action: Dictionary = {}
var automatic_presentation_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	automatic_presentation_enabled = DisplayServer.get_name() != "headless"
	top_hud.day_changed.connect(_on_day_changed)
	build_controller.building_placed.connect(_on_building_placed)
	build_controller.land_expanded.connect(_on_land_expanded)
	build_controller.gate_toggled.connect(_on_gate_toggled)
	player.whistle_used.connect(_on_whistle_used)
	roundup_manager.roundup_succeeded.connect(_on_roundup_succeeded)
	dog_manager.command_issued.connect(_on_dog_command_issued)
	player.stamina_low.connect(_on_worker_stamina_low.bind(player))
	dog_manager.worker_stamina_low.connect(_on_worker_stamina_low)
	roundup_manager.dog_roundup_succeeded.connect(_on_dog_roundup_succeeded)
	market_manager.market_viewed.connect(_on_market_viewed)
	market_manager.order_completed.connect(_on_market_order_completed)
	day_routine_manager.wolf_den_discovered.connect(_on_wolf_den_discovered)
	daily_report.report_closed.connect(_on_report_closed)
	right_side_panel.story_action_requested.connect(_on_story_action_requested)
	right_side_panel.story_closed.connect(_on_story_closed)
	call_deferred("queue_event", &"welcome")


func queue_event(event_id: StringName) -> bool:
	if fired_events.has(event_id):
		return false
	fired_events[event_id] = true
	event_queue.append({"id": event_id})
	event_queued.emit(event_id)
	call_deferred("_try_present_automatically")
	return true


func is_event_fired(event_id: StringName) -> bool:
	return fired_events.has(event_id)


func get_pending_event_count() -> int:
	return event_queue.size()


func get_current_event_id() -> StringName:
	return current_event.get("id", &"")


func get_day_four_target() -> Variant:
	_ensure_day_four_target()
	return day_four_target


func get_save_data() -> Dictionary:
	return {"fired_events": fired_events.keys().map(func(value: Variant) -> String: return String(value))}


func restore_save_data(data: Dictionary) -> void:
	fired_events.clear()
	var saved_events: Variant = data.get("fired_events", [])
	if saved_events is Array:
		for event_id in saved_events:
			fired_events[StringName(String(event_id))] = true
	event_queue.clear()
	current_event = {}
	pending_action = {}
	day_four_target = null
	if right_side_panel.visible:
		right_side_panel.close_panel()


func present_next_event() -> bool:
	if not current_event.is_empty() or event_queue.is_empty() or daily_report.visible:
		return false
	var queued: Dictionary = event_queue.pop_front()
	if queued.id == &"day_4_medical":
		_ensure_day_four_target()
	current_event = _build_event_data(queued.id)
	right_side_panel.show_story(current_event)
	time_controls.pause_for_report()
	event_shown.emit(current_event.id)
	return true


func _try_present_automatically() -> void:
	if automatic_presentation_enabled:
		present_next_event()


func _on_day_changed(new_day: int) -> void:
	if new_day >= 2 and not is_event_fired(&"day_2_capacity"):
		queue_event(&"day_2_capacity")
	if new_day >= 4 and not is_event_fired(&"day_4_medical"):
		_ensure_day_four_target()
		queue_event(&"day_4_medical")
	if new_day >= 8 and not is_event_fired(&"day_8_commission"):
		queue_event(&"day_8_commission")


func _on_building_placed(item_id: StringName) -> void:
	if item_id == &"lamb_shelter":
		queue_event(&"first_lamb_shelter")


func _on_land_expanded() -> void:
	queue_event(&"first_land_expansion")


func _on_whistle_used() -> void:
	queue_event(&"first_whistle")


func _on_gate_toggled(_fence: Node, _is_open: bool) -> void:
	queue_event(&"first_gate")


func _on_roundup_succeeded(_day: int, _reward: int) -> void:
	queue_event(&"first_roundup_success")


func _on_dog_command_issued(_mode: int) -> void:
	queue_event(&"first_dog_command")


func _on_worker_stamina_low(_worker: Node) -> void:
	queue_event(&"first_low_stamina")


func _on_dog_roundup_succeeded(_day: int) -> void:
	queue_event(&"first_dog_roundup")


func _on_market_viewed() -> void:
	queue_event(&"first_market_view")


func _on_market_order_completed(_order_id: String, _count: int, _income: int) -> void:
	queue_event(&"first_market_order")


func _on_wolf_den_discovered() -> void:
	queue_event(&"wolf_den_discovered")


func _on_report_closed() -> void:
	call_deferred("_try_present_automatically")


func _on_story_action_requested(action_id: StringName) -> void:
	pending_action = {
		"id": action_id,
		"target": current_event.get("target", null),
	}
	right_side_panel.close_panel()


func _on_story_closed(event_id: StringName) -> void:
	if current_event.get("id", &"") == event_id:
		current_event = {}
	time_controls.resume_after_report()
	event_finished.emit(event_id)
	if pending_action.is_empty():
		call_deferred("_try_present_automatically")
	else:
		call_deferred("_execute_pending_action")


func _execute_pending_action() -> void:
	var action := pending_action
	pending_action = {}
	match action.id:
		&"open_medical":
			bottom_toolbar.select_tab(&"medical")
		&"open_tasks":
			daily_task_panel.open_drawer()
		&"locate_sheep":
			var target: Node = action.get("target", null)
			if not _is_valid_sheep(target):
				_ensure_day_four_target()
				target = day_four_target
			if _is_valid_sheep(target):
				world_camera.position = target.global_position
		&"open_build":
			bottom_toolbar.select_tab(&"build")
		&"open_market":
			bottom_toolbar.select_tab(&"sheep")
			sheep_menu.open_market_page()
		&"confirm":
			pass
	call_deferred("_try_present_automatically")


func _ensure_day_four_target() -> void:
	if _is_valid_sheep(day_four_target):
		return
	day_four_target = null
	for sheep in world_controller.sheep_group.get_children():
		if _is_valid_sheep(sheep) and sheep.is_healthy():
			day_four_target = sheep
			break
	if not day_four_target:
		for sheep in world_controller.sheep_group.get_children():
			if _is_valid_sheep(sheep):
				day_four_target = sheep
				break
	if _is_valid_sheep(day_four_target) and day_four_target.is_healthy():
		day_four_target.make_sick()


func _is_valid_sheep(sheep: Variant) -> bool:
	return (
		is_instance_valid(sheep)
		and not sheep.is_queued_for_deletion()
		and sheep.is_inside_tree()
		and sheep.get_parent() == world_controller.sheep_group
	)


func _build_event_data(event_id: StringName) -> Dictionary:
	match event_id:
		&"welcome":
			return _event(
				event_id, "欢迎来到牧羊小岛",
				"先从右上角的“今日任务”开始吧。\n接取后，买羊、建造和照料行为才会计入进度。",
				[{"id": &"open_tasks", "label": "打开今日任务"}, {"id": &"confirm", "label": "稍后再看"}]
			)
		&"day_2_capacity":
			return _event(
				event_id, "牧场承载规则",
				"现在有 %d 只羊，容量为 %d，草有 %d 株。\n每块土地提供 10 点容量和 9 株草，小羊棚还能增加 4 点容量。" % [
					world_controller.get_sheep_count(), world_controller.get_sheep_capacity(),
					world_controller.get_total_grass_count(),
				],
				[{"id": &"open_build", "label": "打开建造"}, {"id": &"confirm", "label": "明白了"}]
			)
		&"day_4_medical":
			_ensure_day_four_target()
			var target_name: String = day_four_target.get_sheep_name() if _is_valid_sheep(day_four_target) else "一只羊"
			var data := _event(
				event_id, "轻症照料教学",
				"%s出现了轻症，头顶会显示医疗图标。\n购买一份普通药物，再从病羊列表中完成治疗。" % target_name,
				[{"id": &"open_medical", "label": "打开医疗"}, {"id": &"locate_sheep", "label": "定位病羊"}]
			)
			data.target = day_four_target
			return data
		&"day_8_commission":
			var succeeded: bool = newbie_commission.finished and newbie_commission.succeeded
			return _event(
				event_id,
				"7 天委托完成" if succeeded else "7 天委托回顾",
				(
					"你养成了足够的健康成年羊，也一直维持着草场供应。\n第一阶段经营已经顺利完成。"
					if succeeded else
					"这次委托没有全部完成。\n留意健康成年羊数量与每日草量，下次经营会更稳妥。"
				),
				[{"id": &"confirm", "label": "继续经营"}]
			)
		&"first_land_expansion":
			return _event(
				event_id, "新的放牧土地",
				"两种新土地都会增加 10 点容量。\n放牧草地生成草和自然物，生活用地保持空旷，适合集中建造。",
				[{"id": &"confirm", "label": "知道了"}]
			)
		&"first_lamb_shelter":
			return _event(
				event_id, "小羊棚投入使用",
				"每座小羊棚增加 4 点容量。\n它还会降低幼羊每天生病的概率，适合在购买幼羊前准备。",
				[{"id": &"confirm", "label": "知道了"}]
			)
		&"first_whistle":
			return _event(
				event_id, "牧羊口哨",
				"口哨会召集附近的羊，距离太远的羊听不到。\n羊群会在你身边分散停下，不会挤在同一个位置。",
				[{"id": &"confirm", "label": "继续放牧"}]
			)
		&"first_gate":
			return _event(
				event_id, "围栏门",
				"靠近围栏门可以打开或关闭通道。\n开门后再用口哨和走位，把羊群带进同一个围栏。",
				[{"id": &"confirm", "label": "明白了"}]
			)
		&"first_roundup_success":
			return _event(
				event_id, "第一次回圈成功",
				"傍晚前目标羊群已经进入同一个围栏。\n今天的回圈奖励已计入金币，每天最多领取一次。",
				[{"id": &"confirm", "label": "收下奖励"}]
			)
		&"first_dog_command":
			return _event(
				event_id, "牧羊犬协同",
				"跟随让牧羊犬留在身边；驱赶需要在土地上指定目的地；守住会让它驻守指定位置。\n牧羊犬的影响范围比牧羊人更大，适合整理分散的羊群。",
				[{"id": &"confirm", "label": "开始协作"}]
			)
		&"first_dog_roundup":
			return _event(
				event_id, "协作回圈完成",
				"牧羊犬参与驱赶后，羊群顺利完成了傍晚回圈。\n今后的每日任务可能要求使用牧羊犬协作。",
				[{"id": &"confirm", "label": "继续经营"}]
			)
		&"first_low_stamina":
			return _event(
				event_id, "夜里的灯还亮着",
				"连续移动、吹口哨和赶羊会消耗体力，疲惫时工作范围与速度都会下降。\n夜间点击牧民小屋或狗窝安排休息，次日就能恢复精神。",
				[{"id": &"open_build", "label": "查看休息建筑"}, {"id": &"confirm", "label": "今晚早点休息"}]
			)
		&"first_market_view":
			var market_intro := _event(
				event_id, "行商人的订单",
				"普通成年羊市价每天都会变化。\n订单价格更高，但只接收符合年龄、性别和健康要求的羊；过期不会罚款。",
				[{"id": &"confirm", "label": "看看今日订单"}]
			)
			market_intro.speaker = "行商人"
			market_intro.subtitle = "往来小岛的牲畜商"
			return market_intro
		&"first_market_order":
			var order_done := _event(
				event_id, "第一份订单完成",
				"这批羊符合要求，订单款已经结清。\n繁育时保留不同性别和年龄的健康羊，之后会更容易完成高价订单。",
				[{"id": &"open_market", "label": "返回订单市场"}, {"id": &"confirm", "label": "继续经营"}]
			)
			order_done.speaker = "行商人"
			order_done.subtitle = "往来小岛的牲畜商"
			return order_done
		&"wolf_den_discovered":
			return _event(
				event_id, "边缘土地的狼窝",
				"牧场最外侧的狼窝出现了新的活动痕迹，夜间需要更谨慎。\n让体力充足的牧羊犬守夜，并在入夜前把羊赶入围栏、关闭大门。",
				[{"id": &"open_build", "label": "检查建造"}, {"id": &"confirm", "label": "加强夜间防护"}]
			)
	return _event(event_id, "牧场消息", "牧场里有了新的变化。", [{"id": &"confirm", "label": "确定"}])


func _event(event_id: StringName, title: String, body: String, actions: Array) -> Dictionary:
	return {
		"id": event_id,
		"title": title,
		"body": body,
		"subtitle": "牧场向导",
		"actions": actions,
	}
