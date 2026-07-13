extends Node

signal save_finished(success: bool, message: String)

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save_v1.json"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const TITLE_SCENE_PATH := "res://scenes/title_screen.tscn"

var save_path := DEFAULT_SAVE_PATH
var pending_load := false
var last_message := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_save_path_for_tests(path: String) -> void:
	save_path = path
	pending_load = false


func reset_save_path() -> void:
	save_path = DEFAULT_SAVE_PATH
	pending_load = false


func has_pending_load() -> bool:
	return pending_load


func has_valid_save() -> bool:
	return not _read_valid_payload().is_empty()


func save_game(world: Node = null) -> bool:
	if not world:
		world = get_tree().current_scene
	if not world or not world.has_method("get_save_data"):
		return _finish(false, "当前场景不能保存")
	var payload := {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"world": world.get_save_data(),
	}
	var json_text := JSON.stringify(payload, "\t")
	var temporary_path := "%s.tmp" % save_path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if not file:
		return _finish(false, "无法写入存档临时文件")
	file.store_string(json_text)
	file.close()
	if _read_payload_from_path(temporary_path).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return _finish(false, "存档写入校验失败")
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var backup_path := "%s.bak" % save_path
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			return _finish(false, "无法替换旧存档")
	var rename_error := DirAccess.rename_absolute(absolute_temporary, absolute_save)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		return _finish(false, "无法完成存档替换")
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return _finish(true, "游戏已保存")


func request_continue_game() -> bool:
	if not has_valid_save():
		return _finish(false, "没有可读取的有效存档")
	pending_load = true
	_prepare_scene_change()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	return true


func request_new_game(delete_existing := false) -> void:
	pending_load = false
	if delete_existing:
		delete_save()
	_prepare_scene_change()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func request_title_screen() -> void:
	pending_load = false
	_prepare_scene_change()
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func restore_pending_into(world: Node) -> bool:
	if not pending_load:
		return false
	pending_load = false
	return load_game_into(world)


func load_game_into(world: Node) -> bool:
	var payload := _read_valid_payload()
	if payload.is_empty():
		return _finish(false, "存档损坏或版本不受支持")
	if not world.has_method("restore_save_data") or not world.restore_save_data(payload.world):
		return _finish(false, "存档内容无法恢复")
	return _finish(true, "存档读取完成")


func delete_save() -> bool:
	pending_load = false
	var success := true
	for path in [save_path, "%s.tmp" % save_path, "%s.bak" % save_path]:
		if FileAccess.file_exists(path):
			success = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and success
	return success


func _read_valid_payload() -> Dictionary:
	return _read_payload_from_path(save_path)


func _read_payload_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is not Dictionary:
		return {}
	var payload := parsed as Dictionary
	if int(payload.get("version", -1)) != SAVE_VERSION or payload.get("world", null) is not Dictionary:
		return {}
	var world := payload.world as Dictionary
	if not _world_data_is_valid(world):
		return {}
	return payload


func _world_data_is_valid(world: Dictionary) -> bool:
	var land_value: Variant = world.get("land", null)
	if land_value is not Array or land_value.is_empty() or world.get("sheep", null) is not Array:
		return false
	var coordinates: Dictionary = {}
	for value in land_value:
		if value is not Dictionary:
			return false
		var coordinate_value: Variant = value.get("coordinate", null)
		var land_type := String(value.get("land_type", ""))
		if coordinate_value is not Array or coordinate_value.size() < 2 or land_type not in ["pasture", "homestead"]:
			return false
		var coordinate := Vector2i(int(coordinate_value[0]), int(coordinate_value[1]))
		if coordinates.has(coordinate):
			return false
		coordinates[coordinate] = true
	if not coordinates.has(Vector2i.ZERO):
		return false
	var reached: Dictionary = {Vector2i.ZERO: true}
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	while not frontier.is_empty():
		var coordinate: Vector2i = frontier.pop_front()
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = coordinate + direction
			if coordinates.has(neighbor) and not reached.has(neighbor):
				reached[neighbor] = true
				frontier.append(neighbor)
	return reached.size() == coordinates.size()


func _prepare_scene_change() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _finish(success: bool, message: String) -> bool:
	last_message = message
	save_finished.emit(success, message)
	return success
