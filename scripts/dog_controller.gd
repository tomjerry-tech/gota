extends AnimatedSprite2D

signal active_changed(is_active: bool)
signal mode_changed(mode: int)
signal command_issued(mode: int)
signal sheep_driven(sheep: Node)
signal stamina_changed(value: float)
signal stamina_low

enum CommandMode {
	FOLLOW,
	DRIVE,
	GUARD,
}

const FRAME_SIZE := Vector2(128, 128)
const MASTER_TEXTURE: Texture2D = preload("res://assets/tiny_swords/dog/dog_master.png")
const RUN_SIDE_TEXTURE: Texture2D = preload("res://assets/tiny_swords/dog/dog_run_side.png")
const RUN_UP_TEXTURE: Texture2D = preload("res://assets/tiny_swords/dog/dog_run_up.png")
const RUN_DOWN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/dog/dog_run_down.png")
const GUARD_TEXTURE: Texture2D = preload("res://assets/tiny_swords/dog/dog_guard.png")
const MAX_STAMINA := 100.0
const LOW_STAMINA_THRESHOLD := 25.0
const DAWN_RECOVERY := 25.0

@export_range(60.0, 180.0, 1.0) var run_speed := 105.0
@export_range(50.0, 180.0, 1.0) var drive_radius := 108.0
@export_range(40.0, 160.0, 1.0) var guard_radius := 88.0
@export_range(8.0, 20.0, 1.0) var collision_radius := 12.0
@export var dog_index := 0

@onready var world_controller: Node = get_node("../..")
@onready var player: AnimatedSprite2D = get_node("../Shepherd")

var active := false
var command_mode := CommandMode.FOLLOW
var command_target := Vector2.ZERO
var has_command_target := false
var movement_shape := CircleShape2D.new()
var avoidance_direction := Vector2.ZERO
var avoidance_time := 0.0
var drive_cooldowns: Dictionary = {}
var mode_label: Label
var target_marker: Polygon2D
var selection_ring: Line2D
var going_to_rest := false
var resting := false
var rest_target := Vector2.ZERO
var stamina := MAX_STAMINA


func _ready() -> void:
	movement_shape.radius = collision_radius
	_build_animations()
	_build_mode_label()
	_build_target_marker()
	_build_selection_ring()
	visible = active
	set_physics_process(active)


func _physics_process(delta: float) -> void:
	_update_drive_cooldowns(delta)
	if not active:
		return
	if resting:
		return
	if going_to_rest:
		if global_position.distance_to(rest_target) <= 12.0:
			going_to_rest = false
			resting = true
			visible = false
			return
		_move_toward(rest_target, delta)
		return
	match command_mode:
		CommandMode.FOLLOW:
			_update_follow(delta)
		CommandMode.DRIVE:
			_update_drive(delta)
		CommandMode.GUARD:
			_update_guard(delta)


func set_command_mode(value: int, issued := true) -> bool:
	if not active or value < CommandMode.FOLLOW or value > CommandMode.GUARD:
		return false
	command_mode = value
	going_to_rest = false
	resting = false
	visible = true
	has_command_target = false
	target_marker.hide()
	avoidance_direction = Vector2.ZERO
	_update_mode_label()
	mode_changed.emit(command_mode)
	if issued:
		command_issued.emit(command_mode)
	return true


func set_command_target(world_position: Vector2, issued := true) -> bool:
	if not active or command_mode == CommandMode.FOLLOW:
		return false
	command_target = world_controller.clamp_point_to_land(world_position, global_position)
	has_command_target = true
	target_marker.position = command_target
	target_marker.show()
	if issued:
		command_issued.emit(command_mode)
	return true


func configure(index: int, home_position: Vector2) -> void:
	dog_index = index
	var was_active := active
	active = true
	visible = not resting
	set_physics_process(true)
	if not was_active:
		global_position = world_controller.clamp_point_to_land(home_position + Vector2(0.0, 58.0), player.global_position)
		command_mode = CommandMode.FOLLOW
		has_command_target = false
		_update_mode_label()
		_play_idle()
		active_changed.emit(true)


func deactivate() -> void:
	if not active:
		return
	active = false
	visible = false
	going_to_rest = false
	resting = false
	has_command_target = false
	target_marker.hide()
	set_physics_process(false)
	set_selected(false)
	active_changed.emit(false)


func set_selected(value: bool) -> void:
	if selection_ring:
		selection_ring.visible = value and active and not resting
	if mode_label:
		mode_label.visible = value and active and not resting


func send_to_rest(world_position: Vector2) -> bool:
	if not active:
		return false
	rest_target = world_controller.clamp_point_to_land(world_position + Vector2(0.0, 46.0), global_position)
	going_to_rest = true
	resting = false
	visible = true
	has_command_target = false
	target_marker.hide()
	return true


