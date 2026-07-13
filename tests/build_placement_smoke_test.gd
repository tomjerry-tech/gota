extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var controller: Node2D = scene.get_node("BuildController")
	var buildings: Node2D = scene.get_node("Island/Buildings")
	var hud: Control = scene.get_node("HUD/TopHUD")

	if scene.has_node("Island/Pen"):
		_fail("Old pen was not removed from the scene")
		return
	if controller.is_build_mode_active():
		_fail("Build mode should stay inactive until a card is clicked")
		return
	controller.select_build_item(&"fence", {"display_name": "木围栏", "price": 8})
	if not controller.is_build_mode_active() or controller.selected_item_id != &"fence":
		_fail("Fence selection did not activate fence build mode")
		return
	scene.get_node("HUD/BottomToolbar").select_tab(&"sheep")
	if controller.is_build_mode_active():
		_fail("Switching away from the build tab did not cancel build mode")
		return
	controller.select_build_item(&"fence", {"display_name": "木围栏", "price": 8})
	if controller.get_fence_cost(Vector2(520, 230), Vector2(600, 310)) != 64:
		_fail("Fence cost is not based on the four rectangle sides")
		return
	var grass_inside_rect := Rect2(600, 310, 40, 80)
	if controller._fence_crosses_natural_obstacle(controller._fence_footprints(grass_inside_rect)):
		_fail("Natural objects inside a fence area incorrectly block the fence")
		return
	var grass_crossing_rect := Rect2(600, 350, 40, 80)
	if not controller._fence_crosses_natural_obstacle(controller._fence_footprints(grass_crossing_rect)):
		_fail("Fence segment was allowed to cross a natural object")
		return
	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Valid rectangular fence could not be placed")
		return
	if hud.get_money() != 19936 or buildings.get_child_count() != 1:
		_fail("Fence placement did not deduct 64 coins and create one fence root")
		return
	if buildings.get_child(0).get_child_count() <= 4:
		_fail("Fence placement did not create collision bodies")
		return
	if controller.try_place_building(&"dog_house", Vector2(560, 270)):
		_fail("Building was allowed to overlap the placed fence")
		return
	if not controller.try_place_building(&"dog_house", Vector2(720, 480)):
		_fail("Valid dog house could not be placed")
		return
	if hud.get_money() != 19756 or buildings.get_child_count() != 2:
		_fail("Dog house placement did not deduct coins or create the building")
		return
	if buildings.get_child(1).get_node_or_null("Collision") == null:
		_fail("Dog house placement did not create a collision body")
		return
	if controller.try_place_building(&"lamb_shelter", Vector2(820, 230)):
		_fail("Building was allowed outside the grass build area")
		return
	if not hud.spend_money(hud.get_money() - 256):
		_fail("Test setup could not reduce money before insufficient-money check")
		return
	if not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD):
		_fail("Test setup could not add clear homestead land")
		return
	if controller.try_place_building(&"shepherd_house", Vector2(1024, 350)):
		_fail("Building was placed even though there was not enough money")
		return
	if hud.get_money() != 256:
		_fail("Failed building placement changed the money total")
		return

	print("PASS: old pen removed; fence and three building types use placement validation and money")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
