extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var player: AnimatedSprite2D = scene.get_node("Island/Shepherd")
	var camera: Camera2D = scene.get_node("WorldCamera")
	var controller: Node = scene.get_node("BuildController")
	var sheep_group: Node = scene.get_node("Island/Sheep")
	var roundup: Control = scene.get_node("HUD/RoundupStatus")
	var hud: Control = scene.get_node("HUD/TopHUD")
	var report: Control = scene.get_node("HUD/DailyReport")
	var story: Node = scene.get_node("StoryEventManager")

	if not scene.is_point_on_land(player.global_position, player.collision_radius):
		_fail("Shepherd did not spawn on owned land")
		return
	player.global_position = Vector2(470, 350)
	var edge_position := player.global_position
	if player.move_character(Vector2.LEFT, 1.0) or player.global_position != edge_position:
		_fail("Shepherd movement escaped owned land")
		return
	player.global_position = Vector2(480, 393)
	var obstacle_position := player.global_position
	if player.move_character(Vector2.RIGHT, 0.5) or player.global_position != obstacle_position:
		_fail("Shepherd walked through the initial tree collider")
		return
	player.global_position = Vector2(640, 440)
	if not player.move_character(Vector2.RIGHT, 0.1):
		_fail("Shepherd could not move across clear owned land")
		return
	camera.set_zoom_level(1.5)
	camera.position = Vector2.ZERO
	camera.focus_on_world_position(player.global_position)
	if camera.position != player.global_position or not is_equal_approx(camera.zoom.x, 1.5):
		_fail("Camera refocus did not preserve the current zoom")
		return

	for index in sheep_group.get_child_count():
		sheep_group.get_child(index).global_position = Vector2(790, 480 - index * 24)
	var herded_sheep: Node = sheep_group.get_child(0)
	player.global_position = Vector2(640, 440)
	herded_sheep.global_position = Vector2(680, 440)
	herded_sheep.state = herded_sheep.State.IDLE
	if player.herd_nearby_sheep() != 1 or herded_sheep.state != herded_sheep.State.RUN or herded_sheep.target_position.x <= herded_sheep.global_position.x:
		_fail("Nearby sheep did not run away from the shepherd")
		return
	if player.herd_nearby_sheep() != 0:
		_fail("Herding cooldown allowed immediate repeated scare commands")
		return

	var near_sheep: Node = sheep_group.get_child(0)
	var far_sheep: Node = sheep_group.get_child(1)
	player.global_position = Vector2(480, 300)
	near_sheep.global_position = Vector2(520, 300)
	far_sheep.global_position = Vector2(810, 300)
	near_sheep.state = near_sheep.State.IDLE
	far_sheep.state = far_sheep.State.IDLE
	player.whistle_cooldown = 0.0
	player.whistling = false
	if not player.use_whistle() or near_sheep.state != near_sheep.State.CALLED or far_sheep.state != far_sheep.State.IDLE:
		_fail("Whistle did not gather only sheep inside its radius")
		return

	if not controller.try_place_fence(Vector2(520, 230), Vector2(600, 310)):
		_fail("Could not place a fence for gate and roundup tests")
		return
	await physics_frame
	var fences: Array[Node2D] = controller.get_fence_roots()
	if fences.size() != 1:
		_fail("Placed fence did not expose one fence root")
		return
	var fence := fences[0]
	var gate := fence.get_node_or_null("Gate") as Node2D
	var gate_shape := gate.get_node_or_null("Collision/CollisionShape2D") as CollisionShape2D if gate else null
	if not gate or not gate_shape or gate_shape.disabled:
		_fail("New fence did not create a closed colliding gate")
		return
	if not controller.set_gate_open(fence, true, true) or not gate_shape.disabled:
		_fail("Opening a gate did not disable its collision")
		return
	controller.set_gate_open(fence, false)
	if gate_shape.disabled:
		_fail("Closing a gate did not restore its collision")
		return

	var grazing_rect: Rect2 = fence.get_meta("grazing_rect")
	for index in sheep_group.get_child_count():
		sheep_group.get_child(index).global_position = (
			grazing_rect.get_center() + Vector2((index % 3 - 1) * 8, (index / 3) * 8)
			if index < 5 else Vector2(760, 450)
		)
	if controller.get_fence_sheep_count(fence) != 5:
		_fail("Per-fence sheep count did not use the enclosure interior")
		return
	roundup._start_day(hud.get_day())
	var money_before: int = hud.get_money()
	if not roundup.evaluate_roundup() or hud.get_money() != money_before + roundup.ROUNDUP_REWARD:
		_fail("Successful dusk roundup did not grant its reward")
		return
	var money_after_reward: int = hud.get_money()
	if not roundup.evaluate_roundup() or hud.get_money() != money_after_reward:
		_fail("Roundup reward could be claimed more than once in one day")
		return
	report.show_daily_report(hud.get_day())
	if "傍晚回圈" not in report.report_text.text or "成功" not in report.report_text.text:
		_fail("Daily report did not include the roundup result")
		return
	report.close_report()

	if not story.is_event_fired(&"first_whistle") or not story.is_event_fired(&"first_gate") or not story.is_event_fired(&"first_roundup_success"):
		_fail("Shepherd tutorial events were not queued from gameplay signals")
		return
	if story.queue_event(&"first_whistle"):
		_fail("A shepherd tutorial story could trigger twice")
		return

	player.global_position = Vector2(650, 450)
	player.facing = &"left"
	controller.set_gate_open(fence, true)
	var save_data: Dictionary = scene.get_save_data()
	root.remove_child(scene)
	scene.free()
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await physics_frame
	if not restored.restore_save_data(save_data):
		_fail("Shepherd gameplay save data could not be restored")
		return
	await physics_frame
	var restored_player: AnimatedSprite2D = restored.get_node("Island/Shepherd")
	var restored_controller: Node = restored.get_node("BuildController")
	var restored_roundup: Control = restored.get_node("HUD/RoundupStatus")
	var restored_fences: Array[Node2D] = restored_controller.get_fence_roots()
	if restored_player.global_position.distance_to(Vector2(650, 450)) > 0.1 or restored_player.facing != &"left":
		_fail("Shepherd position or direction did not survive save restore")
		return
	if restored_fences.size() != 1 or not bool(restored_fences[0].get_meta("gate_open", false)):
		_fail("Fence gate state did not survive save restore")
		return
	if not restored_roundup.evaluated or not restored_roundup.succeeded or not restored_roundup.reward_given:
		_fail("Daily roundup state did not survive save restore")
		return

	print("PASS: shepherd movement, herding, whistle, fence gate, roundup reward, story, and save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
