extends Node

signal market_changed
signal market_viewed
signal normal_sale_completed(count: int, income: int)
signal order_completed(order_id: String, count: int, income: int)
signal order_expired(order_id: String)
signal bloodline_order_completed(order_id: String, count: int, income: int)
signal merchant_chain_started(chain_id: String)
signal merchant_chain_completed(chain_id: String, total_income: int)

const DEFAULT_NORMAL_PRICE := 320
const NORMAL_PRICE_MIN := 280
const NORMAL_PRICE_MAX := 360
const ORDER_PRICE_MIN := 360
const ORDER_PRICE_MAX := 460
const BLOODLINE_PRICE_MIN := 500
const BLOODLINE_PRICE_MAX := 620
const SPECIAL_PRICE_MIN := 480
const SPECIAL_PRICE_MAX := 720
const ORDERS_PER_DAY := 2

const STATUS_ACTIVE := &"active"
const STATUS_COMPLETED := &"completed"
const STATUS_EXPIRED := &"expired"

const TYPE_HEALTHY_ADULT := &"healthy_adult"
const TYPE_SEX := &"sex"
const TYPE_YOUNG_ADULT := &"young_adult"
const TYPE_BLOODLINE := &"bloodline"

@onready var world_controller: Node = get_parent()
@onready var top_hud: Control = get_node("../HUD/TopHUD")

var normal_market_price := DEFAULT_NORMAL_PRICE
var market_day := 0
var next_order_serial := 1
var orders: Array[Dictionary] = []
var initialized := false


func _ready() -> void:
	top_hud.day_changed.connect(_on_day_changed)
	call_deferred("_ensure_market_for_day", top_hud.get_day())


func get_normal_market_price() -> int:
	return normal_market_price


func get_orders() -> Array[Dictionary]:
	return orders


func get_order(order_id: String) -> Dictionary:
	for order in orders:
		if order.id == order_id:
			return order
	return {}


func get_active_order_count() -> int:
	return orders.filter(
		func(order: Dictionary) -> bool: return order.status == STATUS_ACTIVE
	).size()


func get_save_data() -> Dictionary:
	var saved_orders: Array[Dictionary] = []
	for order in orders:
		var saved_order := order.duplicate(true)
		saved_order.type = String(order.type)
		saved_order.status = String(order.status)
		saved_order.sex = String(order.get("sex", &""))
		saved_orders.append(saved_order)
	return {
		"market_day": market_day,
		"normal_market_price": normal_market_price,
		"next_order_serial": next_order_serial,
		"orders": saved_orders,
	}


func restore_save_data(data: Dictionary) -> void:
	var has_saved_market := data.has("market_day") and data.has("normal_market_price")
	market_day = maxi(1, int(data.get("market_day", top_hud.get_day())))
	normal_market_price = clampi(
		int(data.get("normal_market_price", DEFAULT_NORMAL_PRICE)),
		NORMAL_PRICE_MIN,
		NORMAL_PRICE_MAX
	)
	if not has_saved_market:
		normal_market_price = _roll_normal_price(market_day)
	next_order_serial = maxi(1, int(data.get("next_order_serial", 1)))
	orders.clear()
	var saved_orders: Variant = data.get("orders", [])
	if saved_orders is Array:
		for value in saved_orders:
			if value is not Dictionary:
				continue
			var order := (value as Dictionary).duplicate(true)
			order.type = StringName(String(order.get("type", "")))
			order.status = StringName(String(order.get("status", String(STATUS_ACTIVE))))
			order.sex = StringName(String(order.get("sex", "")))
			if not _is_valid_saved_order(order):
				continue
			orders.append(order)
	initialized = true
	if orders.is_empty() and market_day == top_hud.get_day():
		_generate_daily_orders(market_day)
	market_changed.emit()


func mark_market_viewed() -> void:
	market_viewed.emit()


