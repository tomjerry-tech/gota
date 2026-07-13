extends Control

const BUY_LAMB_PRICE := 200
const SELL_ADULT_PRICE := 320
const PAPER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")
const COIN_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/coin_small.png")
const LAMB_TEXTURE := preload("res://assets/tiny_swords/sheep/lamb/sheep_idle.png")
const ADULT_TEXTURE := preload("res://assets/tiny_swords/sheep/sheep_idle.png")

@onready var world_controller: Node = get_node("../..")
@onready var top_hud: Control = get_node("../TopHUD")
@onready var market_manager: Node = get_node("../../MarketOrderManager")

var lamb_count_label: Label
var adult_count_label: Label
var feedback_label: Label
var quantity_spinbox: SpinBox
var transaction_total_label: Label
var capacity_label: Label
var buy_button: Button
var sell_button: Button
var breeding_title_label: Label
var mother_option: OptionButton
var father_option: OptionButton
var mother_status_label: Label
var father_status_label: Label
var breeding_status_label: Label
var breed_button: Button
var mother_candidates: Array[Node] = []
var father_candidates: Array[Node] = []
var breeding_signature := ""
var normal_page_controls: Array[Control] = []
var market_page: Panel
var market_price_label: Label
var order_list: VBoxContainer
var daily_tab_button: Button
var market_tab_button: Button
var current_page: StringName = &"daily"
var market_signature := ""


func _ready() -> void:
	_build_interface()
	market_manager.market_changed.connect(_on_market_changed)
	_refresh_counts.call_deferred()


func _process(_delta: float) -> void:
	_refresh_counts()
	_refresh_breeding_options()
	_refresh_breeding_details()
	if current_page == &"market":
		_refresh_market_page()


func open_menu() -> void:
	show()
	_refresh_counts()
	_refresh_breeding_options(true)
	_refresh_breeding_details()
	_refresh_market_page(true)


func open_market_page() -> void:
	open_menu()
	_switch_page(&"market")


func close_menu() -> void:
	hide()


func buy_lamb() -> bool:
	var quantity := _get_trade_quantity()
	if world_controller.get_available_sheep_capacity() < quantity:
		_set_feedback("牧场容量不足：当前 %d / %d，本批需要 %d 个空位" % [
			world_controller.get_sheep_count(),
			world_controller.get_sheep_capacity(),
			quantity,
		], false)
		return false
	var total_price := BUY_LAMB_PRICE * quantity
	if not top_hud.spend_money(total_price):
		_set_feedback("金币不足，购买 %d 只幼羊需要 %d 金币" % [quantity, total_price], false)
		return false
	var lambs: Array[Node] = world_controller.add_lambs(quantity)
	if lambs.size() != quantity:
		top_hud.refund_money(total_price)
		_set_feedback("当前无法添加幼羊", false)
		return false
	_set_feedback("购买了 %d 只 0 天幼羊，共花费 %d 金币" % [quantity, total_price], true)
	_refresh_counts()
	return true


func sell_adult_sheep() -> bool:
	var quantity := _get_trade_quantity()
	if get_sellable_adult_count() < quantity:
		_set_feedback("可出售成年羊不足；怀孕母羊不能出售，本批需要 %d 只" % quantity, false)
		return false
	var result: Dictionary = market_manager.sell_at_normal_market(quantity)
	if not result.success:
		_set_feedback(result.message, false)
		return false
	_set_feedback("按今日市价出售 %d 只成年羊，获得 %d 金币" % [result.count, result.income], true)
	_refresh_counts()
	return true


func deliver_market_order(order_id: String) -> bool:
	var result: Dictionary = market_manager.deliver_order(order_id)
	if not result.success:
		_set_feedback(result.message, false)
		_refresh_market_page(true)
		return false
	_set_feedback("订单交付成功：%s，共获得 %d 金币" % ["、".join(result.names), result.income], true)
	_refresh_counts()
	_refresh_market_page(true)
	return true


func get_lamb_count() -> int:
	return world_controller.get_lamb_count()


func get_adult_count() -> int:
	return world_controller.get_adult_sheep_count()


func get_sellable_adult_count() -> int:
	return world_controller.get_sellable_adult_count()


func get_selected_mother() -> Node:
	var index := mother_option.selected if mother_option else -1
	return mother_candidates[index] if index >= 0 and index < mother_candidates.size() else null


func get_selected_father() -> Node:
	var index := father_option.selected if father_option else -1
	return father_candidates[index] if index >= 0 and index < father_candidates.size() else null


func breed_selected_pair() -> bool:
	var mother := get_selected_mother()
	var father := get_selected_father()
	var reason: String = world_controller.get_breeding_failure_reason(mother, father)
	if not reason.is_empty():
		_set_feedback(reason, false)
		return false
	if not world_controller.start_breeding(mother, father):
		_set_feedback("当前无法开始繁育，请重新选择", false)
		return false
	_set_feedback("%s和%s完成配对，预计 %d 只，已预留对应容量" % [
		mother.get_sheep_name(), father.get_sheep_name(), mother.get_expected_lamb_count(),
	], true)
	_refresh_breeding_options(true)
	_refresh_counts()
	return true


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
	var title_label := Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.text = "羊群"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 25)
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

	var count_panel := Panel.new()
	count_panel.position = Vector2(30, 50)
	count_panel.size = Vector2(544, 72)
	count_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.78, 0.66, 0.57, 0.38)))
	add_child(count_panel)
	_add_count_block(count_panel, Vector2(22, 8), LAMB_TEXTURE, "小羊", true)
	_add_count_block(count_panel, Vector2(286, 8), ADULT_TEXTURE, "成年羊", false)

	daily_tab_button = Button.new()
	daily_tab_button.position = Vector2(30, 128)
	daily_tab_button.size = Vector2(264, 34)
	daily_tab_button.text = "日常经营"
	daily_tab_button.toggle_mode = true
	daily_tab_button.add_theme_font_size_override("font_size", 16)
	daily_tab_button.pressed.connect(_switch_page.bind(&"daily"))
	add_child(daily_tab_button)
	market_tab_button = Button.new()
	market_tab_button.position = Vector2(310, 128)
	market_tab_button.size = Vector2(264, 34)
	market_tab_button.text = "市场订单"
	market_tab_button.toggle_mode = true
	market_tab_button.add_theme_font_size_override("font_size", 16)
	market_tab_button.pressed.connect(_switch_page.bind(&"market"))
	add_child(market_tab_button)

	var quantity_panel := Panel.new()
	quantity_panel.position = Vector2(30, 168)
	quantity_panel.size = Vector2(544, 56)
	quantity_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.91, 0.84, 0.69, 0.72)))
	add_child(quantity_panel)
	normal_page_controls.append(quantity_panel)
	var quantity_label := _make_label(Vector2(16, 3), Vector2(96, 28), "交易数量", 16)
	quantity_panel.add_child(quantity_label)
	quantity_spinbox = SpinBox.new()
	quantity_spinbox.position = Vector2(110, 2)
	quantity_spinbox.size = Vector2(94, 30)
	quantity_spinbox.min_value = 1.0
	quantity_spinbox.max_value = 20.0
	quantity_spinbox.step = 1.0
	quantity_spinbox.value = 1.0
	quantity_spinbox.allow_greater = false
	quantity_spinbox.allow_lesser = false
	quantity_spinbox.suffix = "只"
	quantity_spinbox.add_theme_font_size_override("font_size", 16)
	quantity_panel.add_child(quantity_spinbox)
	capacity_label = _make_label(Vector2(220, 3), Vector2(308, 28), "", 16)
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_panel.add_child(capacity_label)
	transaction_total_label = _make_label(Vector2(16, 29), Vector2(512, 24), "", 14)
	transaction_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_panel.add_child(transaction_total_label)

	buy_button = _make_action_button(
		Vector2(30, 230),
		LAMB_TEXTURE,
		"购买幼羊",
		"每只均为 0 天幼羊",
		BUY_LAMB_PRICE,
		"幼羊满 6 天成年，满 8 天后可自动参与繁育。"
	)
	buy_button.pressed.connect(buy_lamb)
	add_child(buy_button)
	normal_page_controls.append(buy_button)

	sell_button = _make_action_button(
		Vector2(316, 230),
		ADULT_TEXTURE,
		"出售成年羊",
		"按年龄从大到小出售",
		market_manager.get_normal_market_price(),
		"只有羊龄满 6 天且未怀孕的成年羊可以出售。"
	)
	sell_button.pressed.connect(sell_adult_sheep)
	add_child(sell_button)
	normal_page_controls.append(sell_button)

	_build_breeding_panel()
	_build_market_page()

	feedback_label = Label.new()
	feedback_label.position = Vector2(30, 666)
	feedback_label.size = Vector2(544, 30)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 16)
	feedback_label.add_theme_color_override("font_color", Color("4f382d"))
	feedback_label.text = "购买幼羊，饲养成年后可以获得更高售价。"
	add_child(feedback_label)
	_switch_page(&"daily", false)


func _build_breeding_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(30, 432)
	panel.size = Vector2(544, 234)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.78, 0.66, 0.57, 0.38)))
	add_child(panel)
	normal_page_controls.append(panel)
	breeding_title_label = _make_label(Vector2(16, 8), Vector2(512, 30), "", 19)
	breeding_title_label.add_theme_color_override("font_color", Color("294b5b"))
	panel.add_child(breeding_title_label)

	var mother_label := _make_label(Vector2(16, 46), Vector2(70, 34), "母羊候选", 16)
	mother_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(mother_label)
	mother_option = _make_breeding_option(Vector2(82, 46))
	panel.add_child(mother_option)
	mother_status_label = _make_label(Vector2(292, 46), Vector2(236, 34), "", 14)
	mother_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(mother_status_label)

	var father_label := _make_label(Vector2(16, 88), Vector2(70, 34), "公羊候选", 16)
	father_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(father_label)
	father_option = _make_breeding_option(Vector2(82, 88))
	panel.add_child(father_option)
	father_status_label = _make_label(Vector2(292, 88), Vector2(236, 34), "", 14)
	father_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(father_status_label)

	breeding_status_label = _make_label(Vector2(16, 130), Vector2(512, 34), "", 14)
	breeding_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breeding_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(breeding_status_label)
	breed_button = Button.new()
	breed_button.position = Vector2(190, 174)
	breed_button.size = Vector2(164, 44)
	breed_button.text = "每日自动配对"
	breed_button.add_theme_font_size_override("font_size", 17)
	breed_button.pressed.connect(breed_selected_pair)
	panel.add_child(breed_button)


func _build_market_page() -> void:
	market_page = Panel.new()
	market_page.position = Vector2(30, 168)
	market_page.size = Vector2(544, 498)
	market_page.add_theme_stylebox_override("panel", _panel_style(Color(0.91, 0.84, 0.69, 0.94)))
	add_child(market_page)
	market_price_label = _make_label(Vector2(16, 10), Vector2(512, 30), "", 20)
	market_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	market_price_label.add_theme_color_override("font_color", Color("294b5b"))
	market_page.add_child(market_price_label)
	var market_hint := _make_label(
		Vector2(18, 42), Vector2(508, 38),
		"普通出售价格每天变化；订单价格更高，但必须整单交付健康且未怀孕的羊。", 14
	)
	market_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	market_page.add_child(market_hint)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 88)
	scroll.size = Vector2(520, 372)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	market_page.add_child(scroll)
	order_list = VBoxContainer.new()
	order_list.custom_minimum_size = Vector2(498, 0)
	order_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_list.add_theme_constant_override("separation", 8)
	scroll.add_child(order_list)
	var expiry_hint := _make_label(Vector2(16, 464), Vector2(512, 26), "订单过期没有惩罚；每天会发布 2 份新订单。", 13)
	expiry_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expiry_hint.add_theme_color_override("font_color", Color("7d5140"))
	market_page.add_child(expiry_hint)


func _switch_page(page: StringName, announce_view := true) -> void:
	current_page = page if page in [&"daily", &"market"] else &"daily"
	for control in normal_page_controls:
		control.visible = current_page == &"daily"
	if market_page:
		market_page.visible = current_page == &"market"
	if daily_tab_button:
		daily_tab_button.button_pressed = current_page == &"daily"
	if market_tab_button:
		market_tab_button.button_pressed = current_page == &"market"
	if current_page == &"market":
		_refresh_market_page(true)
		if announce_view:
			market_manager.mark_market_viewed()


func _on_market_changed() -> void:
	market_signature = ""
	_refresh_counts()
	if current_page == &"market":
		_refresh_market_page(true)


func _refresh_market_page(force := false) -> void:
	if not market_page or not order_list:
		return
	var signature_parts: Array[String] = [
		str(market_manager.get_normal_market_price()),
		str(top_hud.get_day()),
	]
	for order in market_manager.get_orders():
		signature_parts.append("%s:%s" % [order.id, order.status])
	for sheep in world_controller.sheep_group.get_children():
		signature_parts.append("%d:%d:%s:%s:%s" % [
			sheep.get_sheep_id(), sheep.get_age_days(), sheep.get_sex(),
			str(sheep.is_healthy()), str(sheep.is_pregnant()),
		])
	var signature := "|".join(signature_parts)
	if not force and signature == market_signature:
		return
	market_signature = signature
	market_price_label.text = "今日普通市价　%d 金币 / 成年羊" % market_manager.get_normal_market_price()
	for child in order_list.get_children():
		order_list.remove_child(child)
		child.queue_free()
	var visible_orders: Array[Dictionary] = []
	for order in market_manager.get_orders():
		if order.status in [market_manager.STATUS_ACTIVE, market_manager.STATUS_COMPLETED]:
			visible_orders.append(order)
	visible_orders.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			if first.status == second.status:
				return int(first.deadline_day) < int(second.deadline_day)
			return first.status == market_manager.STATUS_ACTIVE
	)
	if visible_orders.is_empty():
		var empty := _make_label(Vector2.ZERO, Vector2(498, 80), "当前没有市场订单", 16)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		order_list.add_child(empty)
		return
	for order in visible_orders:
		order_list.add_child(_make_market_order_row(order))


func _make_market_order_row(order: Dictionary) -> Panel:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(498, 126)
	row.add_theme_stylebox_override("panel", _card_style(Color("eee2bd"), Color("a89570")))
	var title := _make_label(Vector2(12, 7), Vector2(260, 25), order.title, 17)
	title.add_theme_color_override("font_color", Color("294b5b"))
	row.add_child(title)
	var deadline := _make_label(Vector2(280, 7), Vector2(202, 25), "截止第 %d 天" % order.deadline_day, 14)
	deadline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deadline.add_theme_color_override("font_color", Color("8b5b24"))
	row.add_child(deadline)
	var description := _make_label(Vector2(12, 34), Vector2(300, 24), order.description, 14)
	row.add_child(description)
	var total_price := int(order.quantity) * int(order.unit_price)
	var price := _make_label(
		Vector2(318, 34), Vector2(164, 24),
		"%d × %d = %d" % [order.quantity, order.unit_price, total_price], 14
	)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	var status := _make_label(Vector2(12, 63), Vector2(340, 50), "", 13)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(status)
	var action := Button.new()
	action.position = Vector2(356, 72)
	action.size = Vector2(126, 38)
	action.add_theme_font_size_override("font_size", 14)
	if order.status == market_manager.STATUS_COMPLETED:
		status.text = "已交付：%s" % "、".join(order.get("delivered_names", []))
		status.add_theme_color_override("font_color", Color("35644c"))
		action.text = "已完成"
		action.disabled = true
	else:
		var candidates: Array[Node] = market_manager.get_order_candidates(order.id)
		var names: Array[String] = []
		for sheep in candidates.slice(0, int(order.quantity)):
			names.append(sheep.get_sheep_name())
		status.text = (
			"可交付：%s" % "、".join(names)
			if candidates.size() >= int(order.quantity)
			else "条件不足：当前 %d / %d 只符合" % [candidates.size(), order.quantity]
		)
		status.add_theme_color_override(
			"font_color",
			Color("35644c") if candidates.size() >= int(order.quantity) else Color("9a4035")
		)
		action.text = "交付 %d" % total_price
		action.disabled = candidates.size() < int(order.quantity)
		action.pressed.connect(deliver_market_order.bind(String(order.id)))
	row.add_child(action)
	return row


func _make_breeding_option(position_value: Vector2) -> OptionButton:
	var option := OptionButton.new()
	option.position = position_value
	option.size = Vector2(196, 34)
	option.add_theme_font_size_override("font_size", 15)
	return option


func _add_count_block(parent: Control, position_value: Vector2, texture: Texture2D, label_text: String, is_lamb_count: bool) -> void:
	var icon := TextureRect.new()
	icon.position = position_value
	icon.size = Vector2(56, 56)
	icon.texture = _first_frame(texture)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)
	var name_label := Label.new()
	name_label.position = position_value + Vector2(62, 2)
	name_label.size = Vector2(82, 24)
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("4a3025"))
	parent.add_child(name_label)
	var count_label := Label.new()
	count_label.position = position_value + Vector2(62, 23)
	count_label.size = Vector2(110, 32)
	count_label.add_theme_font_size_override("font_size", 25)
	count_label.add_theme_color_override("font_color", Color("2e4f5f"))
	parent.add_child(count_label)
	if is_lamb_count:
		lamb_count_label = count_label
	else:
		adult_count_label = count_label


func _make_action_button(position_value: Vector2, texture: Texture2D, title_text: String, subtitle: String, price: int, description: String) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = Vector2(258, 196)
	button.text = ""
	button.add_theme_stylebox_override("normal", _card_style(Color("eee2bd"), Color("a89570")))
	button.add_theme_stylebox_override("hover", _card_style(Color("fff0c9"), Color("638ca0")))
	button.add_theme_stylebox_override("pressed", _card_style(Color("d8e6d0"), Color("315d72")))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.position = Vector2(14, 18)
	icon.size = Vector2(92, 92)
	icon.texture = _first_frame(texture)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var title_label := _make_label(Vector2(108, 22), Vector2(134, 34), title_text, 22)
	button.add_child(title_label)
	var subtitle_label := _make_label(Vector2(108, 58), Vector2(134, 46), subtitle, 14)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(subtitle_label)
	var coin := TextureRect.new()
	coin.position = Vector2(108, 108)
	coin.size = Vector2(22, 22)
	coin.texture = COIN_TEXTURE
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(coin)
	var price_label := _make_label(Vector2(134, 104), Vector2(104, 30), "%d / 只" % price, 19)
	price_label.name = "PriceLabel"
	button.add_child(price_label)
	var description_label := _make_label(Vector2(16, 140), Vector2(226, 44), description, 14)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(description_label)
	return button


func _first_frame(texture: Texture2D) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(0, 0, 128, 128)
	return frame


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


func _card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style


