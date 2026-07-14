extends AnimatedSprite2D

signal whistle_used
signal stamina_changed(value: float)
signal stamina_low

const FRAME_SIZE := Vector2(128, 128)
const IDLE_TEXTURES := {
	&"down": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_idle_down.png"),
	&"up": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_idle_up.png"),
	&"left": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_idle_left.png"),
	&"right": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_idle_right.png"),
}
const WALK_TEXTURES := {
	&"down": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_walk_down.png"),
	&"up": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_walk_up.png"),
	&"left": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_walk_left.png"),
	&"right": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_walk_right.png"),
}
const RUN_TEXTURES := {
	&"down": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_run_down.png"),
	&"up": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_run_up.png"),
	&"left": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_run_left.png"),
	&"right": preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_run_right.png"),
}
const WHISTLE_TEXTURE: Texture2D = preload("res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_whistle_down_right.png")
const MAX_STAMINA := 100.0
const LOW_STAMINA_THRESHOLD := 25.0
const DAWN_RECOVERY := 25.0
const DISPLAY_SCALE := Vector2(1.2, 1.2)

@export_range(40.0, 160.0, 1.0) var walk_speed := 78.0
@export_range(80.0, 260.0, 1.0) var run_speed := 132.0
@export_range(30.0, 160.0, 1.0) var herding_radius := 82.0
@export_range(100.0, 400.0, 1.0) var whistle_radius := 250.0
@export_range(8.0, 24.0, 1.0) var collision_radius := 14.0

@onready var world_controller: Node = get_node("../..")
@onready var world_camera: Camera2D = get_node("../../WorldCamera")
@onready var build_controller: Node = get_node("../../BuildController")

var facing: StringName = &"down"
var movement_shape := CircleShape2D.new()
var whistle_cooldown := 0.0
var whistling := false
var herd_cooldowns: Dictionary = {}
var context_label: Label
var context_refresh_time := 0.0
var selection_ring: Line2D
var selected := false
var movement_target := Vector2.ZERO
var has_movement_target := false
var avoidance_direction := Vector2.ZERO
var avoidance_time := 0.0
var resting := false
var going_to_rest := false
var rest_target := Vector2.ZERO
var auto_roundup_fence: Node2D
var stamina := MAX_STAMINA


func _ready() -> void:
	scale = DISPLAY_SCALE
	movement_shape.radius = collision_radius
	_build_animations()
	_build_context_label()
	_build_selection_ring()
	animation_finished.connect(_on_animation_finished)
	_play_idle()


func _physics_process(delta: float) -> void:
	whistle_cooldown = maxf(0.0, whistle_cooldown - delta)
	_update_herd_cooldowns(delta)
	context_refresh_time -= delta
	if context_refresh_time <= 0.0:
		context_refresh_time = 0.2
		_update_context_label()
	if not _controls_enabled() or whistling:
		return
	if resting:
		return
	if going_to_rest:
		if global_position.distance_to(rest_target) <= 12.0:
			going_to_rest = false
			resting = true
			visible = false
			has_movement_target = false
			return
		_move_toward_click_target(rest_target, delta)
	elif is_instance_valid(auto_roundup_fence):
		_update_auto_roundup(delta)
	elif has_movement_target:
		if global_position.distance_to(movement_target) <= 6.0:
			has_movement_target = false
			avoidance_direction = Vector2.ZERO
			_play_idle()
		else:
			_move_toward_click_target(movement_target, delta)
	else:
		_play_idle()
	herd_nearby_sheep()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or not _controls_enabled():
		return
	match event.keycode:
		KEY_SPACE:
			if use_whistle():
				get_viewport().set_input_as_handled()
		KEY_E:
			if build_controller.toggle_nearest_gate(global_position):
				get_viewport().set_input_as_handled()
		KEY_F:
			world_camera.focus_on_world_position(global_position)
			get_viewport().set_input_as_handled()


