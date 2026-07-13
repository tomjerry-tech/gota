extends Control

signal report_closed

const PAPER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")

@onready var world_controller: Node = get_node("../..")
@onready var top_hud: Control = get_node("../TopHUD")
@onready var time_controls: Control = get_node("../TimeControls")
@onready var roundup_manager: Control = get_node("../RoundupStatus")
@onready var market_manager: Node = get_node("../../MarketOrderManager")
@onready var day_routine_manager: Node = get_node("../../DayRoutineManager")

var report_title: Label
var report_text: Label
var bought_today := 0
var sold_today := 0
var born_today := 0
var normal_sale_income_today := 0
var order_income_today := 0
var expired_orders_today := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	top_hud.day_changed.connect(_on_day_changed)
	world_controller.sheep_added.connect(_on_sheep_added)
	world_controller.sheep_sold.connect(_on_sheep_sold)
	world_controller.lamb_born.connect(_on_lamb_born)
	market_manager.normal_sale_completed.connect(_on_normal_sale_completed)
	market_manager.order_completed.connect(_on_order_completed)
	market_manager.order_expired.connect(_on_order_expired)


func close_report() -> void:
	if not visible:
		return
	hide()
	time_controls.resume_after_report()
	report_closed.emit()


func get_save_data() -> Dictionary:
	return {
		"bought_today": bought_today,
		"sold_today": sold_today,
		"born_today": born_today,
		"normal_sale_income_today": normal_sale_income_today,
		"order_income_today": order_income_today,
		"expired_orders_today": expired_orders_today,
	}


func restore_save_data(data: Dictionary) -> void:
	bought_today = maxi(0, int(data.get("bought_today", 0)))
	sold_today = maxi(0, int(data.get("sold_today", 0)))
	born_today = maxi(0, int(data.get("born_today", 0)))
	normal_sale_income_today = maxi(0, int(data.get("normal_sale_income_today", 0)))
	order_income_today = maxi(0, int(data.get("order_income_today", 0)))
	expired_orders_today = maxi(0, int(data.get("expired_orders_today", 0)))
	hide()


func _on_sheep_added(count: int) -> void:
	bought_today += count


func _on_sheep_sold(count: int) -> void:
	sold_today += count


func _on_lamb_born(_lamb: Node, _mother: Node) -> void:
	born_today += 1


func _on_normal_sale_completed(_count: int, income: int) -> void:
	normal_sale_income_today += income


func _on_order_completed(_order_id: String, _count: int, income: int) -> void:
	order_income_today += income


func _on_order_expired(_order_id: String) -> void:
	expired_orders_today += 1


func _on_day_changed(new_day: int) -> void:
	show_daily_report(new_day - 1)


func show_daily_report(ended_day: int) -> void:
	var wolf_risk: Dictionary = day_routine_manager.evaluate_wolf_night_risk(ended_day)
	var finance: Dictionary = top_hud.consume_daily_finance_summary()
	var sheep_count: int = world_controller.get_sheep_count()
	var capacity: int = world_controller.get_sheep_capacity()
	var mature_grass: int = world_controller.get_mature_grass_count()
	var total_grass: int = world_controller.get_total_grass_count()
	var risks: Array[String] = []
	if sheep_count > capacity:
		risks.append("牧场超出容量 %d 只" % (sheep_count - capacity))
	if mature_grass < sheep_count:
		risks.append("成熟草少于羊群数量")
	var sick_count: int = world_controller.get_sick_sheep_count()
	if sick_count > 0:
		risks.append("%d 只羊生病" % sick_count)
	if world_controller.get_lamb_count() > 0 and not world_controller.has_building(&"lamb_shelter"):
		risks.append("幼羊没有小羊棚保护")
	match String(wolf_risk.get("outcome", "inactive")):
		"warning":
			risks.append("狼窝靠近，羊群受到惊吓")
		"breach":
			risks.append("狼窝骚扰造成羊走散和金币损失")
	if risks.is_empty():
		risks.append("暂无明显风险")
	report_title.text = "第 %d 天结算" % ended_day
	report_text.text = (
		"羊群变化　买入 %d　出生 %d　出售 %d　当前 %d / 容量 %d\n"
		+ "草场情况　成熟 %d / 总数 %d\n"
		+ "收入支出　收入 %d　支出 %d　净变化 %+d\n"
		+ "市场明细　普通出售 %d　订单交付 %d　过期订单 %d\n"
		+ "傍晚回圈　%s\n"
		+ "夜间防护　%s\n"
		+ "风险提醒　%s"
	) % [
		bought_today, born_today, sold_today, sheep_count, capacity,
		mature_grass, total_grass,
		finance.income, finance.expense, finance.income - finance.expense,
		normal_sale_income_today, order_income_today, expired_orders_today,
		roundup_manager.get_report_text(ended_day),
		day_routine_manager.get_wolf_risk_report_text(ended_day),
		"；".join(risks),
	]
	bought_today = 0
	born_today = 0
	sold_today = 0
	normal_sale_income_today = 0
	order_income_today = 0
	expired_orders_today = 0
	show()
	time_controls.pause_for_report()


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.08, 0.09, 0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel_root := Control.new()
	panel_root.set_anchors_preset(Control.PRESET_CENTER)
	panel_root.offset_left = -300.0
	panel_root.offset_top = -235.0
	panel_root.offset_right = 300.0
	panel_root.offset_bottom = 235.0
	add_child(panel_root)
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	panel_root.add_child(paper)
	var title := TextureRect.new()
	title.position = Vector2(18, -34)
	title.size = Vector2(220, 64)
	title.texture = TITLE_TEXTURE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_SCALE
	panel_root.add_child(title)
	report_title = Label.new()
	report_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	report_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	report_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	report_title.add_theme_font_size_override("font_size", 24)
	report_title.add_theme_color_override("font_color", Color("fff0b0"))
	title.add_child(report_title)
	report_text = Label.new()
	report_text.position = Vector2(42, 64)
	report_text.size = Vector2(516, 320)
	report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_text.add_theme_font_size_override("font_size", 18)
	report_text.add_theme_constant_override("line_spacing", 9)
	report_text.add_theme_color_override("font_color", Color("3d2c22"))
	panel_root.add_child(report_text)
	var continue_button := Button.new()
	continue_button.position = Vector2(218, 402)
	continue_button.size = Vector2(164, 46)
	continue_button.text = "继续下一天"
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.pressed.connect(close_report)
	panel_root.add_child(continue_button)
