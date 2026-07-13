extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var audio: Node = root.get_node("AudioManager")
	audio.playback_enabled = true
	audio.reset_debug_play_counts()
	audio.restore_save_data({"master_volume": 0.8, "music_volume": 0.55, "sfx_volume": 0.75})
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	audio.playback_enabled = true
	audio.start_music()
	audio._start_ambience()
	var controller: Node = scene.get_node("BuildController")
	var player: AnimatedSprite2D = scene.get_node("Island/Shepherd")
	var dog: AnimatedSprite2D = scene.get_node("Island/ShepherdDog")
	var medical: Control = scene.get_node("HUD/MedicalMenu")
	var hud: Control = scene.get_node("HUD/TopHUD")
	var system_menu: Control = scene.get_node("HUD/SystemMenu")

	for bus_name in [&"Master", &"Music", &"Ambience", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			_fail("Missing audio bus: %s" % bus_name)
			return
	if not audio.music_player.playing or not audio.day_ambience_player.playing or not audio.night_ambience_player.playing:
		_fail("Music or ambience loops did not start in the pasture")
		return
	if audio.SFX_STREAMS.size() != 10 or audio.sfx_players.size() < 8:
		_fail("Core SFX library or overlap pool is incomplete")
		return
	var sheep: AnimatedSprite2D = scene.sheep_group.get_child(0)
	scene._press_sheep(sheep.global_position, Vector2(100.0, 100.0))
	scene._release_sheep()
	if audio.get_debug_play_count(&"sheep_bleat") != 1:
		_fail("Clicking a sheep did not play its bleat")
		return

	audio.set_day_progress(0.5)
	if audio.day_ambience_player.volume_db <= audio.night_ambience_player.volume_db:
		_fail("Day ambience was not louder at midday")
		return
	audio.set_day_progress(0.0)
	if audio.night_ambience_player.volume_db <= audio.day_ambience_player.volume_db:
		_fail("Night ambience was not louder at midnight")
		return

	player.whistle_cooldown = 0.0
	player.whistling = false
	if not player.use_whistle() or audio.get_debug_play_count(&"whistle") != 1:
		_fail("Whistle gameplay signal did not play its SFX")
		return
	if not scene.add_land_chunk(Vector2i.RIGHT, scene.LAND_TYPE_HOMESTEAD):
		_fail("Could not add test land for audio events")
		return
	if not controller.try_place_building(&"dog_house", Vector2(1024, 350)):
		_fail("Could not build dog house for audio events")
		return
	await process_frame
	dog.set_command_mode(dog.CommandMode.GUARD)
	if audio.get_debug_play_count(&"dog_bark") != 1:
		_fail("Dog command did not play a throttled bark")
		return
	if audio.get_debug_play_count(&"build") < 1:
		_fail("Building placement did not play construction SFX")
		return
	if not controller.try_place_fence(Vector2(880, 190), Vector2(1160, 510)):
		_fail("Could not place fence for gate audio")
		return
	var fence: Node2D = controller.get_fence_roots()[0]
	controller.set_gate_open(fence, true, true)
	controller.set_gate_open(fence, false, true)
	if audio.get_debug_play_count(&"gate_open") != 1 or audio.get_debug_play_count(&"gate_close") != 1:
		_fail("Gate open and close did not use distinct SFX")
		return
	medical.sheep_treated.emit(scene.sheep_group.get_child(0))
	if audio.get_debug_play_count(&"treatment") != 1:
		_fail("Treatment signal did not play treatment SFX")
		return
	hud.add_money(50)
	if audio.get_debug_play_count(&"coin") < 1:
		_fail("Money change did not play coin SFX")
		return
	hud.day_changed.emit(2)
	if audio.get_debug_play_count(&"day_bell") != 1:
		_fail("Day change did not play the day bell")
		return

	audio.reset_debug_play_counts()
	if not audio.play_sfx(&"sheep_bleat") or audio.play_sfx(&"sheep_bleat") or audio.get_debug_play_count(&"sheep_bleat") != 1:
		_fail("Repeated flock SFX was not throttled")
		return
	if system_menu.volume_sliders.size() != 3:
		_fail("System menu does not expose three volume sliders")
		return
	(system_menu.volume_sliders[&"master"] as HSlider).value = 0.65
	(system_menu.volume_sliders[&"music"] as HSlider).value = 0.40
	(system_menu.volume_sliders[&"sfx"] as HSlider).value = 0.70
	if not is_equal_approx(audio.master_volume, 0.65) or not is_equal_approx(audio.music_volume, 0.40) or not is_equal_approx(audio.sfx_volume, 0.70):
		_fail("Volume sliders did not update the audio manager")
		return

	var save_data: Dictionary = scene.get_save_data()
	root.remove_child(scene)
	scene.free()
	audio.restore_save_data({"master_volume": 0.1, "music_volume": 0.1, "sfx_volume": 0.1})
	var restored: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	await process_frame
	if not restored.restore_save_data(save_data):
		_fail("Audio settings save data could not be restored")
		return
	if not is_equal_approx(audio.master_volume, 0.65) or not is_equal_approx(audio.music_volume, 0.40) or not is_equal_approx(audio.sfx_volume, 0.70):
		_fail("Audio settings did not survive the game save round trip")
		return
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	if AudioServer.is_bus_mute(sfx_bus) or absf(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.70)) > 0.01:
		_fail("Restored SFX volume was not applied to the audio bus")
		return

	audio.stop_all(true)
	audio.playback_enabled = false
	await create_timer(0.35, true, false, true).timeout
	await process_frame
	await process_frame
	print("PASS: music, ambience, event SFX, throttling, volume controls, and save restore")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