func move_character(direction: Vector2, delta: float, running := false) -> bool:
	if direction == Vector2.ZERO or delta <= 0.0:
		return false
	direction = direction.normalized()
	_update_facing(direction)
	var distance := (run_speed if running else walk_speed) * get_work_efficiency() * delta
	var motion := direction * distance
	var moved := _try_move_to(global_position + motion)
	if not moved and absf(motion.x) > 0.01:
		moved = _try_move_to(global_position + Vector2(motion.x, 0.0))
	if not moved and absf(motion.y) > 0.01:
		moved = _try_move_to(global_position + Vector2(0.0, motion.y))
	if moved:
		_play_directional(&"run" if running else &"walk", facing)
		consume_stamina(delta * (0.9 if running else 0.55))
	else:
		_play_idle()
	return moved


func set_selected(value: bool) -> void:
	selected = value
	if selection_ring:
		selection_ring.visible = selected and not resting


func set_move_target(world_position: Vector2) -> bool:
	if resting or not _controls_enabled():
		return false
	movement_target = world_controller.clamp_point_to_land(world_position, global_position)
	has_movement_target = true
	auto_roundup_fence = null
	avoidance_direction = Vector2.ZERO
	return true


func start_auto_roundup(fence: Node2D) -> bool:
	if not is_instance_valid(fence):
		return false
	auto_roundup_fence = fence
	has_movement_target = false
	going_to_rest = false
	resting = false
	visible = true
	return true


func stop_auto_roundup() -> void:
	auto_roundup_fence = null
	avoidance_direction = Vector2.ZERO


func send_to_rest(world_position: Vector2) -> bool:
	if resting:
		return false
	rest_target = world_controller.clamp_point_to_land(world_position, global_position)
	going_to_rest = true
	has_movement_target = false
	auto_roundup_fence = null
	visible = true
	return true


func wake_up(natural_recovery := DAWN_RECOVERY) -> void:
	var slept_inside := resting
	if resting:
		global_position = world_controller.clamp_point_to_land(rest_target, global_position)
	resting = false
	going_to_rest = false
	visible = true
	recover_stamina(MAX_STAMINA if slept_inside else float(natural_recovery))
	_play_idle()


func get_stamina_percent() -> int:
	return roundi(stamina)


func get_work_efficiency() -> float:
	return 1.0 if stamina >= 50.0 else lerpf(0.65, 1.0, stamina / 50.0)


func get_stamina_state_text() -> String:
	if stamina <= LOW_STAMINA_THRESHOLD:
		return "疲惫"
	if stamina < 60.0:
		return "有些累"
	return "精力充足"


func consume_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	var was_above_low := stamina > LOW_STAMINA_THRESHOLD
	_set_stamina(stamina - amount)
	if was_above_low and stamina <= LOW_STAMINA_THRESHOLD:
		stamina_low.emit()


func recover_stamina(amount: float) -> void:
	if amount > 0.0:
		_set_stamina(stamina + amount)


func _set_stamina(value: float) -> void:
	var next_value := clampf(value, 0.0, MAX_STAMINA)
	if is_equal_approx(next_value, stamina):
		return
	stamina = next_value
	stamina_changed.emit(stamina)


func _move_toward_click_target(target: Vector2, delta: float) -> bool:
	var direct := global_position.direction_to(target)
	var running := global_position.distance_to(target) > 120.0
	if avoidance_direction != Vector2.ZERO:
		avoidance_time += delta
		if avoidance_time >= 0.55 and _path_probe_is_clear(direct):
			avoidance_direction = Vector2.ZERO
		elif move_character(avoidance_direction, delta, running):
			return true
		else:
			avoidance_direction = Vector2.ZERO
	if move_character(direct, delta, running):
		return true
	for angle in [PI * 0.25, -PI * 0.25, PI * 0.5, -PI * 0.5, PI * 0.75, -PI * 0.75]:
		var detour := direct.rotated(angle).normalized()
		if move_character(detour, delta, running):
			avoidance_direction = detour
			avoidance_time = 0.0
			return true
	return false


func _path_probe_is_clear(direction: Vector2) -> bool:
	for distance in [18.0, 38.0, 64.0]:
		if not _position_is_free(global_position + direction * distance):
			return false
	return true


