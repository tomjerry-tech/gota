extends AnimatedSprite2D

signal health_changed(sheep: Node, healthy: bool)
signal breeding_state_changed(sheep: Node)
signal died(sheep: Node)

enum State {
	IDLE,
	WANDER,
	SEEK_GRASS,
	EAT,
	REST,
	RUN,
	CALLED,
	DRAGGED,
}

const FRAME_SIZE := Vector2(128, 128)
const WALK_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_move.png")
const RUN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_run.png")
const IDLE_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_idle.png")
const EAT_ENTER_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_eat_enter.png")
const EAT_LOOP_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_eat_loop.png")
const LIE_DOWN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_lie_down.png")
const REST_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_rest.png")
const WALK_UP_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_walk_up.png")
const WALK_DOWN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_walk_down.png")
const WALK_DIAG_UP_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_walk_diag_up.png")
const WALK_DIAG_DOWN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/sheep_walk_diag_down.png")
const LAMB_WALK_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_move.png")
const LAMB_RUN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_run.png")
const LAMB_IDLE_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_idle.png")
const LAMB_EAT_ENTER_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_eat_enter.png")
const LAMB_EAT_LOOP_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_eat_loop.png")
const LAMB_LIE_DOWN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_lie_down.png")
const LAMB_REST_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_rest.png")
const LAMB_WALK_UP_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_walk_up.png")
const LAMB_WALK_DOWN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_walk_down.png")
const LAMB_WALK_DIAG_UP_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_walk_diag_up.png")
const LAMB_WALK_DIAG_DOWN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/sheep/lamb/sheep_walk_diag_down.png")
const MEDICAL_ICON_TEXTURE: Texture2D = preload("res://assets/tiny_swords/ui/bottom_toolbar/medical.png")
const MAX_AVOIDANCE_SECONDS := 6.0
const SEX_MALE := &"male"
const SEX_FEMALE := &"female"
const ADULT_AGE_DAYS := 6
const BREEDING_AGE_DAYS := 8
const PREGNANCY_DURATION_DAYS := 3
const MOTHER_COOLDOWN_DAYS := 4
const FATHER_COOLDOWN_DAYS := 2

@export var activity_bounds := Rect2(475, 185, 330, 325)
@export_range(10.0, 100.0, 1.0) var walk_speed := 32.0
@export_range(20.0, 180.0, 1.0) var run_speed := 82.0
@export_group("Activity Timing")
@export_range(1.0, 30.0, 0.5) var min_idle_seconds := 4.0
@export_range(1.0, 30.0, 0.5) var max_idle_seconds := 8.0
@export_range(2.0, 60.0, 0.5) var min_rest_seconds := 12.0
@export_range(2.0, 60.0, 0.5) var max_rest_seconds := 22.0
@export_range(2.0, 30.0, 0.5) var min_eat_seconds := 8.0
@export_range(2.0, 30.0, 0.5) var max_eat_seconds := 12.0
@export_range(16.0, 48.0, 1.0) var eating_distance := 25.0
@export_group("Hunger")
@export_range(30.0, 600.0, 5.0) var min_seconds_to_full_hunger := 120.0
@export_range(30.0, 600.0, 5.0) var max_seconds_to_full_hunger := 180.0
@export_range(0.0, 70.0, 1.0) var max_initial_hunger := 25.0
@export_range(0.0, 100.0, 1.0) var seek_food_hunger := 60.0
@export_range(0.0, 100.0, 1.0) var urgent_food_hunger := 85.0
@export_group("Age")
@export_range(0, 999, 1) var starting_age_days := 8
@export_group("Profile")
@export var sheep_id := 0
@export var sheep_name := ""
@export var sex: StringName = &""
@export_group("")

