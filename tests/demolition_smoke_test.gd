extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var controller: Node2D = scene.get_node("BuildController")
	var buildings: Node2D = scene.get_node("Island/Buildings")
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")
	var menu: Control = scene.get_node("HUD/BuildMenu")
	var hud: Control = scene.get_node("HUD/TopHUD")

	if controller.demolition_hammer_frames.get_frame_count(&"strike") != 6:
		_fail("Demolition hammer does not have six animation frames")
		return
	if not controller.try_place_building(&"dog_house", Vector2(720, 480)):
		_fail("Test dog house could not be placed")
		return
	var money_after_build: int = hud.get_money()
	if controller.placed_footprints.size() != 1:
		_fail("Placed building footprint was not recorded")
		return

	toolbar.select_tab(&"build")
	menu.demolish_button.pressed.emit()
	if controller.selected_item_id != &"demolish" or menu.visible:
		_fail("Demolition button did not enter demolition mode and close the menu")
		return
	if not controller.try_demolish_at(Vector2(720, 480)):
		_fail("Placed dog house could not be selected for demolition")
		return
	await create_timer(0.65).timeout
	if buildings.get_child_count() != 0 or controller.placed_footprints.size() != 0:
		_fail("Demolition did not remove the building, collision, and footprint")
		return
	if hud.get_money() != money_after_build:
		_fail("Demolition unexpectedly refunded or deducted money")
		return
	if not controller.try_place_building(&"dog_house", Vector2(720, 480)):
		_fail("Demolished building footprint still blocks rebuilding")
		return

	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Test fence could not be placed")
		return
	controller.select_build_item(&"demolish", {"display_name": "拆除"})
	if not controller.try_demolish_at(Vector2(540, 240)):
		_fail("Fence segment did not select the complete fence for demolition")
		return
	await create_timer(0.65).timeout
	if buildings.get_child_count() != 1:
		_fail("Demolishing a fence did not remove exactly the complete fence root")
		return

	print("PASS: demolition button, six-frame hammer strike, building and whole-fence removal")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
