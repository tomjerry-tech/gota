extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var toolbar: Control = scene.get_node("HUD/BottomToolbar")
	if toolbar.scale != Vector2(0.5, 0.5):
		_fail("Bottom toolbar was not scaled to half size")
		return
	if toolbar.buttons.size() != 4:
		_fail("Bottom toolbar does not contain build, sheep, medical, and help buttons")
		return
	if toolbar.get_selected_tab() != &"":
		_fail("Bottom toolbar should start without an active tab")
		return
	toolbar.select_tab(&"sheep")
	if toolbar.get_selected_tab() != &"sheep":
		_fail("Bottom toolbar could not select the sheep tab")
		return
	if toolbar.buttons[1].scale.x <= toolbar.buttons[0].scale.x:
		_fail("Selected toolbar button has no visible selected state")
		return
	toolbar.select_tab(&"help")
	var help_menu: Control = scene.get_node("HUD/HelpMenu")
	if not help_menu.visible or scene.get_node_or_null("HUD/ContextInfoPanel") != null:
		_fail("Help tab did not replace the always-visible context strip")
		return
	if help_menu.TOPICS.size() < 5 or "牧羊犬" not in String(help_menu.TOPICS[3].body):
		_fail("Help menu does not explain the main controllable objects")
		return
	print("PASS: four-button toolbar, help handbook, and no permanent context strip")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