var state := State.IDLE
var state_time := 0.0
var hunger := 0.0
var hunger_rate := 0.0
var food_search_cooldown := 0.0
var target_position := Vector2.ZERO
var target_grass: Node = null
var eat_from_left := true
var random := RandomNumberGenerator.new()
var is_waking_up := false
var blocked_time := 0.0
var movement_shape := CircleShape2D.new()
var avoidance_direction := Vector2.ZERO
var avoidance_time := 0.0
var avoidance_switches := 0
var age_days := 0
var sick := false
var sick_days := 0
var medical_icon: Sprite2D
var lost := false
var lost_icon: Label
var pregnant := false
var pregnancy_days := 0
var expected_lamb_count := 0
var pregnancy_father_id := 0
var breeding_cooldown_days := 0
var mother_id := 0
var father_id := 0
var generation := 0
var breeding_icon: Label
var going_to_shelter := false
var sheltered := false
var shelter_target := Vector2.ZERO


func _ready() -> void:
	random.seed = Time.get_ticks_usec() + get_instance_id() * 9973
	if sheep_name.is_empty():
		sheep_name = "小羊"
	if sex not in [SEX_MALE, SEX_FEMALE]:
		sex = SEX_MALE
	age_days = starting_age_days
	_update_age_size()
	_build_animations()
	_build_medical_icon()
	_build_lost_icon()
	_build_breeding_icon()
	animation_finished.connect(_on_animation_finished)
	_start_hunger_cycle(random.randf_range(0.0, max_initial_hunger))
	_enter_idle()


func is_adult() -> bool:
	return age_days >= ADULT_AGE_DAYS


func get_age_days() -> int:
	return age_days


func get_sheep_id() -> int:
	return sheep_id


func get_sheep_name() -> String:
	return sheep_name


func set_sheep_name(value: String) -> void:
	var trimmed := value.strip_edges()
	if not trimmed.is_empty():
		sheep_name = trimmed.left(8)


func get_sex() -> StringName:
	return sex


func set_sex(value: StringName) -> void:
	if value not in [SEX_MALE, SEX_FEMALE] or sex == value:
		return
	sex = value
	breeding_state_changed.emit(self)


func get_sex_text() -> String:
	return "公羊" if sex == SEX_MALE else "母羊"


func get_hunger_percent() -> int:
	return roundi(hunger)


func is_healthy() -> bool:
	return not sick


func get_health_text() -> String:
	return "健康" if is_healthy() else "生病"


func is_lost() -> bool:
	return lost


func set_lost(value: bool) -> void:
	lost = value
	if lost_icon:
		lost_icon.visible = lost


func is_pregnant() -> bool:
	return pregnant


func get_pregnancy_days() -> int:
	return pregnancy_days


func get_expected_lamb_count() -> int:
	return expected_lamb_count if pregnant else 0


func get_pregnancy_father_id() -> int:
	return pregnancy_father_id if pregnant else 0


func get_mother_id() -> int:
	return mother_id


func get_father_id() -> int:
	return father_id


func get_generation() -> int:
	return generation


func set_lineage(value_mother_id: int, value_father_id: int, value_generation: int) -> void:
	mother_id = maxi(0, value_mother_id)
	father_id = maxi(0, value_father_id)
	generation = maxi(0, value_generation)


func get_breeding_cooldown_days() -> int:
	return breeding_cooldown_days


func get_save_data() -> Dictionary:
	return {
		"sheep_id": sheep_id,
		"name": sheep_name,
		"position": [global_position.x, global_position.y],
		"sex": String(sex),
		"age_days": age_days,
		"sick": sick,
		"sick_days": sick_days,
		"hunger": hunger,
		"hunger_rate": hunger_rate,
		"lost": lost,
		"pregnant": pregnant,
		"pregnancy_days": pregnancy_days,
		"expected_lamb_count": expected_lamb_count,
		"pregnancy_father_id": pregnancy_father_id,
		"breeding_cooldown_days": breeding_cooldown_days,
		"mother_id": mother_id,
		"father_id": father_id,
		"generation": generation,
		"going_to_shelter": going_to_shelter,
		"sheltered": sheltered,
		"shelter_target": [shelter_target.x, shelter_target.y],
	}


