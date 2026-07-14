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
	var story: Node = scene.get_node("StoryEventManager")
	var command_bar: Control = scene.get_node("HUD/DogCommandBar")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.current_event = {}
	story.fired_events.clear()

	if (
		not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD)
		or not scene.add_land_chunk(Vector2i.DOWN, scene.LAND_TYPE_HOMESTEAD)
	):
		_fail("Could not prepare land for wolf patrol testing")
		return
	hud.restore_save_data({"money": 20000, "day": 12, "day_progress": 0.25})
	routine._try_discover_wolf_den()
	if (
		not routine.has_pending_wolf_tracks()
		or routine.wolf_tracks_day != 12
		or not is_instance_valid(routine.wolf_tracks_node)
		or not story.is_event_fired(&"fresh_wolf_tracks")
	):
		_fail("Wolf discovery did not create a visible daily trail or its story")
		return

	if not controller.try_place_building(&"dog_house", Vector2(960, 300)):
		_fail("Could not place a dog house for patrol testing")
		return
	dogs.sync_dogs()
	var dog: AnimatedSprite2D = dogs.get_dogs()[0]
	scene.select_entity(dog)
	command_bar._update_action_buttons()
	if command_bar.patrol_button.disabled or "巡查" not in command_bar.patrol_button.text:
		_fail("Selected dog did not expose the wolf-trail patrol action")
		return
	var defense_before: int = int(routine.get_wolf_defense_preview(12).score)
	var stamina_before: int = dog.get_stamina_percent()
	var request: Dictionary = routine.request_wolf_patrol(dog)
	if not bool(request.get("success", false)) or not routine.wolf_patrol_active:
		_fail("Dog could not start the available wolf patrol")
		return
	dog.global_position = routine.wolf_tracks_position
	routine._update_wolf_patrol()
	if (
		routine.has_pending_wolf_tracks()
		or routine.wolf_patrol_active
		or routine.wolf_patrol_bonus_day != 12
		or dog.get_stamina_percent() != stamina_before - routine.WOLF_PATROL_STAMINA_COST
		or int(routine.get_wolf_defense_preview(12).patrol_score) != routine.WOLF_PATROL_DEFENSE_BONUS
		or int(routine.get_wolf_defense_preview(12).score) != defense_before + routine.WOLF_PATROL_DEFENSE_BONUS
		or not story.is_event_fired(&"first_wolf_patrol")
	):
		_fail("Completed patrol did not consume stamina, clear tracks, add defense, or queue story")
		return
	var stamina_after: int = dog.get_stamina_percent()
	if bool(routine.request_wolf_patrol(dog).get("success", false)) or dog.get_stamina_percent() != stamina_after:
		_fail("Completed tracks could be patrolled and charged twice")
		return

	hud.restore_save_data({"money": hud.get_money(), "day": 13, "day_progress": 0.25})
	routine._prepare_daily_wolf_tracks(13)
	if not routine.has_pending_wolf_tracks() or not bool(routine.request_wolf_patrol(dog).get("success", false)):
		_fail("A new day did not provide one new patrol opportunity")
		return
	var save_data: Dictionary = scene.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Active wolf patrol save data could not be restored")
		return
	var restored_routine: Node = restored.get_node("DayRoutineManager")
	if (
		not restored_routine.has_pending_wolf_tracks()
		or not restored_routine.wolf_patrol_active
		or restored_routine.wolf_tracks_day != 13
		or not is_instance_valid(restored_routine.wolf_tracks_node)
		or not restored.get_node("StoryEventManager").is_event_fired(&"first_wolf_patrol")
	):
		_fail("Wolf tracks, active patrol, or story state did not survive save restore")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: daily wolf tracks, dog patrol, stamina cost, defense bonus, selected-dog action, story, and save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
