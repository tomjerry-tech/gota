extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var project := ConfigFile.new()
	if project.load("res://project.godot") != OK:
		_fail("Project configuration could not be loaded")
		return
	if (
		String(project.get_value("application", "config/version", "")) != "0.3.0"
		or int(project.get_value("display", "window/size/viewport_width", 0)) != 1280
		or int(project.get_value("display", "window/size/viewport_height", 0)) != 720
		or String(project.get_value("rendering", "renderer/rendering_method", "")) != "gl_compatibility"
	):
		_fail("Release version, viewport, or renderer settings are incomplete")
		return
	var export_config := ConfigFile.new()
	if export_config.load("res://export_presets.cfg") != OK:
		_fail("Windows export preset could not be loaded")
		return
	var excluded := String(export_config.get_value("preset.0", "exclude_filter", ""))
	if (
		String(export_config.get_value("preset.0", "name", "")) != "Windows Desktop"
		or String(export_config.get_value("preset.0", "export_path", "")) != "build/牧羊小岛.exe"
		or "tests/*" not in excluded
		or "work/*" not in excluded
	):
		_fail("Windows preset name, output path, or release exclusions are incorrect")
		return
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	if title.get_node("VersionLabel").text != "v0.3.0":
		_fail("Title screen does not display the configured release version")
		return
	for required_path in [
		"res://assets/title/title_background.png",
		"res://assets/tiny_swords/shepherd/shepherd_backup/shepherd_master_down.png",
		"res://assets/audio/pasture_theme.wav",
		"res://assets/audio/ambience_day.wav",
		"res://assets/audio/ambience_night.wav",
	]:
		if not FileAccess.file_exists(required_path):
			_fail("Required release asset is missing: %s" % required_path)
			return
	print("PASS: version, title, viewport, renderer, Windows export preset, exclusions, and release assets")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
