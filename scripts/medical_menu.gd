extends Control

signal sheep_treated(sheep: Node)

const MEDICINE_PRICE := 60
const PAPER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")
const COIN_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/coin_small.png")
const MEDICAL_TEXTURE := preload("res://assets/tiny_swords/ui/bottom_toolbar/medical.png")

@onready var world_controller: Node = get_node("../..")
@onready var top_hud: Control = get_node("../TopHUD")

var medicine_inventory := 0
var inventory_label: Label
var sick_count_label: Label
var feedback_label: Label
var list_container: VBoxContainer


func _ready() -> void:
	_build_interface()
	world_controller.sheep_added.connect(_on_flock_changed)
	world_controller.sheep_sold.connect(_on_flock_changed)
	call_deferred("_sync_sheep_connections")
	call_deferred("_refresh")


func open_menu() -> void:
	_sync_sheep_connections()
	_refresh()
	show()


func close_menu() -> void:
	hide()


func get_medicine_inventory() -> int:
	return medicine_inventory


func get_save_data() -> Dictionary:
	return {"medicine_inventory": medicine_inventory}


func restore_save_data(data: Dictionary) -> void:
	medicine_inventory = maxi(0, int(data.get("medicine_inventory", 0)))
	_sync_sheep_connections()
	_refresh()


func buy_medicine() -> bool:
	if not top_hud.spend_money(MEDICINE_PRICE):
		_set_feedback("金币不足：普通药物需要 %d 金币" % MEDICINE_PRICE, false)
		return false
	medicine_inventory += 1
	_set_feedback("已购买 1 份普通药物", true)
	_refresh()
	return true


func treat_sheep(sheep: Node) -> bool:
	if not is_instance_valid(sheep) or sheep.is_queued_for_deletion():
		_set_feedback("这只羊已经不在牧场中", false)
		_refresh()
		return false
	if sheep.is_healthy():
		_set_feedback("%s很健康，不需要治疗" % sheep.get_sheep_name(), false)
		return false
	if medicine_inventory <= 0:
		_set_feedback("药物库存不足，请先购买普通药物", false)
		return false
	if not sheep.treat():
		_set_feedback("治疗未生效，请重新选择病羊", false)
		return false
	medicine_inventory -= 1
	_set_feedback("%s已经恢复健康" % sheep.get_sheep_name(), true)
	sheep_treated.emit(sheep)
	_refresh()
	return true


func get_sick_sheep() -> Array[Node]:
	var sick_sheep: Array[Node] = []
	for sheep in world_controller.sheep_group.get_children():
		if sheep.has_method("is_healthy") and not sheep.is_healthy():
			sick_sheep.append(sheep)
	return sick_sheep


func _on_flock_changed(_count: int) -> void:
	call_deferred("_sync_sheep_connections")
	call_deferred("_refresh")


func _on_health_changed(_sheep: Node, _healthy: bool) -> void:
	_refresh()


func _sync_sheep_connections() -> void:
	for sheep in world_controller.sheep_group.get_children():
		if sheep.has_signal("health_changed") and not sheep.health_changed.is_connected(_on_health_changed):
			sheep.health_changed.connect(_on_health_changed)


func _refresh() -> void:
	if not inventory_label:
		return
	var sick_sheep := get_sick_sheep()
	inventory_label.text = "普通药物库存　%d" % medicine_inventory
	sick_count_label.text = "生病羊　%d 只" % sick_sheep.size()
	for child in list_container.get_children():
		child.queue_free()
	if sick_sheep.is_empty():
		var empty_label := _make_label(Vector2.ZERO, Vector2(500, 46), "目前没有生病的羊", 17)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color("5f6c55"))
		list_container.add_child(empty_label)
		return
	for sheep in sick_sheep:
		list_container.add_child(_make_sheep_row(sheep))


func _make_sheep_row(sheep: Node) -> Control:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(500, 56)
	row.add_theme_stylebox_override("panel", _panel_style(Color(0.91, 0.84, 0.69, 0.76)))
	var info := _make_label(
		Vector2(14, 5),
		Vector2(344, 46),
		"%s　%d 天　%s" % [
			sheep.get_sheep_name(),
			sheep.get_age_days(),
			"成年羊" if sheep.is_adult() else "幼羊",
		],
		16
	)
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(info)
	var treat_button := Button.new()
	treat_button.position = Vector2(380, 9)
	treat_button.size = Vector2(104, 38)
	treat_button.text = "治疗"
	treat_button.tooltip_text = "消耗 1 份普通药物"
	treat_button.add_theme_font_size_override("font_size", 16)
	treat_button.pressed.connect(treat_sheep.bind(sheep))
	row.add_child(treat_button)
	return row


func _build_interface() -> void:
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)

	var title := TextureRect.new()
	title.position = Vector2(18, -38)
	title.size = Vector2(190, 64)
	title.texture = TITLE_TEXTURE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_SCALE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var title_label := _make_label(Vector2.ZERO, title.size, "医疗", 25)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color("fff0b0"))
	title_label.add_theme_color_override("font_shadow_color", Color("172337"))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title.add_child(title_label)

	var close_button := Button.new()
	close_button.position = Vector2(548, 16)
	close_button.size = Vector2(34, 34)
	close_button.text = "×"
	close_button.tooltip_text = "关闭"
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(close_menu)
	add_child(close_button)

	var summary := Panel.new()
	summary.position = Vector2(30, 50)
	summary.size = Vector2(544, 94)
	summary.add_theme_stylebox_override("panel", _panel_style(Color(0.78, 0.66, 0.57, 0.38)))
	add_child(summary)
	var icon := TextureRect.new()
	icon.position = Vector2(16, 14)
	icon.size = Vector2(64, 64)
	icon.texture = MEDICAL_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(icon)
	inventory_label = _make_label(Vector2(92, 10), Vector2(260, 34), "", 20)
	summary.add_child(inventory_label)
	sick_count_label = _make_label(Vector2(92, 46), Vector2(220, 30), "", 17)
	summary.add_child(sick_count_label)
	var buy_button := Button.new()
	buy_button.position = Vector2(374, 21)
	buy_button.size = Vector2(150, 52)
	buy_button.text = "购买 1 份　%d" % MEDICINE_PRICE
	buy_button.icon = COIN_TEXTURE
	buy_button.add_theme_font_size_override("font_size", 16)
	buy_button.pressed.connect(buy_medicine)
	summary.add_child(buy_button)

	var list_scroll := ScrollContainer.new()
	list_scroll.position = Vector2(30, 158)
	list_scroll.size = Vector2(544, 208)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(list_scroll)
	list_container = VBoxContainer.new()
	list_container.custom_minimum_size = Vector2(500, 0)
	list_container.add_theme_constant_override("separation", 7)
	list_scroll.add_child(list_container)

	feedback_label = _make_label(Vector2(30, 374), Vector2(544, 42), "购买药物后，可在病羊列表中进行治疗", 16)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(feedback_label)


func _set_feedback(message: String, success: bool) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", Color("35644c") if success else Color("9a4035"))


func _make_label(position_value: Vector2, size_value: Vector2, text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("3d2c22"))
	return label


func _panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.42, 0.32, 0.28, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style