func _position_is_free(candidate: Vector2) -> bool:
	if not world_controller.is_point_on_land(candidate, collision_radius):
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = movement_shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_auto_roundup(delta: float) -> void:
	if not is_instance_valid(auto_roundup_fence):
		stop_auto_roundup()
		return
	var area: Rect2 = auto_roundup_fence.get_meta("grazing_rect", Rect2())
	var outside: Array[Node] = []
	for sheep in world_controller.sheep_group.get_children():
		if not area.has_point(sheep.global_position):
			outside.append(sheep)
	if outside.is_empty():
		stop_auto_roundup()
		_play_idle()
		return
	var center := area.get_center()
	outside.sort_custom(
		func(first: Node, second: Node) -> bool:
			return first.global_position.distance_squared_to(center) < second.global_position.distance_squared_to(center)
	)
	var target_sheep := outside[0]
	var push_direction: Vector2 = target_sheep.global_position.direction_to(center)
	var behind: Vector2 = world_controller.clamp_point_to_land(target_sheep.global_position - push_direction * 58.0, global_position)
	_move_toward_click_target(behind, delta)


func herd_nearby_sheep() -> int:
	var affected := 0
	var effective_radius := herding_radius * get_work_efficiency()
	for sheep in world_controller.sheep_group.get_children():
		if sheep.global_position.distance_to(global_position) > effective_radius:
			continue
		var sheep_key: int = sheep.get_instance_id()
		if herd_cooldowns.has(sheep_key):
			continue
		if sheep.has_method("scare"):
			sheep.scare(global_position)
			herd_cooldowns[sheep_key] = 0.8
			affected += 1
	if affected > 0:
		consume_stamina(float(affected) * 0.25)
	return affected


func use_whistle() -> bool:
	if whistle_cooldown > 0.0 or whistling:
		return false
	whistle_cooldown = 1.2
	whistling = true
	var nearby: Array[Node] = []
	var effective_whistle_radius := whistle_radius * get_work_efficiency()
	for sheep in world_controller.sheep_group.get_children():
		if sheep.global_position.distance_to(global_position) <= effective_whistle_radius:
			nearby.append(sheep)
	nearby.sort_custom(
		func(first: Node, second: Node) -> bool:
			return first.global_position.distance_squared_to(global_position) < second.global_position.distance_squared_to(global_position)
	)
	for index in nearby.size():
		var ring := index / 8
		var angle := TAU * float(index % 8) / 8.0
		var target := global_position + Vector2.from_angle(angle) * (52.0 + ring * 24.0)
		if nearby[index].has_method("answer_whistle"):
			nearby[index].answer_whistle(target)
	play(&"whistle")
	consume_stamina(2.0)
	whistle_used.emit()
	return true


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"facing": String(facing),
		"movement_target": [movement_target.x, movement_target.y],
		"has_movement_target": has_movement_target,
		"rest_target": [rest_target.x, rest_target.y],
		"going_to_rest": going_to_rest,
		"resting": resting,
		"stamina": stamina,
	}


func restore_save_data(data: Dictionary) -> void:
	var saved_position: Variant = data.get("position", [])
	if saved_position is Array and saved_position.size() >= 2:
		global_position = world_controller.clamp_point_to_land(
			Vector2(float(saved_position[0]), float(saved_position[1])),
			global_position
		)
	var saved_facing := StringName(String(data.get("facing", "down")))
	facing = saved_facing if saved_facing in [&"down", &"up", &"left", &"right"] else &"down"
	whistling = false
	var saved_target: Variant = data.get("movement_target", [])
	if saved_target is Array and saved_target.size() >= 2:
		movement_target = world_controller.clamp_point_to_land(Vector2(float(saved_target[0]), float(saved_target[1])), global_position)
	has_movement_target = bool(data.get("has_movement_target", false))
	var saved_rest_target: Variant = data.get("rest_target", [])
	if saved_rest_target is Array and saved_rest_target.size() >= 2:
		rest_target = world_controller.clamp_point_to_land(Vector2(float(saved_rest_target[0]), float(saved_rest_target[1])), global_position)
	going_to_rest = bool(data.get("going_to_rest", false))
	resting = bool(data.get("resting", false))
	stamina = clampf(float(data.get("stamina", MAX_STAMINA)), 0.0, MAX_STAMINA)
	visible = not resting
	stamina_changed.emit(stamina)
	_play_idle()


