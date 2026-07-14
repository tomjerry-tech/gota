extends Control

const PAPER_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/bottom_toolbar/toolbar_paper.png")
const BUTTON_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/time_controls/button_regular.png")
const BUTTON_PRESSED_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/time_controls/button_pressed.png")
const MODE_LABELS := ["跟随", "驱赶", "守住"]
const MODE_TOOLTIPS := [
	"牧羊犬跟随牧羊人",
	"选择后在土地上指定羊群目的地",
	"选择后在土地上指定守卫位置",
]

@onready var dog_manager: Node = get_node("../../DogManager")
@onready var routine_manager: Node = get_node("../../DayRoutineManager")
@onready var top_hud: Control = get_node("../TopHUD")

var buttons: Array[Button] = []
var title_label: Label
var roundup_button: Button
var patrol_button: Button
var target_pending := false
var dog: AnimatedSprite2D
var refresh_time := 0.0


func _ready() -> void:
	_build_interface()
	dog_manager.selected_dog_changed.connect(_on_selected_dog_changed)
	hide()


func _process(delta: float) -> void:
	refresh_time -= delta
	if refresh_time > 0.0:
		return
	refresh_time = 0.25
	_update_action_buttons()


func is_target_pending() -> bool:
	return visible and target_pending


func consume_world_target(world_position: Vector2) -> bool:
	if not is_target_pending() or not is_instance_valid(dog) or not dog.set_command_target(world_position):
		return false
	target_pending = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	return true


func select_mode(mode: int) -> bool:
	if not is_instance_valid(dog) or not dog.set_command_mode(mode):
		return false
	target_pending = mode != dog.CommandMode.FOLLOW
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if target_pending else Input.CURSOR_ARROW)
	_update_buttons(mode)
	return true


func _on_selected_dog_changed(selected: Node) -> void:
	target_pending = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if is_instance_valid(dog) and dog.mode_changed.is_connected(_on_mode_changed):
		dog.mode_changed.disconnect(_on_mode_changed)
	dog = selected as AnimatedSprite2D
	visible = is_instance_valid(dog)
	if not dog:
		target_pending = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	else:
		dog.mode_changed.connect(_on_mode_changed)
		_update_buttons(dog.command_mode)
	_update_action_buttons()


func _on_mode_changed(mode: int) -> void:
	_update_buttons(mode)


func _on_mode_button_pressed(mode: int) -> void:
	select_mode(mode)


func _update_buttons(selected_mode: int) -> void:
	for index in buttons.size():
		buttons[index].button_pressed = index == selected_mode


func request_roundup() -> bool:
	if not is_instance_valid(dog):
		return false
	var result: Dictionary = routine_manager.request_dog_roundup(dog)
	_update_action_buttons()
	return bool(result.get("success", false))


func request_wolf_patrol() -> bool:
	if not is_instance_valid(dog):
		return false
	var result: Dictionary = routine_manager.request_wolf_patrol(dog)
	_update_action_buttons()
	return bool(result.get("success", false))


func _update_action_buttons() -> void:
	if not title_label:
		return
	var has_dog := is_instance_valid(dog)
	title_label.text = "牧羊犬 %d\n%d%%" % [dog.dog_index + 1, dog.get_stamina_percent()] if has_dog else "牧羊犬"
	roundup_button.disabled = not has_dog or not top_hud.is_night() or routine_manager.build_controller.get_fence_roots().is_empty()
	roundup_button.tooltip_text = (
		"打开围栏并把羊群赶回圈内，完成后自动关门"
		if not roundup_button.disabled else "夜间建有围栏后可使用"
	)
	patrol_button.disabled = not has_dog or not routine_manager.has_pending_wolf_tracks() or top_hud.is_night() or routine_manager.wolf_patrol_active
	patrol_button.tooltip_text = (
		"巡查当日狼迹，为今晚增加防护"
		if not patrol_button.disabled else "白天发现新鲜狼迹后可使用"
	)


func _build_interface() -> void:
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(paper)
	title_label = Label.new()
	title_label.position = Vector2(18, 14)
	title_label.size = Vector2(96, 72)
	title_label.text = "牧羊犬"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color("4c3828"))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(title_label)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for index in MODE_LABELS.size():
		var button := Button.new()
		button.position = Vector2(114 + index * 116, 16)
		button.size = Vector2(106, 68)
		button.text = MODE_LABELS[index]
		button.tooltip_text = MODE_TOOLTIPS[index]
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color("e7f4f2"))
		button.add_theme_color_override("font_pressed_color", Color("fff0a8"))
		button.add_theme_color_override("font_shadow_color", Color("172337"))
		button.add_theme_constant_override("shadow_offset_x", 2)
		button.add_theme_constant_override("shadow_offset_y", 2)
		button.add_theme_stylebox_override("normal", _texture_style(BUTTON_TEXTURE))
		button.add_theme_stylebox_override("hover", _texture_style(BUTTON_TEXTURE))
		button.add_theme_stylebox_override("pressed", _texture_style(BUTTON_PRESSED_TEXTURE))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_on_mode_button_pressed.bind(index))
		paper.add_child(button)
		buttons.append(button)
	roundup_button = _make_action_button("回圈", Vector2(462, 16), request_roundup)
	patrol_button = _make_action_button("巡查狼迹", Vector2(578, 16), request_wolf_patrol)
	paper.add_child(roundup_button)
	paper.add_child(patrol_button)


func _make_action_button(label: String, position_value: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = Vector2(106, 68)
	button.text = label
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("e7f4f2"))
	button.add_theme_color_override("font_disabled_color", Color("798687"))
	button.add_theme_color_override("font_shadow_color", Color("172337"))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_stylebox_override("normal", _texture_style(BUTTON_TEXTURE))
	button.add_theme_stylebox_override("hover", _texture_style(BUTTON_TEXTURE))
	button.add_theme_stylebox_override("pressed", _texture_style(BUTTON_PRESSED_TEXTURE))
	button.add_theme_stylebox_override("disabled", _texture_style(BUTTON_TEXTURE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	return button


func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style
