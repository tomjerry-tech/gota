extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var hud: Control = scene.get_node("HUD/TopHUD")
	var controller: Node = scene.get_node("BuildController")
	var dogs: Node = scene.get_node("DogManager")
	var routine: Node = scene.get_node("DayRoutineManager")
	var wolf_manager: Node = scene.get_node("WolfManager")
	var lost_manager: Node = scene.get_node("LostSheepManager")
	var command_bar: Control = scene.get_node("HUD/DogCommandBar")
	var player: AnimatedSprite2D = scene.get_node("Island/Shepherd")
	var story: Node = scene.get_node("StoryEventManager")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.current_event = {}

	if scene.get_node_or_null("HUD/ContextInfoPanel") != null:
		_fail("The permanent bottom context strip still exists")
		return
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")
	toolbar.select_tab(&"help")
	if not scene.get_node("HUD/HelpMenu").visible or toolbar.buttons.size() != 4:
		_fail("The fourth help tool did not open the gameplay handbook")
		return

	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Could not prepare an enclosure for four-gate testing")
		return
	var fence: Node2D = controller.get_fence_roots()[0]
	var gates: Array[Node2D] = controller.get_fence_gates(fence)
	if gates.size() != 4:
		_fail("Enclosure did not create top, bottom, left, and right gates")
		return
	controller.set_specific_gate_open(fence, gates[2], true)
	if controller.get_fence_gate_states(fence) != [false, false, true, false]:
		_fail("A specific fence gate could not be opened independently")
		return
	var fence_save: Array[Dictionary] = controller.get_save_data()
	controller.restore_save_data(fence_save)
	fence = controller.get_fence_roots()[0]
	if controller.get_fence_gate_states(fence) != [false, false, true, false]:
		_fail("Four independent gate states did not survive restore")
		return
	controller.set_gate_open(fence, false)

	if (
		not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
		or not scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD)
	):
		_fail("Could not prepare clear building land")
		return
	hud.restore_save_data({"money": 20000, "day": 11, "day_progress": 0.55})
	if (
		not controller.try_place_building(&"dog_house", Vector2(980, 280))
		or not controller.try_place_building(&"dog_house", Vector2(1120, 430))
	):
		_fail("Could not build two dog houses in the second ten-day cycle")
		return
	if dogs.get_active_dog_count() != 2:
		_fail("The second dog house did not immediately create a second dog")
		return
	var active_dogs: Array[AnimatedSprite2D] = dogs.get_dogs()
	if (
		not active_dogs[0].visible or not active_dogs[1].visible
		or active_dogs[0].global_position.distance_to(active_dogs[1].global_position) < 40.0
		or active_dogs[0].scale.x < 1.2 or player.scale.x < 1.15
	):
		_fail("Dogs were hidden, stacked under houses, or character visuals stayed too small")
		return

	if not controller.try_place_building(&"shepherd_house", Vector2(640, 700)):
		_fail("Could not build a shepherd house for reachable rest testing")
		return
	var shepherd_house: Node2D = controller.get_buildings_by_type(&"shepherd_house")[0]
	var entrance: Vector2 = controller.get_building_entrance_position(shepherd_house)
	var house_footprint: Rect2 = shepherd_house.get_meta("footprints")[0]
	if house_footprint.has_point(entrance):
		_fail("Building entrance was still inside the building collision")
		return
	hud.restore_save_data({"money": hud.get_money(), "day": 12, "day_progress": 0.90})
	var rest_result: Dictionary = routine.assign_building_rest(shepherd_house)
	if not bool(rest_result.get("success", false)) or player.rest_target.distance_to(entrance) > 0.1:
		_fail("Shepherd rest did not use the shared reachable entrance")
		return
	for step in 500:
		player._physics_process(0.05)
		if player.resting:
			break
	if not player.resting or player.visible:
		_fail("Shepherd could not reach and enter the house at night")
		return
	player.wake_up()

	var grazing_rect: Rect2 = fence.get_meta("grazing_rect")
	for index in scene.sheep_group.get_child_count():
		scene.sheep_group.get_child(index).global_position = grazing_rect.get_center() + Vector2((index % 3 - 1) * 10, floori(float(index) / 3.0) * 12)
	scene.select_entity(active_dogs[1])
	command_bar._update_action_buttons()
	if command_bar.roundup_button.disabled or not command_bar.request_roundup():
		_fail("Selected dog did not expose a usable night roundup command")
		return
	if controller.get_fence_gate_states(fence).count(true) != 4:
		_fail("Night roundup did not open all four enclosure gates")
		return
	routine._update_manual_dog_roundup()
	if routine.is_manual_dog_roundup_active() or controller.get_fence_gate_states(fence).count(true) != 0:
		_fail("Completed night roundup did not close all gates")
		return

	routine._try_discover_wolf_den()
	if not routine.wolf_den_found:
		_fail("Day-12 three-land pasture did not discover the wolf den")
		return
	var secured_sheep: Node = scene.sheep_group.get_child(0)
	var exposed_sheep: Node = scene.sheep_group.get_child(1)
	for sheep in scene.sheep_group.get_children():
		sheep.global_position = grazing_rect.get_center()
	exposed_sheep.global_position = Vector2(1040, 520)
	controller.set_gate_open(fence, false)
	wolf_manager._sync_night_pack()
	var wolves: Array[AnimatedSprite2D] = wolf_manager.get_active_wolves()
	if wolves.is_empty():
		_fail("Discovered wolf den did not release visible wolves at night")
		return
	var target: Node = wolf_manager._find_nearest_target(wolves[0].global_position)
	if target != exposed_sheep or target == secured_sheep:
		_fail("Visible wolf targeted a sheep protected by a closed enclosure")
		return
	wolves[0].set_meta("target", exposed_sheep)
	wolves[0].global_position = exposed_sheep.global_position
	wolf_manager._update_wolf(wolves[0], 0.1)
	if not exposed_sheep.is_lost() or not lost_manager.has_active_rescue() or routine.visible_wolf_captured_ids.size() != 1:
		_fail("Wolf contact did not start the existing lost-sheep rescue flow")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: help UI, four gates, multi-dog visibility, reachable rest, night roundup, and visible wolf chase")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
