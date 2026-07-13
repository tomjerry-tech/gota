extends Node2D

signal sheep_added(count: int)
signal sheep_sold(count: int)
signal breeding_started(mother: Node, father: Node)
signal lamb_born(lamb: Node, mother: Node)
signal selection_changed(entity: Variant)

const PICK_RADIUS_SQUARED := 38.0 * 38.0
const DRAG_THRESHOLD_SQUARED := 8.0 * 8.0
const GRASS_PER_LAND_CHUNK := 9
const CAPACITY_PER_LAND_CHUNK := 10
const CAPACITY_PER_LAMB_SHELTER := 4
const BASE_LAMB_SICKNESS_CHANCE := 0.08
const LITTER_WEIGHTS := [35, 30, 20, 10, 5]
const LAND_TYPE_PASTURE := &"pasture"
const LAND_TYPE_HOMESTEAD := &"homestead"
const LAND_CHUNK_SIZE := Vector2(384.0, 384.0)
const LAND_ORIGIN := Vector2(640.0, 350.0)
const LAND_EDGE_MARGIN := 28.0
const CARDINAL_DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const GRASS_POSITIONS := [
	Vector2(610, 210),
	Vector2(770, 200),
	Vector2(665, 245),
	Vector2(500, 205),
	Vector2(790, 300),
	Vector2(620, 350),
	Vector2(480, 475),
	Vector2(630, 480),
	Vector2(690, 365),
]
const SHEEP_NAME_POOL := [
	"团团", "云朵", "雪球", "棉花", "豆豆", "乐乐", "暖暖", "星星",
	"奶糖", "麦穗", "铃铛", "月牙", "泡芙", "元宝", "花卷", "糯米",
	"小白", "芝麻", "布丁", "果果", "米粒", "糖豆", "年糕", "春卷",
]

@onready var sheep_group: Node2D = $Island/Sheep
@onready var decorations: Node2D = $Island/Decorations
@onready var grass_template: AnimatedSprite2D = $Island/Decorations/SwayingGrass
@onready var build_controller: Node = $BuildController
@onready var top_hud: Control = $HUD/TopHUD
@onready var time_controls: Control = $HUD/TimeControls
@onready var medical_menu: Control = $HUD/MedicalMenu
@onready var daily_task_manager: Node = $DailyTaskManager
@onready var market_order_manager: Node = $MarketOrderManager
@onready var story_event_manager: Node = $StoryEventManager
@onready var newbie_commission: Control = $HUD/NewbieCommission
@onready var daily_report: Control = $HUD/DailyReport
@onready var world_camera: Camera2D = $WorldCamera
@onready var player: AnimatedSprite2D = $Island/Shepherd
@onready var dog_controller: AnimatedSprite2D = $Island/ShepherdDog
@onready var dog_manager: Node = $DogManager
@onready var day_routine_manager: Node = $DayRoutineManager
@onready var roundup_manager: Control = $HUD/RoundupStatus
@onready var dog_command_bar: Control = $HUD/DogCommandBar
@onready var save_manager: Node = get_node("/root/SaveManager")
@onready var audio_manager: Node = get_node("/root/AudioManager")
@onready var island: Node2D = $Island
@onready var initial_land: Sprite2D = $Island/Grass
@onready var initial_cliff: Sprite2D = $Island/Cliff
@onready var tree_template: Sprite2D = $Island/Decorations/Tree
@onready var bush_template: Sprite2D = $Island/Decorations/Bush
@onready var rock1_template: Sprite2D = $Island/Decorations/Rock1
@onready var rock2_template: Sprite2D = $Island/Decorations/Rock2

var dragged_sheep: AnimatedSprite2D
var pressed_sheep: AnimatedSprite2D
var sheep_press_screen_position := Vector2.ZERO
var occupied_land: Dictionary = {Vector2i.ZERO: LAND_TYPE_PASTURE}
var land_chunk_nodes: Dictionary = {}
var bridge_keys: Dictionary = {}
var junction_keys: Dictionary = {}
var land_chunks_root: Node2D
var land_bridges_root: Node2D
var land_junctions_root: Node2D
var physics_colliders: Node2D
var natural_build_obstacles: Array[Dictionary] = []
var next_sheep_id := 7
var sheep_template: AnimatedSprite2D
var profile_random := RandomNumberGenerator.new()
var autosave_enabled := true
var selected_entity: Variant


func _ready() -> void:
	autosave_enabled = DisplayServer.get_name() != "headless"
	next_sheep_id = sheep_group.get_child_count() + 1
	profile_random.seed = Time.get_ticks_usec() ^ get_instance_id() * 7919
	_assign_initial_sheep_ids()
	_assign_initial_sheep_names()
	_assign_initial_sheep_sexes()
	if sheep_group.get_child_count() > 0:
		sheep_template = sheep_group.get_child(0).duplicate() as AnimatedSprite2D
	_initialize_initial_grass()
	_initialize_land_system()
	_create_world_colliders()
	audio_manager.attach_world(self)
	daily_report.report_closed.connect(_on_daily_report_closed)
	call_deferred("_restore_pending_save")


func _exit_tree() -> void:
	if is_instance_valid(sheep_template) and not sheep_template.is_inside_tree():
		sheep_template.free()


func _initialize_initial_grass() -> void:
	var current_grass := decorations.get_children().filter(
		func(child: Node) -> bool: return child.is_in_group(&"grass")
	)
	for index in range(current_grass.size(), GRASS_PER_LAND_CHUNK):
		var grass := grass_template.duplicate() as AnimatedSprite2D
		grass.name = "SwayingGrass%d" % (index + 1)
		grass.position = GRASS_POSITIONS[index]
		decorations.add_child(grass)


