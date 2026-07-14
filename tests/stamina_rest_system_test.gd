extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var player: AnimatedSprite2D = scene.get_node("Island/Shepherd")
	var controller: Node = scene.get_node("BuildController")
	var dogs: Node = scene.get_node("DogManager")
	var routine: Node = scene.get_node("DayRoutineManager")
	var story: Node = scene.get_node("StoryEventManager")
	var help_menu: Control = scene.get_node("HUD/HelpMenu")
	story.automatic_presentation_enabled = false
	story.event_queue.clear()
	story.fired_events.clear()
	story.current_event = {}

	if player.get_stamina_percent() != 100 or not is_equal_approx(player.get_work_efficiency(), 1.0):
		_fail("Shepherd did not start with full stamina")
		return
	player.consume_stamina(76.0)
	if (
		player.get_stamina_percent() != 24
		or player.get_work_efficiency() >= 1.0
		or not story.is_event_fired(&"first_low_stamina")
	):
		_fail("Low shepherd stamina did not reduce efficiency or queue its story")
		return
	if story.queue_event(&"first_low_stamina"):
		_fail("Low-stamina story could be queued more than once")
		return
	scene.select_entity(player)
	if scene.get_node_or_null("HUD/ContextInfoPanel") != null or "体力" not in String(help_menu.TOPICS[2].body):
		_fail("Permanent context strip was not replaced by shepherd help")
		return
	player.wake_up()
	if player.get_stamina_percent() != 49:
		_fail("Shepherd without indoor rest did not recover exactly 25 stamina at dawn")
		return
	player.consume_stamina(29.0)
	player.rest_target = player.global_position
	player.resting = true
	player.wake_up()
	if player.get_stamina_percent() != 100:
		_fail("Shepherd who slept indoors did not recover full stamina")
		return
	var stamina_before_move: float = float(player.stamina)
	var moved: bool = player.move_character(Vector2.RIGHT, 0.1)
	if not moved:
		moved = player.move_character(Vector2.LEFT, 0.1)
	if not moved or player.stamina >= stamina_before_move:
		_fail("Shepherd movement did not consume stamina")
		return

	if not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD):
		_fail("Could not prepare clear land for a dog house")
		return
	if not controller.try_place_building(&"dog_house", Vector2(960, 300)):
		_fail("Could not place a dog house for stamina testing")
		return
	dogs.sync_dogs()
	var dog: AnimatedSprite2D = dogs.get_dogs()[0]
	story.event_queue.clear()
	story.fired_events.clear()
	dog.consume_stamina(76.0)
	if (
		dog.get_stamina_percent() != 24
		or dog.get_night_defense_points() != 4
		or not story.is_event_fired(&"first_low_stamina")
	):
		_fail("Dog stamina did not affect defense or propagate the low-stamina story")
		return
	scene.select_entity(dog)
	var command_bar: Control = scene.get_node("HUD/DogCommandBar")
	command_bar._update_action_buttons()
	if "24%" not in command_bar.title_label.text or "牧羊犬" not in String(help_menu.TOPICS[3].body):
		_fail("Selected dog command bar did not show stamina or dog help is missing")
		return
	var tired_preview: Dictionary = routine.get_wolf_defense_preview()
	if int(tired_preview.get("dog_score", -1)) != 4:
		_fail("Tired dog did not contribute four wolf-defense points")
		return
	dog.wake_up()
	if dog.get_stamina_percent() != 49:
		_fail("Dog without kennel rest did not recover exactly 25 stamina at dawn")
		return
	dog.consume_stamina(29.0)
	dog.rest_target = dog.global_position
	dog.resting = true
	dog.wake_up()
	if dog.get_stamina_percent() != 100 or dog.get_night_defense_points() != 10:
		_fail("Dog who slept in its kennel did not recover full stamina and defense")
		return

	player.consume_stamina(67.0)
	dog.consume_stamina(56.0)
	var save_data: Dictionary = scene.get_save_data()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Stamina save data could not be restored")
		return
	var restored_player: AnimatedSprite2D = restored.get_node("Island/Shepherd")
	var restored_dogs: Node = restored.get_node("DogManager")
	var restored_dog: AnimatedSprite2D = restored_dogs.get_dogs()[0]
	if restored_player.get_stamina_percent() != 33 or restored_dog.get_stamina_percent() != 44:
		_fail("Shepherd or dog stamina did not survive save restore")
		return
	if not restored.get_node("StoryEventManager").is_event_fired(&"first_low_stamina"):
		_fail("Low-stamina story state did not survive save restore")
		return
	var event_data: Dictionary = story._build_event_data(&"first_low_stamina")
	if "体力" not in event_data.body or event_data.actions.size() != 2:
		_fail("Low-stamina story does not explain rest or provide its actions")
		return

	Engine.time_scale = 1.0
	paused = false
	print("PASS: stamina drain, efficiency, indoor rest, dog defense, help UI, story, and save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