func _controls_enabled() -> bool:
	if get_tree().paused or build_controller.is_build_mode_active():
		return false
	var hud := world_controller.get_node_or_null("HUD")
	if hud:
		for panel_name in ["DailyReport", "SystemMenu"]:
			var panel := hud.get_node_or_null(panel_name) as Control
			if panel and panel.visible:
				return false
		var right_panel := hud.get_node_or_null("RightSidePanel") as Control
		if right_panel and right_panel.visible and right_panel.get_mode() == &"story":
			return false
	return get_viewport().gui_get_focus_owner() is not LineEdit


func _read_input_direction() -> Vector2:
	var horizontal := 0.0
	var vertical := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vertical -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vertical += 1.0
	return Vector2(horizontal, vertical).normalized()


func _try_move_to(candidate: Vector2) -> bool:
	if not world_controller.is_point_on_land(candidate, collision_radius):
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = movement_shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	global_position = candidate
	return true


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing = &"right" if direction.x > 0.0 else &"left"
	else:
		facing = &"down" if direction.y > 0.0 else &"up"


func _play_idle() -> void:
	_play_directional(&"idle", facing)


func _play_directional(action: StringName, direction: StringName) -> void:
	var animation_name := StringName("%s_%s" % [action, direction])
	if animation != animation_name or not is_playing():
		play(animation_name)


func _on_animation_finished() -> void:
	if animation == &"whistle":
		whistling = false
		_play_idle()


func _update_herd_cooldowns(delta: float) -> void:
	for sheep_key in herd_cooldowns.keys():
		var remaining := float(herd_cooldowns[sheep_key]) - delta
		if remaining <= 0.0:
			herd_cooldowns.erase(sheep_key)
		else:
			herd_cooldowns[sheep_key] = remaining


func _build_context_label() -> void:
	context_label = Label.new()
	context_label.position = Vector2(-70, -76)
	context_label.size = Vector2(140, 28)
	context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	context_label.add_theme_font_size_override("font_size", 14)
	context_label.add_theme_color_override("font_color", Color("fff0b0"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.12, 0.16, 0.78)
	background.corner_radius_top_left = 4
	background.corner_radius_top_right = 4
	background.corner_radius_bottom_left = 4
	background.corner_radius_bottom_right = 4
	context_label.add_theme_stylebox_override("normal", background)
	context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context_label.z_index = 20
	context_label.hide()
	add_child(context_label)


func _build_selection_ring() -> void:
	selection_ring = Line2D.new()
	selection_ring.name = "SelectionRing"
	selection_ring.width = 2.0
	selection_ring.default_color = Color("7fe4ec")
	selection_ring.z_index = -1
	for index in 25:
		var angle := TAU * float(index) / 24.0
		selection_ring.add_point(Vector2(cos(angle) * 27.0, sin(angle) * 14.0 + 18.0))
	selection_ring.hide()
	add_child(selection_ring)


func _update_context_label() -> void:
	var info: Dictionary = build_controller.get_nearest_gate_info(global_position)
	if info.is_empty():
		context_label.hide()
		return
	context_label.text = "圈内 %d 只" % int(info.get("sheep_count", 0))
	context_label.show()


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for direction: StringName in IDLE_TEXTURES:
		_add_animation(frames, StringName("idle_%s" % direction), IDLE_TEXTURES[direction], 1, 1.0, true)
		_add_animation(frames, StringName("walk_%s" % direction), WALK_TEXTURES[direction], 6, 9.0, true)
		_add_animation(frames, StringName("run_%s" % direction), RUN_TEXTURES[direction], 7, 13.0, true)
	_add_animation(frames, &"whistle", WHISTLE_TEXTURE, 6, 10.0, false)
	sprite_frames = frames


func _add_animation(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, frame_count: int, speed: float, loop: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, speed)
	for frame_index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_index * FRAME_SIZE.x, 0.0), FRAME_SIZE)
		frames.add_frame(animation_name, atlas)