func get_save_data() -> Dictionary:
	var land_data: Array[Dictionary] = []
	for coordinate: Vector2i in occupied_land:
		land_data.append({
			"coordinate": [coordinate.x, coordinate.y],
			"land_type": String(occupied_land[coordinate]),
		})
	land_data.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			var first_coordinate: Array = first.coordinate
			var second_coordinate: Array = second.coordinate
			return (
				int(first_coordinate[1]) < int(second_coordinate[1])
				or (
					int(first_coordinate[1]) == int(second_coordinate[1])
					and int(first_coordinate[0]) < int(second_coordinate[0])
				)
			)
	)
	var sheep_data: Array[Dictionary] = []
	for sheep in sheep_group.get_children():
		sheep_data.append(sheep.get_save_data())
	var grass_data: Array[Dictionary] = []
	for grass in _get_world_grass():
		grass_data.append(grass.get_save_data())
	return {
		"next_sheep_id": next_sheep_id,
		"land": land_data,
		"buildings": build_controller.get_save_data(),
		"sheep": sheep_data,
		"grass": grass_data,
		"top_hud": top_hud.get_save_data(),
		"time_speed": time_controls.get_save_speed(),
		"medical": medical_menu.get_save_data(),
		"daily_tasks": daily_task_manager.get_save_data(),
		"market": market_order_manager.get_save_data(),
		"newbie_commission": newbie_commission.get_save_data(),
		"story": story_event_manager.get_save_data(),
		"daily_report": daily_report.get_save_data(),
		"player": player.get_save_data(),
		"dogs": dog_manager.get_save_data(),
		"roundup": roundup_manager.get_save_data(),
		"day_routine": day_routine_manager.get_save_data(),
		"audio": audio_manager.get_save_data(),
		"camera": {
			"position": [world_camera.position.x, world_camera.position.y],
			"zoom": world_camera.zoom.x,
		},
	}


func restore_save_data(data: Dictionary) -> bool:
	if data.is_empty() or data.get("land", null) is not Array or data.get("sheep", null) is not Array:
		return false
	if not _restore_land_data(data.land):
		return false
	_restore_sheep_data(data.sheep)
	_restore_grass_data(data.get("grass", []))
	build_controller.restore_save_data(data.get("buildings", []))
	top_hud.restore_save_data(data.get("top_hud", {}))
	medical_menu.restore_save_data(data.get("medical", {}))
	daily_task_manager.restore_save_data(data.get("daily_tasks", {}))
	market_order_manager.restore_save_data(data.get("market", {}))
	newbie_commission.restore_save_data(data.get("newbie_commission", {}))
	daily_report.restore_save_data(data.get("daily_report", {}))
	player.restore_save_data(data.get("player", {}))
	dog_manager.restore_save_data(data.get("dogs", data.get("dog", {})))
	roundup_manager.restore_save_data(data.get("roundup", {}))
	day_routine_manager.restore_save_data(data.get("day_routine", {}))
	audio_manager.restore_save_data(data.get("audio", {}))
	story_event_manager.restore_save_data(data.get("story", {}))
	_restore_camera_data(data.get("camera", {}))
	next_sheep_id = maxi(next_sheep_id, int(data.get("next_sheep_id", next_sheep_id)))
	var saved_speed := float(data.get("time_speed", 1.0))
	if saved_speed not in [0.0, 1.0, 2.0, 4.0]:
		saved_speed = 1.0
	time_controls.set_speed(saved_speed)
	_update_sheep_activity_bounds()
	return true


func _restore_pending_save() -> void:
	if save_manager.has_pending_load():
		save_manager.restore_pending_into(self)


func _on_daily_report_closed() -> void:
	if autosave_enabled:
		save_manager.save_game(self)


func _restore_land_data(saved_land: Array) -> bool:
	var pending: Array[Dictionary] = []
	for value in saved_land:
		if value is not Dictionary:
			continue
		var entry := value as Dictionary
		var coordinate_value: Variant = entry.get("coordinate", [])
		if coordinate_value is not Array or coordinate_value.size() < 2:
			continue
		var coordinate := Vector2i(int(coordinate_value[0]), int(coordinate_value[1]))
		if coordinate == Vector2i.ZERO:
			continue
		var land_type := StringName(String(entry.get("land_type", String(LAND_TYPE_PASTURE))))
		pending.append({"coordinate": coordinate, "land_type": land_type})
	while not pending.is_empty():
		var restored_one := false
		for index in range(pending.size() - 1, -1, -1):
			var entry: Dictionary = pending[index]
			if add_land_chunk(entry.coordinate, entry.land_type):
				pending.remove_at(index)
				restored_one = true
		if not restored_one:
			return false
	return true


func _restore_sheep_data(saved_sheep: Array) -> void:
	for sheep in sheep_group.get_children():
		sheep_group.remove_child(sheep)
		sheep.free()
	next_sheep_id = 1
	for value in saved_sheep:
		if value is not Dictionary:
			continue
		var sheep := add_lamb(false)
		if sheep:
			sheep.restore_save_data(value)
			sheep.global_position = clamp_point_to_land(sheep.global_position, LAND_ORIGIN)
			next_sheep_id = maxi(next_sheep_id, sheep.get_sheep_id() + 1)


func _restore_grass_data(saved_grass: Variant) -> void:
	if saved_grass is not Array:
		return
	var grass_by_position: Dictionary = {}
	for grass in _get_world_grass():
		grass_by_position[_position_key(grass.global_position)] = grass
	for value in saved_grass:
		if value is not Dictionary:
			continue
		var position_value: Variant = value.get("position", [])
		if position_value is not Array or position_value.size() < 2:
			continue
		var key := _position_key(Vector2(float(position_value[0]), float(position_value[1])))
		var grass: Node = grass_by_position.get(key, null)
		if grass:
			grass.restore_save_data(value)


func _get_world_grass() -> Array[Node]:
	var result: Array[Node] = []
	for grass in get_tree().get_nodes_in_group(&"grass"):
		if island.is_ancestor_of(grass):
			result.append(grass)
	return result


