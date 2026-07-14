extends Control

signal story_action_requested(action_id: StringName)
signal story_closed(event_id: StringName)
signal mode_changed(mode: StringName)

const PAPER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")
const COIN_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/coin_small.png")
const SHEPHERD_TEXTURE: Texture2D = preload("res://assets/tiny_swords/units/blue_pawn_idle.png")

@onready var newbie_commission: Control = get_node("../NewbieCommission")

var mode: StringName = &""
var current_story_id: StringName = &""
var task_manager: Node
var progression_manager: Node
var commission_was_visible := false
var title_label: Label
var content_root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_frame()


func get_mode() -> StringName:
	return mode


func show_tasks(manager: Node) -> bool:
	if visible and mode == &"story":
		return false
	_prepare_open()
	mode = &"tasks"
	task_manager = manager
	current_story_id = &""
	title_label.text = "今日任务"
	refresh_tasks()
	show()
	mode_changed.emit(mode)
	return true


func show_story(event_data: Dictionary) -> void:
	_prepare_open()
	mode = &"story"
	current_story_id = event_data.id
	title_label.text = event_data.title
	_build_story_content(event_data)
	show()
	mode_changed.emit(mode)


func show_records(manager: Node) -> bool:
	if visible and mode == &"story":
		return false
	_prepare_open()
	mode = &"records"
	progression_manager = manager
	if not progression_manager.progression_changed.is_connected(refresh_records):
		progression_manager.progression_changed.connect(refresh_records)
	current_story_id = &""
	title_label.text = "牧场档案"
	refresh_records()
	show()
	mode_changed.emit(mode)
	return true


func refresh_tasks() -> void:
	if mode != &"tasks" or not task_manager:
		return
	_clear_content()
	var tasks: Array[Dictionary] = task_manager.get_tasks()
	if tasks.is_empty():
		var empty_label := _make_label(Vector2(14, 40), Vector2(274, 80), "今天没有可用任务", 16)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_root.add_child(empty_label)
		return
	var y := 6.0
	for task in tasks:
		content_root.add_child(_make_task_row(task, y))
		y += 121.0
	var hint := _make_label(Vector2(12, minf(374.0, y + 4.0)), Vector2(278, 34), "未领取奖励会在次日过期", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("7d5140"))
	content_root.add_child(hint)


func refresh_records() -> void:
	if mode != &"records" or not progression_manager:
		return
	_clear_content()
	var summary := _make_label(
		Vector2(10, 4), Vector2(286, 56),
		"牧场 Lv.%d　%s\n%s" % [
			progression_manager.get_level(), progression_manager.get_level_progress_text(),
			progression_manager.get_chapter_title(),
		], 16
	)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", Color("294b5b"))
	content_root.add_child(summary)
	var statistics := _make_label(
		Vector2(10, 66), Vector2(286, 68),
		"订单 %d　血统订单 %d　连单 %d\n出生 %d　巡查 %d　救援 %d\n最佳安全守夜 %d 晚" % [
			progression_manager.get_stat(&"orders_completed"), progression_manager.get_stat(&"bloodline_orders"),
			progression_manager.get_stat(&"merchant_chains"), progression_manager.get_stat(&"lambs_born"),
			progression_manager.get_stat(&"wolf_patrols"), progression_manager.get_stat(&"rescues_completed"),
			progression_manager.get_stat(&"best_safe_night_streak"),
		], 13
	)
	statistics.add_theme_color_override("font_color", Color("49362b"))
	content_root.add_child(statistics)
	var achievement_title := _make_label(
		Vector2(10, 142), Vector2(286, 26),
		"成就 %d / %d" % [progression_manager.get_unlocked_achievement_count(), progression_manager.ACHIEVEMENTS.size()], 16
	)
	achievement_title.add_theme_color_override("font_color", Color("8b5b24"))
	content_root.add_child(achievement_title)
	var y := 174.0
	for achievement in progression_manager.get_achievement_rows():
		var row := _make_label(
			Vector2(12, y), Vector2(282, 28),
			"%s %s　+%d" % ["已完成" if achievement.unlocked else "未完成", achievement.title, achievement.reward], 13
		)
		row.add_theme_color_override("font_color", Color("35644c") if achievement.unlocked else Color("6d5e49"))
		content_root.add_child(row)
		y += 29.0


func close_panel() -> void:
	if not visible:
		return
	var closed_mode := mode
	var closed_story_id := current_story_id
	hide()
	mode = &""
	current_story_id = &""
	_clear_content()
	if commission_was_visible:
		newbie_commission.show()
	commission_was_visible = false
	mode_changed.emit(mode)
	if closed_mode == &"story":
		story_closed.emit(closed_story_id)


