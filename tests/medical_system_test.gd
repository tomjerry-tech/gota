extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var medical_menu: Control = scene.get_node("HUD/MedicalMenu")
	var top_hud: Control = scene.get_node("HUD/TopHUD")
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")
	var sheep: Node = scene.get_node("Island/Sheep").get_child(0)
	var treatment_result := {"count": 0}
	medical_menu.sheep_treated.connect(func(_sheep: Node) -> void: treatment_result.count += 1)

	if medical_menu.MEDICINE_PRICE != 60 or medical_menu.get_medicine_inventory() != 0:
		_fail("Medicine price or initial inventory is incorrect")
		return
	toolbar.select_tab(&"medical")
	if (
		not medical_menu.visible
		or scene.get_node("HUD/BuildMenu").visible
		or scene.get_node("HUD/SheepMenu").visible
		or scene.get_node("HUD/SheepDetailMenu").visible
	):
		_fail("Medical tab did not open as the exclusive left-side panel")
		return
	if not sheep.make_sick() or sheep.is_healthy() or not sheep.medical_icon.visible:
		_fail("make_sick did not expose sickness or the medical icon")
		return
	if not medical_menu.buy_medicine():
		_fail("Buying one medicine failed")
		return
	if top_hud.get_money() != 19940 or medical_menu.get_medicine_inventory() != 1:
		_fail("Buying medicine did not deduct 60 coins and add inventory")
		return
	if not medical_menu.treat_sheep(sheep):
		_fail("Treating a sick sheep failed")
		return
	if not sheep.is_healthy() or sheep.medical_icon.visible:
		_fail("Treatment did not restore health or hide the medical icon")
		return
	if medical_menu.get_medicine_inventory() != 0 or treatment_result.count != 1:
		_fail("Treatment did not consume exactly one medicine or emit once")
		return
	if medical_menu.treat_sheep(sheep) or treatment_result.count != 1:
		_fail("A healthy sheep could be treated repeatedly")
		return

	print("PASS: medical tab, medicine purchase, inventory, controlled sickness, treatment, and health icon")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
