extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var market: Node = scene.get_node("MarketOrderManager")
	var hud: Control = scene.get_node("HUD/TopHUD")
	var report: Control = scene.get_node("HUD/DailyReport")
	var story: Node = scene.get_node("StoryEventManager")
	var sheep_menu: Control = scene.get_node("HUD/SheepMenu")
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")

	if market.get_normal_market_price() != 320:
		_fail("Day-one normal market price did not preserve the 320 baseline")
		return
	var saw_changed_price := false
	for day in range(2, 9):
		var price: int = market._roll_normal_price(day)
		if price < market.NORMAL_PRICE_MIN or price > market.NORMAL_PRICE_MAX or price % 10 != 0:
			_fail("Daily normal price left the configured range")
			return
		saw_changed_price = saw_changed_price or price != market.DEFAULT_NORMAL_PRICE
	if not saw_changed_price:
		_fail("Normal market price did not fluctuate after day one")
		return

	market.regenerate_market_for_tests(1)
	var orders: Array[Dictionary] = market.get_orders()
	if orders.size() != 2 or orders[0].id == orders[1].id:
		_fail("The market did not generate two unique daily orders")
		return
	var requirement_keys: Dictionary = {}
	for order in orders:
		var requirement_key := "%s:%s" % [order.type, order.sex]
		if requirement_keys.has(requirement_key):
			_fail("Daily orders repeated the same requirement")
			return
		requirement_keys[requirement_key] = true
		if (
			int(order.deadline_day) - int(order.created_day) not in [2, 3]
			or int(order.unit_price) < market.ORDER_PRICE_MIN
			or int(order.unit_price) > market.ORDER_PRICE_MAX
			or not market.can_fulfill_order(order.id)
		):
			_fail("A generated order had an invalid deadline, price, or initial feasibility")
			return

	story.event_queue.clear()
	story.fired_events.clear()
	toolbar.select_tab(&"sheep")
	sheep_menu.open_market_page()
	if not sheep_menu.market_page.visible or sheep_menu.normal_page_controls[0].visible:
		_fail("The flock panel did not switch exclusively to the market page")
		return
	if not story.is_event_fired(&"first_market_view"):
		_fail("Opening the market did not trigger the one-time merchant introduction")
		return
	market.mark_market_viewed()
	if story.event_queue.size() != 1:
		_fail("The merchant introduction was queued more than once")
		return

	var first_order: Dictionary = orders[0]
	var initial_candidates: Array[Node] = market.get_order_candidates(first_order.id)
	var sick_sheep: Node = initial_candidates[0]
	sick_sheep.make_sick()
	if sick_sheep in market.get_order_candidates(first_order.id):
		_fail("A sick sheep remained eligible for order delivery")
		return
	sick_sheep.treat()
	var female: Node = null
	for sheep in scene.sheep_group.get_children():
		if sheep.get_sex() == sheep.SEX_FEMALE:
			female = sheep
			break
	var female_data: Dictionary = female.get_save_data()
	female_data.age_days = 18
	female_data.hunger = 0.0
	female.restore_save_data(female_data)
	if not female.start_pregnancy(1) or market._is_order_eligible(female):
		_fail("A pregnant sheep remained eligible for order delivery")
		return
	female.finish_birth()

	var money_before_order: int = hud.get_money()
	var order_result: Dictionary = market.deliver_order(first_order.id)
	if not order_result.success or hud.get_money() != money_before_order + int(order_result.income):
		_fail("A feasible market order did not pay its full income")
		return
	if first_order.status != market.STATUS_COMPLETED or report.order_income_today != int(order_result.income):
		_fail("Completed order state or daily order income was not recorded")
		return
	if not story.is_event_fired(&"first_market_order"):
		_fail("The first completed order did not trigger its merchant story")
		return
	var money_after_order: int = hud.get_money()
	if market.deliver_order(first_order.id).success or hud.get_money() != money_after_order:
		_fail("A completed order could be paid more than once")
		return

	var normal_result: Dictionary = market.sell_at_normal_market(1)
	if not normal_result.success or report.normal_sale_income_today != int(normal_result.income):
		_fail("Normal market sale was not recorded separately from order income")
		return
	var second_order: Dictionary = orders[1]
	second_order.deadline_day = second_order.created_day
	var money_before_expiry: int = hud.get_money()
	market._expire_overdue_orders(int(second_order.deadline_day) + 1)
	if second_order.status != market.STATUS_EXPIRED or hud.get_money() != money_before_expiry or report.expired_orders_today != 1:
		_fail("Order expiry changed money or was not counted in the daily report")
		return

	report.show_daily_report(1)
	if (
		"市场明细" not in report.report_text.text
		or "普通出售 %d" % normal_result.income not in report.report_text.text
		or "订单交付 %d" % order_result.income not in report.report_text.text
		or "过期订单 1" not in report.report_text.text
	):
		_fail("Daily report did not separate market income and expired orders")
		return
	report.close_report()

	var saved_market: Dictionary = market.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await process_frame
	var restored_market: Node = restored.get_node("MarketOrderManager")
	restored_market.restore_save_data(saved_market)
	var restored_first: Dictionary = restored_market.get_order(first_order.id)
	var restored_second: Dictionary = restored_market.get_order(second_order.id)
	if (
		restored_market.get_normal_market_price() != market.get_normal_market_price()
		or restored_first.is_empty()
		or restored_first.status != market.STATUS_COMPLETED
		or restored_second.is_empty()
		or restored_second.status != market.STATUS_EXPIRED
	):
		_fail("Market price, deadlines, or order states did not survive save restore")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: daily prices, unique orders, eligibility, atomic delivery, expiry, report, story, UI, and save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
