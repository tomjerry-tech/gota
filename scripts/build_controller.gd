extends Node2D

signal building_placed(item_id: StringName)
signal fence_placed
signal land_expanded
signal gate_toggled(fence: Node, is_open: bool)
signal building_removed(item_id: StringName)
signal building_upgraded(building: Node, item_id: StringName, level: int)

const GRID_SIZE := 40.0
const FENCE_PRICE := 8
const UPGRADE_UNLOCK_DAY := 20
const MAX_BUILDING_LEVEL := 3
const VALID_TINT := Color(0.68, 1.0, 0.68, 0.78)
const INVALID_TINT := Color(1.0, 0.48, 0.42, 0.78)
const FENCE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/fence.png")
const FENCE_GATE_TEXTURE := preload("res://assets/tiny_swords/buildings/fence_gate.png")
const DEMOLITION_HAMMER_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/demolition_hammer.png")
const DOG_HOUSE_TEXTURE := preload("res://assets/tiny_swords/buildings/dog_house.png")
const SHEPHERD_HOUSE_TEXTURE := preload("res://assets/tiny_swords/ui/build_menu/shepherd_house.png")
const LAMB_SHELTER_TEXTURE := preload("res://assets/tiny_swords/buildings/lamb_shelter.png")

const BUILDINGS := {
	&"dog_house": {
		"display_name": "牧羊犬小屋",
		"price": 180,
		"texture": DOG_HOUSE_TEXTURE,
		"scale": Vector2(0.125, 0.125),
		"footprint": Vector2(102.0, 72.0),
	},
	&"shepherd_house": {
		"display_name": "牧民小屋",
		"price": 320,
		"texture": SHEPHERD_HOUSE_TEXTURE,
		"scale": Vector2(2.2, 2.2),
		"footprint": Vector2(88.0, 78.0),
	},
	&"lamb_shelter": {
		"display_name": "小羊棚",
		"price": 240,
		"texture": LAMB_SHELTER_TEXTURE,
		"scale": Vector2(0.165, 0.165),
		"footprint": Vector2(120.0, 84.0),
	},
}
const UPGRADE_COSTS := {
	&"dog_house": {2: 500, 3: 900},
	&"shepherd_house": {2: 700, 3: 1200},
	&"lamb_shelter": {2: 600, 3: 1000},
}

@onready var buildings_root: Node2D = get_node("../Island/Buildings")
@onready var top_hud: Control = get_node("../HUD/TopHUD")
@onready var build_menu: Control = get_node("../HUD/BuildMenu")
@onready var bottom_toolbar: Control = get_node("../HUD/BottomToolbar")
@onready var world_controller: Node = get_parent()

var selected_item_id: StringName = &""
var selected_item_data: Dictionary = {}
var is_pointer_down := false
var drag_start := Vector2.ZERO
var preview_root: Node2D
var status_label: Label
var placed_footprints: Array[Rect2] = []
var demolition_hammer_frames: SpriteFrames
var demolition_in_progress := false


func _ready() -> void:
	demolition_hammer_frames = _build_demolition_hammer_frames()
	_create_status_label()
	call_deferred("_connect_build_menu")


func _connect_build_menu() -> void:
	if not build_menu.build_item_selected.is_connected(_on_build_item_selected):
		build_menu.build_item_selected.connect(_on_build_item_selected)
	if not build_menu.demolition_selected.is_connected(_on_demolition_selected):
		build_menu.demolition_selected.connect(_on_demolition_selected)
	if not bottom_toolbar.tab_selected.is_connected(_on_toolbar_tab_selected):
		bottom_toolbar.tab_selected.connect(_on_toolbar_tab_selected)


func is_build_mode_active() -> bool:
	return selected_item_id != &""


func select_build_item(item_id: StringName, item_data: Dictionary = {}) -> void:
	_clear_preview()
	is_pointer_down = false
	if item_id == &"land_expand":
		selected_item_id = item_id
		selected_item_data = item_data
		_show_status("%s：移动到已有土地的上、下、左或右侧，点击放置" % _selected_land_type_name())
		return
	if item_id == &"demolish":
		selected_item_id = item_id
		selected_item_data = item_data
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		_show_status("拆除模式：按住鼠标拖到小屋或围栏上，松开后拆除")
		return
	if item_id != &"fence" and not BUILDINGS.has(item_id):
		cancel_build_mode()
		return

	selected_item_id = item_id
	selected_item_data = item_data
	var display_name: String = item_data.get(
		"display_name",
		"木围栏" if item_id == &"fence" else BUILDINGS[item_id].display_name
	)
	_show_status("已选择%s：在草地上按住并拖动，右键取消" % display_name)


