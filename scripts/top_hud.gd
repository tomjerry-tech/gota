extends Control

signal day_changed(day: int)
signal money_changed(delta: int)
signal phase_changed(phase: StringName)

@export var starting_money := 20000
@export_range(30.0, 900.0, 10.0) var seconds_per_day := 180.0

@onready var money_label: Label = $Ribbon/MoneyLabel
@onready var sheep_label: Label = $Ribbon/SheepLabel
@onready var day_label: Label = $Ribbon/DayLabel
@onready var day_cycle: Control = $Ribbon/DayCycle

var money := 0
var day := 1
var day_progress := 0.25
var sheep_group: Node = null
var daily_income := 0
var daily_expense := 0
var current_phase: StringName = &"morning"


func _ready() -> void:
	money = starting_money
	sheep_group = get_node_or_null("../../Island/Sheep")
	_refresh_labels()
	_apply_world_light()


func _process(delta: float) -> void:
	day_progress += delta / seconds_per_day
	if day_progress >= 1.0:
		day_progress -= 1.0
		day += 1
		_age_sheep_one_day()
		day_changed.emit(day)
	_refresh_labels()
	day_cycle.set_day_progress(day_progress)
	_apply_world_light()
	_update_phase()


func add_money(amount: int) -> void:
	if amount > 0:
		daily_income += amount
	money = maxi(0, money + amount)
	_refresh_labels()
	if amount != 0:
		money_changed.emit(amount)


func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	daily_expense += amount
	_refresh_labels()
	if amount > 0:
		money_changed.emit(-amount)
	return true


func refund_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	daily_expense = maxi(0, daily_expense - amount)
	_refresh_labels()
	money_changed.emit(amount)


func consume_daily_finance_summary() -> Dictionary:
	var summary := {"income": daily_income, "expense": daily_expense}
	daily_income = 0
	daily_expense = 0
	return summary


func get_money() -> int:
	return money


func get_day() -> int:
	return day


func get_day_phase() -> StringName:
	return current_phase


func is_night() -> bool:
	return current_phase == &"night"


func get_save_data() -> Dictionary:
	return {
		"money": money,
		"day": day,
		"day_progress": day_progress,
		"daily_income": daily_income,
		"daily_expense": daily_expense,
	}


func restore_save_data(data: Dictionary) -> void:
	money = maxi(0, int(data.get("money", starting_money)))
	day = maxi(1, int(data.get("day", 1)))
	day_progress = clampf(float(data.get("day_progress", 0.25)), 0.0, 0.999999)
	daily_income = maxi(0, int(data.get("daily_income", 0)))
	daily_expense = maxi(0, int(data.get("daily_expense", 0)))
	_refresh_labels()
	day_cycle.set_day_progress(day_progress)
	_apply_world_light()
	_update_phase()


func _age_sheep_one_day() -> void:
	if not sheep_group:
		return
	var world_controller := get_node_or_null("../..")
	var sickness_chance: float = (
		world_controller.get_lamb_sickness_chance()
		if world_controller and world_controller.has_method("get_lamb_sickness_chance")
		else 0.08
	)
	var mothers_due_to_give_birth: Array[Node] = []
	for sheep in sheep_group.get_children():
		if sheep.has_method("advance_day"):
			if sheep.advance_day():
				mothers_due_to_give_birth.append(sheep)
		if sheep.has_method("daily_health_check"):
			sheep.daily_health_check(sickness_chance)
	if world_controller and world_controller.has_method("complete_birth"):
		for mother in mothers_due_to_give_birth:
			world_controller.complete_birth(mother)
	if world_controller and world_controller.has_method("run_automatic_breeding"):
		world_controller.run_automatic_breeding()


func _update_phase() -> void:
	var next_phase: StringName
	if day_progress < 0.48:
		next_phase = &"morning"
	elif day_progress < 0.72:
		next_phase = &"day"
	elif day_progress < 0.82:
		next_phase = &"dusk"
	else:
		next_phase = &"night"
	if next_phase == current_phase:
		return
	current_phase = next_phase
	phase_changed.emit(current_phase)


func _refresh_labels() -> void:
	money_label.text = str(money)
	sheep_label.text = str(sheep_group.get_child_count() if sheep_group else 0)
	day_label.text = "第%d天" % day


func _apply_world_light() -> void:
	var daylight := clampf(sin(day_progress * TAU - PI * 0.5) * 0.5 + 0.5, 0.0, 1.0)
	var night_tint := Color("7884b5")
	var day_tint := Color.WHITE
	var tint := night_tint.lerp(day_tint, 0.35 + daylight * 0.65)
	RenderingServer.set_default_clear_color(Color("183b4b").lerp(Color("329598"), 0.28 + daylight * 0.72))
	var world := get_node_or_null("../../Island") as CanvasItem
	if world:
		world.modulate = tint
