extends Control

const PAPER_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")

const TOPICS := [
	{
		"title": "开始经营",
		"body": "• 鼠标中键或按住空格拖动画面，滚轮缩放土地。\n• 右上角可暂停或切换 1×、2×、4× 时间。\n• 每天接取 2 个今日任务，完成后记得领取金币。\n• 傍晚前安排羊群回圈，夜间关闭围栏门。",
	},
	{
		"title": "羊群",
		"body": "• 单击羊查看名字、年龄、性别、健康和谱系。\n• 按住羊可拖动，羊只能放回已有土地。\n• 羊会自行找成熟草；生病后应购买药物及时治疗。\n• 成年健康公羊与母羊会自动配对，怀孕后生下 1–5 只幼羊。",
	},
	{
		"title": "牧羊人",
		"body": "• 单击牧羊人后，再单击土地即可移动。\n• 靠近羊群会驱赶，吹口哨会召集附近的羊。\n• 移动和工作消耗体力；夜间点击牧民小屋安排休息。\n• 傍晚有围栏和牧羊犬时，会自动协助羊群回圈。",
	},
	{
		"title": "牧羊犬",
		"body": "• 每座狗窝对应一只牧羊犬，每 10 天增加一座狗窝上限。\n• 单击牧羊犬后使用跟随、驱赶、守住和夜间回圈命令。\n• 白天出现狼迹时可派犬巡查，提高当晚防护。\n• 夜间点击对应狗窝安排休息，次日恢复更多体力。",
	},
	{
		"title": "建筑与安全",
		"body": "• 建造页可放置围栏、小羊棚、狗窝、牧民小屋和新土地。\n• 围栏四面各有一扇门，单击门可独立开关。\n• 小羊棚增加容量并降低幼羊生病概率。\n• 狼群只会袭击未进入关闭围栏的羊，夜间要确认羊群与门。",
	},
]

var topic_buttons: Array[Button] = []
var title_label: Label
var body_label: RichTextLabel
var selected_topic := 0


func _ready() -> void:
	_build_interface()
	_show_topic(0)


func open_menu() -> void:
	show()


func close_menu() -> void:
	hide()


func _show_topic(index: int) -> void:
	selected_topic = clampi(index, 0, TOPICS.size() - 1)
	var topic: Dictionary = TOPICS[selected_topic]
	title_label.text = topic.title
	body_label.text = topic.body
	for button_index in topic_buttons.size():
		topic_buttons[button_index].button_pressed = button_index == selected_topic


func _build_interface() -> void:
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(paper)

	var ribbon := TextureRect.new()
	ribbon.position = Vector2(72, -18)
	ribbon.size = Vector2(456, 92)
	ribbon.texture = TITLE_TEXTURE
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ribbon)

	var heading := Label.new()
	heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading.text = "牧场手册"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("fff0b0"))
	heading.add_theme_color_override("font_shadow_color", Color("172337"))
	heading.add_theme_constant_override("shadow_offset_x", 2)
	heading.add_theme_constant_override("shadow_offset_y", 2)
	ribbon.add_child(heading)

	var labels := ["入门", "羊群", "牧人", "犬只", "建筑"]
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for index in labels.size():
		var button := Button.new()
		button.position = Vector2(34 + index * 106, 82)
		button.size = Vector2(98, 52)
		button.text = labels[index]
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_show_topic.bind(index))
		add_child(button)
		topic_buttons.append(button)

	title_label = Label.new()
	title_label.position = Vector2(44, 156)
	title_label.size = Vector2(512, 42)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("294b5b"))
	add_child(title_label)

	body_label = RichTextLabel.new()
	body_label.position = Vector2(44, 205)
	body_label.size = Vector2(512, 430)
	body_label.fit_content = false
	body_label.scroll_active = true
	body_label.add_theme_font_size_override("normal_font_size", 19)
	body_label.add_theme_color_override("default_color", Color("49362b"))
	body_label.add_theme_constant_override("line_separation", 9)
	add_child(body_label)
