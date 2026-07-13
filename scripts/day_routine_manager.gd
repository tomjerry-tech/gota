extends Node

signal guidance_changed(title: String, body: String, urgent: bool)
signal wolf_den_discovered

const AUTO_ROUNDUP_PROGRESS := 0.72
const WOLF_DISCOVERY_DAY := 12
const WOLF_DISCOVERY_LAND_COUNT := 3
const WOLF_SAFE_SCORE := 80
const WOLF_WARNING_SCORE := 50
const WOLF_DEN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/wolf/wolf_den.png")

@onready var world_controller: Node = get_parent()
@onready var top_hud: Control = get_node("../HUD/TopHUD")
@onready var build_controller: Node = get_node("../BuildController")
@onready var player: AnimatedSprite2D = get_node("../Island/Shepherd")
@onready var dog_manager: Node = get_node("../DogManager")
@onready var roundup_manager: Control = get_node("../HUD/RoundupStatus")
@onready var decorations: Node2D = get_node("../Island/Decorations")

var auto_roundup_day := 0
var gates_closed_day := 0
var wolf_den_found := false
var wolf_den_position := Vector2.ZERO
var wolf_den_node: Node2D
var wolf_den_discovered_day := 0
var wolf_risk_evaluated_day := 0
var last_wolf_risk_result: Dictionary = {}
var last_guidance_key := ""
var refresh_time := 0.0


func _ready() -> void:
	top_hud.day_changed.connect(_on_day_changed)
	build_controller.land_expanded.connect(_try_discover_wolf_den)
	_refresh_guidance()
	call_deferred("_try_discover_wolf_den")


func _process(delta: float) -> void:
	refresh_time -= delta
	if refresh_time > 0.0:
		return
	refresh_time = 0.2
	_try_start_auto_roundup()
	_try_close_gates_at_night()
	_try_discover_wolf_den()
	_refresh_guidance()


func get_save_data() -> Dictionary:
	return {
		"auto_roundup_day": auto_roundup_day,
		"gates_closed_day": gates_closed_day,
		"wolf_den_found": wolf_den_found,
		"wolf_den_position": [wolf_den_position.x, wolf_den_position.y],
		"wolf_den_discovered_day": wolf_den_discovered_day,
		"wolf_risk_evaluated_day": wolf_risk_evaluated_day,
		"last_wolf_risk_result": last_wolf_risk_result.duplicate(true),
	}


func restore_save_data(data: Dictionary) -> void:
	auto_roundup_day = maxi(0, int(data.get("auto_roundup_day", 0)))
	gates_closed_day = maxi(0, int(data.get("gates_closed_day", 0)))
	wolf_den_found = bool(data.get("wolf_den_found", false))
	wolf_den_discovered_day = maxi(0, int(data.get(
		"wolf_den_discovered_day",
		WOLF_DISCOVERY_DAY if wolf_den_found else 0
	)))
	wolf_risk_evaluated_day = maxi(0, int(data.get("wolf_risk_evaluated_day", 0)))
	var saved_risk: Variant = data.get("last_wolf_risk_result", {})
	last_wolf_risk_result = (saved_risk as Dictionary).duplicate(true) if saved_risk is Dictionary else {}
	var position_value: Variant = data.get("wolf_den_position", [])
	if position_value is Array and position_value.size() >= 2:
		wolf_den_position = Vector2(float(position_value[0]), float(position_value[1]))
	if wolf_den_found:
		_spawn_wolf_den()
	last_guidance_key = ""
	_refresh_guidance()


