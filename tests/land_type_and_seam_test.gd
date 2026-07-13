extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var controller: Node = scene.get_node("BuildController")
	var hud: Control = scene.get_node("HUD/TopHUD")
	var decorations: Node = scene.get_node("Island/Decorations")
	var colliders: Node = scene.get_node("Island/PhysicsColliders")
	var initial_grass := get_nodes_in_group(&"grass").size()
	var initial_decorations := decorations.get_child_count()
	var initial_colliders := colliders.get_child_count()

	for blocked_position in [Vector2(610, 210), Vector2(536, 365), Vector2(732, 410), Vector2(728, 247)]:
		if controller.try_place_building(&"dog_house", blocked_position):
			_fail("A building was placed over grass or a natural object")
			return
	if hud.get_money() != 20000:
		_fail("Rejected natural-object placement changed the money balance")
		return

	controller.select_build_item(&"land_expand", {
		"display_name": "土地扩充",
		"price": 450,
		"land_type": scene.LAND_TYPE_HOMESTEAD,
	})
	if not controller.try_expand_land_at(Vector2(1024, 350)):
		_fail("Homestead land could not be expanded")
		return
	if scene.get_land_type(Vector2i.RIGHT) != scene.LAND_TYPE_HOMESTEAD:
		_fail("Expanded land did not retain its selected homestead type")
		return
	if get_nodes_in_group(&"grass").size() != initial_grass:
		_fail("Homestead land incorrectly generated edible grass")
		return
	if decorations.get_child_count() != initial_decorations or colliders.get_child_count() != initial_colliders:
		_fail("Homestead land incorrectly generated natural decorations or colliders")
		return
	if scene.get_sheep_capacity() != 20 or hud.get_money() != 19550:
		_fail("Homestead land did not add capacity or deduct the expansion price")
		return
	if not controller.try_place_building(&"dog_house", Vector2(1024, 350)):
		_fail("A building could not be placed on clear homestead land")
		return

	if not scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_PASTURE):
		_fail("Pasture setup chunk could not be added")
		return
	if not scene.add_land_chunk(Vector2i(1, 1), scene.LAND_TYPE_HOMESTEAD):
		_fail("Fourth junction chunk could not be added")
		return
	if get_nodes_in_group(&"grass").size() != initial_grass + scene.GRASS_PER_LAND_CHUNK:
		_fail("Pasture and homestead chunks generated the wrong grass total")
		return
	if scene.get_pasture_land_count() != 2:
		_fail("Pasture land count is incorrect")
		return
	var junctions: Node2D = scene.get_node("Island/LandJunctions")
	if junctions.get_child_count() != 1:
		_fail("Four connected chunks did not create one seam junction patch")
		return
	var junction: Sprite2D = junctions.get_child(0)
	var expected_junction: Vector2 = (
		scene.get_land_chunk_center(Vector2i.ZERO)
		+ scene.get_land_chunk_center(Vector2i(1, 1))
	) * 0.5
	if not junction.position.is_equal_approx(expected_junction) or junction.texture == null:
		_fail("Seam junction patch is missing or positioned incorrectly")
		return

	print("PASS: natural build blocking, selectable land types, clear homestead, and seam junction fill")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
