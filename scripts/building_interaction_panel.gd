extends Control

const PAPER_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")

@onready var top_hud: Control = get_node("../TopHUD")
@onready var routine_manager: Node = get_node("../../DayRoutineManager")

var current_building: Node2D
var title_label: Label
var detail_label: Label
var feedback_label: Label
var rest_button: Button


func _ready() -> void:
	_build_interface()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(current_building):
		close_panel()
		return
	rest_button.disabled = not top_hud.is_night()
	rest_button.text = "安排进屋休息" if top_hud.is_night() else "夜间可以安排休息"


func open_for_building(building: Node2D) -> void:
	current_building = building
	for panel_name in ["BuildMenu", "SheepMenu", "SheepDetailMenu", "MedicalMenu"]:
		var other := get_node_or_null("../%s" % panel_name)
		if other and other.has_method("close_menu"):
			other.close_menu()
	var item_id: StringName = building.get_meta("build_item_id", &"")
	title_label.text = {
		&"dog_house": "牧羊犬小屋",
		&"shepherd_house": "牧民小屋",
		&"lamb_shelter": "小羊棚",
	}.get(item_id, "牧场建筑")
	detail_label.text = {
		&"dog_house": "每座狗窝对应一只牧羊犬。夜间完成休息后，犬只次日恢复满体力。",
		&"shepherd_house": "牧羊人的生活小屋。夜间完成休息后，牧羊人次日恢复满体力。",
		&"lamb_shelter": "保护幼羊并增加牧场容量。夜间可安排当前全部幼羊进棚休息。",
	}.get(item_id, "这座建筑暂时没有可用的夜间操作。")
	feedback_label.text = "当前是夜间，可以安排休息。" if top_hud.is_night() else "等到夜间后可以使用休息功能。"
	show()


func close_panel() -> void:
	hide()
	current_building = null


func _assign_rest() -> void:
	if not is_instance_valid(current_building):
		return
	var result: Dictionary = routine_manager.assign_building_rest(current_building)
	feedback_label.text = result.message
	feedback_label.add_theme_color_override("font_color", Color("35644c") if result.success else Color("9a4035"))


func _build_interface() -> void:
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(paper)
	var title := TextureRect.new()
	title.position = Vector2(14, -28)
	title.size = Vector2(190, 58)
	title.texture = TITLE_TEXTURE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(title)
	title_label = Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("fff0b0"))
	title.add_child(title_label)
	var close_button := Button.new()
	close_button.position = Vector2(300, 10)
	close_button.size = Vector2(30, 30)
	close_button.text = "×"
	close_button.pressed.connect(close_panel)
	add_child(close_button)
	detail_label = Label.new()
	detail_label.position = Vector2(24, 54)
	detail_label.size = Vector2(292, 72)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 15)
	detail_label.add_theme_color_override("font_color", Color("3d2c22"))
	add_child(detail_label)
	rest_button = Button.new()
	rest_button.position = Vector2(64, 136)
	rest_button.size = Vector2(212, 42)
	rest_button.add_theme_font_size_override("font_size", 15)
	rest_button.pressed.connect(_assign_rest)
	add_child(rest_button)
	feedback_label = Label.new()
	feedback_label.position = Vector2(24, 187)
	feedback_label.size = Vector2(292, 44)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 13)
	feedback_label.add_theme_color_override("font_color", Color("7d5140"))
	add_child(feedback_label)
