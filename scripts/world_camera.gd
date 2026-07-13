extends Camera2D

@export_range(0.35, 1.0, 0.05) var min_zoom := 0.55
@export_range(1.0, 3.0, 0.05) var max_zoom := 1.8
@export_range(0.05, 0.3, 0.01) var zoom_step := 0.12

const LEFT_PAN_THRESHOLD_SQUARED := 8.0 * 8.0
const SHEEP_PICK_RADIUS_SQUARED := 38.0 * 38.0

var is_panning := false
var pan_button := 0
var left_pan_candidate := false
var left_pan_start := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_cursor(1.0 + zoom_step, event.position)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_cursor(1.0 / (1.0 + zoom_step), event.position)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_set_panning(event.pressed, MOUSE_BUTTON_MIDDLE)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _can_start_left_pan(event.position):
					left_pan_candidate = true
					left_pan_start = event.position
			elif left_pan_candidate:
				var was_panning := is_panning and pan_button == MOUSE_BUTTON_LEFT
				left_pan_candidate = false
				if was_panning:
					_set_panning(false, MOUSE_BUTTON_LEFT)
					get_viewport().set_input_as_handled()
			return
	if (
		event is InputEventMouseMotion
		and left_pan_candidate
		and not is_panning
		and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		and event.position.distance_squared_to(left_pan_start) >= LEFT_PAN_THRESHOLD_SQUARED
	):
		_set_panning(true, MOUSE_BUTTON_LEFT)
	if event is InputEventMouseMotion and is_panning:
		if pan_button == MOUSE_BUTTON_LEFT and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			left_pan_candidate = false
			_set_panning(false, MOUSE_BUTTON_LEFT)
			return
		position -= event.relative / zoom.x
		get_viewport().set_input_as_handled()


func _can_start_left_pan(screen_position: Vector2) -> bool:
	var world_controller := get_parent()
	if world_controller.build_controller.is_build_mode_active():
		return false
	if world_controller.dog_command_bar.is_target_pending():
		return false
	if world_controller.is_player_selected():
		return false
	var world_position := get_canvas_transform().affine_inverse() * screen_position
	for sheep in world_controller.sheep_group.get_children():
		if sheep.global_position.distance_squared_to(world_position) <= SHEEP_PICK_RADIUS_SQUARED:
			return false
	return true


func _set_panning(active: bool, button: int) -> void:
	is_panning = active
	pan_button = button if active else 0
	Input.set_default_cursor_shape(Input.CURSOR_DRAG if active else Input.CURSOR_ARROW)


func set_zoom_level(value: float) -> void:
	var clamped := clampf(value, min_zoom, max_zoom)
	zoom = Vector2.ONE * clamped


func focus_on_world_position(world_position: Vector2) -> void:
	position = world_position


func _zoom_at_cursor(multiplier: float, mouse_position: Vector2) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(old_zoom * multiplier, min_zoom, max_zoom)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var viewport_center := get_viewport_rect().size * 0.5
	var screen_offset := mouse_position - viewport_center
	position += screen_offset / old_zoom - screen_offset / new_zoom
	set_zoom_level(new_zoom)
