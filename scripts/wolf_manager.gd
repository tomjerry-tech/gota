extends Node

signal wolf_spawned(wolf: AnimatedSprite2D)
signal sheep_chased(sheep: Node)

const FRAME_SIZE := Vector2(128, 128)
const IDLE_TEXTURE: Texture2D = preload("res://assets/tiny_swords/wolf/wolf_idle.png")
const RUN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/wolf/wolf_run_side.png")
const RUN_SPEED := 92.0
const CAPTURE_DISTANCE := 20.0
const COLLISION_RADIUS := 13.0

@onready var world_controller: Node = get_parent()
@onready var top_hud: Control = get_node("../HUD/TopHUD")
@onready var routine_manager: Node = get_node("../DayRoutineManager")
@onready var island: Node2D = get_node("../Island")

var wolves: Array[AnimatedSprite2D] = []
var movement_shape := CircleShape2D.new()


func _ready() -> void:
	movement_shape.radius = COLLISION_RADIUS
	top_hud.phase_changed.connect(_on_phase_changed)
	top_hud.day_changed.connect(_on_day_changed)
	call_deferred("_sync_night_pack")


func _process(delta: float) -> void:
	if not top_hud.is_night() or not routine_manager.wolf_den_found:
		return
	_sync_night_pack()
	for wolf in wolves:
		_update_wolf(wolf, delta)


func get_active_wolves() -> Array[AnimatedSprite2D]:
	return wolves.filter(func(wolf: AnimatedSprite2D) -> bool:
		return is_instance_valid(wolf) and not wolf.is_queued_for_deletion()
	)


func _on_phase_changed(_phase: StringName) -> void:
	_sync_night_pack()


func _on_day_changed(_day: int) -> void:
	_despawn_all()


func _sync_night_pack() -> void:
	if not top_hud.is_night() or not routine_manager.wolf_den_found or not is_instance_valid(routine_manager.wolf_den_node):
		_despawn_all()
		return
	var desired: int = clampi(1 + floori(float(routine_manager.get_wolf_threat_level() - 1) / 2.0), 1, 3)
	while wolves.size() < desired:
		_spawn_wolf(wolves.size())
	while wolves.size() > desired:
		var wolf: AnimatedSprite2D = wolves.pop_back()
		wolf.queue_free()


func _spawn_wolf(index: int) -> AnimatedSprite2D:
	var wolf := AnimatedSprite2D.new()
	wolf.name = "NightWolf%d" % (index + 1)
	wolf.sprite_frames = _build_frames()
	wolf.animation = &"idle"
	wolf.autoplay = "idle"
	wolf.z_index = 7
	wolf.scale = Vector2(1.1, 1.1)
	wolf.global_position = routine_manager.wolf_den_position + Vector2((index - 1) * 24.0, 18.0 + index * 8.0)
	wolf.set_meta("retreating", false)
	wolf.set_meta("avoidance_direction", Vector2.ZERO)
	island.add_child(wolf)
	wolves.append(wolf)
	wolf_spawned.emit(wolf)
	return wolf


func _update_wolf(wolf: AnimatedSprite2D, delta: float) -> void:
	if bool(wolf.get_meta("retreating", false)):
		if wolf.global_position.distance_to(routine_manager.wolf_den_position) <= 18.0:
			_play(wolf, &"idle")
			return
		_move_wolf(wolf, routine_manager.wolf_den_position, delta)
		return
	var target: Node
	if wolf.has_meta("target"):
		target = wolf.get_meta("target") as Node
	if not _is_valid_target(target):
		target = _find_nearest_target(wolf.global_position)
		wolf.set_meta("target", target)
	if not target:
		_play(wolf, &"idle")
		return
	if wolf.global_position.distance_to(target.global_position) <= CAPTURE_DISTANCE:
		if routine_manager.register_visible_wolf_capture(target):
			sheep_chased.emit(target)
		wolf.remove_meta("target")
		wolf.set_meta("retreating", true)
		return
	_move_wolf(wolf, target.global_position, delta)


func _find_nearest_target(from_position: Vector2) -> Node:
	var nearest: Node
	var nearest_distance: float = INF
	for sheep: Node in routine_manager.get_unsecured_sheep():
		if sheep.is_lost():
			continue
		var distance: float = sheep.global_position.distance_squared_to(from_position)
		if distance < nearest_distance:
			nearest = sheep
			nearest_distance = distance
	return nearest


func _is_valid_target(target: Variant) -> bool:
	return (
		is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and target.get_parent() == world_controller.sheep_group
		and not target.is_lost()
		and not routine_manager.is_sheep_secured(target)
	)


func _move_wolf(wolf: AnimatedSprite2D, target: Vector2, delta: float) -> bool:
	var direction: Vector2 = wolf.global_position.direction_to(target)
	var distance: float = minf(RUN_SPEED * delta, wolf.global_position.distance_to(target))
	for candidate_direction: Vector2 in [direction, direction.rotated(PI * 0.25), direction.rotated(-PI * 0.25), direction.rotated(PI * 0.5), direction.rotated(-PI * 0.5)]:
		var candidate: Vector2 = wolf.global_position + candidate_direction.normalized() * distance
		if _position_is_free(candidate):
			wolf.global_position = candidate
			wolf.flip_h = candidate_direction.x < 0.0
			_play(wolf, &"run")
			return true
	_play(wolf, &"idle")
	return false


func _position_is_free(candidate: Vector2) -> bool:
	if not world_controller.is_point_on_land(candidate, COLLISION_RADIUS):
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = movement_shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_viewport().world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


func _play(wolf: AnimatedSprite2D, animation_name: StringName) -> void:
	if wolf.animation != animation_name or not wolf.is_playing():
		wolf.play(animation_name)


func _despawn_all() -> void:
	for wolf in wolves:
		if is_instance_valid(wolf):
			wolf.queue_free()
	wolves.clear()


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_strip(frames, &"idle", IDLE_TEXTURE, 6, 4.0)
	_add_strip(frames, &"run", RUN_TEXTURE, 6, 9.0)
	return frames


func _add_strip(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, count: int, speed: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, speed)
	for index in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * FRAME_SIZE.x, 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(animation_name, atlas)
