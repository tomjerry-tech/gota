extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	var hud: Control = scene.get_node("HUD/TopHUD")
	var sheep_group: Node = scene.get_node("Island/Sheep")
	var report: Control = scene.get_node("HUD/DailyReport")

	if hud.get_money() != 20000:
		_fail("HUD starting money is incorrect")
		return
	if hud.scale != Vector2(0.5, 0.5):
		_fail("Top HUD was not scaled to half size")
		return
	if hud.sheep_label.text != str(sheep_group.get_child_count()):
		_fail("HUD sheep count does not match the scene")
		return
	if hud.day_label.text != "第1天":
		_fail("HUD did not start on day 1")
		return
	if not hud.spend_money(200) or hud.get_money() != 19800:
		_fail("HUD spending interface failed")
		return
	hud.add_money(50)
	if hud.get_money() != 19850:
		_fail("HUD money addition interface failed")
		return

	hud.seconds_per_day = 0.05
	await create_timer(0.08).timeout
	if hud.get_day() < 2:
		_fail("Day cycle did not advance to the next day")
		return
	if hud.day_cycle.day_progress == 0.25:
		_fail("Day cycle display did not update")
		return
	if not report.visible or not paused:
		_fail("Day end did not open the daily report and pause the game")
		return
	if "收入 50" not in report.report_text.text or "支出 200" not in report.report_text.text:
		_fail("Daily report did not summarize income and expense")
		return
	report.close_report()

	print("PASS: money, sheep count, day cycle, finance tracking, and automatic daily report")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
