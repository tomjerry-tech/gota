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
	if toolbar.buttons.size() != 3:
		_fail("Bottom toolbar does not contain exactly three buttons")
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
	print("PASS: three-button bottom toolbar and selectable tab state")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
