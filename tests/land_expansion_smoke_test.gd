extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var controller: Node2D = scene.get_node("BuildController")
	var hud: Control = scene.get_node("HUD/TopHUD")
	var camera: Camera2D = scene.get_node("WorldCamera")
	var initial_grass_count := get_nodes_in_group(&"grass").size()
	var initial_collider_count := scene.get_node("Island/PhysicsColliders").get_child_count()

	if scene.get_land_chunk_count() != 1:
		_fail("Land system did not register the initial chunk")
		return
	var initial_candidates: Array[Vector2i] = scene.get_expansion_candidates()
	if initial_candidates.size() != 4:
		_fail("Initial land does not expose all four expansion directions")
		return
	for expected in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not initial_candidates.has(expected):
			_fail("Missing a selectable land expansion direction")
			return
	if scene.get_expansion_candidate(Vector2(640, -34)) != Vector2i(0, -1):
		_fail("Upward land expansion direction was not selectable")
		return
	if scene.get_expansion_candidate(Vector2(1024, 350)) != Vector2i(1, 0):
		_fail("Right-side expansion candidate was not detected")
		return
	controller.select_build_item(&"land_expand", {"display_name": "土地扩充", "price": 450})
	if not controller.try_expand_land_at(Vector2(1024, 350)):
		_fail("Valid adjacent land chunk could not be expanded")
		return
	await process_frame
	if scene.get_land_chunk_count() != 2 or hud.get_money() != 19550:
		_fail("Expansion did not add one chunk and deduct 450 coins")
		return
	if get_nodes_in_group(&"grass").size() != initial_grass_count + scene.GRASS_PER_LAND_CHUNK:
		_fail("Expanded chunk did not add the fixed grass amount")
		return
	if scene.get_node("Island/PhysicsColliders").get_child_count() != initial_collider_count + 3:
		_fail("Expanded chunk decoration colliders are incomplete")
		return
	if scene.get_node("Island/LandBridges").get_child_count() != 1:
		_fail("Adjacent chunks did not receive a grass connection strip")
		return
	if scene.get_node_or_null("HUD/CameraHint") != null:
		_fail("Removed camera instruction text is still visible")
		return
	if scene.get_node("Water").color.a != 0.0:
		_fail("Finite water rectangle is still visible")
		return
	if scene.get_node("InfiniteClouds").get_child_count() == 0:
		_fail("Infinite cloud field did not generate scattered clouds")
		return
	if not scene.is_point_on_land(Vector2(1024, 350), 18.0):
		_fail("Expanded chunk was not added to the walkable land mask")
		return
	if not scene.add_land_chunk(Vector2i(2, 0)) or scene.get_land_chunk_count() != 3:
		_fail("Land chunks cannot continue expanding outward")
		return
	if get_nodes_in_group(&"grass").size() != scene.GRASS_PER_LAND_CHUNK * 3:
		_fail("Each additional land chunk does not provide the same grass amount")
		return

	camera.set_zoom_level(0.1)
	if not is_equal_approx(camera.zoom.x, camera.min_zoom):
		_fail("Camera zoom did not respect the minimum zoom")
		return
	camera.set_zoom_level(5.0)
	if not is_equal_approx(camera.zoom.x, camera.max_zoom):
		_fail("Camera zoom did not respect the maximum zoom")
		return

	print("PASS: adjacent same-size land chunks, generated contents, infinite grid, pan-ready camera, and bounded zoom")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
