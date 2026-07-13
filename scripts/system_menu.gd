extends Control

const PAPER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")
const BLUE_BUTTON_TEXTURE := preload("res://assets/tiny_swords/ui/common_buttons/WideBlueButton_Regular.png")
const BLUE_BUTTON_PRESSED_TEXTURE := preload("res://assets/tiny_swords/ui/common_buttons/WideBlueButton_Pressed.png")
const RED_BUTTON_TEXTURE := preload("res://assets/tiny_swords/ui/common_buttons/WideRedButton_Regular.png")
const RED_BUTTON_PRESSED_TEXTURE := preload("res://assets/tiny_swords/ui/common_buttons/WideRedButton_Pressed.png")

@onready var world_controller: Node = get_node("../..")
@onready var time_controls: Control = get_node("../TimeControls")
@onready var daily_report: Control = get_node("../DailyReport")
@onready var right_side_panel: Control = get_node("../RightSidePanel")
@onready var save_manager: Node = get_node("/root/SaveManager")
@onready var audio_manager: Node = get_node("/root/AudioManager")

var feedback_label: Label
var load_button: Button
var confirmation: Control
var volume_sliders: Dictionary = {}
var volume_value_labels: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if visible:
		close_menu()
		get_viewport().set_input_as_handled()
		return
	if world_controller.build_controller.is_build_mode_active():
		return
	if open_menu():
		get_viewport().set_input_as_handled()


func open_menu() -> bool:
	if daily_report.visible or (right_side_panel.visible and right_side_panel.get_mode() == &"story"):
		return false
	load_button.disabled = not save_manager.has_valid_save()
	feedback_label.text = ""
	confirmation.hide()
	_sync_volume_controls()
	show()
	time_controls.pause_for_report()
	return true


func close_menu() -> void:
	if not visible:
		return
	confirmation.hide()
	hide()
	time_controls.resume_after_report()


func save_game() -> bool:
	var success: bool = save_manager.save_game(world_controller)
	feedback_label.text = save_manager.last_message
	feedback_label.add_theme_color_override("font_color", Color("35644c") if success else Color("9a4035"))
	load_button.disabled = not save_manager.has_valid_save()
	return success


func load_game() -> bool:
	if not save_manager.request_continue_game():
		feedback_label.text = save_manager.last_message
		return false
	return true


func request_new_game() -> void:
	confirmation.show()


func cancel_new_game() -> void:
	confirmation.hide()


func confirm_new_game() -> void:
	save_manager.request_new_game(true)