func _position_key(value: Vector2) -> String:
	return "%d,%d" % [roundi(value.x * 100.0), roundi(value.y * 100.0)]


func _restore_camera_data(data: Dictionary) -> void:
	var position_value: Variant = data.get("position", [])
	if position_value is Array and position_value.size() >= 2:
		world_camera.position = Vector2(float(position_value[0]), float(position_value[1]))
	world_camera.set_zoom_level(float(data.get("zoom", 1.0)))


func add_lamb(emit_added_signal := true) -> Node:
	if not sheep_template:
		return null
	var lamb := sheep_template.duplicate() as AnimatedSprite2D
	lamb.name = "Sheep%d" % next_sheep_id
	next_sheep_id += 1
	lamb.set("starting_age_days", 0)
	lamb.set("sheep_name", _generate_unique_sheep_name())
	lamb.set("sex", _generate_random_sex())
	var spawn_random := RandomNumberGenerator.new()
	spawn_random.seed = Time.get_ticks_usec() + next_sheep_id * 3571
	lamb.position = get_random_land_position(spawn_random)
	sheep_group.add_child(lamb)
	_update_sheep_activity_bounds()
	if emit_added_signal:
		sheep_added.emit(1)
	return lamb


func add_lambs(count: int) -> Array[Node]:
	var lambs: Array[Node] = []
	if count <= 0 or not sheep_template:
		return lambs
	for index in count:
		var lamb := add_lamb()
		if lamb:
			lambs.append(lamb)
	return lambs


func sell_oldest_adult() -> bool:
	return sell_oldest_adults(1) == 1


func sell_oldest_adults(count: int) -> int:
	if count <= 0:
		return 0
	var adults: Array[Node] = []
	for sheep in sheep_group.get_children():
		if sheep.has_method("is_adult") and sheep.is_adult() and not sheep.is_pregnant():
			adults.append(sheep)
	if adults.size() < count:
		return 0
	adults.sort_custom(
		func(first: Node, second: Node) -> bool:
			return first.get_age_days() > second.get_age_days()
	)
	var selected: Array[Node] = []
	for index in count:
		selected.append(adults[index])
	return sell_specific_sheep(selected)


func sell_specific_sheep(sheep_to_sell: Array[Node]) -> int:
	if sheep_to_sell.is_empty():
		return 0
	var unique_sheep: Dictionary = {}
	for sheep in sheep_to_sell:
		if (
			not is_instance_valid(sheep)
			or sheep.is_queued_for_deletion()
			or sheep.get_parent() != sheep_group
			or not sheep.has_method("is_adult")
			or not sheep.is_adult()
			or sheep.is_pregnant()
			or unique_sheep.has(sheep)
		):
			return 0
		unique_sheep[sheep] = true
	for sheep in sheep_to_sell:
		if sheep.has_method("prepare_for_sale"):
			sheep.prepare_for_sale()
		sheep.queue_free()
	sheep_sold.emit(sheep_to_sell.size())
	return sheep_to_sell.size()


func get_lamb_count() -> int:
	return sheep_group.get_children().filter(
		func(sheep: Node) -> bool: return sheep.has_method("is_adult") and not sheep.is_adult()
	).size()


func get_adult_sheep_count() -> int:
	return sheep_group.get_children().filter(
		func(sheep: Node) -> bool: return sheep.has_method("is_adult") and sheep.is_adult()
	).size()


func get_sellable_adult_count() -> int:
	return sheep_group.get_children().filter(
		func(sheep: Node) -> bool:
			return sheep.has_method("is_adult") and sheep.is_adult() and not sheep.is_pregnant()
	).size()


func get_male_sheep_count() -> int:
	return sheep_group.get_children().filter(
		func(sheep: Node) -> bool: return sheep.has_method("get_sex") and sheep.get_sex() == sheep.SEX_MALE
	).size()


func get_female_sheep_count() -> int:
	return sheep_group.get_children().filter(
		func(sheep: Node) -> bool: return sheep.has_method("get_sex") and sheep.get_sex() == sheep.SEX_FEMALE
	).size()


func get_pregnant_sheep_count() -> int:
	return sheep_group.get_children().filter(
		func(sheep: Node) -> bool: return sheep.has_method("is_pregnant") and sheep.is_pregnant()
	).size()


func get_reserved_lamb_count() -> int:
	var reserved := 0
	for sheep in sheep_group.get_children():
		if sheep.has_method("get_expected_lamb_count"):
			reserved += sheep.get_expected_lamb_count()
	return reserved


func get_sheep_count() -> int:
	return sheep_group.get_child_count()


func get_building_count(item_id: StringName) -> int:
	var count := 0
	for building in $Island/Buildings.get_children():
		if not building.is_queued_for_deletion() and building.get_meta("build_item_id", &"") == item_id:
			count += 1
	return count


func has_building(item_id: StringName) -> bool:
	return get_building_count(item_id) > 0


func get_first_building_position(item_id: StringName) -> Vector2:
	for building in $Island/Buildings.get_children():
		if not building.is_queued_for_deletion() and building.get_meta("build_item_id", &"") == item_id:
			return building.global_position
	return LAND_ORIGIN


func get_sheep_capacity() -> int:
	return get_land_chunk_count() * CAPACITY_PER_LAND_CHUNK + get_building_count(&"lamb_shelter") * CAPACITY_PER_LAMB_SHELTER


func get_available_sheep_capacity() -> int:
	return maxi(0, get_sheep_capacity() - get_sheep_count() - get_reserved_lamb_count())


