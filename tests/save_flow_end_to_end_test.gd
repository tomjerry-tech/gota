extends SceneTree

const TEST_SAVE_PATH := "user://save_flow_end_to_end_test.json"

var save_manager: Node


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	save_manager = root.get_node("SaveManager")
	save_manager.set_save_path_for_tests(TEST_SAVE_PATH)
	save_manager.delete_save()

	var source: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(source)
	await process_frame
	await process_frame
	source.get_node("HUD/TopHUD").restore_save_data({
		"money": 4321,
		"day": 3,
		"day_progress": 0.55,
	})
	source.get_node("BuildController").select_build_item(&"fence", {"display_name": "木围栏"})
	source.open_sheep_profile(source.sheep_group.get_child(0))
	if not save_manager.save_game(source):
		_fail("End-to-end setup could not create a save")
		return
	root.remove_child(source)
	source.free()

	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	if title.continue_button.disabled or not title.continue_game():
		_fail("Title screen could not start the continue flow")
		return
	await process_frame
	await process_frame
	await process_frame
	var loaded: Node = current_scene
	if not loaded or loaded.name != "Main" or loaded.get_node("HUD/TopHUD").get_money() != 4321:
		_fail("Continue did not enter the main scene with the saved balance")
		return
	if (
		loaded.get_node("BuildController").is_build_mode_active()
		or loaded.get_node("HUD/SheepDetailMenu").visible
		or loaded.get_node("HUD/SystemMenu").visible
	):
		_fail("Continue restored temporary build or panel state")
		return

	save_manager.request_new_game(true)
	await process_frame
	await process_frame
	await process_frame
	var fresh: Node = current_scene
	if (
		not fresh
		or fresh.name != "Main"
		or fresh.get_node("HUD/TopHUD").get_money() != 20000
		or fresh.get_node("HUD/TopHUD").get_day() != 1
		or fresh.get_sheep_count() != 6
		or fresh.get_land_chunk_count() != 1
		or save_manager.has_valid_save()
	):
		_fail("Restart did not delete the save and restore the 20000-coin initial pasture")
		return

	fresh.autosave_enabled = true
	fresh.get_node("HUD/TopHUD").restore_save_data({"money": 8765, "day": 2, "day_progress": 0.4})
	var report: Control = fresh.get_node("HUD/DailyReport")
	report.show_daily_report(1)
	report.close_report()
	await process_frame
	if not save_manager.has_valid_save():
		_fail("Closing the daily report did not create an automatic save")
		return

	var money_before_invalid_load: int = fresh.get_node("HUD/TopHUD").get_money()
	for invalid_payload in [
		{"version": 99, "world": {"land": [{"coordinate": [0, 0], "land_type": "pasture"}], "sheep": []}},
		{"version": 1, "world": {"land": [{"coordinate": [0, 0], "land_type": "pasture"}]}},
		{"version": 1, "world": {"land": [
			{"coordinate": [0, 0], "land_type": "pasture"},
			{"coordinate": [2, 0], "land_type": "pasture"},
		], "sheep": []}},
	]:
		_write_payload(invalid_payload)
		if save_manager.has_valid_save() or save_manager.load_game_into(fresh):
			_fail("Invalid version, missing fields, or disconnected land was accepted")
			return
		if fresh.get_node("HUD/TopHUD").get_money() != money_before_invalid_load:
			_fail("Invalid save data modified the running pasture")
			return

	save_manager.delete_save()
	save_manager.reset_save_path()
	Engine.time_scale = 1.0
	paused = false
	print("PASS: continue, restart, autosave, temporary UI clearing, and structural save validation")
	quit(0)


func _write_payload(payload: Dictionary) -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func _fail(message: String) -> void:
	if save_manager:
		save_manager.delete_save()
		save_manager.reset_save_path()
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
