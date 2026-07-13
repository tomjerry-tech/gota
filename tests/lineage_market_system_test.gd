extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var story: Node = scene.get_node("StoryEventManager")
	var market: Node = scene.get_node("MarketOrderManager")
	var detail: Control = scene.get_node("HUD/SheepDetailMenu")
	var hud: Control = scene.get_node("HUD/TopHUD")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.fired_events.clear()
	story.current_event = {}

	var mother: Node = scene.sheep_group.get_child(0)
	var father: Node = scene.sheep_group.get_child(1)
	_prepare_breeder(mother, mother.SEX_FEMALE)
	_prepare_breeder(father, father.SEX_MALE)
	var sheep_count_before: int = scene.get_sheep_count()
	if not scene.start_breeding(mother, father) or mother.get_pregnancy_father_id() != father.get_sheep_id():
		_fail("Breeding did not store the actual father ID on the pregnancy")
		return
	for day in 3:
		mother.advance_day()
	var first_lamb: Node = scene.complete_birth(mother)
	if not first_lamb or scene.get_sheep_count() <= sheep_count_before:
		_fail("Lineage pregnancy did not produce newborn lambs")
		return
	var newborns: Array[Node] = []
	for index in range(sheep_count_before, scene.get_sheep_count()):
		newborns.append(scene.sheep_group.get_child(index))
	for lamb in newborns:
		if (
			lamb.get_mother_id() != mother.get_sheep_id()
			or lamb.get_father_id() != father.get_sheep_id()
			or lamb.get_generation() != 1
		):
			_fail("Newborn did not inherit both parents and generation one")
			return
	if not story.is_event_fired(&"first_lineage_lamb"):
		_fail("First island-born lineage story was not queued")
		return

	var child_data: Dictionary = first_lamb.get_save_data()
	child_data.age_days = 8
	child_data.sex = "male"
	child_data.hunger = 0.0
	child_data.sick = false
	child_data.breeding_cooldown_days = 0
	first_lamb.restore_save_data(child_data)
	if not scene.are_close_relatives(mother, first_lamb) or "不能配对" not in scene.get_breeding_failure_reason(mother, first_lamb):
		_fail("Parent and child were not blocked from breeding")
		return
	var sibling: Node = scene.add_lamb(false)
	var sibling_data: Dictionary = sibling.get_save_data()
	sibling_data.age_days = 8
	sibling_data.sex = "female"
	sibling_data.hunger = 0.0
	sibling.restore_save_data(sibling_data)
	sibling.set_lineage(mother.get_sheep_id(), father.get_sheep_id(), 1)
	if not scene.are_close_relatives(first_lamb, sibling):
		_fail("Same-parent siblings were not recognized as close relatives")
		return

	detail.open_for_sheep(sibling)
	if (
		"第 1 代" not in detail.lineage_label.text
		or mother.get_sheep_name() not in detail.lineage_label.text
		or father.get_sheep_name() not in detail.lineage_label.text
	):
		_fail("Sheep profile did not show generation and both parent names")
		return

	hud.restore_save_data({"money": hud.get_money(), "day": 20, "day_progress": 0.55})
	var random := RandomNumberGenerator.new()
	random.seed = 20260714
	var bloodline_order: Dictionary = market._make_order(20, market.TYPE_BLOODLINE, &"", random)
	bloodline_order.quantity = 1
	var order_text: Dictionary = market._order_text(bloodline_order)
	bloodline_order.title = order_text.title
	bloodline_order.description = order_text.description
	market.orders.clear()
	market.orders.append(bloodline_order)
	var candidates: Array[Node] = market.get_order_candidates(bloodline_order.id)
	if (
		int(bloodline_order.unit_price) < market.BLOODLINE_PRICE_MIN
		or int(bloodline_order.unit_price) > market.BLOODLINE_PRICE_MAX
		or candidates.is_empty()
		or candidates.any(func(sheep: Node) -> bool: return sheep.get_generation() < 1)
	):
		_fail("Bloodline order price or generation eligibility is incorrect")
		return
	var generation_zero_eligible := candidates.any(
		func(sheep: Node) -> bool: return sheep.get_sheep_id() == mother.get_sheep_id() or sheep.get_sheep_id() == father.get_sheep_id()
	)
	if generation_zero_eligible:
		_fail("Generation-zero foundation sheep entered a bloodline order")
		return
	var money_before_delivery: int = hud.get_money()
	var delivery: Dictionary = market.deliver_order(bloodline_order.id)
	if (
		not delivery.success
		or hud.get_money() != money_before_delivery + int(bloodline_order.unit_price)
		or not story.is_event_fired(&"first_bloodline_order")
	):
		_fail("Bloodline delivery did not pay the premium or queue its story")
		return

	var sibling_id: int = sibling.get_sheep_id()
	var save_data: Dictionary = scene.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Lineage save data could not be restored")
		return
	var restored_sibling: Node = restored.get_sheep_by_id(sibling_id)
	if (
		not restored_sibling
		or restored_sibling.get_generation() != 1
		or restored_sibling.get_mother_id() != mother.get_sheep_id()
		or restored_sibling.get_father_id() != father.get_sheep_id()
	):
		_fail("Parent IDs or generation did not survive save restore")
		return
	var restored_market: Node = restored.get_node("MarketOrderManager")
	var restored_order: Dictionary = restored_market.get_order(bloodline_order.id)
	if restored_order.is_empty() or restored_order.type != market.TYPE_BLOODLINE or restored_order.status != market.STATUS_COMPLETED:
		_fail("Completed bloodline order did not survive save restore")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: parent IDs, generations, kinship block, profile, premium bloodline order, story, and save")
	quit(0)


func _prepare_breeder(sheep: Node, sex: StringName) -> void:
	var data: Dictionary = sheep.get_save_data()
	data.age_days = 8
	data.sex = String(sex)
	data.sick = false
	data.hunger = 0.0
	data.breeding_cooldown_days = 0
	data.pregnant = false
	data.expected_lamb_count = 0
	sheep.restore_save_data(data)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
