extends SceneTree

const TEST_SAVE_PATH := "user://title_screen_test.json"

var save_manager: Node


class FakeWorld:
	extends Node

	func get_save_data() -> Dictionary:
		return {
			"land": [{"coordinate": [0, 0], "land_type": "pasture"}],
			"sheep": [],
		}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	save_manager = root.get_node("SaveManager")
	save_manager.set_save_path_for_tests(TEST_SAVE_PATH)
	save_manager.delete_save()
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	if not title.continue_button.disabled:
		_fail("Continue should be disabled when no valid save exists")
		return
	if title.get_node("TitleRibbon/Title").text != "牧羊小岛" or title.get_node("Background").texture == null:
		_fail("Title screen is missing its title or generated background")
		return
	var fake_world := FakeWorld.new()
	root.add_child(fake_world)
	if not save_manager.save_game(fake_world):
		_fail("Title test could not create a valid save")
		return
	root.remove_child(title)
	title.free()
	var title_with_save: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title_with_save)
	await process_frame
	if title_with_save.continue_button.disabled:
		_fail("Continue stayed disabled when a valid save existed")
		return
	title_with_save.start_new_game()
	if not title_with_save.confirmation.visible:
		_fail("Starting over did not require confirmation")
		return
	title_with_save.cancel_new_game()
	if title_with_save.confirmation.visible:
		_fail("New-game confirmation could not be cancelled")
		return
	save_manager.delete_save()
	save_manager.reset_save_path()
	print("PASS: title background, continue availability, and new-game confirmation")
	quit(0)


func _fail(message: String) -> void:
	if save_manager:
		save_manager.delete_save()
		save_manager.reset_save_path()
	push_error(message)
	quit(1)