func sell_at_normal_market(quantity: int) -> Dictionary:
	quantity = maxi(1, quantity)
	var candidates := _get_normal_sale_candidates()
	if candidates.size() < quantity:
		return {"success": false, "message": "可出售成年羊不足，本批需要 %d 只" % quantity}
	var selected: Array[Node] = []
	for index in quantity:
		selected.append(candidates[index])
	var sold_count: int = world_controller.sell_specific_sheep(selected)
	if sold_count != quantity:
		return {"success": false, "message": "本批出售失败，没有增加金币"}
	var income := sold_count * normal_market_price
	top_hud.add_money(income)
	normal_sale_completed.emit(sold_count, income)
	market_changed.emit()
	return {
		"success": true,
		"count": sold_count,
		"income": income,
		"names": selected.map(func(sheep: Node) -> String: return sheep.get_sheep_name()),
	}


func get_order_candidates(order_id: String) -> Array[Node]:
	var order := get_order(order_id)
	if order.is_empty() or order.status != STATUS_ACTIVE:
		return []
	return _get_matching_sheep(order)


func can_fulfill_order(order_id: String) -> bool:
	var order := get_order(order_id)
	return (
		not order.is_empty()
		and order.status == STATUS_ACTIVE
		and int(order.deadline_day) >= top_hud.get_day()
		and get_order_candidates(order_id).size() >= int(order.quantity)
	)


func deliver_order(order_id: String) -> Dictionary:
	var order := get_order(order_id)
	if order.is_empty():
		return {"success": false, "message": "订单不存在或已经被清理"}
	if order.status != STATUS_ACTIVE:
		return {"success": false, "message": "该订单已经完成或过期"}
	if int(order.deadline_day) < top_hud.get_day():
		_expire_order(order)
		return {"success": false, "message": "该订单已经过期"}
	var candidates := _get_matching_sheep(order)
	var quantity := int(order.quantity)
	if candidates.size() < quantity:
		return {"success": false, "message": _shortage_message(order, quantity, candidates.size())}
	var selected: Array[Node] = []
	for index in quantity:
		selected.append(candidates[index])
	var delivered_names: Array[String] = []
	for sheep in selected:
		delivered_names.append(sheep.get_sheep_name())
	var sold_count: int = world_controller.sell_specific_sheep(selected)
	if sold_count != quantity:
		return {"success": false, "message": "羊群状态发生变化，请重新确认订单"}
	var income := quantity * int(order.unit_price)
	order.status = STATUS_COMPLETED
	order.completed_day = top_hud.get_day()
	order.delivered_names = delivered_names
	top_hud.add_money(income)
	order_completed.emit(order.id, quantity, income)
	if order.type == TYPE_BLOODLINE:
		bloodline_order_completed.emit(order.id, quantity, income)
	if bool(order.get("special", false)):
		if int(order.get("chain_step", 0)) == 1:
			_publish_chain_second_step(order, income)
		else:
			merchant_chain_completed.emit(String(order.get("chain_id", "")), int(order.get("chain_income_before", 0)) + income)
	market_changed.emit()
	return {
		"success": true,
		"count": quantity,
		"income": income,
		"names": delivered_names,
	}


func regenerate_market_for_tests(day: int) -> void:
	orders.clear()
	market_day = 0
	_ensure_market_for_day(day)


func _on_day_changed(new_day: int) -> void:
	_ensure_market_for_day(new_day)


func _ensure_market_for_day(day: int) -> void:
	if initialized and market_day == day:
		return
	initialized = true
	market_day = day
	_expire_overdue_orders(day)
	_prune_old_orders(day)
	normal_market_price = _roll_normal_price(day)
	_generate_daily_orders(day)
	market_changed.emit()


