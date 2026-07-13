extends Node

const MUSIC_STREAM: AudioStream = preload("res://assets/audio/pasture_theme.wav")
const DAY_AMBIENCE_STREAM: AudioStream = preload("res://assets/audio/ambience_day.wav")
const NIGHT_AMBIENCE_STREAM: AudioStream = preload("res://assets/audio/ambience_night.wav")
const SFX_STREAMS := {
	&"whistle": preload("res://assets/audio/whistle.wav"),
	&"sheep_bleat": preload("res://assets/audio/sheep_bleat.wav"),
	&"dog_bark": preload("res://assets/audio/dog_bark.wav"),
	&"gate_open": preload("res://assets/audio/gate_open.wav"),
	&"gate_close": preload("res://assets/audio/gate_close.wav"),
	&"coin": preload("res://assets/audio/coin.wav"),
	&"build": preload("res://assets/audio/build.wav"),
	&"treatment": preload("res://assets/audio/treatment.wav"),
	&"ui_click": preload("res://assets/audio/ui_click.wav"),
	&"day_bell": preload("res://assets/audio/day_bell.wav"),
}
const SFX_COOLDOWNS := {
	&"ui_click": 0.04,
	&"sheep_bleat": 0.45,
	&"dog_bark": 0.45,
	&"coin": 0.08,
}

var master_volume := 0.80
var music_volume := 0.55
var sfx_volume := 0.75
var music_player: AudioStreamPlayer
var day_ambience_player: AudioStreamPlayer
var night_ambience_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_player_index := 0
var last_sfx_times: Dictionary = {}
var debug_play_counts: Dictionary = {}
var current_world: WeakRef
var current_ui_root: WeakRef
var ui_scan_time := 0.0
var sheep_bleat_time := 8.0
var random := RandomNumberGenerator.new()
var playback_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	playback_enabled = DisplayServer.get_name() != "headless"
	random.seed = 20260713
	_ensure_audio_bus(&"Music")
	_ensure_audio_bus(&"Ambience")
	_ensure_audio_bus(&"SFX")
	music_player = _make_player(&"Music", _make_looping_stream(MUSIC_STREAM))
	day_ambience_player = _make_player(&"Ambience", _make_looping_stream(DAY_AMBIENCE_STREAM))
	night_ambience_player = _make_player(&"Ambience", _make_looping_stream(NIGHT_AMBIENCE_STREAM))
	for index in 10:
		sfx_players.append(_make_player(&"SFX"))
	_apply_volumes()


func _exit_tree() -> void:
	stop_all(true)


func _process(delta: float) -> void:
	ui_scan_time -= delta
	if ui_scan_time <= 0.0:
		ui_scan_time = 1.5
		_scan_ui_buttons()
	var world := _get_current_world()
	if not world:
		return
	var top_hud := world.get_node_or_null("HUD/TopHUD")
	if top_hud:
		set_day_progress(top_hud.day_progress)
	if get_tree().paused:
		return
	sheep_bleat_time -= delta
	if sheep_bleat_time <= 0.0 and world.get_sheep_count() > 0:
		play_sfx(&"sheep_bleat", random.randf_range(0.92, 1.08))
		sheep_bleat_time = random.randf_range(9.0, 16.0)


func attach_title(title_root: Node) -> void:
	current_world = null
	current_ui_root = weakref(title_root)
	start_music()
	day_ambience_player.stop()
	night_ambience_player.stop()
	_scan_ui_buttons.call_deferred()


func attach_world(world: Node) -> void:
	current_world = weakref(world)
	current_ui_root = weakref(world)
	start_music()
	_start_ambience()
	_connect_once(world.player.whistle_used, play_sfx.bind(&"whistle", 1.0))
	_connect_once(world.dog_manager.command_issued, _on_dog_command_issued)
	_connect_once(world.build_controller.building_placed, _on_building_placed)
	_connect_once(world.build_controller.building_removed, _on_building_removed)
	_connect_once(world.build_controller.fence_placed, _on_fence_placed)
	_connect_once(world.build_controller.land_expanded, _on_land_expanded)
	_connect_once(world.build_controller.gate_toggled, _on_gate_toggled)
	_connect_once(world.medical_menu.sheep_treated, _on_sheep_treated)
	_connect_once(world.top_hud.day_changed, _on_day_changed)
	_connect_once(world.top_hud.money_changed, _on_money_changed)
	_scan_ui_buttons.call_deferred()


