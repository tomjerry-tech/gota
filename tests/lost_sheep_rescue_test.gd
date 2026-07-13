extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var hud: Control = scene.get_node("HUD/TopHUD")
	var routine: Node = scene.get_node("DayRoutineManager")
	var rescue: Node = scene.get_node("LostSheepManager")
	var story: Node = scene.get_node("StoryEventManager")
	var guide: Control = scene.get_node("HUD/DailyGuidePanel")
	var controller: Node = scene.get_node("BuildController")
	var player: AnimatedSprite2D = scene.get_node("Island/Shepherd")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.fired_events.clear()
	story.current_event = {}

	if (
		not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
		or not scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD)
	):
		_fail("Could not prepare land for the lost-sheep event")
		return
	hud.restore_save_data({"money": 20000, "day": 12, "day_progress": 0.90})
	routine._try_discover_wolf_den()
	var sellable_before: int = scene.get_sellable_adult_count()
	var breach: Dictionary = routine.evaluate_wolf_night_risk(12)
	if (
		breach.get("outcome", "") != "breach"
		or not rescue.has_active_rescue()
		or rescue.get_remaining_count() != 2
		or not story.is_event_fired(&"lost_sheep_rescue")
		or scene.get_sellable_adult_count() != sellable_before - 2
	):
		_fail("Wolf breach did not start a two-sheep rescue or protect them from sale")
		return
	if not guide.locate_button.visible or "走失小羊" not in guide.title_label.text:
		_fail("Daily guide did not expose the active rescue and locate command")
		return
	for sheep_id in rescue.lost_sheep_ids:
		var lost_sheep: Node = rescue._find_sheep(sheep_id)
		if not lost_sheep or not lost_sheep.is_lost() or not lost_sheep.lost_icon.visible:
			_fail("Lost sheep did not show its persistent world marker")
			return

	var first_lost: Node = rescue.get_next_lost_sheep()
	if not rescue.locate_next_lost_sheep() or scene.get_selected_entity() != first_lost:
		_fail("Locate command did not focus and select the next lost sheep")
		return
	player.global_position = first_lost.global_position
	rescue._check_rescue_progress()
	if rescue.get_remaining_count() != 1 or rescue.rescued_count != 1:
		_fail("Approaching a lost sheep did not rescue exactly one target")
		return

	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Could not prepare a closed rescue enclosure")
		return
	var fence: Node2D = controller.get_fence_roots()[0]
	var second_lost: Node = rescue.get_next_lost_sheep()
	second_lost.global_position = (fence.get_meta("grazing_rect") as Rect2).get_center()
	var money_before_reward: int = hud.get_money()
	rescue._check_rescue_progress()
	if (
		rescue.has_active_rescue()
		or rescue.last_reward != 300
		or hud.get_money() != money_before_reward + 300
		or not story.is_event_fired(&"lost_sheep_rescued")
		or guide.locate_button.visible
	):
		_fail("Closed-fence rescue did not complete the mission and pay its one-time reward")
		return
	var money_after_reward: int = hud.get_money()
	rescue._check_rescue_progress()
	if hud.get_money() != money_after_reward:
		_fail("Completed rescue paid its reward more than once")
		return

	var repeat_targets: Array[Node] = [scene.sheep_group.get_child(0), scene.sheep_group.get_child(1)]
	for index in repeat_targets.size():
		repeat_targets[index].global_position = Vector2(980 + index * 48, 430)
	if rescue.start_rescue(repeat_targets, 13) != 2:
		_fail("Could not prepare a mid-rescue save state")
		return
	var save_data: Dictionary = scene.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Active rescue could not be restored")
		return
	var restored_rescue: Node = restored.get_node("LostSheepManager")
	if not restored_rescue.has_active_rescue() or restored_rescue.get_remaining_count() != 2:
		_fail("Lost sheep IDs or mission state did not survive save restore")
		return
	for sheep_id in restored_rescue.lost_sheep_ids:
		if not restored_rescue._find_sheep(sheep_id).is_lost():
			_fail("Restored rescue did not reapply lost markers")
			return
	var restored_hud: Control = restored.get_node("HUD/TopHUD")
	var money_before_failure: int = restored_hud.get_money()
	restored_rescue._on_day_changed(restored_rescue.deadline_day + 1)
	if (
		restored_rescue.has_active_rescue()
		or restored_rescue.last_failed_count != 2
		or restored_hud.get_money() != money_before_failure
		or not restored.get_node("StoryEventManager").is_event_fired(&"lost_sheep_missed")
	):
		_fail("Expired rescue did not return sheep without reward and queue its outcome story")
		return
	for sheep in restored.sheep_group.get_children():
		if sheep.is_lost():
			_fail("Expired rescue left a sheep permanently marked as lost")
			return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: wolf-triggered lost sheep, markers, locate, rescue, reward, expiry, sale lock, story, and save")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