func get_breeding_failure_reason(mother: Node, father: Node) -> String:
	if not _is_flock_sheep(mother) or not _is_flock_sheep(father):
		return "请选择牧场中的公羊和母羊"
	if mother == father:
		return "繁育需要选择两只不同的羊"
	if mother.get_sex() != mother.SEX_FEMALE or father.get_sex() != father.SEX_MALE:
		return "配对必须由一只母羊和一只公羊组成"
	var mother_issue := _breeding_issue(mother)
	if not mother_issue.is_empty():
		return "%s：%s" % [mother.get_sheep_name(), mother_issue]
	var father_issue := _breeding_issue(father)
	if not father_issue.is_empty():
		return "%s：%s" % [father.get_sheep_name(), father_issue]
	if get_available_sheep_capacity() < 1:
		return "牧场容量不足，无法为待出生幼羊预留位置"
	if get_total_grass_count() < get_sheep_count():
		return "草总量少于当前羊数，暂时不能开始繁育"
	return ""


func start_breeding(mother: Node, father: Node) -> bool:
	if not get_breeding_failure_reason(mother, father).is_empty():
		return false
	var litter_size := _roll_litter_size(mini(5, get_available_sheep_capacity()))
	if not mother.start_pregnancy(litter_size):
		return false
	father.start_breeding_cooldown(father.FATHER_COOLDOWN_DAYS)
	_show_breeding_heart(mother, father)
	breeding_started.emit(mother, father)
	return true


func run_automatic_breeding() -> bool:
	if get_available_sheep_capacity() < 1 or get_total_grass_count() < get_sheep_count():
		return false
	var mothers: Array[Node] = []
	var fathers: Array[Node] = []
	for sheep in sheep_group.get_children():
		if not sheep.can_breed():
			continue
		if sheep.get_sex() == sheep.SEX_FEMALE:
			mothers.append(sheep)
		else:
			fathers.append(sheep)
	if mothers.is_empty() or fathers.is_empty():
		return false
	var mother := mothers[profile_random.randi_range(0, mothers.size() - 1)]
	fathers.sort_custom(
		func(first: Node, second: Node) -> bool:
			return first.global_position.distance_squared_to(mother.global_position) < second.global_position.distance_squared_to(mother.global_position)
	)
	return start_breeding(mother, fathers[0])


func complete_birth(mother: Node) -> Node:
	if (
		not _is_flock_sheep(mother)
		or not mother.is_pregnant()
		or mother.get_pregnancy_days() < mother.PREGNANCY_DURATION_DAYS
	):
		return null
	var mother_was_sick: bool = not mother.is_healthy()
	var litter_size: int = mother.get_expected_lamb_count()
	var newborns: Array[Node] = []
	for index in litter_size:
		var lamb := add_lamb(false)
		if not lamb:
			continue
		var angle := TAU * float(index) / float(maxi(1, litter_size))
		var offset := Vector2.from_angle(angle) * (22.0 + float(index % 2) * 8.0)
		lamb.global_position = clamp_point_to_land(mother.global_position + offset, mother.global_position)
		if mother_was_sick and profile_random.randf() < 0.35:
			lamb.make_sick()
		newborns.append(lamb)
	if newborns.is_empty():
		return null
	mother.finish_birth()
	for lamb in newborns:
		lamb_born.emit(lamb, mother)
	return newborns[0]


func _roll_litter_size(maximum_size: int) -> int:
	var allowed_size := clampi(maximum_size, 1, LITTER_WEIGHTS.size())
	var total_weight := 0
	for index in allowed_size:
		total_weight += LITTER_WEIGHTS[index]
	var roll := profile_random.randi_range(1, total_weight)
	var accumulated := 0
	for index in allowed_size:
		accumulated += LITTER_WEIGHTS[index]
		if roll <= accumulated:
			return index + 1
	return 1


func _is_flock_sheep(sheep: Node) -> bool:
	return is_instance_valid(sheep) and not sheep.is_queued_for_deletion() and sheep.get_parent() == sheep_group


func _breeding_issue(sheep: Node) -> String:
	if sheep.is_pregnant():
		return "已经怀孕"
	if sheep.get_age_days() < sheep.BREEDING_AGE_DAYS:
		return "年龄不足 %d 天" % sheep.BREEDING_AGE_DAYS
	if not sheep.is_healthy():
		return "当前生病"
	if sheep.get_hunger_percent() >= roundi(sheep.seek_food_hunger):
		return "当前饥饿值过高"
	if sheep.get_breeding_cooldown_days() > 0:
		return "还需休息 %d 天" % sheep.get_breeding_cooldown_days()
	return ""


func get_lamb_sickness_chance() -> float:
	var shelter_count := get_building_count(&"lamb_shelter")
	return maxf(0.01, BASE_LAMB_SICKNESS_CHANCE * pow(0.5, shelter_count))


func get_healthy_adult_count() -> int:
	return sheep_group.get_children().filter(
		func(sheep: Node) -> bool:
			return sheep.has_method("is_adult") and sheep.is_adult() and sheep.is_healthy()
	).size()


func get_sick_sheep_count() -> int:
	return sheep_group.get_children().filter(
		func(sheep: Node) -> bool: return sheep.has_method("is_healthy") and not sheep.is_healthy()
	).size()


func get_total_grass_count() -> int:
	return get_tree().get_nodes_in_group(&"grass").size()


func get_mature_grass_count() -> int:
	return get_tree().get_nodes_in_group(&"grass").filter(
		func(grass: Node) -> bool: return grass.has_method("is_mature") and grass.is_mature()
	).size()


func recall_stray_sheep() -> int:
	var recalled := 0
	for sheep in sheep_group.get_children():
		if sheep == dragged_sheep or sheep.get("state") == sheep.State.DRAGGED:
			continue
		if not is_point_on_land(sheep.global_position, 18.0):
			sheep.global_position = clamp_point_to_land(sheep.global_position, LAND_ORIGIN)
			if sheep.has_method("end_drag"):
				sheep.end_drag()
			recalled += 1
	return recalled


func _assign_initial_sheep_ids() -> void:
	for index in sheep_group.get_child_count():
		sheep_group.get_child(index).sheep_id = index + 1


