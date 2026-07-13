extends Control

const PAPER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")

var selected_sheep: Node
var avatar: TextureRect
var name_edit: LineEdit
var age_label: Label
var stage_label: Label
var health_label: Label
var breeding_label: Label
var lineage_label: Label
var hunger_bar: ProgressBar
var hunger_value_label: Label


func _ready() -> void:
	_build_interface()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(selected_sheep) or selected_sheep.is_queued_for_deletion():
		close_menu()
		return
	_refresh_profile(false)


func open_for_sheep(sheep: Node) -> void:
	if not is_instance_valid(sheep):
		return
	selected_sheep = sheep
	_refresh_profile(true)
	show()


func close_menu() -> void:
	_commit_name()
	selected_sheep = null
	hide()


func get_selected_sheep() -> Node:
	return selected_sheep


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
	title_label.text = "羊资料"
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

	var content := Panel.new()
	content.position = Vector2(30, 52)
	content.size = Vector2(544, 336)
	content.add_theme_stylebox_override("panel", _panel_style())
	add_child(content)

	avatar = TextureRect.new()
	avatar.position = Vector2(24, 22)
	avatar.size = Vector2(116, 116)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(avatar)

	age_label = _make_label(Vector2(18, 148), Vector2(128, 34), 19)
	age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(age_label)

	var name_title := _make_label(Vector2(166, 20), Vector2(330, 28), 17)
	name_title.text = "名字（可以修改）"
	content.add_child(name_title)
	name_edit = LineEdit.new()
	name_edit.position = Vector2(166, 52)
	name_edit.size = Vector2(338, 44)
	name_edit.max_length = 8
	name_edit.placeholder_text = "输入羊的名字"
	name_edit.select_all_on_focus = true
	name_edit.add_theme_font_size_override("font_size", 21)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_commit_name)
	content.add_child(name_edit)

	stage_label = _make_label(Vector2(166, 116), Vector2(338, 34), 20)
	content.add_child(stage_label)
	health_label = _make_label(Vector2(166, 154), Vector2(338, 30), 18)
	content.add_child(health_label)
	breeding_label = _make_label(Vector2(166, 186), Vector2(338, 30), 17)
	content.add_child(breeding_label)
	lineage_label = _make_label(Vector2(166, 216), Vector2(338, 30), 15)
	content.add_child(lineage_label)

	var hunger_title := _make_label(Vector2(166, 246), Vector2(220, 30), 17)
	hunger_title.text = "饥饿值"
	content.add_child(hunger_title)
	hunger_bar = ProgressBar.new()
	hunger_bar.position = Vector2(166, 274)
	hunger_bar.size = Vector2(270, 30)
	hunger_bar.min_value = 0.0
	hunger_bar.max_value = 100.0
	hunger_bar.show_percentage = false
	content.add_child(hunger_bar)
	hunger_value_label = _make_label(Vector2(444, 272), Vector2(60, 32), 18)
	hunger_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(hunger_value_label)

	var hint := _make_label(Vector2(24, 307), Vector2(480, 26), 13)
	hint.text = "修改名字后按回车，或点击输入框外保存。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("665044"))
	content.add_child(hint)


func _refresh_profile(refresh_name: bool) -> void:
	if not is_instance_valid(selected_sheep):
		return
	var sprite := selected_sheep as AnimatedSprite2D
	if sprite and sprite.sprite_frames.has_animation(&"idle"):
		avatar.texture = sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if refresh_name or not name_edit.has_focus():
		name_edit.text = selected_sheep.get_sheep_name()
	var age_days: int = selected_sheep.get_age_days()
	age_label.text = "存活 %d 天" % age_days
	stage_label.text = "成长阶段：%s　性别：%s" % [
		"成年羊" if selected_sheep.is_adult() else "幼羊",
		selected_sheep.get_sex_text(),
	]
	health_label.text = "健康状态：%s" % selected_sheep.get_health_text()
	health_label.add_theme_color_override(
		"font_color",
		Color("35644c") if selected_sheep.is_healthy() else Color("a33b32")
	)
	var breeding_text: String = selected_sheep.get_breeding_status_text()
	var world_controller := get_node_or_null("../..")
	if (
		world_controller
		and world_controller.has_building(&"lamb_shelter")
		and (not selected_sheep.is_adult() or selected_sheep.is_pregnant())
	):
		breeding_text += " · 小羊棚保护"
	breeding_label.text = "繁育状态：%s" % breeding_text
	breeding_label.add_theme_color_override(
		"font_color",
		Color("a34f68") if selected_sheep.is_pregnant() else Color("4d5860")
	)
	lineage_label.text = "谱系：%s" % world_controller.get_lineage_text(selected_sheep)
	lineage_label.add_theme_color_override("font_color", Color("294b5b"))
	var hunger_value: int = selected_sheep.get_hunger_percent()
	hunger_bar.value = hunger_value
	hunger_value_label.text = "%d / 100" % hunger_value


func _on_name_submitted(_value: String) -> void:
	_commit_name()
	name_edit.release_focus()


func _commit_name() -> void:
	if not is_instance_valid(selected_sheep) or not name_edit:
		return
	var new_name := name_edit.text.strip_edges()
	if new_name.is_empty():
		name_edit.text = selected_sheep.get_sheep_name()
		return
	selected_sheep.set_sheep_name(new_name)
	name_edit.text = selected_sheep.get_sheep_name()


func _make_label(position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("3d2c22"))
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.78, 0.66, 0.57, 0.38)
	style.border_color = Color(0.42, 0.32, 0.28, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style
