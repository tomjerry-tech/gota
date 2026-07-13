extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var controller: Node = scene.get_node("BuildController")
	var sheep: AnimatedSprite2D = scene.get_node("Island/Sheep").get_child(0)
	if not sheep._can_move_to(Vector2(728, 247)):
		_fail("A decorative bush incorrectly blocks movement")
		return
	if not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD):
		_fail("Could not add clear land for avoidance test")
		return
	if not controller.try_place_building(&"lamb_shelter", Vector2(1024, 350)):
		_fail("Could not place a large building for avoidance test")
		return
	await physics_frame
	if sheep._can_move_to(Vector2(1024, 350)):
		_fail("Placed buildings no longer block sheep")
		return

	sheep.global_position = Vector2(920, 350)
	sheep.state = sheep.State.WANDER
	sheep.target_position = Vector2(1130, 350)
	sheep.walk_speed = 32.0
	sheep._clear_obstacle_avoidance()
	for step in 500:
		sheep._move_toward_target(0.1)
		if sheep.global_position.x >= 1110.0:
			break
	if sheep.global_position.x < 1110.0:
		_fail("Sheep remained stuck instead of walking around a large building")
		return

	sheep.global_position = Vector2(1024, 350)
	sheep.state = sheep.State.DRAGGED
	sheep.end_drag()
	if not sheep._can_move_to(sheep.global_position):
		_fail("A sheep dropped inside an obstacle did not recover to nearby free ground")
		return

	print("PASS: sheep ignore bushes, route around buildings, and recover from overlap")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