func _assign_initial_sheep_names() -> void:
	for sheep in sheep_group.get_children():
		if sheep.has_method("set_sheep_name"):
			sheep.set_sheep_name(_generate_unique_sheep_name())


func _assign_initial_sheep_sexes() -> void:
	var sexes: Array[StringName] = [&"male", &"male", &"female", &"female"]
	while sexes.size() < sheep_group.get_child_count():
		sexes.append(_generate_random_sex())
	for index in range(sexes.size() - 1, 0, -1):
		var swap_index := profile_random.randi_range(0, index)
		var swap_value := sexes[index]
		sexes[index] = sexes[swap_index]
		sexes[swap_index] = swap_value
	for index in sheep_group.get_child_count():
		sheep_group.get_child(index).set_sex(sexes[index])


func _generate_random_sex() -> StringName:
	return &"male" if profile_random.randf() < 0.5 else &"female"


func _show_breeding_heart(mother: Node2D, father: Node2D) -> void:
	var heart := Label.new()
	heart.text = "♥"
	heart.position = (mother.global_position + father.global_position) * 0.5 - Vector2(18, 34)
	heart.size = Vector2(36, 36)
	heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heart.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heart.z_index = 100
	heart.add_theme_font_size_override("font_size", 30)
	heart.add_theme_color_override("font_color", Color("f28c9c"))
	heart.add_theme_color_override("font_shadow_color", Color("572b3a"))
	heart.add_theme_constant_override("shadow_offset_x", 2)
	heart.add_theme_constant_override("shadow_offset_y", 2)
	island.add_child(heart)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(heart, "position", heart.position - Vector2(0, 28), 1.0)
	tween.tween_property(heart, "modulate:a", 0.0, 1.0)
	tween.finished.connect(heart.queue_free)


func _generate_unique_sheep_name() -> String:
	var used_names: Dictionary = {}
	for sheep in sheep_group.get_children():
		if sheep.has_method("get_sheep_name"):
			used_names[sheep.get_sheep_name()] = true
	var candidates := SHEEP_NAME_POOL.filter(
		func(candidate: String) -> bool: return not used_names.has(candidate)
	)
	if not candidates.is_empty():
		return candidates[profile_random.randi_range(0, candidates.size() - 1)]
	return "小羊%d" % next_sheep_id


func _create_world_colliders() -> void:
	physics_colliders = get_node_or_null("Island/PhysicsColliders") as Node2D
	if not physics_colliders:
		physics_colliders = Node2D.new()
		physics_colliders.name = "PhysicsColliders"
		island.add_child(physics_colliders)
	_add_rectangle_collider(physics_colliders, "TreeTrunk", Vector2(536, 393), Vector2(54, 58))
	_add_circle_collider(physics_colliders, "Rock1", Vector2(732, 410), 22.0)
	_add_circle_collider(physics_colliders, "Rock2", Vector2(584, 483), 20.0)
	_register_build_rect(Vector2(536, 365), Vector2(128, 176))
	_register_build_rect(Vector2(728, 247), Vector2(80, 52))
	_register_build_circle(Vector2(732, 410), 28.0)
	_register_build_circle(Vector2(584, 483), 26.0)


func _initialize_land_system() -> void:
	land_chunks_root = Node2D.new()
	land_chunks_root.name = "LandChunks"
	island.add_child(land_chunks_root)
	land_bridges_root = Node2D.new()
	land_bridges_root.name = "LandBridges"
	island.add_child(land_bridges_root)
	land_junctions_root = Node2D.new()
	land_junctions_root.name = "LandJunctions"
	island.add_child(land_junctions_root)
	land_chunk_nodes[Vector2i.ZERO] = initial_land


func get_land_chunk_count() -> int:
	return occupied_land.size()


func get_pasture_land_count() -> int:
	return occupied_land.values().count(LAND_TYPE_PASTURE)


func get_land_type(coordinate: Vector2i) -> StringName:
	return occupied_land.get(coordinate, &"") as StringName


func get_land_chunk_center(coordinate: Vector2i) -> Vector2:
	return LAND_ORIGIN + Vector2(coordinate) * LAND_CHUNK_SIZE


func get_expansion_candidate(world_position: Vector2) -> Variant:
	var relative := (world_position - LAND_ORIGIN) / LAND_CHUNK_SIZE
	var coordinate := Vector2i(roundi(relative.x), roundi(relative.y))
	if occupied_land.has(coordinate):
		return null
	for direction in CARDINAL_DIRECTIONS:
		if occupied_land.has(coordinate + direction):
			return coordinate
	return null


func get_expansion_candidates() -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var seen: Dictionary = {}
	for coordinate: Vector2i in occupied_land:
		for direction in CARDINAL_DIRECTIONS:
			var candidate := coordinate + direction
			if occupied_land.has(candidate) or seen.has(candidate):
				continue
			seen[candidate] = true
			candidates.append(candidate)
	return candidates


func add_land_chunk(coordinate: Vector2i, land_type: StringName = LAND_TYPE_PASTURE) -> bool:
	if occupied_land.has(coordinate):
		return false
	if land_type not in [LAND_TYPE_PASTURE, LAND_TYPE_HOMESTEAD]:
		return false
	var has_neighbor := CARDINAL_DIRECTIONS.any(
		func(direction: Vector2i) -> bool: return occupied_land.has(coordinate + direction)
	)
	if not has_neighbor:
		return false

	occupied_land[coordinate] = land_type
	var chunk_root := Node2D.new()
	chunk_root.name = "Chunk_%d_%d" % [coordinate.x, coordinate.y]
	chunk_root.position = get_land_chunk_center(coordinate)
	land_chunks_root.add_child(chunk_root)
	var grass_sprite := initial_land.duplicate() as Sprite2D
	grass_sprite.name = "Grass"
	grass_sprite.position = Vector2.ZERO
	chunk_root.add_child(grass_sprite)
	var cliff_sprite := initial_cliff.duplicate() as Sprite2D
	cliff_sprite.name = "Cliff"
	cliff_sprite.position = Vector2(0.0, 235.0)
	chunk_root.add_child(cliff_sprite)
	land_chunk_nodes[coordinate] = chunk_root

	for direction in CARDINAL_DIRECTIONS:
		var neighbor := coordinate + direction
		if occupied_land.has(neighbor):
			_create_land_bridge(coordinate, neighbor)
	_update_land_junctions(coordinate)
	_update_cliff_visibility()
	if land_type == LAND_TYPE_PASTURE:
		_populate_land_chunk(coordinate)
	_update_sheep_activity_bounds()
	return true


