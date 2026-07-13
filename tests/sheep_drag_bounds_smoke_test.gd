extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var lamb: Node2D = scene.add_lamb()
	await process_frame
	if lamb.is_adult():
		_fail("Drag-boundary test did not create a lamb")
		return

	scene.dragged_sheep = lamb
	lamb.begin_drag()
	scene._move_dragged_sheep(Vector2(-5000, -5000))
	if not scene.is_point_on_land(lamb.global_position, 18.0):
		_fail("A dragged lamb escaped the owned land boundary")
		return

	if not scene.add_land_chunk(Vector2i.RIGHT):
		_fail("Drag-boundary test could not add adjacent land")
		return
	var expanded_center: Vector2 = scene.get_land_chunk_center(Vector2i.RIGHT)
	scene._move_dragged_sheep(expanded_center)
	if not lamb.global_position.is_equal_approx(expanded_center):
		_fail("A dragged lamb could not enter expanded owned land")
		return

	lamb.global_position = Vector2(5000, 5000)
	scene._drop_sheep()
	if not scene.is_point_on_land(lamb.global_position, 18.0):
		_fail("Dropping a lamb outside did not perform the final boundary check")
		return

	print("PASS: dragged lambs stay on owned land and can enter expanded chunks")
	quit(0)


func _fail(message: String) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	push_error(message)
	quit(1)