func restore_save_data(data: Dictionary) -> void:
	_release_grass()
	sheep_id = maxi(1, int(data.get("sheep_id", sheep_id)))
	set_sheep_name(String(data.get("name", sheep_name)))
	var saved_sex := StringName(String(data.get("sex", String(sex))))
	sex = saved_sex if saved_sex in [SEX_MALE, SEX_FEMALE] else SEX_MALE
	age_days = maxi(0, int(data.get("age_days", starting_age_days)))
	starting_age_days = age_days
	sick = bool(data.get("sick", false))
	sick_days = clampi(int(data.get("sick_days", 0)), 0, 2) if sick else 0
	hunger = clampf(float(data.get("hunger", 0.0)), 0.0, 100.0)
	hunger_rate = maxf(0.01, float(data.get("hunger_rate", 100.0 / 150.0)))
	lost = bool(data.get("lost", false))
	pregnant = bool(data.get("pregnant", false)) and sex == SEX_FEMALE
	pregnancy_days = clampi(int(data.get("pregnancy_days", 0)), 0, PREGNANCY_DURATION_DAYS)
	expected_lamb_count = (
		clampi(int(data.get("expected_lamb_count", 1)), 1, 5)
		if pregnant else 0
	)
	pregnancy_father_id = maxi(0, int(data.get("pregnancy_father_id", 0))) if pregnant else 0
	breeding_cooldown_days = maxi(0, int(data.get("breeding_cooldown_days", 0)))
	mother_id = maxi(0, int(data.get("mother_id", 0)))
	father_id = maxi(0, int(data.get("father_id", 0)))
	generation = maxi(0, int(data.get("generation", 0)))
	var saved_shelter_target: Variant = data.get("shelter_target", [])
	if saved_shelter_target is Array and saved_shelter_target.size() >= 2:
		shelter_target = Vector2(float(saved_shelter_target[0]), float(saved_shelter_target[1]))
	going_to_shelter = bool(data.get("going_to_shelter", false))
	sheltered = bool(data.get("sheltered", false))
	visible = not sheltered
	var saved_position: Variant = data.get("position", [])
	if saved_position is Array and saved_position.size() >= 2:
		global_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	_update_age_size()
	_build_animations()
	if medical_icon:
		medical_icon.visible = sick
	if lost_icon:
		lost_icon.visible = lost
	_update_breeding_icon()
	_enter_idle()


func can_breed() -> bool:
	return (
		age_days >= BREEDING_AGE_DAYS
		and is_healthy()
		and hunger < seek_food_hunger
		and breeding_cooldown_days <= 0
		and not pregnant
		and not lost
	)


func get_breeding_status_text() -> String:
	if pregnant:
		return "怀孕 %d / %d 天 · 预计 %d 只" % [
			mini(pregnancy_days, PREGNANCY_DURATION_DAYS),
			PREGNANCY_DURATION_DAYS,
			expected_lamb_count,
		]
	if lost:
		return "走失中，暂不可繁育"
	if age_days < BREEDING_AGE_DAYS:
		return "%d 天后可繁育" % (BREEDING_AGE_DAYS - age_days)
	if not is_healthy():
		return "生病，暂不可繁育"
	if hunger >= seek_food_hunger:
		return "饥饿，进食后可繁育"
	if breeding_cooldown_days > 0:
		return "%s %d 天" % ["产后休息" if sex == SEX_FEMALE else "繁育休息", breeding_cooldown_days]
	return "可以繁育"


func start_pregnancy(litter_size := 1, value_father_id := 0) -> bool:
	if sex != SEX_FEMALE or not can_breed():
		return false
	pregnant = true
	pregnancy_days = 0
	expected_lamb_count = clampi(litter_size, 1, 5)
	pregnancy_father_id = maxi(0, value_father_id)
	_update_breeding_icon()
	breeding_state_changed.emit(self)
	return true


