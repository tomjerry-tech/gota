extends Control

const SPEEDS := [0.0, 1.0, 2.0, 4.0]
const LABELS := ["Ⅱ", "1×", "2×", "4×"]
const RIBBON_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/hud_ribbon_blue.png")
const BUTTON_REGULAR_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/time_controls/button_regular.png")
const BUTTON_PRESSED_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/time_controls/button_pressed.png")

var buttons: Array[Button] = []
var selected_speed := 1.0
var resume_speed := 1.0
var report_locked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_apply_speed(1.0)


func _process(_delta: float) -> void:
	for button in buttons:
		button.disabled = report_locked


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if get_tree():
		get_tree().paused = false


func set_speed(speed: float) -> bool:
	if report_locked:
		return false
	_apply_speed(speed)
	return true


func get_selected_speed() -> float:
	return selected_speed


func get_save_speed() -> float:
	return resume_speed if report_locked else selected_speed


func pause_for_report() -> void:
	if report_locked:
		return
	resume_speed = selected_speed
	report_locked = true
	_apply_speed(0.0)


func resume_after_report() -> void:
	if not report_locked:
		return
	report_locked = false
	_apply_speed(resume_speed)


func _apply_speed(speed: float) -> void:
	selected_speed = speed
	if speed <= 0.0:
		Engine.time_scale = 1.0
		get_tree().paused = true
	else:
		get_tree().paused = false
		Engine.time_scale = speed
	_update_button_visuals()


func _build_interface() -> void:
	var ribbon := TextureRect.new()
	ribbon.name = "Ribbon"
	ribbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ribbon.texture = RIBBON_TEXTURE
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ribbon)
	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(24, 19)
	title.size = Vector2(88, 54)
	title.text = "时间"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("fff0b0"))
	title.add_theme_color_override("font_shadow_color", Color("172337"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	ribbon.add_child(title)
	for index in SPEEDS.size():
		var button := Button.new()
		button.name = "Speed%s" % index
		button.position = Vector2(122 + index * 82, 14)
		button.size = Vector2(72, 68)
		button.text = LABELS[index]
		button.toggle_mode = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = (
			"暂停游戏" if index == 0
			else "%s 游戏速度" % LABELS[index]
		)
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color("e7f4f2"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color("fff0a8"))
		button.add_theme_color_override("font_disabled_color", Color("829096"))
		button.add_theme_color_override("font_shadow_color", Color("172337"))
		button.add_theme_constant_override("shadow_offset_x", 2)
		button.add_theme_constant_override("shadow_offset_y", 2)
		button.add_theme_stylebox_override("normal", _texture_style(BUTTON_REGULAR_TEXTURE))
		button.add_theme_stylebox_override("hover", _texture_style(BUTTON_REGULAR_TEXTURE))
		button.add_theme_stylebox_override("pressed", _texture_style(BUTTON_PRESSED_TEXTURE))
		button.add_theme_stylebox_override("disabled", _texture_style(BUTTON_PRESSED_TEXTURE))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(set_speed.bind(SPEEDS[index]))
		ribbon.add_child(button)
		buttons.append(button)


func _update_button_visuals() -> void:
	if buttons.is_empty():
		return
	for index in buttons.size():
		buttons[index].button_pressed = is_equal_approx(SPEEDS[index], selected_speed)
		buttons[index].modulate = Color.WHITE if buttons[index].button_pressed else Color(0.88, 0.92, 0.92)


func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style
