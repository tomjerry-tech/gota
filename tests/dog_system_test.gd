extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var dog: AnimatedSprite2D = scene.get_node("Island/ShepherdDog")
	var player: AnimatedSprite2D = scene.get_node("Island/Shepherd")
	var sheep_group: Node = scene.get_node("Island/Sheep")
	var controller: Node = scene.get_node("BuildController")
	var command_bar: Control = scene.get_node("HUD/DogCommandBar")
	var roundup: Control = scene.get_node("HUD/RoundupStatus")
	var tasks: Node = scene.get_node("DailyTaskManager")
	var story: Node = scene.get_node("StoryEventManager")
	var hud: Control = scene.get_node("HUD/TopHUD")

	if dog.active or dog.visible or command_bar.visible:
		_fail("Shepherd dog was available before building a dog house")
		return
	if dog.sprite_frames.get_frame_count(&"run_side") != 6 or dog.sprite_frames.get_frame_count(&"run_up") != 4 or dog.sprite_frames.get_frame_count(&"guard") != 4:
		_fail("Shepherd dog animation strips were not packed with the expected frames")
		return
	if not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD):
		_fail("Could not add clear land for dog system test")
		return
	if not controller.try_place_building(&"dog_house", Vector2(1024, 350)):
		_fail("Could not build the dog house")
		return
	await process_frame
	await physics_frame
	if not dog.active or not dog.visible or command_bar.visible or command_bar.buttons.size() != 3:
		_fail("Dog house did not unlock one dog or the command bar was not selection-gated")
		return
	scene.select_entity(dog)
	if not command_bar.visible:
		_fail("Selecting the dog did not open its three-mode command bar")
		return

	player.global_position = Vector2(1120, 350)
	player.facing = &"left"
	dog.global_position = Vector2(920, 350)
	dog.set_command_mode(dog.CommandMode.FOLLOW, false)
	for step in 240:
		dog._update_follow(0.1)
		if dog.global_position.x > 1090.0:
			break
	if dog.global_position.x <= 1090.0 or not scene.is_point_on_land(dog.global_position, dog.collision_radius):
		_fail("Following dog stayed stuck instead of routing around its dog house")
		return

	for index in sheep_group.get_child_count():
		sheep_group.get_child(index).global_position = Vector2(860, 500 - index * 12)
	var driven_sheep: Node = sheep_group.get_child(0)
	driven_sheep.global_position = Vector2(1000, 300)
	driven_sheep.state = driven_sheep.State.IDLE
	dog.global_position = Vector2(925, 300)
	if not dog.set_command_mode(dog.CommandMode.DRIVE) or not dog.set_command_target(Vector2(1120, 300)):
		_fail("Drive command could not be issued")
		return
	dog._update_drive(0.1)
	if driven_sheep.state != driven_sheep.State.RUN or driven_sheep.target_position.x <= driven_sheep.global_position.x:
		_fail("Dog did not push the sheep toward the selected destination")
		return
	if not story.is_event_fired(&"first_dog_command"):
		_fail("First dog command did not queue its tutorial story")
		return

	dog.drive_cooldowns.clear()
	dog.set_command_mode(dog.CommandMode.GUARD, false)
	dog.set_command_target(Vector2(950, 450))
	dog.global_position = Vector2(950, 450)
	driven_sheep.global_position = Vector2(980, 450)
	driven_sheep.state = driven_sheep.State.IDLE
	dog._update_guard(0.1)
	if driven_sheep.state != driven_sheep.State.RUN or driven_sheep.target_position.x <= driven_sheep.global_position.x:
		_fail("Guard dog did not repel a sheep entering its guarded area")
		return

	if not command_bar.select_mode(dog.CommandMode.DRIVE) or not command_bar.is_target_pending():
		_fail("Drive segment did not arm world target selection")
		return
	if not command_bar.consume_world_target(Vector2(1100, 420)) or command_bar.is_target_pending():
		_fail("World click did not finish the dog target command")
		return

	if not controller.try_place_fence(Vector2(880, 190), Vector2(1160, 510)):
		_fail("Could not place a fence for assisted roundup test")
		return
	var fence: Node2D = controller.get_fence_roots()[0]
	var grazing_rect: Rect2 = fence.get_meta("grazing_rect")
	for index in sheep_group.get_child_count():
		sheep_group.get_child(index).global_position = (
			grazing_rect.get_center() + Vector2((index % 3 - 1) * 18, (index / 3) * 18)
			if index < 5 else Vector2(850, 500)
		)
	roundup._start_day(hud.get_day())
	var dog_tasks: Array[Dictionary] = [{
		"id": "dog_roundup_test",
		"id_suffix": "",
		"type": &"dog_roundup",
		"title": "牧羊犬协作",
		"description": "使用牧羊犬完成一次傍晚回圈",
		"target": 1,
		"progress": 0,
		"reward": 140,
		"state": tasks.TaskState.ACTIVE,
	}]
	tasks.tasks = dog_tasks
	dog.sheep_driven.emit(sheep_group.get_child(0))
	if not roundup.dog_assisted or not roundup.evaluate_roundup():
		_fail("Dog assistance was not recorded for a successful roundup")
		return
	if tasks.get_task("dog_roundup_test").state != tasks.TaskState.COMPLETED:
		_fail("Dog-assisted roundup did not advance its daily task")
		return
	if not story.is_event_fired(&"first_dog_roundup"):
		_fail("First dog-assisted roundup did not queue its story")
		return
	var feasible_pool: Array[Dictionary] = tasks._build_feasible_pool(hud.get_day())
	if not feasible_pool.any(func(task: Dictionary) -> bool: return task.type == &"dog_roundup"):
		_fail("Dog roundup task was missing despite a dog house and fence")
		return

	dog.global_position = Vector2(1040, 430)
	dog.set_command_mode(dog.CommandMode.GUARD, false)
	dog.set_command_target(Vector2(1080, 440))
	var save_data: Dictionary = scene.get_save_data()
	root.remove_child(scene)
	scene.free()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Dog system save data could not be restored")
		return
	await physics_frame
	var restored_dog: AnimatedSprite2D = restored.get_node("Island/ShepherdDog")
	if not restored_dog.active or restored_dog.global_position.distance_to(Vector2(1040, 430)) > 5.0:
		_fail("Dog unlock or position did not survive save restore")
		return
	if restored_dog.command_mode != restored_dog.CommandMode.GUARD or not restored_dog.has_command_target or restored_dog.command_target.distance_to(Vector2(1080, 440)) > 0.1:
		_fail("Dog mode or command target did not survive save restore")
		return
	if not restored.get_node("HUD/RoundupStatus").dog_assisted:
		_fail("Dog-assisted roundup state did not survive save restore")
		return

	print("PASS: dog unlock, follow routing, drive, guard, commands, roundup task, story, and save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
