extends Node

signal guidance_changed(title: String, body: String, urgent: bool)
signal wolf_den_discovered
signal wolf_tracks_appeared(day: int)
signal wolf_patrol_completed(dog: Node, defense_bonus: int)
signal sheep_scattered(sheep_list: Array, ended_day: int)

const AUTO_ROUNDUP_PROGRESS := 0.72
const WOLF_DISCOVERY_DAY := 12
const WOLF_DISCOVERY_LAND_COUNT := 3
const WOLF_SAFE_SCORE := 80
const WOLF_WARNING_SCORE := 50
const WOLF_PATROL_DEFENSE_BONUS := 15
const WOLF_PATROL_STAMINA_COST := 8
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
var wolf_tracks_day := 0
var wolf_tracks_position := Vector2.ZERO
var wolf_tracks_investigated_day := 0
var wolf_patrol_bonus_day := 0
var wolf_patrol_active := false
var wolf_patrol_dog_index := -1
var wolf_tracks_node: Node2D
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
	_update_wolf_patrol()
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
		"wolf_tracks_day": wolf_tracks_day,
		"wolf_tracks_position": [wolf_tracks_position.x, wolf_tracks_position.y],
		"wolf_tracks_investigated_day": wolf_tracks_investigated_day,
		"wolf_patrol_bonus_day": wolf_patrol_bonus_day,
		"wolf_patrol_active": wolf_patrol_active,
		"wolf_patrol_dog_index": wolf_patrol_dog_index,
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
	wolf_tracks_day = maxi(0, int(data.get("wolf_tracks_day", 0)))
	wolf_tracks_investigated_day = maxi(0, int(data.get("wolf_tracks_investigated_day", 0)))
	wolf_patrol_bonus_day = maxi(0, int(data.get("wolf_patrol_bonus_day", 0)))
	wolf_patrol_active = bool(data.get("wolf_patrol_active", false))
	wolf_patrol_dog_index = int(data.get("wolf_patrol_dog_index", -1))
	var saved_risk: Variant = data.get("last_wolf_risk_result", {})
	last_wolf_risk_result = (saved_risk as Dictionary).duplicate(true) if saved_risk is Dictionary else {}
	var position_value: Variant = data.get("wolf_den_position", [])
	if position_value is Array and position_value.size() >= 2:
		wolf_den_position = Vector2(float(position_value[0]), float(position_value[1]))
	var tracks_position_value: Variant = data.get("wolf_tracks_position", [])
	if tracks_position_value is Array and tracks_position_value.size() >= 2:
		wolf_tracks_position = Vector2(float(tracks_position_value[0]), float(tracks_position_value[1]))
	if wolf_den_found:
		_spawn_wolf_den()
		if wolf_tracks_day <= 0:
			_prepare_daily_wolf_tracks(top_hud.get_day())
		elif wolf_tracks_investigated_day != wolf_tracks_day:
			_spawn_wolf_tracks()
	if wolf_patrol_active and not is_instance_valid(_get_patrol_dog()):
		wolf_patrol_active = false
		wolf_patrol_dog_index = -1
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
	var shepherd_house_level := maxi(1, build_controller.get_highest_building_level(&"shepherd_house"))
	player.wake_up([25, 40, 55][shepherd_house_level - 1])
	dog_manager.wake_all()
	for sheep in world_controller.sheep_group.get_children():
		sheep.wake_from_shelter()
	player.stop_auto_roundup()
	dog_manager.stop_auto_roundup()
	last_guidance_key = ""
	_try_discover_wolf_den()
	_prepare_daily_wolf_tracks(_new_day)


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

	var defense := get_wolf_defense_preview(ended_day)
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
		var scattered_sheep: Array[Node] = _scatter_unsecured_sheep(stray_target, ended_day)
		result.strayed_count = scattered_sheep.size()
		result.frightened_count = result.strayed_count
		var requested_loss := clampi(120 + (WOLF_WARNING_SCORE - int(defense.score)) * 6, 120, 360)
		result.money_loss = mini(requested_loss, top_hud.get_money())
		if int(result.money_loss) > 0:
			top_hud.spend_money(int(result.money_loss))
		if not scattered_sheep.is_empty():
			sheep_scattered.emit(scattered_sheep, ended_day)
	last_wolf_risk_result = result
	return last_wolf_risk_result


func get_wolf_defense_preview(for_day := 0) -> Dictionary:
	var defense_day: int = top_hud.get_day() if for_day <= 0 else for_day
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
	var dog_score := mini(20, dog_manager.get_total_night_defense_points())
	var patrol_score := WOLF_PATROL_DEFENSE_BONUS if wolf_patrol_bonus_day == defense_day else 0
	return {
		"score": clampi(secured_score + gate_score + dog_score + patrol_score, 0, 100),
		"secured_count": secured_count,
		"sheep_count": sheep_count,
		"closed_gates": closed_gates,
		"gate_count": fences.size(),
		"dog_count": dog_count,
		"dog_score": dog_score,
		"patrol_score": patrol_score,
	}


