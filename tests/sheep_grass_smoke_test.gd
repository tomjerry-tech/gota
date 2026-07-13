extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await physics_frame
	var sheep_group: Node2D = scene.get_node("Island/Sheep")
	var grasses := get_nodes_in_group(&"grass")
	var first_sheep := sheep_group.get_child(0) as AnimatedSprite2D
	if scene.get_node_or_null("Island/PhysicsColliders") == null:
		_fail("World entities do not have a physics collider layer")
		return
	if first_sheep._can_move_to(Vector2(536, 393)):
		_fail("Sheep can walk through the tree trunk")
		return
	if first_sheep._can_move_to(Vector2(732, 410)):
		_fail("Sheep can walk through the rock")
		return
	if not first_sheep._can_move_to(Vector2(728, 247)):
		_fail("Decorative bushes still block sheep movement")
		return
	if not first_sheep._can_move_to(grasses[0].global_position):
		_fail("Edible grass still blocks sheep movement")
		return
	if not first_sheep._can_move_to(Vector2(650, 330)):
		_fail("Sheep collision query rejects an open grassland position")
		return
	var original_position := first_sheep.global_position
	first_sheep.global_position = Vector2(488, 393)
	first_sheep.state = first_sheep.State.WANDER
	first_sheep.target_position = Vector2(600, 393)
	first_sheep._move_toward_target(0.1)
	var chosen_avoidance: Vector2 = first_sheep.avoidance_direction
	if chosen_avoidance == Vector2.ZERO or chosen_avoidance.y <= 0.0:
		_fail("Sheep did not choose the stable downward-preferred detour")
		return
	for step in 3:
		first_sheep._move_toward_target(0.1)
		if first_sheep.avoidance_direction != chosen_avoidance:
			_fail("Sheep alternated avoidance direction and would shake its head")
			return
	first_sheep.global_position = original_position
	first_sheep._enter_idle()
	var required_sheep_animations := {
		&"run": 8,
		&"eat_enter": 5,
		&"eat_loop": 7,
		&"lie_down": 6,
		&"rest": 6,
		&"walk_up": 4,
		&"walk_down": 4,
		&"walk_diag_up": 4,
		&"walk_diag_down": 4,
	}
	for animation_name in required_sheep_animations:
		if not first_sheep.sprite_frames.has_animation(animation_name):
			_fail("Missing sheep animation: %s" % animation_name)
			return
		if first_sheep.sprite_frames.get_frame_count(animation_name) != required_sheep_animations[animation_name]:
			_fail("Incorrect frame count for sheep animation: %s" % animation_name)
			return
	if first_sheep.sprite_frames.get_animation_loop(&"eat_enter"):
		_fail("Eat enter animation must lower the head only once")
		return
	if not first_sheep.sprite_frames.get_animation_loop(&"eat_loop"):
		_fail("Low-head chewing animation must loop")
		return
	if first_sheep.min_seconds_to_full_hunger != 120.0 or first_sheep.max_seconds_to_full_hunger != 180.0:
		_fail("Sheep hunger timing is not using the slower defaults")
		return
	if first_sheep.min_eat_seconds != 8.0 or first_sheep.max_eat_seconds != 12.0:
		_fail("Sheep eating duration is not using the slower defaults")
		return
	if first_sheep.min_idle_seconds != 4.0 or first_sheep.max_idle_seconds != 8.0:
		_fail("Sheep idle timing is incorrect")
		return
	if first_sheep.min_rest_seconds != 12.0 or first_sheep.max_rest_seconds != 22.0:
		_fail("Sheep rest timing is incorrect")
		return

	var first_grass := grasses[0] as AnimatedSprite2D
	if first_grass.sprite_frames.get_frame_count(&"growth") != 4:
		_fail("Grass growth animation does not have four stages")
		return
	if first_grass.sprite_frames.get_frame_count(&"eaten") != 6:
		_fail("Grass eaten animation does not have six frames")
		return
	if first_grass.growth_stage_seconds != 30.0:
		_fail("Grass is not using the slower growth timing")
		return

	if grasses.size() != scene.GRASS_PER_LAND_CHUNK * scene.get_land_chunk_count():
		_fail("Grass count is not fixed per owned land chunk")
		return

	var expected_nearest: Node = null
	var nearest_distance := INF
	for grass in grasses:
		var distance := first_sheep.global_position.distance_squared_to(grass.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			expected_nearest = grass
	for sheep in sheep_group.get_children():
		sheep.hunger = 0.0
		sheep.hunger_rate = 0.0
		sheep.state_time = 100.0
	first_sheep.walk_speed = 1000.0
	first_sheep.hunger = 100.0
	first_sheep.state_time = 0.0
	await create_timer(0.08).timeout
	if first_sheep.target_grass != expected_nearest:
		_fail("Sheep did not reserve its nearest available mature grass")
		return
	first_sheep.begin_drag()
	first_sheep.end_drag()

	for grass in grasses:
		grass.growth_stage_seconds = 0.05
	for sheep in sheep_group.get_children():
		sheep.walk_speed = 1000.0
		sheep.min_eat_seconds = 1.0
		sheep.max_eat_seconds = 1.0
		sheep.hunger = 100.0
		sheep.hunger_rate = 0.0
		sheep.state_time = 0.0

	await create_timer(0.08).timeout
	var reserved_grasses := grasses.filter(
		func(grass: Node) -> bool: return is_instance_valid(grass.reserved_by)
	)
	if reserved_grasses.size() < 2:
		_fail("Multiple sheep did not reserve different grass plants")
		return

	for grass in reserved_grasses:
		grass.reserved_by.global_position = grass.reserved_by.target_position
	await create_timer(0.05).timeout
	for grass in reserved_grasses:
		if not grass.is_being_eaten():
			_fail("Reserved grass did not begin changing while the sheep ate it")
			return
		var sheep: AnimatedSprite2D = grass.eating_by
		if sheep.global_position.distance_to(grass.global_position) < sheep.eating_distance - 1.0:
			_fail("Sheep stood on top of the grass instead of beside it")
			return
		if sheep.flip_h != (not sheep.eat_from_left):
			_fail("Eating sheep is not facing its grass")
			return
	await create_timer(0.2).timeout
	if reserved_grasses.any(func(grass: Node) -> bool: return grass.frame <= 0):
		_fail("Grass did not visibly shorten during eating")
		return
	for grass in reserved_grasses:
		if is_instance_valid(grass.reserved_by):
			grass.reserved_by.state_time = 0.01
	await create_timer(0.08).timeout

	var eaten_grasses := grasses.filter(
		func(grass: Node) -> bool: return not grass.is_mature()
	)
	if eaten_grasses.size() < 2:
		_fail("Multiple sheep did not eat concurrently")
		return

	await create_timer(0.2).timeout
	if eaten_grasses.any(func(grass: Node) -> bool: return not grass.is_mature()):
		_fail("Eaten grass did not regrow through all stages")
		return

	print("PASS: nearest grass targeting, facing, synchronized eating, and regrowth")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