func build_area_has_natural_obstacle(rectangle: Rect2) -> bool:
	for obstacle in natural_build_obstacles:
		if obstacle.type == &"rect":
			var obstacle_rect := Rect2(obstacle.center - obstacle.size * 0.5, obstacle.size)
			if rectangle.intersects(obstacle_rect, true):
				return true
		elif _circle_intersects_rect(obstacle.center, obstacle.radius, rectangle):
			return true
	for grass in get_tree().get_nodes_in_group(&"grass"):
		if _circle_intersects_rect(grass.global_position, 18.0, rectangle):
			return true
	return false


func is_point_on_land(point: Vector2, radius := 0.0) -> bool:
	var samples := [
		point,
		point + Vector2(radius, 0.0),
		point + Vector2(-radius, 0.0),
		point + Vector2(0.0, radius),
		point + Vector2(0.0, -radius),
	]
	return samples.all(func(sample: Vector2) -> bool: return _point_is_in_any_chunk(sample))


func is_rect_on_land(rectangle: Rect2) -> bool:
	var inset := rectangle.grow(-1.0)
	return [
		inset.position,
		Vector2(inset.end.x, inset.position.y),
		inset.end,
		Vector2(inset.position.x, inset.end.y),
	].all(func(point: Vector2) -> bool: return _point_is_in_any_chunk(point))


func get_grazing_areas() -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for building in $Island/Buildings.get_children():
		if building.get_meta("build_item_id", &"") == &"fence" and building.has_meta("grazing_rect"):
			areas.append(building.get_meta("grazing_rect") as Rect2)
	return areas


func count_sheep_in_rect(area: Rect2) -> int:
	var count := 0
	for sheep in sheep_group.get_children():
		if area.has_point(sheep.global_position):
			count += 1
	return count


func is_grass_reachable_from(sheep_position: Vector2, grass_position: Vector2) -> bool:
	for area in get_grazing_areas():
		if area.has_point(sheep_position):
			return area.has_point(grass_position)
	return true


func get_random_land_position(random: RandomNumberGenerator, origin_position: Variant = null) -> Vector2:
	var grazing_areas := get_grazing_areas()
	if not grazing_areas.is_empty():
		var selected_area: Rect2
		var found_origin_area := false
		if origin_position is Vector2:
			for area in grazing_areas:
				if area.has_point(origin_position as Vector2):
					selected_area = area
					found_origin_area = true
					break
		if not found_origin_area:
			selected_area = grazing_areas[random.randi_range(0, grazing_areas.size() - 1)]
		var safe_area := selected_area.grow(-12.0)
		if safe_area.size.x > 0.0 and safe_area.size.y > 0.0:
			return Vector2(
				random.randf_range(safe_area.position.x, safe_area.end.x),
				random.randf_range(safe_area.position.y, safe_area.end.y)
			)
	var coordinates := occupied_land.keys()
	var coordinate: Vector2i = coordinates[random.randi_range(0, coordinates.size() - 1)]
	var half_safe := LAND_CHUNK_SIZE * 0.5 - Vector2.ONE * LAND_EDGE_MARGIN
	return get_land_chunk_center(coordinate) + Vector2(
		random.randf_range(-half_safe.x, half_safe.x),
		random.randf_range(-half_safe.y, half_safe.y)
	)