func cancel_build_mode() -> void:
	selected_item_id = &""
	selected_item_data = {}
	is_pointer_down = false
	_clear_preview()
	_hide_status()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _on_build_item_selected(item_id: StringName, item_data: Dictionary) -> void:
	select_build_item(item_id, item_data)
	build_menu.close_menu()


func _on_demolition_selected() -> void:
	select_build_item(&"demolish", {"display_name": "拆除"})
	build_menu.close_menu()


func _on_toolbar_tab_selected(tab_name: StringName) -> void:
	if tab_name != &"build":
		cancel_build_mode()


func _unhandled_input(event: InputEvent) -> void:
	if not is_build_mode_active():
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_build_mode()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_build_mode()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if selected_item_id == &"demolish":
				if event.pressed:
					is_pointer_down = true
					_update_preview(get_global_mouse_position())
				elif is_pointer_down:
					is_pointer_down = false
					try_demolish_at(get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return
			if selected_item_id == &"land_expand":
				if event.pressed:
					try_expand_land_at(get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return
			if event.pressed:
				_begin_pointer_drag(get_global_mouse_position())
			else:
				_finish_pointer_drag(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_update_preview(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func _begin_pointer_drag(mouse_position: Vector2) -> void:
	if not world_controller.is_point_on_land(mouse_position):
		_show_status("只能在草地范围内建造")
		return
	is_pointer_down = true
	drag_start = _snap_to_grid(mouse_position)
	_update_preview(mouse_position)
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


func _finish_pointer_drag(mouse_position: Vector2) -> void:
	if not is_pointer_down:
		return
	is_pointer_down = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	var placed := false
	if selected_item_id == &"fence":
		placed = try_place_fence(drag_start, _snap_to_grid(mouse_position))
	else:
		placed = try_place_building(selected_item_id, _snap_to_grid(mouse_position))

	if placed:
		cancel_build_mode()
	else:
		_update_preview(mouse_position)


func _update_preview(mouse_position: Vector2) -> void:
	if not is_build_mode_active():
		return
	if selected_item_id == &"land_expand":
		_show_land_expansion_preview(mouse_position)
	elif selected_item_id == &"demolish":
		_show_demolition_preview(mouse_position)
	elif selected_item_id == &"fence":
		if not is_pointer_down:
			return
		_show_fence_preview(drag_start, _snap_to_grid(mouse_position))
	else:
		_show_building_preview(selected_item_id, _snap_to_grid(mouse_position))


func try_place_fence(start: Vector2, end: Vector2) -> bool:
	var fence_rect := _make_fence_rect(start, end)
	var footprints := _fence_footprints(fence_rect)
	var cost := _fence_segment_count(fence_rect) * FENCE_PRICE
	if not _can_place_fence(footprints):
		_show_status("围栏边缘超出草地、横穿自然物或与建筑重叠")
		return false
	if not top_hud.spend_money(cost):
		_show_status("金币不足：这圈围栏需要 %d 金币" % cost)
		return false

	_create_fence(fence_rect, cost, true)
	return true


func try_place_building(item_id: StringName, build_position: Vector2) -> bool:
	if not BUILDINGS.has(item_id):
		return false
	if item_id == &"dog_house" and world_controller.get_building_count(&"dog_house") >= get_allowed_dog_house_count():
		_show_status("当前最多建造 %d 座狗窝；每经过 10 天增加 1 座上限" % get_allowed_dog_house_count())
		return false
	var config: Dictionary = BUILDINGS[item_id]
	var footprint := _building_footprint(build_position, config.footprint)
	if not _building_footprint_is_valid(footprint):
		_show_status("这里有草、自然物或其他建筑，无法放置%s" % config.display_name)
		return false
	if not top_hud.spend_money(config.price):
		_show_status("金币不足：%s需要 %d 金币" % [config.display_name, config.price])
		return false

	_create_building(item_id, build_position, true)
	return true


func get_allowed_dog_house_count() -> int:
	return 1 + floori(float(maxi(0, top_hud.get_day() - 1)) / 10.0)


func get_buildings_by_type(item_id: StringName) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in buildings_root.get_children():
		if not building.is_queued_for_deletion() and building.get_meta("build_item_id", &"") == item_id:
			result.append(building as Node2D)
	result.sort_custom(func(first: Node2D, second: Node2D) -> bool: return first.get_index() < second.get_index())
	return result


func get_building_level(building: Node) -> int:
	if not is_instance_valid(building) or not UPGRADE_COSTS.has(building.get_meta("build_item_id", &"")):
		return 1
	return clampi(int(building.get_meta("building_level", 1)), 1, MAX_BUILDING_LEVEL)


func get_highest_building_level(item_id: StringName) -> int:
	var result := 0
	for building in get_buildings_by_type(item_id):
		result = maxi(result, get_building_level(building))
	return result


func get_upgrade_cost(building: Node) -> int:
	if not is_instance_valid(building):
		return 0
	var item_id: StringName = building.get_meta("build_item_id", &"")
	var next_level := get_building_level(building) + 1
	return int((UPGRADE_COSTS.get(item_id, {}) as Dictionary).get(next_level, 0))


func try_upgrade_building(building: Node2D) -> Dictionary:
	if not is_instance_valid(building) or not UPGRADE_COSTS.has(building.get_meta("build_item_id", &"")):
		return {"success": false, "message": "这座建筑不能升级"}
	if top_hud.get_day() < UPGRADE_UNLOCK_DAY:
		return {"success": false, "message": "第 %d 天收到老牧民来信后解锁升级" % UPGRADE_UNLOCK_DAY}
	var current_level := get_building_level(building)
	if current_level >= MAX_BUILDING_LEVEL:
		return {"success": false, "message": "这座建筑已经达到最高等级"}
	var price := get_upgrade_cost(building)
	if not top_hud.spend_money(price):
		return {"success": false, "message": "金币不足，升级需要 %d 金币" % price}
	var item_id: StringName = building.get_meta("build_item_id", &"")
	var next_level := current_level + 1
	building.set_meta("building_level", next_level)
	_update_building_level_badge(building)
	building_upgraded.emit(building, item_id, next_level)
	return {"success": true, "message": "%s已升级到 Lv.%d" % [BUILDINGS[item_id].display_name, next_level]}


func get_upgrade_effect_text(building: Node) -> String:
	var level := get_building_level(building)
	match building.get_meta("build_item_id", &""):
		&"dog_house":
			return "未进屋恢复 %d 点；守夜额外 +%d 分" % [[25, 40, 55][level - 1], (level - 1) * 2]
		&"shepherd_house":
			return "未进屋恢复 %d 点；自动赶羊提前 %d%%" % [[25, 40, 55][level - 1], (level - 1) * 4]
		&"lamb_shelter":
			return "容量 +%d；幼羊生病倍率 %d%%" % [[4, 6, 8][level - 1], [50, 35, 25][level - 1]]
	return ""


func get_building_at(world_position: Vector2) -> Node2D:
	var children := buildings_root.get_children()
	for index in range(children.size() - 1, -1, -1):
		var building := children[index] as Node2D
		if building.get_meta("build_item_id", &"") == &"fence":
			continue
		for footprint in _get_target_footprints(building):
			if footprint.grow(8.0).has_point(world_position):
				return building
	return null


func toggle_gate_at(world_position: Vector2, maximum_distance := 34.0) -> bool:
	var info := get_nearest_gate_info(world_position, maximum_distance)
	if info.is_empty():
		return false
	return set_gate_open(info.fence, not bool(info.is_open), true)


func try_expand_land_at(world_position: Vector2) -> bool:
	var candidate: Variant = world_controller.get_expansion_candidate(world_position)
	if candidate == null:
		_show_status("新区块必须连接在已有土地的上、下、左或右侧")
		return false
	var price: int = selected_item_data.get("price", 450)
	var land_type: StringName = selected_item_data.get("land_type", world_controller.LAND_TYPE_PASTURE)
	if not top_hud.spend_money(price):
		_show_status("金币不足：土地扩充需要 %d 金币" % price)
		return false
	if not world_controller.add_land_chunk(candidate as Vector2i, land_type):
		top_hud.refund_money(price)
		_show_status("这个位置暂时无法扩充")
		return false
	land_expanded.emit()
	cancel_build_mode()
	return true


func try_demolish_at(world_position: Vector2) -> bool:
	if demolition_in_progress:
		return false
	var target := _find_demolition_target(world_position)
	if not target:
		_show_status("这里没有可以拆除的建筑")
		return false
	demolition_in_progress = true
	_play_demolition_animation(target, world_position)
	return true


func get_fence_cost(start: Vector2, end: Vector2) -> int:
	return _fence_segment_count(_make_fence_rect(start, end)) * FENCE_PRICE


func get_save_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in buildings_root.get_children():
		if building.is_queued_for_deletion():
			continue
		var item_id: StringName = building.get_meta("build_item_id", &"")
		var entry := {
			"item_id": String(item_id),
			"position": [building.position.x, building.position.y],
			"cost": int(building.get_meta("cost", 0)),
			"level": get_building_level(building),
		}
		if item_id == &"fence":
			var grazing_rect: Rect2 = building.get_meta("grazing_rect", Rect2())
			entry.fence_rect = _rect_to_array(grazing_rect.grow(14.0))
			entry.gate_open = bool(building.get_meta("gate_open", false))
		result.append(entry)
	return result


func restore_save_data(data: Variant) -> void:
	cancel_build_mode()
	_clear_placed_buildings()
	if data is not Array:
		return
	for value in data:
		if value is not Dictionary:
			continue
		var entry := value as Dictionary
		var item_id := StringName(String(entry.get("item_id", "")))
		if item_id == &"fence":
			var fence_rect := _array_to_rect(entry.get("fence_rect", []))
			if fence_rect.size.x >= GRID_SIZE and fence_rect.size.y >= GRID_SIZE:
				_create_fence(
					fence_rect,
					int(entry.get("cost", 0)),
					false,
					bool(entry.get("gate_open", false))
				)
		elif BUILDINGS.has(item_id):
			var saved_position: Variant = entry.get("position", [])
			if saved_position is Array and saved_position.size() >= 2:
				_create_building(
					item_id,
					Vector2(float(saved_position[0]), float(saved_position[1])),
					false,
					clampi(int(entry.get("level", 1)), 1, MAX_BUILDING_LEVEL)
				)


func _create_fence(fence_rect: Rect2, cost: int, emit_event: bool, gate_open := false) -> Node2D:
	var footprints := _fence_footprints(fence_rect)
	var gate_footprint_index := _get_gate_footprint_index(fence_rect)
	var fence_root := Node2D.new()
	fence_root.name = "Fence%d" % (buildings_root.get_child_count() + 1)
	fence_root.set_meta("build_item_id", &"fence")
	fence_root.set_meta("cost", cost)
	fence_root.set_meta("footprints", footprints.duplicate())
	fence_root.set_meta("grazing_rect", fence_rect.grow(-14.0))
	fence_root.set_meta("gate_open", gate_open)
	buildings_root.add_child(fence_root)
	_add_fence_sprites(fence_root, fence_rect, Color.WHITE, true)
	_add_fence_colliders(fence_root, footprints, gate_footprint_index)
	_create_fence_gate(fence_root, footprints[gate_footprint_index], gate_open)
	placed_footprints.append_array(footprints)
	if emit_event:
		fence_placed.emit()
	return fence_root


func get_fence_roots() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in buildings_root.get_children():
		if building.get_meta("build_item_id", &"") == &"fence" and not building.is_queued_for_deletion():
			result.append(building as Node2D)
	return result


func get_fence_sheep_count(fence: Node) -> int:
	if not is_instance_valid(fence) or not fence.has_meta("grazing_rect"):
		return 0
	return world_controller.count_sheep_in_rect(fence.get_meta("grazing_rect") as Rect2)


func get_nearest_gate_info(world_position: Vector2, maximum_distance := 92.0) -> Dictionary:
	var nearest: Node2D
	var nearest_distance := maximum_distance
	for fence in get_fence_roots():
		var gate := fence.get_node_or_null("Gate") as Node2D
		if not gate:
			continue
		var distance := gate.global_position.distance_to(world_position)
		if distance <= nearest_distance:
			nearest = fence
			nearest_distance = distance
	if not nearest:
		return {}
	return {
		"fence": nearest,
		"is_open": bool(nearest.get_meta("gate_open", false)),
		"sheep_count": get_fence_sheep_count(nearest),
	}


func toggle_nearest_gate(world_position: Vector2, maximum_distance := 72.0) -> bool:
	var info := get_nearest_gate_info(world_position, maximum_distance)
	if info.is_empty():
		return false
	var fence: Node2D = info.fence
	set_gate_open(fence, not bool(info.is_open), true)
	_show_status("围栏门已%s，圈内有 %d 只羊" % [
		"打开" if bool(fence.get_meta("gate_open", false)) else "关闭",
		get_fence_sheep_count(fence),
	])
	return true


func set_gate_open(fence: Node2D, is_open: bool, emit_event := false) -> bool:
	if not is_instance_valid(fence) or fence.get_meta("build_item_id", &"") != &"fence":
		return false
	var gate := fence.get_node_or_null("Gate") as Node2D
	if not gate:
		return false
	fence.set_meta("gate_open", is_open)
	gate.rotation = -PI * 0.5 if is_open else 0.0
	var shape := gate.get_node_or_null("Collision/CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = is_open
	if emit_event:
		gate_toggled.emit(fence, is_open)
	return true


func _create_building(item_id: StringName, build_position: Vector2, emit_event: bool, level := 1) -> Node2D:
	var config: Dictionary = BUILDINGS[item_id]
	var footprint := _building_footprint(build_position, config.footprint)
	var building_root := Node2D.new()
	building_root.name = "%s%d" % [String(item_id).to_pascal_case(), buildings_root.get_child_count() + 1]
	building_root.position = build_position
	building_root.set_meta("build_item_id", item_id)
	building_root.set_meta("cost", config.price)
	building_root.set_meta("building_level", clampi(level, 1, MAX_BUILDING_LEVEL))
	building_root.set_meta("footprints", [footprint])
	buildings_root.add_child(building_root)
	var sprite := _make_building_sprite(config, Color.WHITE)
	sprite.position = Vector2.ZERO
	building_root.add_child(sprite)
	_add_building_collider(building_root, config.footprint)
	_update_building_level_badge(building_root)
	placed_footprints.append(footprint)
	if emit_event:
		building_placed.emit(item_id)
	return building_root


func _update_building_level_badge(building: Node2D) -> void:
	var badge := building.get_node_or_null("LevelBadge") as Label
	var level := get_building_level(building)
	if level <= 1:
		if badge:
			badge.hide()
		return
	if not badge:
		badge = Label.new()
		badge.name = "LevelBadge"
		badge.position = Vector2(-27, -72)
		badge.size = Vector2(54, 24)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.z_index = 20
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color("fff0b0"))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("294b5b")
		style.border_color = Color("7fd8df")
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		badge.add_theme_stylebox_override("normal", style)
		building.add_child(badge)
	badge.text = "Lv.%d" % level
	badge.show()


func _clear_placed_buildings() -> void:
	placed_footprints.clear()
	for building in buildings_root.get_children():
		buildings_root.remove_child(building)
		building.free()


func _rect_to_array(rectangle: Rect2) -> Array[float]:
	return [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y]


func _array_to_rect(value: Variant) -> Rect2:
	if value is not Array or value.size() < 4:
		return Rect2()
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))


func _show_fence_preview(start: Vector2, end: Vector2) -> void:
	_clear_preview()
	var fence_rect := _make_fence_rect(start, end)
	var footprints := _fence_footprints(fence_rect)
	var is_valid := _can_place_fence(footprints)
	var tint := VALID_TINT if is_valid else INVALID_TINT
	preview_root = Node2D.new()
	preview_root.name = "FencePreview"
	preview_root.z_index = 50
	add_child(preview_root)

	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		fence_rect.position,
		Vector2(fence_rect.end.x, fence_rect.position.y),
		fence_rect.end,
		Vector2(fence_rect.position.x, fence_rect.end.y),
	])
	fill.color = Color(tint.r, tint.g, tint.b, 0.12)
	preview_root.add_child(fill)
	_add_fence_sprites(preview_root, fence_rect, tint)
	_show_status("围栏费用：%d 金币%s" % [
		_fence_segment_count(fence_rect) * FENCE_PRICE,
		"" if is_valid else "（当前位置不可建造）",
	])


