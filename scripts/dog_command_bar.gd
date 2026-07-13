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

var buttons: Array[Button] = []
var target_pending := false
var dog: AnimatedSprite2D


func _ready() -> void:
	_build_interface()
	dog_manager.selected_dog_changed.connect(_on_selected_dog_changed)
	hide()


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


func _on_mode_changed(mode: int) -> void:
	_update_buttons(mode)


func _on_mode_button_pressed(mode: int) -> void:
	select_mode(mode)


func _update_buttons(selected_mode: int) -> void:
	for index in buttons.size():
		buttons[index].button_pressed = index == selected_mode


func _build_interface() -> void:
	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(paper)
	var title := Label.new()
	title.position = Vector2(24, 20)
	title.size = Vector2(104, 60)
	title.text = "牧羊犬"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("4c3828"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(title)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for index in MODE_LABELS.size():
		var button := Button.new()
		button.position = Vector2(138 + index * 142, 16)
		button.size = Vector2(128, 68)
		button.text = MODE_LABELS[index]
		button.tooltip_text = MODE_TOOLTIPS[index]
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 20)
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


func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style