func get_wolf_risk_report_text(ended_day: int) -> String:
	var result := evaluate_wolf_night_risk(ended_day)
	if result.is_empty() or not bool(result.get("active", false)):
		return "未发生（尚未发现狼窝）"
	var defense_text := "防护 %d，安全安置 %d / %d，关门 %d / %d，牧羊犬 %d（%d 分），狼迹巡查 +%d" % [
		int(result.get("score", 0)),
		int(result.get("secured_count", 0)),
		int(result.get("sheep_count", 0)),
		int(result.get("closed_gates", 0)),
		int(result.get("gate_count", 0)),
		int(result.get("dog_count", 0)),
		int(result.get("dog_score", 0)),
		int(result.get("patrol_score", 0)),
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


func _scatter_unsecured_sheep(target_count: int, ended_day: int) -> Array[Node]:
	var random := RandomNumberGenerator.new()
	random.seed = ended_day * 7919 + world_controller.get_sheep_count() * 101
	var scattered: Array[Node] = []
	for sheep in _get_unsecured_sheep():
		var stray_position: Variant = _find_unfenced_land_position(random)
		if stray_position is not Vector2:
			break
		sheep.global_position = stray_position as Vector2
		if sheep.has_method("end_drag"):
			sheep.end_drag()
		if sheep.has_method("scare"):
			sheep.scare(wolf_den_position)
		scattered.append(sheep)
		if scattered.size() >= target_count:
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


func has_pending_wolf_tracks() -> bool:
	return (
		wolf_den_found
		and wolf_tracks_day == top_hud.get_day()
		and wolf_tracks_investigated_day != wolf_tracks_day
	)


func get_wolf_patrol_status() -> String:
	if wolf_patrol_bonus_day == top_hud.get_day():
		return "今日狼迹已巡查，当夜防护 +%d。" % WOLF_PATROL_DEFENSE_BONUS
	if wolf_patrol_active:
		return "正在前往外围狼迹，抵达后当夜防护 +%d。" % WOLF_PATROL_DEFENSE_BONUS
	if has_pending_wolf_tracks():
		return "外围发现新鲜狼迹，可派体力充足的牧羊犬巡查。"
	return "今天没有需要巡查的新鲜狼迹。"


func request_wolf_patrol(dog: Variant) -> Dictionary:
	if not has_pending_wolf_tracks():
		return {"success": false, "message": "今天没有尚未巡查的狼迹"}
	if top_hud.is_night():
		return {"success": false, "message": "已经入夜，巡查需要在白天完成"}
	if not is_instance_valid(dog) or dog not in dog_manager.get_dogs():
		return {"success": false, "message": "请选择一只可用的牧羊犬"}
	if dog.get_stamina_percent() < WOLF_PATROL_STAMINA_COST:
		return {"success": false, "message": "这只牧羊犬体力不足，至少需要 %d 点" % WOLF_PATROL_STAMINA_COST}
	if wolf_patrol_active:
		return {"success": false, "message": "已经有牧羊犬正在巡查"}
	dog.set_command_mode(dog.CommandMode.GUARD)
	dog.set_command_target(wolf_tracks_position)
	wolf_patrol_active = true
	wolf_patrol_dog_index = dog.dog_index
	last_guidance_key = ""
	_refresh_guidance()
	return {"success": true, "message": "牧羊犬正在前往新鲜狼迹"}


func _prepare_daily_wolf_tracks(day: int) -> void:
	if not wolf_den_found or day < wolf_den_discovered_day or wolf_tracks_day == day:
		return
	_cancel_wolf_patrol()
	wolf_tracks_day = day
	wolf_tracks_investigated_day = 0
	wolf_tracks_position = _choose_wolf_tracks_position()
	_spawn_wolf_tracks()
	wolf_tracks_appeared.emit(day)
	last_guidance_key = ""


func _choose_wolf_tracks_position() -> Vector2:
	var pasture_center: Vector2 = world_controller.get_land_chunk_center(Vector2i.ZERO)
	var inward: Vector2 = wolf_den_position.direction_to(pasture_center)
	if inward == Vector2.ZERO:
		inward = Vector2.LEFT
	var candidate: Vector2 = wolf_den_position + inward * 96.0
	return world_controller.clamp_point_to_land(candidate, pasture_center)


func _spawn_wolf_tracks() -> void:
	_remove_wolf_tracks()
	if wolf_tracks_position == Vector2.ZERO:
		wolf_tracks_position = _choose_wolf_tracks_position()
	wolf_tracks_node = Node2D.new()
	wolf_tracks_node.name = "WolfTracks"
	wolf_tracks_node.position = wolf_tracks_position
	wolf_tracks_node.z_index = 7
	wolf_tracks_node.set_meta("world_entity_type", &"wolf_tracks")
	decorations.add_child(wolf_tracks_node)
	for step_index in 3:
		var paw := Node2D.new()
		paw.position = Vector2(float(step_index - 1) * 22.0, sin(float(step_index) * PI) * 5.0)
		paw.rotation = -0.2 + float(step_index) * 0.16
		wolf_tracks_node.add_child(paw)
		_add_paw_shape(paw)
	var label := Label.new()
	label.position = Vector2(-46, -43)
	label.size = Vector2(92, 24)
	label.text = "新鲜狼迹"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("fff0b0"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.10, 0.08, 0.82)
	style.border_color = Color("d7a44f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	label.add_theme_stylebox_override("normal", style)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wolf_tracks_node.add_child(label)


func _add_paw_shape(parent: Node2D) -> void:
	var color := Color("4a2b24")
	var pad := Polygon2D.new()
	pad.polygon = _ellipse_polygon(7.0, 5.0)
	pad.position = Vector2(0.0, 4.0)
	pad.color = color
	parent.add_child(pad)
	for toe_position in [Vector2(-6, -3), Vector2(0, -6), Vector2(6, -3)]:
		var toe := Polygon2D.new()
		toe.polygon = _ellipse_polygon(2.5, 3.5)
		toe.position = toe_position
		toe.color = color
		parent.add_child(toe)


func _ellipse_polygon(radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in 12:
		var angle := TAU * float(point_index) / 12.0
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _update_wolf_patrol() -> void:
	if not wolf_patrol_active:
		return
	var dog: Variant = _get_patrol_dog()
	if not is_instance_valid(dog):
		_cancel_wolf_patrol()
		return
	if dog.global_position.distance_to(wolf_tracks_position) > 24.0:
		return
	dog.consume_stamina(float(WOLF_PATROL_STAMINA_COST))
	dog.set_command_mode(dog.CommandMode.FOLLOW, false)
	wolf_tracks_investigated_day = wolf_tracks_day
	wolf_patrol_bonus_day = wolf_tracks_day
	wolf_patrol_active = false
	wolf_patrol_dog_index = -1
	_remove_wolf_tracks()
	wolf_patrol_completed.emit(dog, WOLF_PATROL_DEFENSE_BONUS)
	last_guidance_key = ""
	_refresh_guidance()


func _get_patrol_dog() -> Variant:
	for dog in dog_manager.get_dogs():
		if dog.dog_index == wolf_patrol_dog_index:
			return dog
	return null


func _cancel_wolf_patrol() -> void:
	wolf_patrol_active = false
	wolf_patrol_dog_index = -1


func _remove_wolf_tracks() -> void:
	if is_instance_valid(wolf_tracks_node):
		wolf_tracks_node.queue_free()
	wolf_tracks_node = null


func _try_start_auto_roundup() -> void:
	if (
		top_hud.day_progress < _get_auto_roundup_progress()
		or auto_roundup_day == top_hud.get_day()
		or build_controller.get_fence_roots().is_empty()
		or not dog_manager.has_active_dog()
	):
		return
	_cancel_wolf_patrol()
	var fence: Node2D = build_controller.get_fence_roots()[0]
	build_controller.set_gate_open(fence, true, true)
	player.start_auto_roundup(fence)
	dog_manager.start_auto_roundup((fence.get_meta("grazing_rect") as Rect2).get_center())
	auto_roundup_day = top_hud.get_day()


func _get_auto_roundup_progress() -> float:
	var level := maxi(1, build_controller.get_highest_building_level(&"shepherd_house"))
	return AUTO_ROUNDUP_PROGRESS - float(level - 1) * 0.04


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
	_prepare_daily_wolf_tracks(top_hud.get_day())


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
	if wolf_patrol_active:
		title = "牧羊犬巡查"
		body = "牧羊犬正在前往外围狼迹；抵达后今晚防护增加 %d 分。" % WOLF_PATROL_DEFENSE_BONUS
		urgent = true
	elif has_pending_wolf_tracks() and not top_hud.is_night():
		title = "外围狼迹"
		body = (
			"选中一只牧羊犬，在底部信息栏点击“巡查狼迹”。"
			if dog_manager.has_active_dog() else "外围有新鲜脚印；建造牧羊犬小屋后才能提前巡查。"
		)
		urgent = true
	else:
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