func _show_building_preview(item_id: StringName, build_position: Vector2) -> void:
	_clear_preview()
	var config: Dictionary = BUILDINGS[item_id]
	var footprint := _building_footprint(build_position, config.footprint)
	var is_valid := _building_footprint_is_valid(footprint)
	preview_root = Node2D.new()
	preview_root.name = "BuildingPreview"
	preview_root.z_index = 50
	add_child(preview_root)
	var sprite := _make_building_sprite(config, VALID_TINT if is_valid else INVALID_TINT)
	sprite.position = build_position
	preview_root.add_child(sprite)
	_show_status("%s：%d 金币%s" % [
		config.display_name,
		config.price,
		"" if is_valid else "（当前位置不可建造）",
	])


func _show_land_expansion_preview(mouse_position: Vector2) -> void:
	_clear_preview()
	preview_root = Node2D.new()
	preview_root.name = "LandExpansionPreview"
	preview_root.z_index = 40
	add_child(preview_root)
	var hovered_candidate: Variant = world_controller.get_expansion_candidate(mouse_position)
	for coordinate: Vector2i in world_controller.get_expansion_candidates():
		var sprite := get_node("../Island/Grass").duplicate() as Sprite2D
		sprite.position = world_controller.get_land_chunk_center(coordinate)
		if hovered_candidate != null and coordinate == hovered_candidate:
			sprite.modulate = VALID_TINT
		else:
			sprite.modulate = Color(0.68, 1.0, 0.68, 0.24)
		preview_root.add_child(sprite)
	_show_status("选择绿色预览块建造%s：%d 金币" % [
		_selected_land_type_name(),
		selected_item_data.get("price", 450),
	])