func _prepare_open() -> void:
	if not visible:
		commission_was_visible = newbie_commission.visible
	newbie_commission.hide()


func _make_task_row(task: Dictionary, y: float) -> Control:
	var row := Panel.new()
	row.position = Vector2(6, y)
	row.size = Vector2(288, 113)
	row.add_theme_stylebox_override("panel", _card_style())
	var task_title := _make_label(Vector2(12, 7), Vector2(176, 25), task.title, 16)
	task_title.add_theme_color_override("font_color", Color("294b5b"))
	row.add_child(task_title)
	var reward := _make_label(Vector2(190, 7), Vector2(86, 25), "+%d" % task.reward, 15)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_theme_color_override("font_color", Color("8b5b24"))
	row.add_child(reward)
	var description := _make_label(Vector2(12, 34), Vector2(264, 28), task.description, 14)
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(description)
	var progress := _make_label(
		Vector2(12, 72), Vector2(116, 28),
		"进度 %d / %d" % [task.progress, task.target], 13
	)
	progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(progress)
	var action := Button.new()
	action.position = Vector2(150, 67)
	action.size = Vector2(126, 36)
	action.add_theme_font_size_override("font_size", 14)
	match task.state:
		task_manager.TaskState.AVAILABLE:
			action.text = "接取"
			action.pressed.connect(_accept_task.bind(task.id))
		task_manager.TaskState.ACTIVE:
			action.text = "进行中"
			action.disabled = true
		task_manager.TaskState.COMPLETED:
			action.text = "领取 %d" % task.reward
			action.pressed.connect(_claim_task.bind(task.id))
		task_manager.TaskState.CLAIMED:
			action.text = "已领取"
			action.disabled = true
	row.add_child(action)
	return row


func _accept_task(task_id: String) -> void:
	task_manager.accept_task(task_id)


func _claim_task(task_id: String) -> void:
	task_manager.claim_task(task_id)


func _build_story_content(event_data: Dictionary) -> void:
	_clear_content()
	var portrait_panel := Panel.new()
	portrait_panel.position = Vector2(8, 10)
	portrait_panel.size = Vector2(106, 116)
	portrait_panel.add_theme_stylebox_override("panel", _card_style())
	content_root.add_child(portrait_panel)
	var portrait := TextureRect.new()
	portrait.position = Vector2(5, 7)
	portrait.size = Vector2(96, 96)
	portrait.texture = _shepherd_first_frame()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait)
	var speaker := _make_label(Vector2(126, 22), Vector2(160, 28), event_data.get("speaker", "牧羊人"), 18)
	speaker.add_theme_color_override("font_color", Color("294b5b"))
	content_root.add_child(speaker)
	var subtitle := _make_label(Vector2(126, 55), Vector2(160, 58), event_data.get("subtitle", "牧场向导"), 14)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_root.add_child(subtitle)
	var body := _make_label(Vector2(12, 144), Vector2(276, 150), event_data.body, 16)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	content_root.add_child(body)
	var actions: Array = event_data.get("actions", [])
	var button_width := 132.0 if actions.size() > 1 else 200.0
	var start_x := 12.0 if actions.size() > 1 else 50.0
	for index in mini(2, actions.size()):
		var action_data: Dictionary = actions[index]
		var button := Button.new()
		button.position = Vector2(start_x + index * 144.0, 326)
		button.size = Vector2(button_width, 44)
		button.text = action_data.label
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(story_action_requested.emit.bind(action_data.id))
		content_root.add_child(button)


func _build_frame() -> void:
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var title := TextureRect.new()
	title.position = Vector2(14, -25)
	title.size = Vector2(174, 58)
	title.texture = TITLE_TEXTURE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_SCALE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	title_label = _make_label(Vector2.ZERO, title.size, "", 21)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color("fff0b0"))
	title_label.add_theme_color_override("font_shadow_color", Color("172337"))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title.add_child(title_label)
	var close_button := Button.new()
	close_button.position = Vector2(294, 10)
	close_button.size = Vector2(30, 30)
	close_button.text = "×"
	close_button.tooltip_text = "关闭"
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(close_panel)
	add_child(close_button)
	content_root = Control.new()
	content_root.position = Vector2(12, 44)
	content_root.size = Vector2(306, 416)
	add_child(content_root)


func _clear_content() -> void:
	if not content_root:
		return
	for child in content_root.get_children():
		content_root.remove_child(child)
		child.queue_free()


func _shepherd_first_frame() -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = SHEPHERD_TEXTURE
	frame.region = Rect2(0, 0, 192, 192)
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


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.91, 0.84, 0.69, 0.74)
	style.border_color = Color(0.42, 0.32, 0.28, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
