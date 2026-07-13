extends AnimatedSprite2D

const FRAME_SIZE := Vector2(128, 128)
const SWAY_TEXTURE: Texture2D = preload("res://assets/tiny_swords/decorations/grass_sway.png")
const GROWTH_TEXTURE: Texture2D = preload("res://assets/tiny_swords/decorations/grass_growth.png")
const EATEN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/decorations/grass_eaten.png")

enum GrowthState {
	EATEN,
	SPROUT,
	GROWING,
	MATURE,
}

@export_range(5.0, 180.0, 5.0) var growth_stage_seconds := 30.0
@export_range(0.1, 3.0, 0.05) var min_sway_pause := 0.35
@export_range(0.1, 3.0, 0.05) var max_sway_pause := 2.2

var growth_state := GrowthState.MATURE
var growth_time := 0.0
var sway_time := 0.0
var reserved_by: Node = null
var eating_by: Node = null
var eating_time := 0.0
var eating_duration := 1.0
var base_scale := Vector2.ONE
var random := RandomNumberGenerator.new()


func _ready() -> void:
	random.seed = Time.get_ticks_usec() + get_instance_id() * 7919
	base_scale = scale
	_build_animations()
	add_to_group(&"grass")
	animation_finished.connect(_on_animation_finished)
	_apply_growth_visual()


func _process(delta: float) -> void:
	if is_instance_valid(eating_by):
		eating_time = minf(eating_duration, eating_time + delta)
		animation = &"eaten"
		frame = mini(
			sprite_frames.get_frame_count(&"eaten") - 1,
			floori(eating_time / eating_duration * sprite_frames.get_frame_count(&"eaten"))
		)
		return

	if growth_state != GrowthState.MATURE:
		growth_time += delta
		if growth_time >= growth_stage_seconds:
			growth_time -= growth_stage_seconds
			growth_state += 1
			_apply_growth_visual()
		return

	if not is_playing():
		sway_time -= delta
		if sway_time <= 0.0:
			speed_scale = random.randf_range(0.65, 1.25)
			play(&"sway")


func is_mature() -> bool:
	return growth_state == GrowthState.MATURE


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"growth_state": growth_state,
		"growth_time": growth_time,
	}


func restore_save_data(data: Dictionary) -> void:
	reserved_by = null
	eating_by = null
	eating_time = 0.0
	growth_state = clampi(int(data.get("growth_state", GrowthState.MATURE)), GrowthState.EATEN, GrowthState.MATURE)
	growth_time = clampf(float(data.get("growth_time", 0.0)), 0.0, growth_stage_seconds)
	_apply_growth_visual()


func is_available_for(sheep: Node) -> bool:
	return is_mature() and (reserved_by == null or reserved_by == sheep)


func reserve(sheep: Node) -> bool:
	if not is_available_for(sheep):
		return false
	reserved_by = sheep
	return true


func release_reservation(sheep: Node) -> void:
	if reserved_by == sheep:
		reserved_by = null


func begin_eating(sheep: Node, duration: float) -> bool:
	if not is_mature() or reserved_by != sheep:
		return false
	eating_by = sheep
	eating_time = 0.0
	eating_duration = maxf(duration, 0.1)
	stop()
	animation = &"eaten"
	frame = 0
	return true


func finish_eating(sheep: Node) -> bool:
	if eating_by != sheep or reserved_by != sheep:
		return false
	eating_by = null
	reserved_by = null
	growth_state = GrowthState.EATEN
	growth_time = 0.0
	_apply_growth_visual()
	return true


func cancel_eating(sheep: Node) -> void:
	if eating_by == sheep:
		eating_by = null
	if reserved_by == sheep:
		reserved_by = null
	if growth_state == GrowthState.MATURE:
		_apply_growth_visual()


func is_being_eaten() -> bool:
	return is_instance_valid(eating_by)


func _apply_growth_visual() -> void:
	stop()
	frame = 0
	match growth_state:
		GrowthState.EATEN:
			scale = base_scale
			modulate = Color.WHITE
			animation = &"growth"
			frame = 0
		GrowthState.SPROUT:
			scale = base_scale
			modulate = Color.WHITE
			animation = &"growth"
			frame = 1
		GrowthState.GROWING:
			scale = base_scale
			modulate = Color.WHITE
			animation = &"growth"
			frame = 2
		GrowthState.MATURE:
			scale = base_scale
			modulate = Color.WHITE
			animation = &"sway"
			frame = 0
			sway_time = random.randf_range(min_sway_pause, max_sway_pause)


func _on_animation_finished() -> void:
	if growth_state == GrowthState.MATURE and not is_being_eaten():
		frame = 0
		sway_time = random.randf_range(min_sway_pause, max_sway_pause)


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"sway", SWAY_TEXTURE, 8, 7.0, false)
	_add_animation(frames, &"growth", GROWTH_TEXTURE, 4, 1.0, false)
	_add_animation(frames, &"eaten", EATEN_TEXTURE, 6, 8.0, false)
	sprite_frames = frames


func _add_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	texture: Texture2D,
	frame_count: int,
	fps: float,
	loop: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_index * 128, 0), FRAME_SIZE)
		frames.add_frame(animation_name, atlas)