func clamp_point_to_land(point: Vector2, fallback: Vector2) -> Vector2:
	if is_point_on_land(point, 18.0):
		return point
	var closest := fallback
	var closest_distance := INF
	for coordinate in occupied_land:
		var center := get_land_chunk_center(coordinate)
		var safe_rect := Rect2(
			center - LAND_CHUNK_SIZE * 0.5 + Vector2.ONE * LAND_EDGE_MARGIN,
			LAND_CHUNK_SIZE - Vector2.ONE * LAND_EDGE_MARGIN * 2.0
		)
		var candidate := Vector2(
			clampf(point.x, safe_rect.position.x, safe_rect.end.x),
			clampf(point.y, safe_rect.position.y, safe_rect.end.y)
		)
		var distance := point.distance_squared_to(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func _point_is_in_any_chunk(point: Vector2) -> bool:
	var relative := (point - LAND_ORIGIN) / LAND_CHUNK_SIZE
	var coordinate := Vector2i(roundi(relative.x), roundi(relative.y))
	if not occupied_land.has(coordinate):
		return false
	var center := get_land_chunk_center(coordinate)
	return Rect2(center - LAND_CHUNK_SIZE * 0.5, LAND_CHUNK_SIZE).has_point(point)


func _create_land_bridge(first: Vector2i, second: Vector2i) -> void:
	var first_text := "%d,%d" % [first.x, first.y]
	var second_text := "%d,%d" % [second.x, second.y]
	var key := "%s|%s" % (
		[first_text, second_text] if first_text < second_text
		else [second_text, first_text]
	)
	if bridge_keys.has(key):
		return
	bridge_keys[key] = true
	var bridge := Node2D.new()
	bridge.name = "Bridge_%s" % key.replace(",", "_").replace("|", "__")
	land_bridges_root.add_child(bridge)
	var patch := AtlasTexture.new()
	patch.atlas = (initial_land.texture as AtlasTexture).atlas
	patch.region = Rect2(80, 80, 32, 32)
	var midpoint := (get_land_chunk_center(first) + get_land_chunk_center(second)) * 0.5
	var horizontal_neighbors := first.y == second.y
	for index in range(-2, 3):
		var sprite := Sprite2D.new()
		sprite.texture = patch
		sprite.scale = Vector2(2.05, 2.05)
		sprite.z_index = 3
		sprite.position = midpoint + (
			Vector2(0.0, index * 64.0) if horizontal_neighbors
			else Vector2(index * 64.0, 0.0)
		)
		bridge.add_child(sprite)


func _update_land_junctions(added_coordinate: Vector2i) -> void:
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
		var top_left: Vector2i = added_coordinate + offset
		var square := [
			top_left,
			top_left + Vector2i.RIGHT,
			top_left + Vector2i.DOWN,
			top_left + Vector2i(1, 1),
		]
		if not square.all(func(coordinate: Vector2i) -> bool: return occupied_land.has(coordinate)):
			continue
		var key := "%d,%d" % [top_left.x, top_left.y]
		if junction_keys.has(key):
			continue
		junction_keys[key] = true
		var patch := AtlasTexture.new()
		patch.atlas = (initial_land.texture as AtlasTexture).atlas
		patch.region = Rect2(80, 80, 32, 32)
		var sprite := Sprite2D.new()
		sprite.name = "Junction_%d_%d" % [top_left.x, top_left.y]
		sprite.texture = patch
		sprite.position = (
			get_land_chunk_center(top_left)
			+ get_land_chunk_center(top_left + Vector2i(1, 1))
		) * 0.5
		sprite.scale = Vector2(2.3, 2.3)
		sprite.z_index = 3
		land_junctions_root.add_child(sprite)


func _update_cliff_visibility() -> void:
	for coordinate in occupied_land:
		var cliff: Sprite2D
		if coordinate == Vector2i.ZERO:
			cliff = initial_cliff
		else:
			cliff = (land_chunk_nodes[coordinate] as Node2D).get_node("Cliff") as Sprite2D
		cliff.visible = not occupied_land.has(coordinate + Vector2i.DOWN)


func _populate_land_chunk(coordinate: Vector2i) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = abs(coordinate.x * 73856093 ^ coordinate.y * 19349663) + 20260713
	var center := get_land_chunk_center(coordinate)
	var bases := [
		Vector2(-104, -58),
		Vector2(96, -92),
		Vector2(-92, 92),
		Vector2(96, 72),
		Vector2(-18, -112),
		Vector2(28, -58),
		Vector2(-18, 12),
		Vector2(62, 118),
		Vector2(-118, 28),
		Vector2(116, -6),
		Vector2(-54, -50),
		Vector2(48, 18),
		Vector2(-52, 132),
		Vector2(132, -134),
	]
	var positions: Array[Vector2] = []
	for base in bases:
		positions.append(center + base + Vector2(random.randf_range(-10, 10), random.randf_range(-10, 10)))
	_add_chunk_decoration(tree_template, "Tree", positions[0], coordinate, Vector2(0, 45), Vector2(54, 58), true)
	_add_chunk_decoration(bush_template, "BushA", positions[1], coordinate, Vector2.ZERO, Vector2(80, 52), false)
	_add_chunk_decoration(bush_template, "BushB", positions[2], coordinate, Vector2.ZERO, Vector2(80, 52), false)
	_add_chunk_rock(rock1_template, "RockA", positions[3], coordinate, 22.0, Vector2(0, 14))
	_add_chunk_rock(rock2_template, "RockB", positions[4], coordinate, 20.0, Vector2(0, 11))
	for index in range(5, 5 + GRASS_PER_LAND_CHUNK):
		var grass := grass_template.duplicate() as AnimatedSprite2D
		grass.name = "ChunkGrass_%d_%d_%d" % [coordinate.x, coordinate.y, index - 4]
		grass.position = positions[index]
		decorations.add_child(grass)


func _add_chunk_decoration(template: Sprite2D, label: String, position_value: Vector2, coordinate: Vector2i, collider_offset: Vector2, build_blocker_size: Vector2, create_movement_collider: bool) -> void:
	var sprite := template.duplicate() as Sprite2D
	sprite.name = "%s_%d_%d" % [label, coordinate.x, coordinate.y]
	sprite.position = position_value
	decorations.add_child(sprite)
	var build_center := position_value + (Vector2(0, 17) if label.begins_with("Tree") else Vector2(0, 12))
	_register_build_rect(build_center, Vector2(128, 176) if label.begins_with("Tree") else build_blocker_size)
	if create_movement_collider:
		_add_rectangle_collider(physics_colliders, "%sCollision" % sprite.name, position_value + collider_offset, build_blocker_size)


func _add_chunk_rock(template: Sprite2D, label: String, position_value: Vector2, coordinate: Vector2i, radius: float, collider_offset: Vector2) -> void:
	var sprite := template.duplicate() as Sprite2D
	sprite.name = "%s_%d_%d" % [label, coordinate.x, coordinate.y]
	sprite.position = position_value
	decorations.add_child(sprite)
	_add_circle_collider(physics_colliders, "%sCollision" % sprite.name, position_value + collider_offset, radius)
	_register_build_circle(position_value + collider_offset, radius + 6.0)


func _register_build_rect(center: Vector2, size_value: Vector2) -> void:
	natural_build_obstacles.append({"type": &"rect", "center": center, "size": size_value})


func _register_build_circle(center: Vector2, radius: float) -> void:
	natural_build_obstacles.append({"type": &"circle", "center": center, "radius": radius})


func _circle_intersects_rect(center: Vector2, radius: float, rectangle: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rectangle.position.x, rectangle.end.x),
		clampf(center.y, rectangle.position.y, rectangle.end.y)
	)
	return closest.distance_squared_to(center) <= radius * radius