func start_music() -> void:
	if not playback_enabled:
		return
	if not music_player.playing:
		music_player.play()


func stop_all(release_streams := false) -> void:
	for player in [music_player, day_ambience_player, night_ambience_player]:
		if player:
			player.stop()
			if release_streams:
				player.stream = null
	for player in sfx_players:
		player.stop()
		if release_streams:
			player.stream = null


func set_day_progress(progress: float) -> void:
	if not day_ambience_player.playing or not night_ambience_player.playing:
		return
	var daylight := clampf(sin(progress * TAU - PI * 0.5) * 0.5 + 0.5, 0.0, 1.0)
	day_ambience_player.volume_db = linear_to_db(maxf(0.001, 0.12 + daylight * 0.88))
	night_ambience_player.volume_db = linear_to_db(maxf(0.001, 0.12 + (1.0 - daylight) * 0.88))


func play_sfx(sfx_id: StringName, pitch := 1.0) -> bool:
	if not playback_enabled or not SFX_STREAMS.has(sfx_id):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := float(SFX_COOLDOWNS.get(sfx_id, 0.0))
	if now - float(last_sfx_times.get(sfx_id, -1000.0)) < cooldown:
		return false
	last_sfx_times[sfx_id] = now
	var player := sfx_players[sfx_player_index]
	sfx_player_index = (sfx_player_index + 1) % sfx_players.size()
	player.stream = SFX_STREAMS[sfx_id]
	player.pitch_scale = pitch
	player.play()
	debug_play_counts[sfx_id] = int(debug_play_counts.get(sfx_id, 0)) + 1
	return true


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(&"Master", master_volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(&"Music", music_volume)
	_set_bus_volume(&"Ambience", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(&"SFX", sfx_volume)


func get_save_data() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}


func restore_save_data(data: Dictionary) -> void:
	set_master_volume(float(data.get("master_volume", master_volume)))
	set_music_volume(float(data.get("music_volume", music_volume)))
	set_sfx_volume(float(data.get("sfx_volume", sfx_volume)))


func get_debug_play_count(sfx_id: StringName) -> int:
	return int(debug_play_counts.get(sfx_id, 0))


func reset_debug_play_counts() -> void:
	debug_play_counts.clear()
	last_sfx_times.clear()


func _on_dog_command_issued(_mode: int) -> void:
	play_sfx(&"dog_bark", random.randf_range(0.94, 1.05))


func _on_building_placed(_item_id: StringName) -> void:
	play_sfx(&"build")


func _on_building_removed(_item_id: StringName) -> void:
	play_sfx(&"build", 0.82)


func _on_fence_placed() -> void:
	play_sfx(&"build")


func _on_land_expanded() -> void:
	play_sfx(&"build", 0.75)


func _on_gate_toggled(_fence: Node, is_open: bool) -> void:
	play_sfx(&"gate_open" if is_open else &"gate_close")


func _on_sheep_treated(_sheep: Node) -> void:
	play_sfx(&"treatment")


func _on_day_changed(_day: int) -> void:
	play_sfx(&"day_bell")


func _on_money_changed(delta: int) -> void:
	if delta != 0:
		play_sfx(&"coin", 1.06 if delta > 0 else 0.92)


func _on_ui_button_pressed() -> void:
	play_sfx(&"ui_click")


func _start_ambience() -> void:
	if not playback_enabled:
		return
	if not day_ambience_player.playing:
		day_ambience_player.play()
	if not night_ambience_player.playing:
		night_ambience_player.play()


func _scan_ui_buttons() -> void:
	if not current_ui_root:
		return
	var root_node: Node = current_ui_root.get_ref()
	if not is_instance_valid(root_node):
		return
	var click_callable := Callable(self, "_on_ui_button_pressed")
	for button in root_node.find_children("*", "BaseButton", true, false):
		if not button.pressed.is_connected(click_callable):
			button.pressed.connect(click_callable)


func _get_current_world() -> Node:
	if not current_world:
		return null
	var world: Node = current_world.get_ref()
	return world if is_instance_valid(world) else null


func _connect_once(signal_value: Signal, callable: Callable) -> void:
	if not signal_value.is_connected(callable):
		signal_value.connect(callable)


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, value)))


func _apply_volumes() -> void:
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)


func _make_player(bus_name: StringName, stream_value: AudioStream = null) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.stream = stream_value
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _make_looping_stream(source: AudioStream) -> AudioStream:
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream
