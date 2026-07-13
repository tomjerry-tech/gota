extends Control

signal build_item_selected(item_id: StringName, item_data: Dictionary)
signal demolition_selected

const CARD_SCRIPT := preload("res://scripts/build_card.gd")
const PAPER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")
const COIN_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/coin_small.png")
const FENCE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/fence.png")
const DOG_HOUSE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/dog_house.png")
const SHEPHERD_HOUSE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/shepherd_house.png")
const LAMB_SHELTER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/lamb_shelter.png")
const LAND_EXPAND_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/land_expand.png")
const DEMOLITION_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/demolition_hammer.png")

const ITEMS := [
	{
		"id": &"fence",
		"display_name": "木围栏",
		"price": 8,
		"price_suffix": "/ 段",
		"short_text": "圈定实际放牧范围",
		"description": "围栏围成的内部区域会成为羊群放牧区。圈内羊优先在同一围栏内散步和寻找草，围栏边缘同时保留实体碰撞。",
		"instruction": "单击卡片查看说明；双击后，在草地上按住鼠标并向外拖出围栏。",
		"icon": FENCE_TEXTURE,
	},
	{
		"id": &"dog_house",
		"display_name": "牧羊犬小屋",
		"price": 180,
		"price_suffix": "",
		"short_text": "每座狗窝对应一只牧羊犬",
		"description": "第 1–10 天最多建造 1 座，之后每 10 天增加 1 座上限。点击犬只后可选择跟随、驱赶或守住；夜间完成休息后，次日恢复满体力。",
		"instruction": "单击卡片查看说明；双击后，在空闲草地按住拖动，松开后建造。",
		"icon": DOG_HOUSE_TEXTURE,
	},
	{
		"id": &"shepherd_house",
		"display_name": "牧民小屋",
		"price": 320,
		"price_suffix": "",
		"short_text": "牧民的生活与工具住所",
		"description": "供牧民居住并收纳日常工具。夜间安排牧羊人完成休息，次日恢复满体力；疲惫时移动和赶羊效率会下降。",
		"instruction": "单击卡片查看说明；双击后，在空闲草地按住拖动，松开后建造。",
		"icon": SHEPHERD_HOUSE_TEXTURE,
	},
	{
		"id": &"lamb_shelter",
		"display_name": "小羊棚",
		"price": 240,
		"price_suffix": "",
		"short_text": "容量 +4，保护幼羊健康",
		"description": "每座小羊棚增加 4 点牧场容量，并将幼羊每日生病概率降低一半，最低降至 1%；夜间可以安排幼羊进棚休息。",
		"instruction": "单击卡片查看说明；双击后，在空闲草地按住拖动，松开后建造。",
		"icon": LAMB_SHELTER_TEXTURE,
	},
	{
		"id": &"land_expand",
		"display_name": "土地扩充",
		"price": 450,
		"price_suffix": "",
		"short_text": "增加一块同等大小的草地",
		"description": "每次增加一块与初始草地同等大小的区块。新区块提供 10 点牧场容量和 9 株固定可食用草，并可继续向外扩充。",
		"instruction": "单击卡片查看说明；双击后，把鼠标移到土地外侧的相邻位置并点击确认。",
		"icon": LAND_EXPAND_TEXTURE,
	},
]

const LAND_TYPE_DATA := {
	&"pasture": {
		"label": "放牧草地",
		"summary": "9 株草 · 自然放牧区",
		"description": "生成 9 株可食用草、1 棵树、2 个灌木和 2 块石头，并增加 10 点牧场容量。",
	},
	&"homestead": {
		"label": "生活用地",
		"summary": "无自然物 · 集中建造区",
		"description": "不生成树、灌木、石头和可食用草，保留完整空地用于小屋与围栏，并增加 10 点牧场容量。",
	},
}

var selected_item: Dictionary = {}
var card_buttons: Array[Button] = []
var card_grid: GridContainer
var name_label: Label
var summary_label: Label
var price_label: Label
var description_label: Label
var instruction_label: Label
var demolish_button: Button
var land_type_selector: HBoxContainer
var land_type_buttons: Array[Button] = []
var selected_land_type: StringName = &"pasture"


func _ready() -> void:
	_build_interface()
	_select_item(0)


func open_menu() -> void:
	show()


func close_menu() -> void:
	hide()


func get_selected_item_id() -> StringName:
	return selected_item.id if not selected_item.is_empty() else &""


func get_item_count() -> int:
	return ITEMS.size()


func get_selected_land_type() -> StringName:
	return selected_land_type


func _build_interface() -> void:
	var paper := TextureRect.new()
	paper.name = "Paper"
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
	title_label.text = "建造"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.add_theme_color_override("font_color", Color("fff0b0"))
	title_label.add_theme_color_override("font_shadow_color", Color("172337"))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title.add_child(title_label)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.position = Vector2(548, 16)
	close_button.size = Vector2(34, 34)
	close_button.text = "×"
	close_button.tooltip_text = "关闭"
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(close_menu)
	add_child(close_button)

	card_grid = GridContainer.new()
	card_grid.name = "CardGrid"
	card_grid.columns = 2
	card_grid.position = Vector2(30, 60)
	card_grid.size = Vector2(268, 306)
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 12)
	add_child(card_grid)

	for index in ITEMS.size():
		var item: Dictionary = ITEMS[index]
		var card := Button.new()
		card.set_script(CARD_SCRIPT)
		card.name = "Card%s" % item.id
		card.custom_minimum_size = Vector2(122, 94)
		card.text = ""
		card.icon = item.icon
		card.expand_icon = false
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.tooltip_text = ""
		card.toggle_mode = true
		card.add_theme_stylebox_override("normal", _card_style(Color("eee2bd"), Color("a89570")))
		card.add_theme_stylebox_override("hover", _card_style(Color("fff0c9"), Color("638ca0")))
		card.add_theme_stylebox_override("pressed", _card_style(Color("d8e6d0"), Color("315d72")))
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		card.set("item_id", item.id)
		card.set("item_data", item)
		card.pressed.connect(_select_item.bind(index))
		card.gui_input.connect(_on_card_gui_input.bind(index))
		card_grid.add_child(card)
		var card_label := Label.new()
		card_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		card_label.offset_top = -28.0
		card_label.offset_bottom = -4.0
		card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_label.text = item.display_name
		card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_label.add_theme_font_size_override("font_size", 16)
		card_label.add_theme_color_override("font_color", Color("3d2c22"))
		card.add_child(card_label)
		card_buttons.append(card)

	var detail_panel := Panel.new()
	detail_panel.name = "Details"
	detail_panel.position = Vector2(316, 60)
	detail_panel.size = Vector2(258, 306)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.78, 0.66, 0.57, 0.45)
	detail_style.border_color = Color(0.42, 0.32, 0.28, 0.45)
	detail_style.set_border_width_all(2)
	detail_style.set_corner_radius_all(5)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	add_child(detail_panel)

	name_label = _make_label(Vector2(18, 14), Vector2(224, 34), 24)
	detail_panel.add_child(name_label)
	summary_label = _make_label(Vector2(18, 48), Vector2(224, 28), 15)
	detail_panel.add_child(summary_label)

	var coin_icon := TextureRect.new()
	coin_icon.position = Vector2(18, 82)
	coin_icon.size = Vector2(22, 22)
	coin_icon.texture = COIN_TEXTURE
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_panel.add_child(coin_icon)
	price_label = _make_label(Vector2(44, 78), Vector2(190, 30), 18)
	detail_panel.add_child(price_label)

	description_label = _make_label(Vector2(18, 116), Vector2(224, 116), 15)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(description_label)
	instruction_label = _make_label(Vector2(18, 240), Vector2(224, 54), 14)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_color_override("font_color", Color("4f382d"))
	detail_panel.add_child(instruction_label)
	_create_land_type_selector(detail_panel)
	_create_demolish_button()


func _create_land_type_selector(parent: Control) -> void:
	land_type_selector = HBoxContainer.new()
	land_type_selector.name = "LandTypeSelector"
	land_type_selector.position = Vector2(18, 216)
	land_type_selector.size = Vector2(224, 40)
	land_type_selector.add_theme_constant_override("separation", 6)
	parent.add_child(land_type_selector)
	var group := ButtonGroup.new()
	for land_type: StringName in [&"pasture", &"homestead"]:
		var button := Button.new()
		button.name = "PastureButton" if land_type == &"pasture" else "HomesteadButton"
		button.custom_minimum_size = Vector2(109, 40)
		button.text = LAND_TYPE_DATA[land_type].label
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_stylebox_override("normal", _card_style(Color("eee2bd"), Color("a89570")))
		button.add_theme_stylebox_override("hover", _card_style(Color("fff0c9"), Color("638ca0")))
		button.add_theme_stylebox_override("pressed", _card_style(Color("d8e6d0"), Color("315d72")))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(set_land_type.bind(land_type))
		land_type_selector.add_child(button)
		land_type_buttons.append(button)
	land_type_selector.hide()


func _create_demolish_button() -> void:
	demolish_button = Button.new()
	demolish_button.name = "DemolishButton"
	demolish_button.custom_minimum_size = Vector2(122, 94)
	demolish_button.tooltip_text = "拆除已建造的围栏或小屋"
	demolish_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	demolish_button.add_theme_stylebox_override("normal", _card_style(Color("eee2bd"), Color("a89570")))
	demolish_button.add_theme_stylebox_override("hover", _card_style(Color("fff0c9"), Color("638ca0")))
	demolish_button.add_theme_stylebox_override("pressed", _card_style(Color("d8e6d0"), Color("315d72")))
	demolish_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var first_frame := AtlasTexture.new()
	first_frame.atlas = DEMOLITION_TEXTURE
	first_frame.region = Rect2(0, 0, 128, 128)
	demolish_button.icon = first_frame
	demolish_button.expand_icon = false
	demolish_button.add_theme_constant_override("icon_max_width", 58)
	demolish_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	demolish_button.pressed.connect(func() -> void: demolition_selected.emit())
	card_grid.add_child(demolish_button)
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -27.0
	label.offset_bottom = -3.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "拆除"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("3d2c22"))
	demolish_button.add_child(label)


func _make_label(position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("33251d"))
	return label


func _card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_top = 5.0
	style.content_margin_bottom = 24.0
	return style


func _select_item(index: int) -> void:
	selected_item = ITEMS[index]
	_refresh_selected_item_details()
	for button_index in card_buttons.size():
		card_buttons[button_index].button_pressed = button_index == index


func set_land_type(land_type: StringName) -> void:
	if not LAND_TYPE_DATA.has(land_type):
		return
	selected_land_type = land_type
	_update_land_type_button_states()
	if not selected_item.is_empty() and selected_item.id == &"land_expand":
		_refresh_selected_item_details()


func _update_land_type_button_states() -> void:
	for index in land_type_buttons.size():
		land_type_buttons[index].button_pressed = (
			(index == 0 and selected_land_type == &"pasture")
			or (index == 1 and selected_land_type == &"homestead")
		)


func _refresh_selected_item_details() -> void:
	name_label.text = selected_item.display_name
	price_label.text = "%d%s" % [selected_item.price, selected_item.price_suffix]
	if selected_item.id == &"land_expand":
		var type_data: Dictionary = LAND_TYPE_DATA[selected_land_type]
		summary_label.text = type_data.summary
		description_label.text = type_data.description
		description_label.size.y = 94.0
		instruction_label.position.y = 262.0
		instruction_label.size.y = 38.0
		instruction_label.text = "选择类型后，双击卡片并点击相邻土地。"
		land_type_selector.show()
		_update_land_type_button_states()
	else:
		summary_label.text = selected_item.short_text
		description_label.text = selected_item.description
		description_label.size.y = 116.0
		instruction_label.position.y = 240.0
		instruction_label.size.y = 54.0
		instruction_label.text = selected_item.instruction
		land_type_selector.hide()


func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.double_click
	):
		_activate_item(index)


func _activate_item(index: int) -> void:
	_select_item(index)
	var item_data := selected_item.duplicate()
	if selected_item.id == &"land_expand":
		item_data.land_type = selected_land_type
	build_item_selected.emit(selected_item.id, item_data)
