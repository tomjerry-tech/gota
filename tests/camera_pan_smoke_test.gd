extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var camera: Camera2D = scene.get_node("WorldCamera")
	var controller: Node = scene.get_node("BuildController")
	var initial_position := camera.position

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100, 100)
	camera._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(140, 120)
	motion.relative = Vector2(40, 20)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	camera._unhandled_input(motion)
	if not camera.is_panning or camera.pan_button != MOUSE_BUTTON_LEFT:
		_fail("Left-dragging empty world did not start camera panning")
		return
	var expected_position := initial_position - motion.relative / camera.zoom.x
	if not camera.position.is_equal_approx(expected_position):
		_fail("Left-drag camera movement did not account for current zoom")
		return
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	camera._unhandled_input(release)
	if camera.is_panning or camera.left_pan_candidate:
		_fail("Releasing left mouse did not stop camera panning")
		return

	var sheep: Node2D = scene.get_node("Island/Sheep").get_child(0)
	var sheep_screen_position := camera.get_canvas_transform() * sheep.global_position
	press.position = sheep_screen_position
	camera._unhandled_input(press)
	if camera.left_pan_candidate:
		_fail("Pressing a sheep incorrectly armed camera panning")
		return

	controller.select_build_item(&"fence", {"display_name": "木围栏", "price": 8})
	press.position = Vector2(100, 100)
	camera._unhandled_input(press)
	if camera.left_pan_candidate:
		_fail("Build mode incorrectly allowed left-drag camera panning")
		return

	print("PASS: left-drag empty-world panning preserves sheep dragging and build placement")
	quit(0)


func _fail(message: String) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	push_error(message)
	quit(1)
