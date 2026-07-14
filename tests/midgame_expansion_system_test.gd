extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var hud: Control = scene.get_node("HUD/TopHUD")
	var controller: Node = scene.get_node("BuildController")
	var market: Node = scene.get_node("MarketOrderManager")
	var routine: Node = scene.get_node("DayRoutineManager")
	var story: Node = scene.get_node("StoryEventManager")
	var building_panel: Control = scene.get_node("HUD/BuildingInteractionPanel")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.fired_events.clear()
	story.current_event = {}
	hud.restore_save_data({"money": 50000, "day": 20, "day_progress": 0.30})

	var fence_start := Vector2(520, 230)
	var fence_end := Vector2(600, 310)
	if not controller.try_place_fence(fence_start, fence_end):
		_fail("Could not prepare a fence for upgrade testing")
		return
	var fence: Node2D = controller.get_fence_roots()[0]
	var money_before: int = hud.get_money()
	var level_two: Dictionary = controller.try_upgrade_building(fence)
	var level_three: Dictionary = controller.try_upgrade_building(fence)
	if (
		not level_two.success
		or not level_three.success
		or controller.get_building_level(fence) != 3
		or controller.get_fence_upgrade_defense_points() != 6
		or hud.get_money() >= money_before
		or not fence.has_node("LevelBadge")
	):
		_fail("Fence upgrades did not apply cost, level badge, and defense points")
		return
	var segment_position: Rect2 = (fence.get_meta("footprints") as Array)[0]
	if controller.get_building_at(segment_position.get_center()) != fence:
		_fail("Fence segments could not be selected for interaction")
		return
	building_panel.open_for_building(fence)
	if "木围栏" not in building_panel.title_label.text or building_panel.rest_button.visible:
		_fail("Fence interaction did not reuse the building panel correctly")
		return
	building_panel.close_panel()

	hud.restore_save_data({"money": hud.get_money(), "day": 15, "day_progress": 0.35})
	market.regenerate_market_for_tests(15)
	var chain_first: Dictionary = {}
	for order in market.get_orders():
		if bool(order.get("special", false)) and int(order.get("chain_step", 0)) == 1:
			chain_first = order
			break
	if chain_first.is_empty() or "连单" not in chain_first.title:
		_fail("The scheduled merchant chain did not replace one daily order")
		return
	var first_delivery: Dictionary = market.deliver_order(chain_first.id)
	if not first_delivery.success:
		_fail("The first merchant-chain step could not be delivered")
		return
	var chain_second: Dictionary = {}
	for order in market.get_orders():
		if order.get("chain_id", "") == chain_first.chain_id and int(order.get("chain_step", 0)) == 2:
			chain_second = order
			break
	if chain_second.is_empty() or int(chain_second.unit_price) <= int(chain_first.unit_price):
		_fail("Completing chain step one did not publish a higher-value second step")
		return
	var chain_completed := [false]
	market.merchant_chain_completed.connect(func(_chain_id: String, _income: int) -> void: chain_completed[0] = true)
	var second_delivery: Dictionary = market.deliver_order(chain_second.id)
	if not second_delivery.success or not chain_completed[0] or not story.is_event_fired(&"first_merchant_chain_completed"):
		_fail("The final merchant-chain step failed: delivery=%s signal=%s story=%s" % [
			str(second_delivery.get("success", false)), str(chain_completed[0]),
			str(story.is_event_fired(&"first_merchant_chain_completed")),
		])
		return

	for coordinate in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i(2, 0)]:
		scene.add_land_chunk(coordinate, scene.LAND_TYPE_HOMESTEAD)
	scene.add_lambs(14)
	hud.restore_save_data({"money": hud.get_money(), "day": 40, "day_progress": 0.86})
	routine._try_discover_wolf_den()
	var threat_level: int = routine.get_wolf_threat_level(40)
	var defense: Dictionary = routine.get_wolf_defense_preview(40)
	if threat_level < 3 or int(defense.threat_penalty) <= 0 or int(defense.raw_score) < int(defense.score):
		_fail("Wolf pressure did not scale with date, land, and flock size")
		return
	if "威胁 Lv.%d" % threat_level not in routine.get_wolf_risk_report_text(40):
		_fail("Wolf risk report did not explain the scaled threat level")
		return

	var save_data: Dictionary = scene.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Midgame expansion state could not be restored")
		return
	var restored_controller: Node = restored.get_node("BuildController")
	var restored_market: Node = restored.get_node("MarketOrderManager")
	if (
		restored_controller.get_building_level(restored_controller.get_fence_roots()[0]) != 3
		or restored_market.get_order(chain_second.id).status != market.STATUS_COMPLETED
		or restored.get_node("DayRoutineManager").get_wolf_threat_level(40) != threat_level
	):
		_fail("Fence level, merchant chain, or wolf pressure did not survive full save restore")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: fence upgrades, merchant chains, special events, scaled wolf pressure, UI, and full save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
