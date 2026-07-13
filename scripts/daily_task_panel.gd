extends Control

@onready var task_manager: Node = get_node("../../DailyTaskManager")
@onready var right_side_panel: Control = get_node("../RightSidePanel")

var task_button: Button
var claim_marker: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_button()
	task_manager.tasks_changed.connect(_refresh)
	right_side_panel.mode_changed.connect(_on_panel_mode_changed)
	_refresh.call_deferred()


func open_drawer() -> bool:
	return right_side_panel.show_tasks(task_manager)


func close_drawer() -> void:
	if right_side_panel.get_mode() == &"tasks":
		right_side_panel.close_panel()


func is_drawer_open() -> bool:
	return right_side_panel.visible and right_side_panel.get_mode() == &"tasks"


func _toggle_drawer() -> void:
	if is_drawer_open():
		close_drawer()
	else:
		open_drawer()


func _refresh() -> void:
	if not task_button:
		return
	task_button.text = "今日任务　%d / 2" % task_manager.get_finished_count()
	claim_marker.visible = task_manager.has_claimable_reward()
	if is_drawer_open():
		right_side_panel.refresh_tasks()


func _on_panel_mode_changed(mode: StringName) -> void:
	if task_button:
		task_button.button_pressed = mode == &"tasks"


func _build_button() -> void:
	task_button = Button.new()
	task_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	task_button.toggle_mode = true
	task_button.text = "今日任务　0 / 2"
	task_button.tooltip_text = "查看、接取和领取今日任务"
	task_button.add_theme_font_size_override("font_size", 16)
	task_button.add_theme_stylebox_override("normal", _button_style(Color("f0e5c4"), Color("6d5e49")))
	task_button.add_theme_stylebox_override("hover", _button_style(Color("fff0c9"), Color("638ca0")))
	task_button.add_theme_stylebox_override("pressed", _button_style(Color("d8e6d0"), Color("315d72")))
	task_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	task_button.pressed.connect(_toggle_drawer)
	add_child(task_button)
	claim_marker = Label.new()
	claim_marker.position = Vector2(164, -8)
	claim_marker.size = Vector2(26, 26)
	claim_marker.text = "!"
	claim_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	claim_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	claim_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	claim_marker.add_theme_font_size_override("font_size", 18)
	claim_marker.add_theme_color_override("font_color", Color.WHITE)
	claim_marker.add_theme_stylebox_override("normal", _marker_style())
	claim_marker.hide()
	add_child(claim_marker)


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style


func _marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("c94f3d")
	style.border_color = Color("fff0b0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	return style