func assign_building_rest(building: Node2D) -> Dictionary:
	if not is_instance_valid(building) or not top_hud.is_night():
		return {"success": false, "message": "只有夜间才能安排角色进屋休息"}
	match building.get_meta("build_item_id", &""):
		&"shepherd_house":
			if player.send_to_rest(building.global_position):
				return {"success": true, "message": "牧羊人正在前往小屋，完成休息后次日恢复满体力"}
		&"dog_house":
			if dog_manager.send_dog_to_house(building):
				return {"success": true, "message": "对应牧羊犬正在返回狗窝，完成休息后次日恢复满体力"}
		&"lamb_shelter":
			var assigned := 0
			for sheep in world_controller.sheep_group.get_children():
				if not sheep.is_adult() and sheep.send_to_shelter(building.global_position + Vector2(0.0, 48.0)):
					assigned += 1
			if assigned > 0:
				return {"success": true, "message": "已安排 %d 只幼羊进入小羊棚" % assigned}
			return {"success": false, "message": "当前没有可以安排休息的幼羊"}
	return {"success": false, "message": "当前角色已经在休息或无法进入这座建筑"}


func _on_day_changed(_new_day: int) -> void:
	evaluate_wolf_night_risk(_new_day - 1)
	player.wake_up()
	dog_manager.wake_all()
	for sheep in world_controller.sheep_group.get_children():
		sheep.wake_from_shelter()
	player.stop_auto_roundup()
	dog_manager.stop_auto_roundup()
	last_guidance_key = ""
	_try_discover_wolf_den()


func evaluate_wolf_night_risk(ended_day: int) -> Dictionary:
	if ended_day <= wolf_risk_evaluated_day:
		return last_wolf_risk_result if int(last_wolf_risk_result.get("day", -1)) == ended_day else {}
	wolf_risk_evaluated_day = ended_day
	if not wolf_den_found or ended_day < wolf_den_discovered_day:
		last_wolf_risk_result = {
			"day": ended_day,
			"active": false,
			"outcome": "inactive",
		}
		return last_wolf_risk_result

	var defense := get_wolf_defense_preview()
	var result := defense.duplicate(true)
	result.day = ended_day
	result.active = true
	result.frightened_count = 0
	result.strayed_count = 0
	result.money_loss = 0
	if int(defense.score) >= WOLF_SAFE_SCORE:
		result.outcome = "safe"
	elif int(defense.score) >= WOLF_WARNING_SCORE:
		result.outcome = "warning"
		result.frightened_count = _frighten_sheep(1)
	else:
		result.outcome = "breach"
		var stray_target := 1 if int(defense.score) >= 25 else 2
		result.strayed_count = _scatter_unsecured_sheep(stray_target, ended_day)
		result.frightened_count = result.strayed_count
		var requested_loss := clampi(120 + (WOLF_WARNING_SCORE - int(defense.score)) * 6, 120, 360)
		result.money_loss = mini(requested_loss, top_hud.get_money())
		if int(result.money_loss) > 0:
			top_hud.spend_money(int(result.money_loss))
	last_wolf_risk_result = result
	return last_wolf_risk_result


func get_wolf_defense_preview() -> Dictionary:
	var sheep_count: int = world_controller.get_sheep_count()
	var secured_count := 0
	for sheep in world_controller.sheep_group.get_children():
		if _is_sheep_secured(sheep):
			secured_count += 1
	var fences: Array[Node2D] = build_controller.get_fence_roots()
	var closed_gates := fences.filter(
		func(fence: Node2D) -> bool: return not bool(fence.get_meta("gate_open", false))
	).size()
	var dogs: Array[AnimatedSprite2D] = dog_manager.get_dogs()
	var dog_count := dogs.size()
	var secured_score := roundi(60.0 * float(secured_count) / float(maxi(1, sheep_count)))
	var gate_score := roundi(20.0 * float(closed_gates) / float(fences.size())) if not fences.is_empty() else 0
	var dog_score := 0
	for dog in dogs:
		dog_score += dog.get_night_defense_points()
	dog_score = mini(20, dog_score)
	return {
		"score": clampi(secured_score + gate_score + dog_score, 0, 100),
		"secured_count": secured_count,
		"sheep_count": sheep_count,
		"closed_gates": closed_gates,
		"gate_count": fences.size(),
		"dog_count": dog_count,
		"dog_score": dog_score,
	}


