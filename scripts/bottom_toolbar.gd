extends Control

signal tab_selected(tab_name: StringName)

const TAB_NAMES := [&"build", &"sheep", &"medical", &"help"]

@onready var buttons: Array[TextureButton] = [
	$Paper/BuildButton,
	$Paper/SheepButton,
	$Paper/MedicalButton,
	$Paper/HelpButton,
]
@onready var build_menu: Control = get_node_or_null("../BuildMenu")
@onready var sheep_menu: Control = get_node_or_null("../SheepMenu")
@onready var sheep_detail_menu: Control = get_node_or_null("../SheepDetailMenu")
@onready var medical_menu: Control = get_node_or_null("../MedicalMenu")
@onready var help_menu: Control = get_node_or_null("../HelpMenu")

var selected_index := -1


func _ready() -> void:
	for index in buttons.size():
		buttons[index].pressed.connect(_select_tab.bind(index))
		buttons[index].pivot_offset = buttons[index].size * 0.5
	_update_button_visuals()


func get_selected_tab() -> StringName:
	return TAB_NAMES[selected_index] if selected_index >= 0 else &""


func select_tab(tab_name: StringName) -> void:
	var index := TAB_NAMES.find(tab_name)
	if index >= 0:
		_select_tab(index)


func _select_tab(index: int) -> void:
	selected_index = index
	_update_button_visuals()
	if build_menu:
		if TAB_NAMES[index] == &"build":
			build_menu.open_menu()
		else:
			build_menu.close_menu()
	if sheep_menu:
		if TAB_NAMES[index] == &"sheep":
			sheep_menu.open_menu()
		else:
			sheep_menu.close_menu()
	if sheep_detail_menu:
		sheep_detail_menu.close_menu()
	if medical_menu:
		if TAB_NAMES[index] == &"medical":
			medical_menu.open_menu()
		else:
			medical_menu.close_menu()
	if help_menu:
		if TAB_NAMES[index] == &"help":
			help_menu.open_menu()
		else:
			help_menu.close_menu()
	tab_selected.emit(TAB_NAMES[index])


func _update_button_visuals() -> void:
	for index in buttons.size():
		var selected := index == selected_index
		buttons[index].modulate = Color.WHITE if selected else Color(0.86, 0.82, 0.72, 1.0)
		buttons[index].scale = Vector2.ONE * (1.12 if selected else 1.0)