func _build_interface() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.07, 0.08, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -320.0
	panel.offset_top = -280.0
	panel.offset_right = 320.0
	panel.offset_bottom = 280.0
	add_child(panel)
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(paper)
	var ribbon := TextureRect.new()
	ribbon.position = Vector2(210, -28)
	ribbon.size = Vector2(220, 70)
	ribbon.texture = TITLE_TEXTURE
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(ribbon)
	var title := _make_label(Vector2.ZERO, ribbon.size, "系统菜单", 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("fff0b0"))
	title.add_theme_color_override("font_shadow_color", Color("172337"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	ribbon.add_child(title)

	var button_specs := [
		["继续游戏", close_menu],
		["保存游戏", save_game],
		["读取存档", load_game],
		["重新开始", request_new_game],
		["退出游戏", func() -> void: get_tree().quit()],
	]
	for index in button_specs.size():
		var button := Button.new()
		button.position = Vector2(48, 76 + index * 66)
		button.size = Vector2(238, 50)
		button.text = button_specs[index][0]
		button.add_theme_font_size_override("font_size", 18)
		_apply_button_style(button, index == 4)
		button.pressed.connect(button_specs[index][1])
		panel.add_child(button)
		if index == 2:
			load_button = button
	_build_audio_controls(panel)
	feedback_label = _make_label(Vector2(54, 476), Vector2(532, 52), "", 15)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(feedback_label)
	confirmation = _build_confirmation(panel)


func _build_confirmation(parent: Control) -> Control:
	var root := Panel.new()
	root.position = Vector2(134, 150)
	root.size = Vector2(372, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f2e4bf")
	style.border_color = Color("6d5e49")
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	root.add_theme_stylebox_override("panel", style)
	parent.add_child(root)
	var message := _make_label(Vector2(24, 28), Vector2(324, 78), "重新开始会删除现有存档，确定继续吗？", 17)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(message)
	var confirm_button := Button.new()
	confirm_button.position = Vector2(40, 132)
	confirm_button.size = Vector2(132, 46)
	confirm_button.text = "删除并开始"
	_apply_button_style(confirm_button, true)
	confirm_button.pressed.connect(confirm_new_game)
	root.add_child(confirm_button)
	var cancel_button := Button.new()
	cancel_button.position = Vector2(200, 132)
	cancel_button.size = Vector2(132, 46)
	cancel_button.text = "取消"
	_apply_button_style(cancel_button)
	cancel_button.pressed.connect(cancel_new_game)
	root.add_child(cancel_button)
	root.hide()
	return root


func _build_audio_controls(parent: Control) -> void:
	var heading := _make_label(Vector2(336, 70), Vector2(240, 40), "声音设置", 22)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(heading)
	_add_volume_control(parent, "主音量", &"master", 126, audio_manager.master_volume)
	_add_volume_control(parent, "音乐与环境", &"music", 224, audio_manager.music_volume)
	_add_volume_control(parent, "操作音效", &"sfx", 322, audio_manager.sfx_volume)


func _add_volume_control(parent: Control, title: String, setting_id: StringName, y: float, initial_value: float) -> void:
	var label := _make_label(Vector2(336, y), Vector2(152, 30), title, 17)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	var value_label := _make_label(Vector2(494, y), Vector2(82, 30), "%d%%" % roundi(initial_value * 100.0), 16)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(value_label)
	var slider := HSlider.new()
	slider.position = Vector2(336, y + 38)
	slider.size = Vector2(240, 30)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_stylebox_override("slider", _slider_style(Color("b8a97f"), 6))
	slider.add_theme_stylebox_override("grabber_area", _slider_style(Color("4b8293"), 10))
	slider.add_theme_stylebox_override("grabber_area_highlight", _slider_style(Color("68a8b8"), 10))
	slider.value_changed.connect(_on_volume_changed.bind(setting_id))
	parent.add_child(slider)
	volume_sliders[setting_id] = slider
	volume_value_labels[setting_id] = value_label


func _on_volume_changed(value: float, setting_id: StringName) -> void:
	match setting_id:
		&"master": audio_manager.set_master_volume(value)
		&"music": audio_manager.set_music_volume(value)
		&"sfx": audio_manager.set_sfx_volume(value)
	var value_label: Label = volume_value_labels.get(setting_id, null)
	if value_label:
		value_label.text = "%d%%" % roundi(value * 100.0)


func _sync_volume_controls() -> void:
	var values := {
		&"master": audio_manager.master_volume,
		&"music": audio_manager.music_volume,
		&"sfx": audio_manager.sfx_volume,
	}
	for setting_id: StringName in values:
		var slider: HSlider = volume_sliders.get(setting_id, null)
		var value_label: Label = volume_value_labels.get(setting_id, null)
		if slider:
			slider.set_value_no_signal(values[setting_id])
		if value_label:
			value_label.text = "%d%%" % roundi(float(values[setting_id]) * 100.0)


func _make_label(position_value: Vector2, size_value: Vector2, text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("3d2c22"))
	return label


func _apply_button_style(button: Button, red := false) -> void:
	var regular := RED_BUTTON_TEXTURE if red else BLUE_BUTTON_TEXTURE
	var pressed := RED_BUTTON_PRESSED_TEXTURE if red else BLUE_BUTTON_PRESSED_TEXTURE
	button.add_theme_stylebox_override("normal", _texture_style(regular))
	button.add_theme_stylebox_override("hover", _texture_style(regular))
	button.add_theme_stylebox_override("pressed", _texture_style(pressed))
	button.add_theme_stylebox_override("disabled", _texture_style(pressed))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color("eefbff"))
	button.add_theme_color_override("font_pressed_color", Color("fff0a8"))
	button.add_theme_color_override("font_shadow_color", Color("172337"))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)


func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style


func _slider_style(color: Color, thickness: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	style.content_margin_top = thickness
	style.content_margin_bottom = thickness
	return style