func _refresh_counts() -> void:
	if lamb_count_label:
		lamb_count_label.text = str(get_lamb_count())
	if adult_count_label:
		adult_count_label.text = str(get_adult_count())
	var quantity := _get_trade_quantity()
	if transaction_total_label:
		transaction_total_label.text = "买 %d 金币　卖 %d 金币" % [
			BUY_LAMB_PRICE * quantity,
			market_manager.get_normal_market_price() * quantity,
		]
	if capacity_label:
		var sheep_count: int = world_controller.get_sheep_count()
		var capacity: int = world_controller.get_sheep_capacity()
		var pending_births: int = world_controller.get_reserved_lamb_count()
		capacity_label.text = "当前 %d + 待出生 %d / 容量 %d" % [sheep_count, pending_births, capacity]
		capacity_label.add_theme_color_override(
			"font_color",
			Color("a33b32") if sheep_count > capacity else Color("2e4f5f")
		)
	if sell_button:
		sell_button.disabled = get_sellable_adult_count() < quantity
		var sell_price_label := sell_button.get_node_or_null("PriceLabel") as Label
		if sell_price_label:
			sell_price_label.text = "%d / 只" % market_manager.get_normal_market_price()
	if breeding_title_label:
		breeding_title_label.text = "自动繁育　公 %d　母 %d　怀孕 %d　待出生 %d" % [
			world_controller.get_male_sheep_count(),
			world_controller.get_female_sheep_count(),
			world_controller.get_pregnant_sheep_count(),
			world_controller.get_reserved_lamb_count(),
		]


func _refresh_breeding_options(force := false) -> void:
	if not mother_option or not father_option:
		return
	var signature_parts: Array[String] = []
	for sheep in world_controller.sheep_group.get_children():
		signature_parts.append("%d:%s:%d:%s:%d:%d:%s:%s" % [
			sheep.get_instance_id(), sheep.get_sheep_name(), sheep.get_age_days(), sheep.get_sex(),
			sheep.get_hunger_percent(), sheep.get_breeding_cooldown_days(),
			str(sheep.is_healthy()), str(sheep.is_pregnant()),
		])
	var new_signature := "|".join(signature_parts)
	if not force and new_signature == breeding_signature:
		return
	var previous_mother := get_selected_mother()
	var previous_father := get_selected_father()
	breeding_signature = new_signature
	mother_candidates.clear()
	father_candidates.clear()
	for sheep in world_controller.sheep_group.get_children():
		if not sheep.can_breed():
			continue
		if sheep.get_sex() == sheep.SEX_FEMALE:
			mother_candidates.append(sheep)
		else:
			father_candidates.append(sheep)
	_rebuild_breeding_option(mother_option, mother_candidates, previous_mother, "暂无可繁育母羊")
	_rebuild_breeding_option(father_option, father_candidates, previous_father, "暂无可繁育公羊")


func _rebuild_breeding_option(option: OptionButton, candidates: Array[Node], previous: Variant, empty_text: String) -> void:
	option.clear()
	if candidates.is_empty():
		option.add_item(empty_text)
		option.disabled = true
		return
	option.disabled = true
	var selected_index := 0
	for index in candidates.size():
		var sheep := candidates[index]
		option.add_item("%s · %d 天" % [sheep.get_sheep_name(), sheep.get_age_days()])
		if is_instance_valid(previous) and sheep == previous:
			selected_index = index
	option.select(selected_index)


func _refresh_breeding_details() -> void:
	if not breeding_status_label:
		return
	var mother := get_selected_mother()
	var father := get_selected_father()
	mother_status_label.text = mother.get_breeding_status_text() if mother else "需健康且满 8 天"
	father_status_label.text = father.get_breeding_status_text() if father else "需健康且满 8 天"
	var reason: String = world_controller.get_breeding_failure_reason(mother, father)
	breeding_status_label.text = (
		"条件满足，下个清晨自动配对；本胎随机 1–%d 只" % mini(5, world_controller.get_available_sheep_capacity())
		if reason.is_empty() else reason
	)
	breeding_status_label.add_theme_color_override("font_color", Color("35644c") if reason.is_empty() else Color("7d5140"))
	breed_button.disabled = true


func _get_trade_quantity() -> int:
	return maxi(1, roundi(quantity_spinbox.value)) if quantity_spinbox else 1


func _set_feedback(message: String, success: bool) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", Color("35644c") if success else Color("9a4035"))