func _show_demolition_preview(mouse_position: Vector2) -> void:
	_clear_preview()
	var target := _find_demolition_target(mouse_position)
	preview_root = Node2D.new()
	preview_root.name = "DemolitionPreview"
	preview_root.z_index = 50
	add_child(preview_root)
	var hammer_icon := Sprite2D.new()
	var first_frame := AtlasTexture.new()
	first_frame.atlas = DEMOLITION_HAMMER_TEXTURE
	first_frame.region = Rect2(0, 0, 128, 128)
	hammer_icon.texture = first_frame
	hammer_icon.position = mouse_position + Vector2(0.0, -42.0)
	hammer_icon.scale = Vector2(0.72, 0.72)
	hammer_icon.modulate = Color.WHITE if target else Color(1.0, 0.65, 0.62, 0.82)
	preview_root.add_child(hammer_icon)
	if not target:
		_show_status("拆除模式：把锤子拖到已建小屋或围栏上")
		return
	for footprint in _get_target_footprints(target):
		var highlight := Polygon2D.new()
		highlight.polygon = PackedVector2Array([
			footprint.position,
			Vector2(footprint.end.x, footprint.position.y),
			footprint.end,
			Vector2(footprint.position.x, footprint.end.y),
		])
		highlight.color = Color(1.0, 0.2, 0.16, 0.28)
		preview_root.add_child(highlight)
	_show_status("点击拆除%s（不返还金币）" % _demolition_target_name(target))


