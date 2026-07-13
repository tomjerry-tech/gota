extends Control

const PAPER_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/bottom_toolbar/toolbar_paper.png")

@onready var world_controller: Node = get_node("../..")
@onready var player: AnimatedSprite2D = get_node("../../Island/Shepherd")
@onready var world_camera: Camera2D = get_node("../../WorldCamera")
@onready var routine_manager: Node = get_node("../../DayRoutineManager")

var title_label: Label
var detail_label: Label
var primary_button: Button
var secondary_button: Button
var current_entity: Variant


func _ready() -> void:
	_build_interface()
	world_controller.selection_changed.connect(_on_selection_changed)
	_refresh()


func _process(_delta: float) -> void:
	if is_instance_valid(current_entity):
		_refresh()
	elif current_entity != null:
		current_entity = null
		_refresh()


func _on_selection_changed(entity: Variant) -> void:
	current_entity = entity
	_refresh()


func _refresh() -> void:
	primary_button.hide()
	secondary_button.hide()
	if not is_instance_valid(current_entity):
		title_label.text = "操作信息"
		detail_label.text = "点击羊、牧羊人、牧羊犬或小屋，查看当前对象可以执行的操作。"
		return
	if current_entity == player:
		title_label.text = "牧羊人"
		detail_label.text = "体力 %d%%（%s）。移动、驱赶和口哨消耗体力；夜间进牧民小屋可在次日完全恢复。" % [
			player.get_stamina_percent(), player.get_stamina_state_text(),
		]
		_setup_button(primary_button, "吹口哨", _whistle)
		_setup_button(secondary_button, "镜头定位", _focus_selected)
		return
	if current_entity is AnimatedSprite2D and current_entity.has_method("get_sheep_name"):
		var sheep: Node = current_entity
		title_label.text = "%s · %s%s" % [
			sheep.get_sheep_name(), sheep.get_sex_text(), " · 走失" if sheep.is_lost() else "",
		]
		detail_label.text = "%d 天 · 第%d代 · %s · 饥饿 %d%%。按住拖动可搬运，单击打开资料并修改名字。" % [
			sheep.get_age_days(), sheep.get_generation(), sheep.get_health_text(), sheep.get_hunger_percent(),
		]
		_setup_button(primary_button, "查看资料", _open_sheep_profile)
		return
	if current_entity is AnimatedSprite2D and current_entity.has_method("set_command_mode"):
		var dog: AnimatedSprite2D = current_entity
		title_label.text = "牧羊犬 %d" % (dog.dog_index + 1)
		detail_label.text = "体力 %d%%（%s）。狼窝防护受体力影响；%s" % [
			dog.get_stamina_percent(), dog.get_stamina_state_text(), routine_manager.get_wolf_patrol_status(),
		]
		if routine_manager.has_pending_wolf_tracks() and not routine_manager.wolf_patrol_active:
			_setup_button(primary_button, "巡查狼迹", _patrol_wolf_tracks)
			_setup_button(secondary_button, "镜头定位", _focus_selected)
		else:
			_setup_button(primary_button, "镜头定位", _focus_selected)
		return
	if current_entity is Node and current_entity.has_meta("build_item_id"):
		var item_id: StringName = current_entity.get_meta("build_item_id", &"")
		title_label.text = {
			&"dog_house": "牧羊犬小屋",
			&"shepherd_house": "牧民小屋",
			&"lamb_shelter": "小羊棚",
		}.get(item_id, "牧场建筑")
		detail_label.text = "夜间点击建筑安排对应角色休息；完成休息后，次日恢复满体力并自动回到牧场。"
		_setup_button(primary_button, "镜头定位", _focus_selected)


func _setup_button(button: Button, text_value: String, callback: Callable) -> void:
	button.text = text_value
	for connection in button.pressed.get_connections():
		button.pressed.disconnect(connection.callable)
	button.pressed.connect(callback)
	button.show()


func _whistle() -> void:
	player.use_whistle()


func _focus_selected() -> void:
	if current_entity is Node2D:
		world_camera.focus_on_world_position(current_entity.global_position)


func _patrol_wolf_tracks() -> void:
	if is_instance_valid(current_entity):
		routine_manager.request_wolf_patrol(current_entity)
		_refresh()


func _open_sheep_profile() -> void:
	if is_instance_valid(current_entity):
		world_controller.open_sheep_profile(current_entity)


func _build_interface() -> void:
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	title_label = Label.new()
	title_label.position = Vector2(24, 9)
	title_label.size = Vector2(150, 46)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color("294b5b"))
	add_child(title_label)
	detail_label = Label.new()
	detail_label.position = Vector2(184, 8)
	detail_label.size = Vector2(350, 48)
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", Color("3d2c22"))
	add_child(detail_label)
	primary_button = _make_button(Vector2(546, 13))
	secondary_button = _make_button(Vector2(644, 13))
	add_child(primary_button)
	add_child(secondary_button)


func _make_button(position_value: Vector2) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = Vector2(90, 38)
	button.add_theme_font_size_override("font_size", 13)
	return button