func wake_up(natural_recovery := DAWN_RECOVERY) -> void:
	if not active:
		return
	var slept_inside := resting
	if resting:
		global_position = world_controller.clamp_point_to_land(rest_target, player.global_position)
	resting = false
	going_to_rest = false
	visible = true
	command_mode = CommandMode.FOLLOW
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


func get_night_defense_points() -> int:
	if stamina >= 60.0:
		return 10
	if stamina >= LOW_STAMINA_THRESHOLD:
		return 7
	return 4


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


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"mode": command_mode,
		"command_target": [command_target.x, command_target.y],
		"has_command_target": has_command_target,
		"dog_index": dog_index,
		"going_to_rest": going_to_rest,
		"resting": resting,
		"rest_target": [rest_target.x, rest_target.y],
		"stamina": stamina,
	}


func restore_save_data(data: Dictionary) -> void:
	if not active:
		return
	var saved_position: Variant = data.get("position", [])
	if saved_position is Array and saved_position.size() >= 2:
		global_position = world_controller.clamp_point_to_land(
			Vector2(float(saved_position[0]), float(saved_position[1])),
			global_position
		)
	command_mode = clampi(int(data.get("mode", CommandMode.FOLLOW)), CommandMode.FOLLOW, CommandMode.GUARD)
	var saved_target: Variant = data.get("command_target", [])
	if saved_target is Array and saved_target.size() >= 2:
		command_target = world_controller.clamp_point_to_land(
			Vector2(float(saved_target[0]), float(saved_target[1])),
			global_position
		)
	has_command_target = bool(data.get("has_command_target", false)) and command_mode != CommandMode.FOLLOW
	var saved_rest_target: Variant = data.get("rest_target", [])
	if saved_rest_target is Array and saved_rest_target.size() >= 2:
		rest_target = world_controller.clamp_point_to_land(
			Vector2(float(saved_rest_target[0]), float(saved_rest_target[1])), global_position
		)
	going_to_rest = bool(data.get("going_to_rest", false))
	resting = bool(data.get("resting", false))
	stamina = clampf(float(data.get("stamina", MAX_STAMINA)), 0.0, MAX_STAMINA)
	visible = not resting
	if has_command_target:
		target_marker.position = command_target
		target_marker.show()
	else:
		target_marker.hide()
	_update_mode_label()
	stamina_changed.emit(stamina)
	mode_changed.emit(command_mode)


func _update_follow(delta: float) -> void:
	var target := player.global_position + _follow_offset()
	if global_position.distance_to(target) <= 42.0:
		_play_idle()
		return
	_move_toward(target, delta)


func _follow_offset() -> Vector2:
	var spread := float(dog_index % 3 - 1) * 34.0
	match player.facing:
		&"left": return Vector2(48, 22 + spread)
		&"right": return Vector2(-48, 22 + spread)
		&"up": return Vector2(26 + spread, 52)
		_: return Vector2(-26 + spread, -52)


func _update_drive(delta: float) -> void:
	if not has_command_target:
		_play_idle()
		return
	var flock := _get_drive_flock()
	if flock.is_empty():
		if global_position.distance_to(command_target) > 34.0:
			_move_toward(command_target, delta)
		else:
			_play_guard()
		return
	var center := Vector2.ZERO
	for sheep in flock:
		center += sheep.global_position
	center /= float(flock.size())
	var push_direction := center.direction_to(command_target)
	if push_direction == Vector2.ZERO:
		push_direction = Vector2.RIGHT
	var drive_anchor: Vector2 = world_controller.clamp_point_to_land(center - push_direction * 72.0, global_position)
	if global_position.distance_to(drive_anchor) > 24.0:
		_move_toward(drive_anchor, delta)
	else:
		_play_guard()
	var dog_to_flock := global_position.direction_to(center)
	if dog_to_flock.dot(push_direction) >= 0.35:
		_drive_sheep(flock, drive_radius, command_target)


func _get_drive_flock() -> Array[Node]:
	var flock: Array[Node] = []
	var nearest: Node
	var nearest_distance := INF
	for sheep in world_controller.sheep_group.get_children():
		var distance: float = sheep.global_position.distance_to(command_target)
		if distance < nearest_distance:
			nearest = sheep
			nearest_distance = distance
		if distance <= 260.0 and distance > 44.0:
			flock.append(sheep)
	if flock.is_empty() and nearest and nearest_distance > 44.0:
		flock.append(nearest)
	return flock


func _update_guard(delta: float) -> void:
	if not has_command_target:
		_play_idle()
		return
	if global_position.distance_to(command_target) > 12.0:
		_move_toward(command_target, delta)
		return
	_play_guard()
	_drive_sheep(world_controller.sheep_group.get_children(), guard_radius, null)