func get_wolf_risk_report_text(ended_day: int) -> String:
	var result := evaluate_wolf_night_risk(ended_day)
	if result.is_empty() or not bool(result.get("active", false)):
		return "未发生（尚未发现狼窝）"
	var defense_text := "防护 %d，安全安置 %d / %d，关门 %d / %d，牧羊犬 %d（%d 分）" % [
		int(result.get("score", 0)),
		int(result.get("secured_count", 0)),
		int(result.get("sheep_count", 0)),
		int(result.get("closed_gates", 0)),
		int(result.get("gate_count", 0)),
		int(result.get("dog_count", 0)),
		int(result.get("dog_score", 0)),
	]
	match String(result.get("outcome", "inactive")):
		"safe":
			return "平安，%s" % defense_text
		"warning":
			return "有狼靠近，%d 只羊受惊；%s" % [int(result.get("frightened_count", 0)), defense_text]
		"breach":
			return "外围受扰，%d 只羊走散，损失 %d 金币；%s" % [
				int(result.get("strayed_count", 0)),
				int(result.get("money_loss", 0)),
				defense_text,
			]
	return "未发生"


func _is_sheep_secured(sheep: Node) -> bool:
	if bool(sheep.get("sheltered")):
		return true
	for fence in build_controller.get_fence_roots():
		if (
			not bool(fence.get_meta("gate_open", false))
			and (fence.get_meta("grazing_rect") as Rect2).has_point(sheep.global_position)
		):
			return true
	return false


func _frighten_sheep(target_count: int) -> int:
	var frightened := 0
	for sheep in _get_unsecured_sheep():
		if sheep.has_method("scare"):
			sheep.scare(wolf_den_position)
			frightened += 1
			if frightened >= target_count:
				break
	return frightened


func _scatter_unsecured_sheep(target_count: int, ended_day: int) -> int:
	var random := RandomNumberGenerator.new()
	random.seed = ended_day * 7919 + world_controller.get_sheep_count() * 101
	var scattered := 0
	for sheep in _get_unsecured_sheep():
		var stray_position: Variant = _find_unfenced_land_position(random)
		if stray_position is not Vector2:
			break
		sheep.global_position = stray_position as Vector2
		if sheep.has_method("end_drag"):
			sheep.end_drag()
		if sheep.has_method("scare"):
			sheep.scare(wolf_den_position)
		scattered += 1
		if scattered >= target_count:
			break
	return scattered


func _get_unsecured_sheep() -> Array[Node]:
	var result: Array[Node] = []
	for sheep in world_controller.sheep_group.get_children():
		if not _is_sheep_secured(sheep):
			result.append(sheep)
	result.sort_custom(
		func(first: Node, second: Node) -> bool:
			return first.global_position.distance_squared_to(wolf_den_position) < second.global_position.distance_squared_to(wolf_den_position)
	)
	return result


func _find_unfenced_land_position(random: RandomNumberGenerator) -> Variant:
	var start_angle := random.randf_range(0.0, TAU)
	for radius: float in [92.0, 128.0, 164.0, 200.0]:
		for index in 12:
			var angle: float = start_angle + TAU * float(index) / 12.0
			var candidate: Vector2 = wolf_den_position + Vector2.from_angle(angle) * radius
			if world_controller.is_point_on_land(candidate, 18.0) and not _is_position_in_any_fence(candidate):
				return candidate
	return null


func _is_position_in_any_fence(position_value: Vector2) -> bool:
	return build_controller.get_fence_roots().any(
		func(fence: Node2D) -> bool:
			return (fence.get_meta("grazing_rect") as Rect2).has_point(position_value)
	)


func _try_start_auto_roundup() -> void:
	if (
		top_hud.day_progress < AUTO_ROUNDUP_PROGRESS
		or auto_roundup_day == top_hud.get_day()
		or build_controller.get_fence_roots().is_empty()
		or not dog_manager.has_active_dog()
	):
		return
	var fence: Node2D = build_controller.get_fence_roots()[0]
	build_controller.set_gate_open(fence, true, true)
	player.start_auto_roundup(fence)
	dog_manager.start_auto_roundup((fence.get_meta("grazing_rect") as Rect2).get_center())
	auto_roundup_day = top_hud.get_day()