func _find_demolition_target(world_position: Vector2) -> Node2D:
	var children := buildings_root.get_children()
	for index in range(children.size() - 1, -1, -1):
		var target := children[index] as Node2D
		for footprint in _get_target_footprints(target):
			if footprint.grow(8.0).has_point(world_position):
				return target
	return null


func _get_target_footprints(target: Node) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for footprint in target.get_meta("footprints", []):
		result.append(footprint as Rect2)
	return result


func _demolition_target_name(target: Node) -> String:
	match target.get_meta("build_item_id", &""):
		&"fence": return "整圈木围栏"
		&"dog_house": return "牧羊犬小屋"
		&"shepherd_house": return "牧民小屋"
		&"lamb_shelter": return "小羊棚"
		_: return "建筑"


func _play_demolition_animation(target: Node2D, strike_position: Vector2) -> void:
	_clear_preview()
	var hammer := AnimatedSprite2D.new()
	hammer.name = "DemolitionHammerAnimation"
	hammer.sprite_frames = demolition_hammer_frames
	hammer.position = strike_position + Vector2(0.0, -48.0)
	hammer.z_index = 100
	add_child(hammer)
	hammer.play(&"strike")
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(target):
		var item_id: StringName = target.get_meta("build_item_id", &"")
		_remove_target_footprints(target)
		target.queue_free()
		building_removed.emit(item_id)
	await hammer.animation_finished
	hammer.queue_free()
	demolition_in_progress = false
	cancel_build_mode()


