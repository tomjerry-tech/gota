extends Control

const PAPER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/panel_paper.png")
const TITLE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/title_ribbon.png")
const BLUE_BUTTON_TEXTURE := preload("res://assets/tiny_swords/ui/common_buttons/WideBlueButton_Regular.png")
const BLUE_BUTTON_PRESSED_TEXTURE := preload("res://assets/tiny_swords/ui/common_buttons/WideBlueButton_Pressed.png")
const RED_BUTTON_TEXTURE := preload("res://assets/tiny_swords/ui/common_buttons/WideRedButton_Regular.png")
const RED_BUTTON_PRESSED_TEXTURE := preload("res://assets/tiny_swords/ui/common_buttons/WideRedButton_Pressed.png")

@onready var continue_button: Button = $MenuPanel/ContinueButton
@onready var new_game_button: Button = $MenuPanel/NewGameButton
@onready var exit_button: Button = $MenuPanel/ExitButton
@onready var confirmation: Control = $Confirmation
@onready var save_manager: Node = get_node("/root/SaveManager")
@onready var audio_manager: Node = get_node("/root/AudioManager")


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_apply_interface_textures()
	continue_button.disabled = not save_manager.has_valid_save()
	continue_button.pressed.connect(continue_game)
	new_game_button.pressed.connect(start_new_game)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	$Confirmation/ConfirmButton.pressed.connect(confirm_new_game)
	$Confirmation/CancelButton.pressed.connect(cancel_new_game)
	confirmation.hide()
	audio_manager.attach_title(self)


func continue_game() -> bool:
	return save_manager.request_continue_game()


func start_new_game() -> void:
	if save_manager.has_valid_save():
		confirmation.show()
	else:
		save_manager.request_new_game()


func confirm_new_game() -> void:
	save_manager.request_new_game(true)


func cancel_new_game() -> void:
	confirmation.hide()


func _apply_interface_textures() -> void:
	$TitleRibbon.texture = TITLE_TEXTURE
	$MenuPanel.texture = PAPER_TEXTURE
	for button in [continue_button, new_game_button]:
		button.add_theme_stylebox_override("normal", _texture_style(BLUE_BUTTON_TEXTURE))
		button.add_theme_stylebox_override("hover", _texture_style(BLUE_BUTTON_TEXTURE))
		button.add_theme_stylebox_override("pressed", _texture_style(BLUE_BUTTON_PRESSED_TEXTURE))
		button.add_theme_stylebox_override("disabled", _texture_style(BLUE_BUTTON_PRESSED_TEXTURE))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	exit_button.add_theme_stylebox_override("normal", _texture_style(RED_BUTTON_TEXTURE))
	exit_button.add_theme_stylebox_override("hover", _texture_style(RED_BUTTON_TEXTURE))
	exit_button.add_theme_stylebox_override("pressed", _texture_style(RED_BUTTON_PRESSED_TEXTURE))
	exit_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	$Confirmation.add_theme_stylebox_override("panel", _texture_style(PAPER_TEXTURE))
	for button in [$Confirmation/ConfirmButton, $Confirmation/CancelButton]:
		button.add_theme_stylebox_override("normal", _texture_style(BLUE_BUTTON_TEXTURE))
		button.add_theme_stylebox_override("hover", _texture_style(BLUE_BUTTON_TEXTURE))
		button.add_theme_stylebox_override("pressed", _texture_style(BLUE_BUTTON_PRESSED_TEXTURE))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style