func _update_sheep_activity_bounds() -> void:
	var bounds := Rect2(get_land_chunk_center(Vector2i.ZERO) - LAND_CHUNK_SIZE * 0.5, LAND_CHUNK_SIZE)
	for coordinate in occupied_land:
		var chunk_rect := Rect2(get_land_chunk_center(coordinate) - LAND_CHUNK_SIZE * 0.5, LAND_CHUNK_SIZE)
		bounds = bounds.merge(chunk_rect)
	for sheep in sheep_group.get_children():
		sheep.activity_bounds = bounds.grow(-LAND_EDGE_MARGIN)


func _add_rectangle_collider(parent: Node2D, collider_name: String, collider_position: Vector2, collider_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = collider_name
	body.position = collider_position
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = collider_size
	shape.shape = rectangle
	body.add_child(shape)
	parent.add_child(body)


func _add_circle_collider(parent: Node2D, collider_name: String, collider_position: Vector2, radius: float) -> void:
	var body := StaticBody2D.new()
	body.name = collider_name
	body.position = collider_position
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	parent.add_child(body)


func _unhandled_input(event: InputEvent) -> void:
	if build_controller.is_build_mode_active():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		select_entity(null)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var world_position := get_global_mouse_position()
			if dog_command_bar.consume_world_target(world_position):
				get_viewport().set_input_as_handled()
				return
			var dog: AnimatedSprite2D = dog_manager.find_dog_at(world_position)
			if dog:
				select_entity(dog)
				get_viewport().set_input_as_handled()
				return
			if player.visible and player.global_position.distance_squared_to(world_position) <= 42.0 * 42.0:
				select_entity(player)
				get_viewport().set_input_as_handled()
				return
			if build_controller.toggle_gate_at(world_position):
				get_viewport().set_input_as_handled()
				return
			if _press_sheep(world_position, event.position):
				return
			var building: Node2D = build_controller.get_building_at(world_position)
			if building:
				select_entity(building)
				get_viewport().set_input_as_handled()
				return
			if selected_entity == player and player.set_move_target(world_position):
				get_viewport().set_input_as_handled()
				return
		else:
			_release_sheep()
	elif event is InputEventMouseMotion and pressed_sheep:
		if (
			not dragged_sheep
			and event.position.distance_squared_to(sheep_press_screen_position) >= DRAG_THRESHOLD_SQUARED
		):
			_begin_sheep_drag()
		if dragged_sheep:
			_move_dragged_sheep(get_global_mouse_position())
			get_viewport().set_input_as_handled()


func _press_sheep(mouse_position: Vector2, screen_position: Vector2) -> bool:
	for sheep in sheep_group.get_children():
		if not sheep.visible:
			continue
		if sheep.global_position.distance_squared_to(mouse_position) <= PICK_RADIUS_SQUARED:
			pressed_sheep = sheep
			sheep_press_screen_position = screen_position
			select_entity(sheep)
			get_viewport().set_input_as_handled()
			return true
	return false


func select_entity(entity: Variant) -> void:
	if selected_entity == entity:
		return
	player.set_selected(false)
	dog_manager.select_dog(null)
	selected_entity = entity
	if selected_entity == player:
		player.set_selected(true)
	elif selected_entity is AnimatedSprite2D and (selected_entity as Node).get_script() == dog_controller.get_script():
		dog_manager.select_dog(selected_entity)
	var building_panel := get_node_or_null("HUD/BuildingInteractionPanel")
	if building_panel:
		if selected_entity is Node2D and (selected_entity as Node).has_meta("build_item_id"):
			building_panel.open_for_building(selected_entity)
		else:
			building_panel.close_panel()
	selection_changed.emit(selected_entity)


func get_selected_entity() -> Variant:
	return selected_entity if is_instance_valid(selected_entity) else null


func is_player_selected() -> bool:
	return selected_entity == player


func _begin_sheep_drag() -> void:
	if not pressed_sheep:
		return
	dragged_sheep = pressed_sheep
	if dragged_sheep.has_method("begin_drag"):
		dragged_sheep.begin_drag()
	else:
		dragged_sheep.stop()
	dragged_sheep.scale = Vector2(1.12, 1.12)
	dragged_sheep.z_index = 100
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


func _move_dragged_sheep(target_position: Vector2) -> void:
	if not dragged_sheep:
		return
	dragged_sheep.global_position = clamp_point_to_land(
		target_position,
		dragged_sheep.global_position
	)


func _release_sheep() -> void:
	if dragged_sheep:
		_drop_sheep()
		return
	if not pressed_sheep:
		return
	var sheep := pressed_sheep
	pressed_sheep = null
	audio_manager.play_sfx(&"sheep_bleat", randf_range(0.96, 1.04))
	open_sheep_profile(sheep)
	get_viewport().set_input_as_handled()


func open_sheep_profile(sheep: Node) -> void:
	select_entity(sheep)
	var build_menu := get_node_or_null("HUD/BuildMenu")
	var sheep_menu := get_node_or_null("HUD/SheepMenu")
	var detail_menu := get_node_or_null("HUD/SheepDetailMenu")
	var medical_menu := get_node_or_null("HUD/MedicalMenu")
	if build_menu:
		build_menu.close_menu()
	if sheep_menu:
		sheep_menu.close_menu()
	if medical_menu:
		medical_menu.close_menu()
	if detail_menu:
		detail_menu.open_for_sheep(sheep)


func _drop_sheep() -> void:
	if not dragged_sheep:
		return

	var sheep := dragged_sheep
	dragged_sheep = null
	pressed_sheep = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	sheep.global_position = clamp_point_to_land(sheep.global_position, LAND_ORIGIN)
	sheep.scale = Vector2.ONE
	sheep.z_index = 0
	if sheep.has_method("end_drag"):
		sheep.end_drag()
	else:
		sheep.play("walk")

	get_viewport().set_input_as_handled()
