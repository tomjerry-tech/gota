extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")
	var build_menu: Control = scene.get_node("HUD/BuildMenu")
	var sheep_menu: Control = scene.get_node("HUD/SheepMenu")
	var hud: Control = scene.get_node("HUD/TopHUD")

	if sheep_menu.scale != Vector2(0.5, 0.5) or sheep_menu.visible:
		_fail("Sheep menu should start hidden at half size")
		return
	if sheep_menu.get_lamb_count() != 0 or sheep_menu.get_adult_count() != 6:
		_fail("Initial lamb and adult counts are incorrect")
		return

	toolbar.select_tab(&"sheep")
	if not sheep_menu.visible or build_menu.visible:
		_fail("Sheep tab did not exclusively open the sheep menu")
		return
	if sheep_menu.BUY_LAMB_PRICE != 200 or sheep_menu.SELL_ADULT_PRICE != 320:
		_fail("Sheep trading prices are incorrect")
		return
	if sheep_menu.quantity_spinbox == null or sheep_menu.quantity_spinbox.max_value != 20.0:
		_fail("Batch trade quantity selector is missing or has the wrong limit")
		return
	if scene.get_sheep_capacity() != 10 or "当前 6 + 待出生 0 / 容量 10" not in sheep_menu.capacity_label.text:
		_fail("Initial pasture capacity is missing from the sheep menu")
		return
	if sheep_menu.mother_option == null or sheep_menu.father_option == null or sheep_menu.breed_button == null:
		_fail("Sheep menu is missing the breeding pair controls")
		return
	sheep_menu.quantity_spinbox.value = 5.0
	if sheep_menu.buy_lamb() or hud.get_money() != 20000:
		_fail("Batch buying was allowed beyond pasture capacity")
		return

	sheep_menu.quantity_spinbox.value = 3.0
	if not sheep_menu.buy_lamb():
		_fail("Batch buying lambs failed")
		return
	await process_frame
	var sheep_group: Node = scene.get_node("Island/Sheep")
	var grass_count := get_nodes_in_group(&"grass").size()
	var lamb: Node = sheep_group.get_node("Sheep7")
	if hud.get_money() != 19400 or sheep_group.get_child_count() != 9:
		_fail("Batch buying did not update money and sheep count")
		return
	if sheep_menu.get_lamb_count() != 3 or sheep_menu.get_adult_count() != 6:
		_fail("Batch buying did not update age-group counts")
		return
	if lamb.get_age_days() != 0 or lamb.is_adult():
		_fail("Purchased sheep did not start as a 0-day lamb")
		return
	if grass_count != 9:
		_fail("Buying sheep changed the fixed grass count of the current land")
		return

	sheep_menu.quantity_spinbox.value = 2.0
	if not sheep_menu.sell_adult_sheep():
		_fail("Batch selling adult sheep failed")
		return
	await process_frame
	if hud.get_money() != 20040 or sheep_group.get_child_count() != 7:
		_fail("Batch selling did not update money and sheep count")
		return
	if sheep_menu.get_adult_count() != 4:
		_fail("Adult count did not decrease after batch sale")
		return

	sheep_menu.quantity_spinbox.value = 5.0
	if sheep_menu.sell_adult_sheep() or hud.get_money() != 20040 or sheep_group.get_child_count() != 7:
		_fail("Insufficient adults caused a partial batch sale")
		return

	for sheep in sheep_group.get_children():
		if not sheep.is_adult():
			for day_index in 6:
				sheep.advance_day()
	if lamb.get_age_days() != 6 or not lamb.is_adult():
		_fail("A sheep did not become adult at 6 days")
		return
	if sheep_menu.get_lamb_count() != 0 or sheep_menu.get_adult_count() != 7:
		_fail("Age-group counts did not update after lamb growth")
		return

	sheep_menu.quantity_spinbox.value = 7.0
	if not sheep_menu.sell_adult_sheep():
		_fail("Selling the complete adult flock failed")
		return
	await process_frame
	if sheep_group.get_child_count() != 0 or hud.get_money() != 22280:
		_fail("Selling the complete flock produced the wrong count or money")
		return
	sheep_menu.quantity_spinbox.value = 2.0
	if not sheep_menu.buy_lamb():
		_fail("Buying lambs after selling the complete flock failed")
		return
	await process_frame
	if sheep_group.get_child_count() != 2 or sheep_menu.get_lamb_count() != 2 or hud.get_money() != 21880:
		_fail("Flock template did not restore batch buying after selling all sheep")
		return

	toolbar.select_tab(&"medical")
	if sheep_menu.visible or build_menu.visible:
		_fail("Medical tab did not close the other panels")
		return

	print("PASS: batch sheep trading, atomic validation, aging, counts, and fixed land grass")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
