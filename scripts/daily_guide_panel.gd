extends Control

const SHEPHERD_TEXTURE: Texture2D = preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_idle_down.png")

@onready var routine_manager: Node = get_node("../../DayRoutineManager")

var title_label: Label
var body_label: Label
var panel: Panel


func _ready() -> void:
	_build_interface()
	routine_manager.guidance_changed.connect(_on_guidance_changed)
	routine_manager.last_guidance_key = ""
	routine_manager._refresh_guidance()


func _on_guidance_changed(title: String, body: String, urgent: bool) -> void:
	title_label.text = title
	body_label.text = body
	panel.add_theme_stylebox_override("panel", _panel_style(urgent))


func _build_interface() -> void:
	panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(false))
	add_child(panel)
	var portrait := TextureRect.new()
	portrait.position = Vector2(10, 10)
	portrait.size = Vector2(54, 54)
	var frame := AtlasTexture.new()
	frame.atlas = SHEPHERD_TEXTURE
	frame.region = Rect2(0, 0, 128, 128)
	portrait.texture = frame
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)
	title_label = Label.new()
	title_label.position = Vector2(70, 8)
	title_label.size = Vector2(236, 26)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color("294b5b"))
	panel.add_child(title_label)
	body_label = Label.new()
	body_label.position = Vector2(70, 33)
	body_label.size = Vector2(236, 42)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 13)
	body_label.add_theme_color_override("font_color", Color("49362b"))
	panel.add_child(body_label)


func _panel_style(urgent: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4e8c5")
	style.border_color = Color("b5523f") if urgent else Color("6d5e49")
	style.set_border_width_all(3 if urgent else 2)
	style.set_corner_radius_all(4)
	return style