func start_breeding_cooldown(days: int) -> void:
	breeding_cooldown_days = maxi(breeding_cooldown_days, days)
	breeding_state_changed.emit(self)


func finish_birth() -> void:
	pregnant = false
	pregnancy_days = 0
	expected_lamb_count = 0
	pregnancy_father_id = 0
	breeding_cooldown_days = MOTHER_COOLDOWN_DAYS
	_update_breeding_icon()
	breeding_state_changed.emit(self)


func make_sick() -> bool:
	if sick:
		return false
	_set_sick(true)
	return true


func get_sick_days() -> int:
	return sick_days


func get_sickness_deadline_text() -> String:
	if not sick:
		return "健康"
	return "明日死亡" if sick_days >= 1 else "剩余 2 天治疗"


func treat() -> bool:
	if not sick:
		return false
	_set_sick(false)
	return true


func daily_health_check(lamb_sickness_chance: float, recovery_chance := 0.35) -> void:
	if sick:
		sick_days += 1
		if sick_days >= 2:
			died.emit(self)
			return
		if random.randf() < recovery_chance:
			_set_sick(false)
	elif not is_adult() and random.randf() < lamb_sickness_chance:
		_set_sick(true)


func _set_sick(value: bool) -> void:
	if sick == value:
		return
	sick = value
	sick_days = 0
	if medical_icon:
		medical_icon.visible = sick
	health_changed.emit(self, not sick)


func _build_medical_icon() -> void:
	medical_icon = Sprite2D.new()
	medical_icon.name = "MedicalStatusIcon"
	medical_icon.texture = MEDICAL_ICON_TEXTURE
	medical_icon.position = Vector2(0.0, -50.0)
	medical_icon.scale = Vector2(0.48, 0.48)
	medical_icon.z_index = 20
	medical_icon.visible = sick
	add_child(medical_icon)


func _build_lost_icon() -> void:
	lost_icon = Label.new()
	lost_icon.name = "LostStatusIcon"
	lost_icon.position = Vector2(-40.0, -72.0)
	lost_icon.size = Vector2(32.0, 32.0)
	lost_icon.text = "!"
	lost_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lost_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lost_icon.z_index = 22
	lost_icon.add_theme_font_size_override("font_size", 22)
	lost_icon.add_theme_color_override("font_color", Color("fff4c4"))
	lost_icon.add_theme_color_override("font_shadow_color", Color("633f24"))
	lost_icon.add_theme_constant_override("shadow_offset_x", 1)
	lost_icon.add_theme_constant_override("shadow_offset_y", 2)
	var lost_style := StyleBoxFlat.new()
	lost_style.bg_color = Color("b5523f")
	lost_style.border_color = Color("ffd45c")
	lost_style.set_border_width_all(2)
	lost_style.set_corner_radius_all(16)
	lost_icon.add_theme_stylebox_override("normal", lost_style)
	lost_icon.visible = lost
	add_child(lost_icon)


func _build_breeding_icon() -> void:
	breeding_icon = Label.new()
	breeding_icon.name = "BreedingStatusIcon"
	breeding_icon.position = Vector2(13.0, -66.0)
	breeding_icon.size = Vector2(30.0, 30.0)
	breeding_icon.text = "♥"
	breeding_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breeding_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breeding_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breeding_icon.z_index = 21
	breeding_icon.add_theme_font_size_override("font_size", 22)
	breeding_icon.add_theme_color_override("font_color", Color("f28c9c"))
	breeding_icon.add_theme_color_override("font_shadow_color", Color("572b3a"))
	breeding_icon.add_theme_constant_override("shadow_offset_x", 1)
	breeding_icon.add_theme_constant_override("shadow_offset_y", 2)
	add_child(breeding_icon)
	_update_breeding_icon()


func _update_breeding_icon() -> void:
	if breeding_icon:
		breeding_icon.visible = pregnant


