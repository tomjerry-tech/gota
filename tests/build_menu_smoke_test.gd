extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")
	var menu: Control = scene.get_node("HUD/BuildMenu")
	if menu.scale != Vector2(0.5, 0.5):
		_fail("Build menu was not scaled to half size")
		return
	if menu.visible:
		_fail("Build menu should start hidden")
		return
	toolbar.select_tab(&"build")
	await process_frame
	if not menu.visible:
		_fail("Hammer tab did not open the build menu")
		return
	if menu.get_item_count() != 5:
		_fail("Build menu does not contain five planned items")
		return
	if menu.demolish_button == null or menu.demolish_button.get_parent() != menu.card_grid:
		_fail("Demolition hammer is not placed in the build card grid")
		return
	if menu.demolish_button.custom_minimum_size != menu.card_buttons[0].custom_minimum_size:
		_fail("Demolition hammer card size does not match the build cards")
		return
	var land_card: Button = menu.card_buttons[4]
	if menu.demolish_button.position.x <= land_card.position.x or not is_equal_approx(menu.demolish_button.position.y, land_card.position.y):
		_fail("Demolition hammer is not placed to the right of land expansion")
		return
	var hammer_style: StyleBoxFlat = menu.demolish_button.get_theme_stylebox("normal")
	var build_card_style: StyleBoxFlat = menu.card_buttons[0].get_theme_stylebox("normal")
	if hammer_style.bg_color != build_card_style.bg_color or hammer_style.border_color != build_card_style.border_color:
		_fail("Demolition hammer card background does not match the build cards")
		return
	if menu.get_selected_item_id() != &"fence":
		_fail("Build menu did not select the fence card by default")
		return
	var expected_prices := [8, 180, 320, 240, 450]
	for index in expected_prices.size():
		if menu.ITEMS[index].price != expected_prices[index]:
			_fail("Build menu price is incorrect at card %d" % index)
			return
	var fence_drag_data: Variant = menu.card_buttons[0].get_build_drag_data()
	if not fence_drag_data is Dictionary or fence_drag_data.item_id != &"fence":
		_fail("Fence card does not provide building drag data")
		return
	if land_card.get_build_drag_data() != null:
		_fail("Land expansion should use click confirmation, not drag placement")
		return
	menu._select_item(4)
	if not menu.land_type_selector.visible or menu.land_type_buttons.size() != 2:
		_fail("Land expansion details are missing the two land-type choices")
		return
	if menu.get_selected_land_type() != &"pasture":
		_fail("Land expansion did not default to pasture land")
		return
	menu.set_land_type(&"homestead")
	if menu.get_selected_land_type() != &"homestead" or "生活用地" not in menu.land_type_buttons[1].text:
		_fail("Homestead land could not be selected in the build menu")
		return
	var activation := {"count": 0, "item_id": &""}
	menu.build_item_selected.connect(
		func(item_id: StringName, _item_data: Dictionary) -> void:
			activation.count += 1
			activation.item_id = item_id
	)
	menu._select_item(2)
	if activation.count != 0 or menu.get_selected_item_id() != &"shepherd_house" or not menu.visible:
		_fail("Single-click selection did not remain a details-only action")
		return
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	menu._on_card_gui_input(double_click, 2)
	if activation.count != 1 or activation.item_id != &"shepherd_house":
		_fail("Double-click did not activate the selected build item exactly once")
		return
	toolbar.select_tab(&"sheep")
	if menu.visible:
		_fail("Switching tabs did not close the build menu")
		return
	print("PASS: build cards use single-click details, land-type choice, and double-click activation")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
