extends Node

signal mission_started(total_count: int, deadline_day: int)
signal mission_changed
signal mission_completed(reward: int)
signal mission_failed(missing_count: int)

const RESCUE_RADIUS := 90.0
const REWARD_PER_SHEEP := 150

@onready var world_controller: Node = get_parent()
@onready var top_hud: Control = get_node("../HUD/TopHUD")
@onready var day_routine_manager: Node = get_node("../DayRoutineManager")
@onready var build_controller: Node = get_node("../BuildController")
@onready var player: AnimatedSprite2D = get_node("../Island/Shepherd")
@onready var world_camera: Camera2D = get_node("../WorldCamera")

var active := false
var start_day := 0
var deadline_day := 0
var lost_sheep_ids: Array[int] = []
var total_count := 0
var rescued_count := 0
var last_reward := 0
var last_failed_count := 0
var refresh_time := 0.0


func _ready() -> void:
	day_routine_manager.sheep_scattered.connect(_on_sheep_scattered)
	top_hud.day_changed.connect(_on_day_changed)
	world_controller.sheep_died.connect(_on_sheep_died)


func _process(delta: float) -> void:
	if not active:
		return
	refresh_time -= delta
	if refresh_time > 0.0:
		return
	refresh_time = 0.2
	_check_rescue_progress()


func get_save_data() -> Dictionary:
	return {
		"active": active,
		"start_day": start_day,
		"deadline_day": deadline_day,
		"lost_sheep_ids": lost_sheep_ids.duplicate(),
		"total_count": total_count,
		"rescued_count": rescued_count,
		"last_reward": last_reward,
		"last_failed_count": last_failed_count,
	}


func restore_save_data(data: Dictionary) -> void:
	active = bool(data.get("active", false))
	start_day = maxi(0, int(data.get("start_day", 0)))
	deadline_day = maxi(0, int(data.get("deadline_day", 0)))
	lost_sheep_ids.clear()
	var saved_ids: Variant = data.get("lost_sheep_ids", [])
	if saved_ids is Array:
		for value in saved_ids:
			var sheep_id := int(value)
			if sheep_id > 0 and not lost_sheep_ids.has(sheep_id):
				lost_sheep_ids.append(sheep_id)
	total_count = maxi(lost_sheep_ids.size(), int(data.get("total_count", lost_sheep_ids.size())))
	rescued_count = clampi(int(data.get("rescued_count", 0)), 0, total_count)
	last_reward = maxi(0, int(data.get("last_reward", 0)))
	last_failed_count = maxi(0, int(data.get("last_failed_count", 0)))
	_apply_lost_flags()
	if active and lost_sheep_ids.is_empty():
		active = false
	mission_changed.emit()


func start_rescue(sheep_list: Array, ended_day: int) -> int:
	var added := 0
	if not active:
		active = true
		start_day = ended_day + 1
		deadline_day = ended_day + 1
		lost_sheep_ids.clear()
		total_count = 0
		rescued_count = 0
		last_reward = 0
		last_failed_count = 0
	else:
		deadline_day = maxi(deadline_day, ended_day + 1)
	for value in sheep_list:
		var sheep := value as Node
		if not _is_valid_sheep(sheep):
			continue
		var sheep_id: int = sheep.get_sheep_id()
		if lost_sheep_ids.has(sheep_id):
			continue
		lost_sheep_ids.append(sheep_id)
		sheep.set_lost(true)
		added += 1
	total_count += added
	if added == 0:
		if total_count == 0:
			active = false
		return 0
	mission_started.emit(total_count, deadline_day)
	mission_changed.emit()
	return added


func has_active_rescue() -> bool:
	return active


func get_remaining_count() -> int:
	return lost_sheep_ids.size() if active else 0


func get_status_title() -> String:
	return "走失小羊　%d / %d" % [rescued_count, total_count]


func get_status_body() -> String:
	return "靠近走失羊，或赶进关闭围栏；第 %d 天结束前完成。" % deadline_day