func _drive_sheep(candidates: Array, radius: float, toward: Variant) -> int:
	var affected := 0
	var effective_radius := radius * get_work_efficiency()
	for sheep in candidates:
		if sheep.global_position.distance_to(global_position) > effective_radius:
			continue
		var sheep_key: int = sheep.get_instance_id()
		if drive_cooldowns.has(sheep_key):
			continue
		if sheep.has_method("scare_from_dog") and sheep.scare_from_dog(global_position, toward):
			drive_cooldowns[sheep_key] = 0.7
			sheep_driven.emit(sheep)
			affected += 1
	if affected > 0:
		consume_stamina(float(affected) * 0.4)
	return affected


func _move_toward(target: Vector2, delta: float) -> bool:
	var direction := global_position.direction_to(target)
	var distance := minf(run_speed * get_work_efficiency() * delta, global_position.distance_to(target))
	var direct_candidate := global_position + direction * distance
	if _try_move_to(direct_candidate, direction):
		avoidance_direction = Vector2.ZERO
		consume_stamina(delta * 0.75)
		return true
	if avoidance_direction != Vector2.ZERO:
		avoidance_time += delta
		if _try_move_to(global_position + avoidance_direction * distance, avoidance_direction):
			consume_stamina(delta * 0.75)
			if avoidance_time < 0.65:
				return true
		avoidance_direction = Vector2.ZERO
	for angle in [PI * 0.25, -PI * 0.25, PI * 0.5, -PI * 0.5, PI * 0.75, -PI * 0.75, PI]:
		var detour := direction.rotated(angle).normalized()
		if _try_move_to(global_position + detour * distance, detour):
			avoidance_direction = detour
			avoidance_time = 0.0
			consume_stamina(delta * 0.75)
			return true
	_play_idle()
	return false


func _try_move_to(candidate: Vector2, direction: Vector2) -> bool:
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
	_play_run(direction)
	return true


func _play_run(direction: Vector2) -> void:
	if absf(direction.y) > absf(direction.x) * 1.1:
		flip_h = false
		_play_animation(&"run_down" if direction.y > 0.0 else &"run_up")
	else:
		flip_h = direction.x < 0.0
		_play_animation(&"run_side")


func _play_idle() -> void:
	flip_h = player.facing == &"left"
	_play_animation(&"idle")


func _play_guard() -> void:
	_play_animation(&"guard")


func _play_animation(animation_name: StringName) -> void:
	if animation != animation_name or not is_playing():
		play(animation_name)


func _update_drive_cooldowns(delta: float) -> void:
	for sheep_key in drive_cooldowns.keys():
		var remaining := float(drive_cooldowns[sheep_key]) - delta
		if remaining <= 0.0:
			drive_cooldowns.erase(sheep_key)
		else:
			drive_cooldowns[sheep_key] = remaining


func _build_mode_label() -> void:
	mode_label = Label.new()
	mode_label.position = Vector2(-43, -56)
	mode_label.size = Vector2(86, 22)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_size_override("font_size", 12)
	mode_label.add_theme_color_override("font_color", Color("fff0b0"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.16, 0.72)
	style.set_corner_radius_all(3)
	mode_label.add_theme_stylebox_override("normal", style)
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mode_label)
	mode_label.hide()


func _build_target_marker() -> void:
	target_marker = Polygon2D.new()
	target_marker.name = "DogCommandTarget"
	target_marker.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(0, -6), Vector2(9, 0), Vector2(0, 6),
	])
	target_marker.color = Color(0.38, 0.78, 0.86, 0.78)
	target_marker.z_index = 5
	target_marker.top_level = true
	target_marker.hide()
	add_child(target_marker)


func _build_selection_ring() -> void:
	selection_ring = Line2D.new()
	selection_ring.name = "SelectionRing"
	selection_ring.width = 2.0
	selection_ring.default_color = Color("7fe4ec")
	selection_ring.z_index = -1
	for index in 25:
		var angle := TAU * float(index) / 24.0
		selection_ring.add_point(Vector2(cos(angle) * 25.0, sin(angle) * 13.0 + 12.0))
	selection_ring.hide()
	add_child(selection_ring)


func _update_mode_label() -> void:
	if not mode_label:
		return
	mode_label.text = ["跟随", "驱赶", "守住"][command_mode]


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"idle", MASTER_TEXTURE, 1, 1.0, true)
	_add_animation(frames, &"run_side", RUN_SIDE_TEXTURE, 6, 12.0, true)
	_add_animation(frames, &"run_up", RUN_UP_TEXTURE, 4, 11.0, true)
	_add_animation(frames, &"run_down", RUN_DOWN_TEXTURE, 4, 11.0, true)
	_add_animation(frames, &"guard", GUARD_TEXTURE, 4, 5.0, true)
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