func advance_day() -> bool:
	var was_adult := is_adult()
	age_days += 1
	var breeding_state_updated := false
	if breeding_cooldown_days > 0:
		breeding_cooldown_days -= 1
		breeding_state_updated = true
	if pregnant:
		pregnancy_days += 1
		breeding_state_updated = true
	if is_adult() != was_adult:
		_update_age_size()
		_build_animations()
		_enter_idle()
	if breeding_state_updated:
		breeding_state_changed.emit(self)
	return pregnant and pregnancy_days >= PREGNANCY_DURATION_DAYS


func prepare_for_sale() -> void:
	_release_grass()
	state = State.DRAGGED
	stop()


func _update_age_size() -> void:
	movement_shape.radius = 18.0 if is_adult() else 11.0


func _process(delta: float) -> void:
	if state == State.DRAGGED:
		return
	if sheltered:
		return
	if going_to_shelter:
		if global_position.distance_to(shelter_target) <= 5.0:
			going_to_shelter = false
			sheltered = true
			visible = false
			_enter_idle()
			return
		target_position = shelter_target
		state = State.CALLED
		_move_toward_target(delta)
		return

	hunger = minf(100.0, hunger + hunger_rate * delta)
	food_search_cooldown = maxf(0.0, food_search_cooldown - delta)
	if (
		hunger >= urgent_food_hunger
		and food_search_cooldown <= 0.0
		and state not in [State.SEEK_GRASS, State.EAT, State.RUN]
	):
		if _seek_nearest_grass():
			return
		food_search_cooldown = 1.5

	match state:
		State.IDLE:
			state_time -= delta
			if state_time <= 0.0:
				_choose_next_activity()
		State.REST:
			state_time -= delta
			if state_time <= 0.0 and not is_waking_up:
				is_waking_up = true
				play_backwards(&"lie_down")
		State.WANDER, State.RUN, State.CALLED:
			_move_toward_target(delta)
		State.SEEK_GRASS:
			_update_grass_search(delta)
		State.EAT:
			state_time -= delta
			if state_time <= 0.0:
				_finish_eating()


func begin_drag() -> void:
	_release_grass()
	state = State.DRAGGED
	stop()


func end_drag() -> void:
	_recover_from_overlap()
	_enter_idle()


func scare(away_from: Vector2) -> void:
	_start_scare((global_position - away_from).normalized(), 140.0)


func scare_from_dog(away_from: Vector2, drive_toward: Variant = null) -> bool:
	var direction := (global_position - away_from).normalized()
	if drive_toward is Vector2:
		var toward_direction := global_position.direction_to(drive_toward as Vector2)
		if toward_direction != Vector2.ZERO:
			direction = (direction * 0.35 + toward_direction * 0.65).normalized()
	return _start_scare(direction, 190.0)


func _start_scare(direction: Vector2, distance: float) -> bool:
	if state == State.DRAGGED:
		return false
	_release_grass()
	_clear_obstacle_avoidance()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	target_position = _clamp_to_bounds(global_position + direction * distance)
	state = State.RUN
	_play_animation(&"run")
	return true


func answer_whistle(gather_position: Vector2) -> bool:
	if state == State.DRAGGED:
		return false
	_release_grass()
	_clear_obstacle_avoidance()
	target_position = _clamp_to_bounds(gather_position)
	state = State.CALLED
	_update_movement_animation(global_position.direction_to(target_position))
	return true


func send_to_shelter(world_position: Vector2) -> bool:
	if state == State.DRAGGED or sheltered:
		return false
	_release_grass()
	shelter_target = _clamp_to_bounds(world_position)
	target_position = shelter_target
	going_to_shelter = true
	state = State.CALLED
	_clear_obstacle_avoidance()
	return true


func wake_from_shelter() -> void:
	if sheltered:
		global_position = _clamp_to_bounds(shelter_target)
	sheltered = false
	going_to_shelter = false
	visible = true
	_enter_idle()