func _remove_target_footprints(target: Node) -> void:
	for footprint in _get_target_footprints(target):
		var index := placed_footprints.find(footprint)
		if index >= 0:
			placed_footprints.remove_at(index)


func _build_demolition_hammer_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"strike")
	frames.set_animation_loop(&"strike", false)
	frames.set_animation_speed(&"strike", 12.0)
	for frame_index in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas = DEMOLITION_HAMMER_TEXTURE
		atlas.region = Rect2(frame_index * 128, 0, 128, 128)
		frames.add_frame(&"strike", atlas)
	return frames


func _make_building_sprite(config: Dictionary, tint: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = config.texture
	sprite.scale = config.scale
	sprite.modulate = tint
	sprite.z_index = 6
	return sprite


func _add_fence_sprites(parent: Node2D, fence_rect: Rect2, tint: Color, reserve_gate := false) -> void:
	var horizontal_count := maxi(1, roundi(fence_rect.size.x / GRID_SIZE))
	var vertical_count := maxi(1, roundi(fence_rect.size.y / GRID_SIZE))
	var gate_column := horizontal_count / 2
	for index in horizontal_count:
		var x := fence_rect.position.x + GRID_SIZE * (index + 0.5)
		parent.add_child(_make_fence_sprite(Vector2(x, fence_rect.position.y), 0.0, tint))
		if not reserve_gate or index != gate_column:
			parent.add_child(_make_fence_sprite(Vector2(x, fence_rect.end.y), 0.0, tint))
	for index in vertical_count:
		var y := fence_rect.position.y + GRID_SIZE * (index + 0.5)
		parent.add_child(_make_fence_sprite(Vector2(fence_rect.position.x, y), PI * 0.5, tint))
		parent.add_child(_make_fence_sprite(Vector2(fence_rect.end.x, y), PI * 0.5, tint))


func _make_fence_sprite(build_position: Vector2, rotation_value: float, tint: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = FENCE_TEXTURE
	sprite.position = build_position
	sprite.rotation = rotation_value
	sprite.modulate = tint
	sprite.z_index = 5
	return sprite


func _add_fence_colliders(parent: Node2D, footprints: Array[Rect2], skipped_index := -1) -> void:
	for index in footprints.size():
		if index == skipped_index:
			continue
		var footprint := footprints[index]
		var body := StaticBody2D.new()
		body.name = "Collision%d" % index
		body.position = footprint.position + footprint.size * 0.5
		body.collision_layer = 1
		body.collision_mask = 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = footprint.size
		shape.shape = rectangle
		body.add_child(shape)
		parent.add_child(body)


func _create_fence_gate(parent: Node2D, footprint: Rect2, is_open: bool) -> Node2D:
	var gate := Node2D.new()
	gate.name = "Gate"
	gate.position = footprint.position + Vector2(0.0, footprint.size.y * 0.5)
	parent.add_child(gate)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = FENCE_GATE_TEXTURE
	sprite.position = Vector2(footprint.size.x * 0.5, 0.0)
	sprite.scale = Vector2(0.55, 0.55)
	sprite.z_index = 6
	gate.add_child(sprite)
	var body := StaticBody2D.new()
	body.name = "Collision"
	body.position = Vector2(footprint.size.x * 0.5, 0.0)
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = footprint.size
	shape.shape = rectangle
	body.add_child(shape)
	gate.add_child(body)
	set_gate_open(parent, is_open)
	return gate


func _add_building_collider(parent: Node2D, footprint_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = footprint_size
	shape.shape = rectangle
	body.add_child(shape)
	parent.add_child(body)


func _make_fence_rect(start: Vector2, end: Vector2) -> Rect2:
	var snapped_start := _snap_to_grid(start)
	var snapped_end := _snap_to_grid(end)
	var delta := snapped_end - snapped_start
	if absf(delta.x) < GRID_SIZE:
		delta.x = GRID_SIZE if delta.x >= 0.0 else -GRID_SIZE
	if absf(delta.y) < GRID_SIZE:
		delta.y = GRID_SIZE if delta.y >= 0.0 else -GRID_SIZE
	var other_corner := snapped_start + delta
	var position_value := Vector2(
		minf(snapped_start.x, other_corner.x),
		minf(snapped_start.y, other_corner.y)
	)
	return Rect2(position_value, Vector2(absf(delta.x), absf(delta.y)))


func _fence_segment_count(fence_rect: Rect2) -> int:
	var horizontal_count := maxi(1, roundi(fence_rect.size.x / GRID_SIZE))
	var vertical_count := maxi(1, roundi(fence_rect.size.y / GRID_SIZE))
	return (horizontal_count + vertical_count) * 2


func _get_gate_footprint_index(fence_rect: Rect2) -> int:
	var horizontal_count := maxi(1, roundi(fence_rect.size.x / GRID_SIZE))
	return (horizontal_count / 2) * 2 + 1


func _fence_footprints(fence_rect: Rect2) -> Array[Rect2]:
	var footprints: Array[Rect2] = []
	var horizontal_count := maxi(1, roundi(fence_rect.size.x / GRID_SIZE))
	var vertical_count := maxi(1, roundi(fence_rect.size.y / GRID_SIZE))
	for index in horizontal_count:
		var x := fence_rect.position.x + GRID_SIZE * (index + 0.5)
		footprints.append(Rect2(Vector2(x - 20.0, fence_rect.position.y - 10.0), Vector2(40.0, 20.0)))
		footprints.append(Rect2(Vector2(x - 20.0, fence_rect.end.y - 10.0), Vector2(40.0, 20.0)))
	for index in vertical_count:
		var y := fence_rect.position.y + GRID_SIZE * (index + 0.5)
		footprints.append(Rect2(Vector2(fence_rect.position.x - 10.0, y - 20.0), Vector2(20.0, 40.0)))
		footprints.append(Rect2(Vector2(fence_rect.end.x - 10.0, y - 20.0), Vector2(20.0, 40.0)))
	return footprints


func _building_footprint(build_position: Vector2, size_value: Vector2) -> Rect2:
	return Rect2(build_position - size_value * 0.5, size_value)


func _footprints_are_valid(footprints: Array[Rect2]) -> bool:
	for footprint in footprints:
		if not world_controller.is_rect_on_land(footprint):
			return false
		for occupied in placed_footprints:
			if footprint.grow(-2.0).intersects(occupied.grow(-2.0), true):
				return false
	return true


func _building_footprint_is_valid(footprint: Rect2) -> bool:
	return (
		_footprints_are_valid([footprint])
		and not world_controller.build_area_has_natural_obstacle(footprint)
	)


func _selected_land_type_name() -> String:
	return (
		"生活用地"
		if selected_item_data.get("land_type", world_controller.LAND_TYPE_PASTURE) == world_controller.LAND_TYPE_HOMESTEAD
		else "放牧草地"
	)


func _can_place_fence(footprints: Array[Rect2]) -> bool:
	if not _footprints_are_valid(footprints):
		return false
	# Natural objects only block the fence segments that cross them. Objects
	# inside the enclosed area do not invalidate the fence.
	return not _fence_crosses_natural_obstacle(footprints)


func _fence_crosses_natural_obstacle(footprints: Array[Rect2]) -> bool:
	var collider_root := get_node_or_null("../Island/PhysicsColliders") as Node2D
	if not collider_root:
		return false
	for body in collider_root.get_children():
		var shape_node: CollisionShape2D = null
		for child in body.get_children():
			if child is CollisionShape2D:
				shape_node = child as CollisionShape2D
				break
		if not shape_node or not shape_node.shape:
			continue
		for footprint in footprints:
			if shape_node.shape is RectangleShape2D:
				var rectangle := shape_node.shape as RectangleShape2D
				var obstacle_rect := Rect2(body.global_position - rectangle.size * 0.5, rectangle.size)
				if obstacle_rect.intersects(footprint, true):
					return true
			elif shape_node.shape is CircleShape2D:
				var circle := shape_node.shape as CircleShape2D
				if _circle_intersects_rect(body.global_position, circle.radius, footprint):
					return true
	for grass in get_tree().get_nodes_in_group(&"grass"):
		for footprint in footprints:
			if _circle_intersects_rect(grass.global_position, 6.0, footprint):
				return true
	return false


func _circle_intersects_rect(center: Vector2, radius: float, rectangle: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rectangle.position.x, rectangle.end.x),
		clampf(center.y, rectangle.position.y, rectangle.end.y)
	)
	return closest.distance_squared_to(center) <= radius * radius


func _snap_to_grid(point: Vector2) -> Vector2:
	return Vector2(roundf(point.x / GRID_SIZE), roundf(point.y / GRID_SIZE)) * GRID_SIZE


func _clear_preview() -> void:
	if is_instance_valid(preview_root):
		preview_root.queue_free()
	preview_root = null


func _create_status_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	status_label = Label.new()
	status_label.position = Vector2(390.0, 126.0)
	status_label.size = Vector2(500.0, 42.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color("fff0b0"))
	status_label.add_theme_color_override("font_shadow_color", Color("172337"))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.hide()
	canvas.add_child(status_label)


func _show_status(message: String) -> void:
	if status_label:
		status_label.text = message
		status_label.show()


func _hide_status() -> void:
	if status_label:
		status_label.hide()