func _generate_daily_orders(day: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = day * 131071 + world_controller.get_sheep_count() * 4099 + next_order_serial * 17
	var templates: Array[Dictionary] = [
		{"type": TYPE_HEALTHY_ADULT, "sex": &""},
		{"type": TYPE_SEX, "sex": &"male"},
		{"type": TYPE_SEX, "sex": &"female"},
		{"type": TYPE_YOUNG_ADULT, "sex": &""},
	]
	if day >= 20:
		templates.append({"type": TYPE_BLOODLINE, "sex": &""})
	for index in range(templates.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var temporary := templates[index]
		templates[index] = templates[swap_index]
		templates[swap_index] = temporary
	var publish_chain := day >= 15 and day % 5 == 0 and not _has_active_merchant_chain()
	var regular_count := ORDERS_PER_DAY - 1 if publish_chain else ORDERS_PER_DAY
	for index in regular_count:
		var template: Dictionary = templates[index]
		orders.append(_make_order(day, template.type, template.sex, random))
	if publish_chain:
		var chain_id := "merchant_chain_%d" % day
		orders.append(_make_chain_order(day, 1, chain_id, random))
		merchant_chain_started.emit(chain_id)


func _make_order(day: int, type: StringName, required_sex: StringName, random: RandomNumberGenerator) -> Dictionary:
	var quantity := random.randi_range(1, 3)
	if type in [TYPE_SEX, TYPE_YOUNG_ADULT, TYPE_BLOODLINE]:
		quantity = random.randi_range(1, 2)
	var unit_price := (
		random.randi_range(BLOODLINE_PRICE_MIN / 10, BLOODLINE_PRICE_MAX / 10) * 10
		if type == TYPE_BLOODLINE else
		random.randi_range(ORDER_PRICE_MIN / 10, ORDER_PRICE_MAX / 10) * 10
	)
	var order := {
		"id": "market_%d_%d" % [day, next_order_serial],
		"type": type,
		"sex": required_sex,
		"quantity": quantity,
		"unit_price": unit_price,
		"created_day": day,
		"deadline_day": day + random.randi_range(2, 3),
		"status": STATUS_ACTIVE,
		"completed_day": 0,
		"delivered_names": [],
	}
	next_order_serial += 1
	var text := _order_text(order)
	order.title = text.title
	order.description = text.description
	return order


func _order_text(order: Dictionary) -> Dictionary:
	var result: Dictionary
	match order.type:
		TYPE_SEX:
			var sex_text := "公羊" if order.sex == &"male" else "母羊"
			result = {
				"title": "%s采购" % sex_text,
				"description": "%d 只健康成年%s" % [order.quantity, sex_text],
			}
		TYPE_YOUNG_ADULT:
			result = {
				"title": "青年羊采购",
				"description": "%d 只 6–12 天健康成年羊" % order.quantity,
			}
		TYPE_BLOODLINE:
			result = {
				"title": "本岛血统订单",
				"description": "%d 只第 1 代以上健康成年羊" % order.quantity,
			}
		_:
			result = {
				"title": "健康成年羊采购",
				"description": "%d 只健康成年羊，公母不限" % order.quantity,
			}
	if bool(order.get("special", false)):
		result.title = "行商连单 %d/2 · %s" % [int(order.get("chain_step", 1)), result.title]
		result.description += "；完成后继续下一批" if int(order.get("chain_step", 1)) == 1 else "；完成整组连单"
	return result


func _make_chain_order(day: int, step: int, chain_id: String, random: RandomNumberGenerator) -> Dictionary:
	var type := TYPE_HEALTHY_ADULT if step == 1 else TYPE_SEX
	var required_sex := &"" if step == 1 else (&"female" if day % 2 == 0 else &"male")
	var unit_price := (
		random.randi_range(SPECIAL_PRICE_MIN / 10, 540 / 10) * 10
		if step == 1 else random.randi_range(620 / 10, SPECIAL_PRICE_MAX / 10) * 10
	)
	var order := {
		"id": "%s_step_%d_%d" % [chain_id, step, next_order_serial],
		"type": type,
		"sex": required_sex,
		"quantity": 1,
		"unit_price": unit_price,
		"created_day": day,
		"deadline_day": day + (2 if step == 1 else 3),
		"status": STATUS_ACTIVE,
		"completed_day": 0,
		"delivered_names": [],
		"special": true,
		"chain_id": chain_id,
		"chain_step": step,
		"chain_income_before": 0,
	}
	next_order_serial += 1
	var text := _order_text(order)
	order.title = text.title
	order.description = text.description
	return order


func _publish_chain_second_step(first_order: Dictionary, first_income: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = int(first_order.created_day) * 99991 + next_order_serial * 37
	var next_order := _make_chain_order(
		top_hud.get_day(), 2, String(first_order.get("chain_id", "merchant_chain")), random
	)
	next_order.chain_income_before = first_income
	orders.append(next_order)


func _has_active_merchant_chain() -> bool:
	return orders.any(
		func(order: Dictionary) -> bool:
			return bool(order.get("special", false)) and order.status == STATUS_ACTIVE
	)


func _get_matching_sheep(order: Dictionary) -> Array[Node]:
	var result: Array[Node] = []
	for sheep in world_controller.sheep_group.get_children():
		if not _is_order_eligible(sheep):
			continue
		match order.type:
			TYPE_SEX:
				if sheep.get_sex() != order.sex:
					continue
			TYPE_YOUNG_ADULT:
				if sheep.get_age_days() < 6 or sheep.get_age_days() > 12:
					continue
			TYPE_BLOODLINE:
				if sheep.get_generation() < 1:
					continue
		result.append(sheep)
	result.sort_custom(
		func(first: Node, second: Node) -> bool:
			if first.get_age_days() == second.get_age_days():
				return first.get_sheep_id() < second.get_sheep_id()
			return first.get_age_days() > second.get_age_days()
	)
	return result


func _get_normal_sale_candidates() -> Array[Node]:
	var result: Array[Node] = []
	for sheep in world_controller.sheep_group.get_children():
		if (
			sheep.has_method("is_adult")
			and sheep.is_adult()
			and not sheep.is_pregnant()
			and not sheep.is_lost()
			and not sheep.is_queued_for_deletion()
		):
			result.append(sheep)
	result.sort_custom(
		func(first: Node, second: Node) -> bool: return first.get_age_days() > second.get_age_days()
	)
	return result


func _is_order_eligible(sheep: Node) -> bool:
	return (
		is_instance_valid(sheep)
		and not sheep.is_queued_for_deletion()
		and sheep.has_method("is_adult")
		and sheep.is_adult()
		and sheep.is_healthy()
		and not sheep.is_pregnant()
		and not sheep.is_lost()
	)


func _shortage_message(order: Dictionary, required: int, available: int) -> String:
	return "%s不足：需要 %d 只，目前只有 %d 只；生病、怀孕或走失的羊不能交付" % [
		order.description, required, available,
	]


func _expire_overdue_orders(day: int) -> void:
	for order in orders:
		if order.status == STATUS_ACTIVE and int(order.deadline_day) < day:
			_expire_order(order)


func _expire_order(order: Dictionary) -> void:
	if order.status != STATUS_ACTIVE:
		return
	order.status = STATUS_EXPIRED
	order_expired.emit(order.id)
	market_changed.emit()


func _prune_old_orders(day: int) -> void:
	orders = orders.filter(
		func(order: Dictionary) -> bool:
			return order.status == STATUS_ACTIVE or int(order.get("completed_day", 0)) >= day - 1
	)


func _roll_normal_price(day: int) -> int:
	if day <= 1:
		return DEFAULT_NORMAL_PRICE
	var random := RandomNumberGenerator.new()
	random.seed = day * 524287 + 97
	return random.randi_range(NORMAL_PRICE_MIN / 10, NORMAL_PRICE_MAX / 10) * 10


func _is_valid_saved_order(order: Dictionary) -> bool:
	return (
		String(order.get("id", "")) != ""
		and order.type in [TYPE_HEALTHY_ADULT, TYPE_SEX, TYPE_YOUNG_ADULT, TYPE_BLOODLINE]
		and order.status in [STATUS_ACTIVE, STATUS_COMPLETED, STATUS_EXPIRED]
		and int(order.get("quantity", 0)) in [1, 2, 3]
		and _is_valid_order_price(order)
		and int(order.get("deadline_day", 0)) >= int(order.get("created_day", 0))
		and (
			not bool(order.get("special", false))
			or (String(order.get("chain_id", "")) != "" and int(order.get("chain_step", 0)) in [1, 2])
		)
	)


func _is_valid_order_price(order: Dictionary) -> bool:
	var price := int(order.get("unit_price", 0))
	if bool(order.get("special", false)):
		return price >= SPECIAL_PRICE_MIN and price <= SPECIAL_PRICE_MAX
	if order.type == TYPE_BLOODLINE:
		return price >= BLOODLINE_PRICE_MIN and price <= BLOODLINE_PRICE_MAX
	return price >= ORDER_PRICE_MIN and price <= ORDER_PRICE_MAX
