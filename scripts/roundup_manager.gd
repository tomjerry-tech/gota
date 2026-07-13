extends Control

signal roundup_succeeded(day: int, reward: int)
signal roundup_evaluated(day: int, succeeded: bool)
signal dog_roundup_succeeded(day: int)

const DUSK_PROGRESS := 0.82
const ROUNDUP_REWARD := 120
const RIBBON_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/hud_ribbon_blue.png")

@onready var world_controller: Node = get_node("../..")
@onready var top_hud: Control = get_node("../TopHUD")
@onready var build_controller: Node = get_node("../../BuildController")
@onready var dog_manager: Node = get_node("../../DogManager")

var current_day := 0
var active := false
var evaluated := false
var succeeded := false
var target_count := 0
var best_count := 0
var reward_given := false
var dog_assisted := false
var last_result: Dictionary = {}
var refresh_time := 0.0
var status_label: Label


func _ready() -> void:
	_build_interface()
	top_hud.day_changed.connect(_on_day_changed)
	build_controller.fence_placed.connect(_on_fence_placed)
	dog_manager.sheep_driven.connect(_on_dog_sheep_driven)
	_start_day(top_hud.get_day())


func _process(delta: float) -> void:
	refresh_time -= delta
	if refresh_time > 0.0:
		return
	refresh_time = 0.25
	if current_day != top_hud.get_day():
		_start_day(top_hud.get_day())
	_refresh_current_state()
	if active and not evaluated and top_hud.day_progress >= DUSK_PROGRESS:
		evaluate_roundup()


func evaluate_roundup() -> bool:
	_refresh_current_state()
	if not active or evaluated:
		return succeeded
	evaluated = true
	best_count = _get_best_enclosure_count()
	succeeded = target_count > 0 and best_count >= target_count
	if succeeded and not reward_given:
		reward_given = true
		top_hud.add_money(ROUNDUP_REWARD)
		roundup_succeeded.emit(current_day, ROUNDUP_REWARD)
	if succeeded and dog_assisted:
		dog_roundup_succeeded.emit(current_day)
	_record_current_result()
	roundup_evaluated.emit(current_day, succeeded)
	_update_interface()
	return succeeded


func get_report_text(ended_day: int) -> String:
	var result := last_result
	if int(result.get("day", -1)) != ended_day and current_day == ended_day:
		result = _current_result()
	if int(result.get("day", -1)) != ended_day or not bool(result.get("available", false)):
		return "未开放（当天没有围栏）"
	if bool(result.get("succeeded", false)):
		return "成功，圈内 %d / %d，只奖励 %d 金币%s" % [
			int(result.get("best_count", 0)),
			int(result.get("target_count", 0)),
			int(result.get("reward", 0)),
			"，牧羊犬协助" if bool(result.get("dog_assisted", false)) else "",
		]
	return "未完成，圈内 %d / %d（无惩罚）" % [
		int(result.get("best_count", 0)), int(result.get("target_count", 0)),
	]


func get_save_data() -> Dictionary:
	return {
		"current_day": current_day,
		"active": active,
		"evaluated": evaluated,
		"succeeded": succeeded,
		"target_count": target_count,
		"best_count": best_count,
		"reward_given": reward_given,
		"dog_assisted": dog_assisted,
		"last_result": last_result.duplicate(true),
	}


func restore_save_data(data: Dictionary) -> void:
	if int(data.get("current_day", -1)) != top_hud.get_day():
		_start_day(top_hud.get_day())
		return
	current_day = top_hud.get_day()
	active = bool(data.get("active", false)) and not build_controller.get_fence_roots().is_empty()
	evaluated = bool(data.get("evaluated", false))
	succeeded = bool(data.get("succeeded", false))
	target_count = maxi(0, int(data.get("target_count", 0)))
	best_count = maxi(0, int(data.get("best_count", 0)))
	reward_given = bool(data.get("reward_given", false))
	dog_assisted = bool(data.get("dog_assisted", false))
	var saved_last: Variant = data.get("last_result", {})
	last_result = (saved_last as Dictionary).duplicate(true) if saved_last is Dictionary else {}
	_update_interface()


func _on_day_changed(new_day: int) -> void:
	if current_day == new_day - 1:
		if active and not evaluated:
			evaluate_roundup()
		elif last_result.is_empty() or int(last_result.get("day", -1)) != current_day:
			_record_current_result()
	_start_day(new_day)


func _on_fence_placed() -> void:
	if evaluated:
		return
	active = true
	target_count = mini(5, world_controller.get_sheep_count())
	best_count = _get_best_enclosure_count()
	_update_interface()
	if top_hud.day_progress >= DUSK_PROGRESS:
		call_deferred("evaluate_roundup")


func _on_dog_sheep_driven(_sheep: Node) -> void:
	if active and not evaluated:
		dog_assisted = true


func _start_day(day: int) -> void:
	current_day = day
	active = not build_controller.get_fence_roots().is_empty()
	evaluated = false
	succeeded = false
	target_count = mini(5, world_controller.get_sheep_count()) if active else 0
	best_count = _get_best_enclosure_count() if active else 0
	reward_given = false
	dog_assisted = false
	_update_interface()


func _refresh_current_state() -> void:
	if evaluated:
		_update_interface()
		return
	active = not build_controller.get_fence_roots().is_empty()
	if active:
		target_count = mini(5, world_controller.get_sheep_count())
		best_count = _get_best_enclosure_count()
	else:
		target_count = 0
		best_count = 0
	_update_interface()


func _get_best_enclosure_count() -> int:
	var result := 0
	for fence in build_controller.get_fence_roots():
		result = maxi(result, build_controller.get_fence_sheep_count(fence))
	return result


func _current_result() -> Dictionary:
	return {
		"day": current_day,
		"available": active,
		"evaluated": evaluated,
		"succeeded": succeeded,
		"target_count": target_count,
		"best_count": best_count,
		"reward": ROUNDUP_REWARD if reward_given else 0,
		"dog_assisted": dog_assisted,
	}


func _record_current_result() -> void:
	last_result = _current_result()


func _update_interface() -> void:
	visible = active or evaluated
	if not visible or not status_label:
		return
	if evaluated:
		status_label.text = (
			"回圈成功　%d / %d　+%d" % [best_count, target_count, ROUNDUP_REWARD]
			if succeeded else
			"今日回圈　%d / %d　未完成" % [best_count, target_count]
		)
	else:
		status_label.text = "傍晚回圈　圈内 %d / %d" % [best_count, target_count]


func _build_interface() -> void:
	var ribbon := TextureRect.new()
	ribbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ribbon.texture = RIBBON_TEXTURE
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ribbon)
	status_label = Label.new()
	status_label.position = Vector2(24, 14)
	status_label.size = Vector2(392, 54)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 21)
	status_label.add_theme_color_override("font_color", Color("fff0b0"))
	status_label.add_theme_color_override("font_shadow_color", Color("172337"))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(status_label)