func _choose_next_activity() -> void:
	if hunger >= seek_food_hunger:
		if _seek_nearest_grass():
			return
		food_search_cooldown = 1.5
	if random.randf() < 0.25:
		_enter_rest()
	else:
		_enter_wander()


func _enter_idle() -> void:
	_clear_obstacle_avoidance()
	state = State.IDLE
	state_time = random.randf_range(min_idle_seconds, max_idle_seconds)
	_play_animation(&"idle")


func _enter_rest() -> void:
	state = State.REST
	state_time = random.randf_range(min_rest_seconds, max_rest_seconds)
	is_waking_up = false
	_play_animation(&"lie_down")


func _enter_wander() -> void:
	_clear_obstacle_avoidance()
	state = State.WANDER
	var world_controller := get_node_or_null("../../..")
	if world_controller and world_controller.has_method("get_random_land_position"):
		target_position = world_controller.get_random_land_position(random, global_position)
	else:
		target_position = Vector2(
			random.randf_range(activity_bounds.position.x, activity_bounds.end.x),
			random.randf_range(activity_bounds.position.y, activity_bounds.end.y)
		)
	_play_animation(&"walk")


func _seek_nearest_grass() -> bool:
	var nearest_distance := INF
	var nearest_grass: Node = null
	var world_controller := get_node_or_null("../../..")
	for grass in get_tree().get_nodes_in_group(&"grass"):
		if not grass.is_available_for(self):
			continue
		if (
			world_controller
			and world_controller.has_method("is_grass_reachable_from")
			and not world_controller.is_grass_reachable_from(global_position, grass.global_position)
		):
			continue
		var distance := global_position.distance_squared_to(grass.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_grass = grass

	if not nearest_grass or not nearest_grass.reserve(self):
		return false
	target_grass = nearest_grass
	eat_from_left = global_position.x <= target_grass.global_position.x
	target_position = target_grass.global_position + Vector2(
		-eating_distance if eat_from_left else eating_distance,
		0.0
	)
	_clear_obstacle_avoidance()
	state = State.SEEK_GRASS
	_play_animation(&"walk")
	return true


func _update_grass_search(delta: float) -> void:
	if not is_instance_valid(target_grass) or not target_grass.is_mature():
		_release_grass()
		_enter_idle()
		return
	if global_position.distance_to(target_position) <= 3.0:
		global_position = target_position
		flip_h = not eat_from_left
		state = State.EAT
		state_time = random.randf_range(min_eat_seconds, max_eat_seconds)
		if not target_grass.begin_eating(self, state_time):
			_release_grass()
			_enter_idle()
			return
		_play_animation(&"eat_enter")
		return
	_move_toward_target(delta)


func _finish_eating() -> void:
	if is_instance_valid(target_grass):
		target_grass.finish_eating(self)
	target_grass = null
	_start_hunger_cycle()
	_enter_idle()


func _start_hunger_cycle(initial_hunger := 0.0) -> void:
	var seconds_to_full := random.randf_range(
		min_seconds_to_full_hunger,
		max_seconds_to_full_hunger
	)
	hunger = clampf(initial_hunger, 0.0, 100.0)
	hunger_rate = 100.0 / seconds_to_full
	food_search_cooldown = 0.0


func _release_grass() -> void:
	if is_instance_valid(target_grass):
		target_grass.cancel_eating(self)
	target_grass = null


func _move_toward_target(delta: float) -> void:
	var speed := run_speed if state == State.RUN else walk_speed
	var step_distance := speed * delta
	var direct_direction := global_position.direction_to(target_position)
	var direct_position := global_position.move_toward(target_position, step_distance)

	if avoidance_direction != Vector2.ZERO:
		avoidance_time += delta
		if avoidance_time >= 0.65 and _direct_route_is_clear(direct_direction, step_distance):
			_clear_obstacle_avoidance()
		else:
			if avoidance_time >= MAX_AVOIDANCE_SECONDS:
				_handle_blocked_route()
				return
			if _move_in_direction(avoidance_direction, step_distance):
				blocked_time = 0.0
				return
			if avoidance_switches == 0 and _start_obstacle_avoidance(direct_direction, step_distance, true):
				return
			blocked_time += delta
			if blocked_time >= 0.35:
				_handle_blocked_route()
			return

	if not _can_move_to(direct_position):
		if _start_obstacle_avoidance(direct_direction, step_distance):
			blocked_time = 0.0
			return
		blocked_time += delta
		if blocked_time >= 0.35:
			_handle_blocked_route()
		return
	blocked_time = 0.0
	_update_movement_animation(direct_direction)
	if absf(direct_direction.x) > 0.05:
		flip_h = direct_direction.x < 0.0
	global_position = direct_position
	if global_position.distance_to(target_position) <= 2.0 and state != State.SEEK_GRASS:
		_enter_idle()


func _start_obstacle_avoidance(direction: Vector2, distance: float, switch_side := false) -> bool:
	var first_side := direction.rotated(PI * 0.5).normalized()
	var second_side := direction.rotated(-PI * 0.5).normalized()
	if second_side.y > first_side.y:
		var swap := first_side
		first_side = second_side
		second_side = swap
	var detour_directions := [
		first_side,
		(direction + first_side).normalized(),
		(-direction + first_side).normalized(),
		(direction + second_side).normalized(),
		second_side,
		(-direction + second_side).normalized(),
		-direction,
	]
	for detour_direction in detour_directions:
		if switch_side and detour_direction.dot(avoidance_direction) > 0.5:
			continue
		if not _move_in_direction(detour_direction, distance):
			continue
		avoidance_direction = detour_direction
		avoidance_time = 0.0
		avoidance_switches = 1 if switch_side else 0
		return true
	return false


func _direct_route_is_clear(direction: Vector2, step_distance: float) -> bool:
	if direction == Vector2.ZERO:
		return true
	for probe_distance in [step_distance, 20.0, 40.0, 64.0]:
		var candidate := _clamp_to_bounds(global_position + direction * probe_distance)
		if candidate == global_position or not _can_move_to(candidate):
			return false
	return true


func _move_in_direction(direction: Vector2, distance: float) -> bool:
	var candidate := _clamp_to_bounds(global_position + direction * distance)
	if candidate == global_position or not _can_move_to(candidate):
		return false
	_update_movement_animation(direction)
	if absf(direction.x) > 0.05:
		flip_h = direction.x < 0.0
	global_position = candidate
	return true


func _handle_blocked_route() -> void:
	_clear_obstacle_avoidance()
	blocked_time = 0.0
	if _recover_from_overlap():
		return
	if state == State.SEEK_GRASS:
		_release_grass()
		food_search_cooldown = 2.0
		_enter_wander()
	else:
		_enter_wander()


func _recover_from_overlap() -> bool:
	if _can_move_to(global_position):
		return false
	for radius in [12.0, 24.0, 36.0, 52.0, 72.0, 96.0]:
		for direction_index in 16:
			var angle := TAU * float(direction_index) / 16.0
			var candidate := _clamp_to_bounds(global_position + Vector2.from_angle(angle) * radius)
			if candidate != global_position and _can_move_to(candidate):
				global_position = candidate
				return true
	return false


func _clear_obstacle_avoidance() -> void:
	avoidance_direction = Vector2.ZERO
	avoidance_time = 0.0
	avoidance_switches = 0


func _can_move_to(candidate_position: Vector2) -> bool:
	var world_controller := get_node_or_null("../../..")
	if (
		world_controller
		and world_controller.has_method("is_point_on_land")
		and not world_controller.is_point_on_land(candidate_position, movement_shape.radius)
	):
		return false
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = movement_shape
	query.transform = Transform2D(0.0, candidate_position)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space_state.intersect_shape(query, 1).is_empty()


func _clamp_to_bounds(point: Vector2) -> Vector2:
	var world_controller := get_node_or_null("../../..")
	if world_controller and world_controller.has_method("clamp_point_to_land"):
		return world_controller.clamp_point_to_land(point, global_position)
	return Vector2(
		clampf(point.x, activity_bounds.position.x, activity_bounds.end.x),
		clampf(point.y, activity_bounds.position.y, activity_bounds.end.y)
	)


func _play_animation(animation_name: StringName, playback_speed := 1.0) -> void:
	speed_scale = playback_speed
	if animation != animation_name or not is_playing():
		play(animation_name)


func _update_movement_animation(direction: Vector2) -> void:
	if state == State.RUN:
		_play_animation(&"run")
	elif absf(direction.x) > 0.25 and absf(direction.y) > 0.25:
		flip_h = direction.x < 0.0
		_play_animation(&"walk_diag_down" if direction.y > 0.0 else &"walk_diag_up")
	elif absf(direction.y) > absf(direction.x) * 1.25:
		flip_h = false
		_play_animation(&"walk_down" if direction.y > 0.0 else &"walk_up")
	else:
		flip_h = direction.x < 0.0
		_play_animation(&"walk")


func _on_animation_finished() -> void:
	if state == State.EAT and animation == &"eat_enter":
		_play_animation(&"eat_loop")
		return
	if state != State.REST:
		return
	if is_waking_up:
		is_waking_up = false
		_choose_next_activity()
	elif animation == &"lie_down":
		_play_animation(&"rest")


func _build_animations() -> void:
	var walk_texture := WALK_TEXTURE if is_adult() else LAMB_WALK_TEXTURE
	var run_texture := RUN_TEXTURE if is_adult() else LAMB_RUN_TEXTURE
	var idle_texture := IDLE_TEXTURE if is_adult() else LAMB_IDLE_TEXTURE
	var eat_enter_texture := EAT_ENTER_TEXTURE if is_adult() else LAMB_EAT_ENTER_TEXTURE
	var eat_loop_texture := EAT_LOOP_TEXTURE if is_adult() else LAMB_EAT_LOOP_TEXTURE
	var lie_down_texture := LIE_DOWN_TEXTURE if is_adult() else LAMB_LIE_DOWN_TEXTURE
	var rest_texture := REST_TEXTURE if is_adult() else LAMB_REST_TEXTURE
	var walk_up_texture := WALK_UP_TEXTURE if is_adult() else LAMB_WALK_UP_TEXTURE
	var walk_down_texture := WALK_DOWN_TEXTURE if is_adult() else LAMB_WALK_DOWN_TEXTURE
	var walk_diag_up_texture := WALK_DIAG_UP_TEXTURE if is_adult() else LAMB_WALK_DIAG_UP_TEXTURE
	var walk_diag_down_texture := WALK_DIAG_DOWN_TEXTURE if is_adult() else LAMB_WALK_DIAG_DOWN_TEXTURE
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"walk", walk_texture, 4, 4.0)
	_add_animation(frames, &"run", run_texture, 8, 10.0)
	_add_animation(frames, &"idle", idle_texture, 6, 5.0)
	_add_animation(frames, &"eat_enter", eat_enter_texture, 5, 7.0, false)
	_add_animation(frames, &"eat_loop", eat_loop_texture, 7, 5.0)
	_add_animation(frames, &"lie_down", lie_down_texture, 6, 7.0, false)
	_add_animation(frames, &"rest", rest_texture, 6, 3.0)
	_add_animation(frames, &"walk_up", walk_up_texture, 4, 5.0)
	_add_animation(frames, &"walk_down", walk_down_texture, 4, 5.0)
	_add_animation(frames, &"walk_diag_up", walk_diag_up_texture, 4, 5.0)
	_add_animation(frames, &"walk_diag_down", walk_diag_down_texture, 4, 5.0)
	sprite_frames = frames


func _add_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	texture: Texture2D,
	frame_count: int,
	fps: float,
	loop := true
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_index * 128, 0), FRAME_SIZE)
		frames.add_frame(animation_name, atlas)
