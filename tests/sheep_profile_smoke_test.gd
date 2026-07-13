extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var sheep_group: Node = scene.get_node("Island/Sheep")
	var detail_menu: Control = scene.get_node("HUD/SheepDetailMenu")
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")
	var names: Dictionary = {}
	for sheep in sheep_group.get_children():
		var sheep_name: String = sheep.get_sheep_name()
		if sheep_name.is_empty() or names.has(sheep_name):
			_fail("Initial sheep names are empty or duplicated")
			return
		names[sheep_name] = true

	if detail_menu.scale != Vector2(0.5, 0.5) or detail_menu.visible:
		_fail("Sheep profile should start hidden at half size")
		return
	var first_sheep: AnimatedSprite2D = sheep_group.get_child(0)
	scene._press_sheep(first_sheep.global_position, Vector2(100, 100))
	scene._release_sheep()
	await process_frame
	if not detail_menu.visible or detail_menu.get_selected_sheep() != first_sheep:
		_fail("Clicking a sheep did not open its profile")
		return
	if detail_menu.avatar.texture == null or detail_menu.avatar.position.x >= detail_menu.name_edit.position.x:
		_fail("Sheep avatar is missing from the upper-left profile area")
		return
	if detail_menu.age_label.text != "存活 8 天":
		_fail("Sheep lifetime is not shown below the avatar")
		return
	if (
		"成年羊" not in detail_menu.stage_label.text
		or "性别" not in detail_menu.stage_label.text
		or detail_menu.hunger_bar.value < 0.0
		or "健康" not in detail_menu.health_label.text
		or "繁育状态" not in detail_menu.breeding_label.text
	):
		_fail("Sheep stage, sex, health, breeding, or hunger property is missing")
		return

	detail_menu.name_edit.text = "牧场明星"
	detail_menu._commit_name()
	if first_sheep.get_sheep_name() != "牧场明星":
		_fail("In-game sheep rename did not persist on the sheep")
		return

	detail_menu.close_menu()
	scene._press_sheep(first_sheep.global_position, Vector2(100, 100))
	scene._begin_sheep_drag()
	scene._release_sheep()
	if detail_menu.visible:
		_fail("Dragging a sheep incorrectly opened the profile")
		return

	scene.open_sheep_profile(first_sheep)
	toolbar.select_tab(&"sheep")
	if detail_menu.visible:
		_fail("Opening a toolbar panel did not close the sheep profile")
		return

	print("PASS: unique Chinese sheep names, click profile, properties, rename, and drag distinction")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