func get_lost_sheep_names() -> String:
	var names: Array[String] = []
	for sheep_id in lost_sheep_ids:
		var sheep := _find_sheep(sheep_id)
		if sheep:
			names.append(sheep.get_sheep_name())
	return "、".join(names) if not names.is_empty() else "走失的小羊"


func get_next_lost_sheep() -> Node:
	for sheep_id in lost_sheep_ids:
		var sheep := _find_sheep(sheep_id)
		if sheep:
			return sheep
	return null


func locate_next_lost_sheep() -> bool:
	var sheep := get_next_lost_sheep()
	if not sheep:
		return false
	world_camera.focus_on_world_position(sheep.global_position)
	world_controller.select_entity(sheep)
	return true


func _on_sheep_scattered(sheep_list: Array, ended_day: int) -> void:
	start_rescue(sheep_list, ended_day)


func _on_day_changed(new_day: int) -> void:
	if active and new_day > deadline_day:
		_fail_rescue()


func _on_sheep_died(sheep: Node) -> void:
	if not active or not lost_sheep_ids.has(sheep.get_sheep_id()):
		return
	lost_sheep_ids.erase(sheep.get_sheep_id())
	last_failed_count += 1
	mission_changed.emit()
	if lost_sheep_ids.is_empty():
		active = false
		mission_failed.emit(last_failed_count)


func _check_rescue_progress() -> void:
	for sheep_id in lost_sheep_ids.duplicate():
		var sheep := _find_sheep(sheep_id)
		if not sheep:
			lost_sheep_ids.erase(sheep_id)
			continue
		if sheep.global_position.distance_to(player.global_position) <= RESCUE_RADIUS or _is_inside_closed_fence(sheep.global_position):
			_rescue_sheep(sheep)
	if active and lost_sheep_ids.is_empty():
		_complete_rescue()


func _rescue_sheep(sheep: Node) -> void:
	var sheep_id: int = sheep.get_sheep_id()
	if not lost_sheep_ids.has(sheep_id):
		return
	lost_sheep_ids.erase(sheep_id)
	sheep.set_lost(false)
	rescued_count += 1
	mission_changed.emit()


func _complete_rescue() -> void:
	if not active:
		return
	active = false
	last_reward = total_count * REWARD_PER_SHEEP
	if last_reward > 0:
		top_hud.add_money(last_reward)
	mission_changed.emit()
	mission_completed.emit(last_reward)


func _fail_rescue() -> void:
	last_failed_count = lost_sheep_ids.size()
	var index := 0
	for sheep_id in lost_sheep_ids:
		var sheep := _find_sheep(sheep_id)
		if not sheep:
			continue
		sheep.set_lost(false)
		sheep.global_position = world_controller.clamp_point_to_land(
			player.global_position + Vector2((index % 3 - 1) * 30.0, 42.0 + floori(float(index) / 3.0) * 24.0),
			player.global_position
		)
		if sheep.has_method("end_drag"):
			sheep.end_drag()
		index += 1
	lost_sheep_ids.clear()
	active = false
	mission_changed.emit()
	mission_failed.emit(last_failed_count)


func _is_inside_closed_fence(position_value: Vector2) -> bool:
	for fence in build_controller.get_fence_roots():
		if (
			not bool(fence.get_meta("gate_open", false))
			and (fence.get_meta("grazing_rect") as Rect2).has_point(position_value)
		):
			return true
	return false


func _apply_lost_flags() -> void:
	for sheep in world_controller.sheep_group.get_children():
		sheep.set_lost(active and lost_sheep_ids.has(sheep.get_sheep_id()))


func _find_sheep(sheep_id: int) -> Node:
	for sheep in world_controller.sheep_group.get_children():
		if sheep.get_sheep_id() == sheep_id and not sheep.is_queued_for_deletion():
			return sheep
	return null


func _is_valid_sheep(sheep: Variant) -> bool:
	return (
		is_instance_valid(sheep)
		and not sheep.is_queued_for_deletion()
		and sheep.get_parent() == world_controller.sheep_group
	)
