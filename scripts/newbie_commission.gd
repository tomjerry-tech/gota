extends Control

const COMMISSION_DAYS := 7
const HEALTHY_ADULT_GOAL := 3

@onready var world_controller: Node = get_node("../..")
@onready var top_hud: Control = get_node("../TopHUD")

var title_label: Label
var adult_goal_label: Label
var grass_goal_label: Label
var result_label: Label
var sufficient_grass_days := 0
var finished := false
var succeeded := false


func _ready() -> void:
	_build_interface()
	top_hud.day_changed.connect(_on_day_changed)
	_refresh.call_deferred()


func _process(_delta: float) -> void:
	_refresh()


func get_status_summary() -> String:
	if finished:
		return "7 天委托：%s" % ("完成" if succeeded else "未完成")
	return "7 天委托：第 %d / 7 天" % mini(top_hud.get_day(), COMMISSION_DAYS)


func get_save_data() -> Dictionary:
	return {
		"sufficient_grass_days": sufficient_grass_days,
		"finished": finished,
		"succeeded": succeeded,
	}


func restore_save_data(data: Dictionary) -> void:
	sufficient_grass_days = clampi(int(data.get("sufficient_grass_days", 0)), 0, COMMISSION_DAYS)
	finished = bool(data.get("finished", false))
	succeeded = bool(data.get("succeeded", false))
	_refresh()
	visible = not finished and top_hud.get_day() <= COMMISSION_DAYS


func _on_day_changed(new_day: int) -> void:
	if finished:
		return
	if new_day <= COMMISSION_DAYS + 1 and _is_grass_supply_sufficient():
		sufficient_grass_days += 1
	if new_day >= COMMISSION_DAYS + 1:
		finished = true
		succeeded = (
			world_controller.get_healthy_adult_count() >= HEALTHY_ADULT_GOAL
			and sufficient_grass_days >= COMMISSION_DAYS
		)
	_refresh()
	if finished:
		hide()


func _is_grass_supply_sufficient() -> bool:
	return world_controller.get_total_grass_count() >= world_controller.get_sheep_count()


func _refresh() -> void:
	if not title_label or not world_controller:
		return
	title_label.text = get_status_summary()
	var healthy_adults: int = world_controller.get_healthy_adult_count()
	adult_goal_label.text = "健康成年羊　%d / %d" % [mini(healthy_adults, HEALTHY_ADULT_GOAL), HEALTHY_ADULT_GOAL]
	grass_goal_label.text = "草量充足　　%d / %d 天" % [sufficient_grass_days, COMMISSION_DAYS]
	adult_goal_label.add_theme_color_override("font_color", Color("35644c") if healthy_adults >= HEALTHY_ADULT_GOAL else Color("49362b"))
	grass_goal_label.add_theme_color_override("font_color", Color("35644c") if sufficient_grass_days >= COMMISSION_DAYS else Color("49362b"))
	result_label.text = "委托完成" if succeeded else ("委托未完成" if finished else "")
	result_label.add_theme_color_override("font_color", Color("35644c") if succeeded else Color("a33b32"))
	if finished and top_hud.get_day() >= COMMISSION_DAYS + 1:
		hide()


func _build_interface() -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	title_label = _make_label(Vector2(18, 12), Vector2(374, 34), 22)
	title_label.add_theme_color_override("font_color", Color("294b5b"))
	panel.add_child(title_label)
	adult_goal_label = _make_label(Vector2(22, 54), Vector2(366, 30), 17)
	panel.add_child(adult_goal_label)
	grass_goal_label = _make_label(Vector2(22, 88), Vector2(366, 30), 17)
	panel.add_child(grass_goal_label)
	result_label = _make_label(Vector2(22, 120), Vector2(366, 30), 17)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(result_label)


func _make_label(position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("49362b"))
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0e5c4")
	style.border_color = Color("6d5e49")
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	return style