func _try_close_gates_at_night() -> void:
	if not top_hud.is_night() or gates_closed_day == top_hud.get_day():
		return
	var fences: Array[Node2D] = build_controller.get_fence_roots()
	if fences.is_empty():
		return
	var target := maxi(1, roundup_manager.target_count)
	var best := 0
	for fence in fences:
		best = maxi(best, build_controller.get_fence_sheep_count(fence))
	if best < target:
		return
	for fence in fences:
		build_controller.set_gate_open(fence, false, true)
	player.stop_auto_roundup()
	dog_manager.stop_auto_roundup()
	gates_closed_day = top_hud.get_day()


func _try_discover_wolf_den() -> void:
	if wolf_den_found or top_hud.get_day() < WOLF_DISCOVERY_DAY or world_controller.get_land_chunk_count() < WOLF_DISCOVERY_LAND_COUNT:
		return
	wolf_den_found = true
	wolf_den_discovered_day = top_hud.get_day()
	wolf_den_position = _choose_outer_land_position()
	_spawn_wolf_den()
	wolf_den_discovered.emit()


func _choose_outer_land_position() -> Vector2:
	var farthest := Vector2i.ZERO
	var farthest_length := -1
	for coordinate: Vector2i in world_controller.occupied_land:
		var length := absi(coordinate.x) + absi(coordinate.y)
		if length > farthest_length:
			farthest = coordinate
			farthest_length = length
	var outward := Vector2(farthest).normalized()
	if outward == Vector2.ZERO:
		outward = Vector2.RIGHT
	var candidate: Vector2 = world_controller.get_land_chunk_center(farthest) + outward * 118.0
	return world_controller.clamp_point_to_land(candidate, world_controller.get_land_chunk_center(farthest))


func _spawn_wolf_den() -> void:
	if is_instance_valid(wolf_den_node):
		return
	wolf_den_node = Node2D.new()
	wolf_den_node.name = "WolfDen"
	wolf_den_node.position = wolf_den_position
	wolf_den_node.set_meta("world_entity_type", &"wolf_den")
	decorations.add_child(wolf_den_node)
	var sprite := Sprite2D.new()
	sprite.texture = WOLF_DEN_TEXTURE
	sprite.scale = Vector2(0.62, 0.62)
	sprite.z_index = 5
	wolf_den_node.add_child(sprite)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 46.0
	shape_node.shape = shape
	body.add_child(shape_node)
	wolf_den_node.add_child(body)
	world_controller._register_build_circle(wolf_den_position, 50.0)


func _refresh_guidance() -> void:
	var title := ""
	var body := ""
	var urgent := false
	match top_hud.get_day_phase():
		&"morning":
			title = "清晨照料"
			body = "检查病羊和草量，再决定今天购买、出售或扩建什么。"
		&"day":
			title = "白天经营"
			body = "完成今日 2 项任务；奖励会随日期和难度逐步提高。"
		&"dusk":
			title = "傍晚回圈"
			urgent = true
			body = (
				"牧羊人与牧羊犬正在协助把羊赶入围栏。"
				if auto_roundup_day == top_hud.get_day()
				else "建好围栏和狗窝后，牧羊人与牧羊犬会在傍晚协助回圈。"
			)
		&"night":
			title = "夜间安置"
			urgent = wolf_den_found
			body = (
				"当前防护 %d。赶羊入圈并关门；疲惫犬只的守夜效果会下降。" % int(get_wolf_defense_preview().score)
				if wolf_den_found else "点击小屋安排牧羊人、牧羊犬或幼羊进屋休息。"
			)
	var key := "%s|%s|%s" % [title, body, str(urgent)]
	if key == last_guidance_key:
		return
	last_guidance_key = key
	guidance_changed.emit(title, body, urgent)
