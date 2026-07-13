extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var sheep_group: Node = scene.get_node("Island/Sheep")
	var sheep_menu: Control = scene.get_node("HUD/SheepMenu")
	var top_hud: Control = scene.get_node("HUD/TopHUD")

	if scene.get_male_sheep_count() < 2 or scene.get_female_sheep_count() < 2:
		_fail("Initial flock did not guarantee at least two males and two females")
		return
	for sheep in sheep_group.get_children():
		if sheep.get_age_days() != 8 or not sheep.is_adult() or not sheep.can_breed():
			_fail("Initial sheep did not start as healthy 8-day breeding adults")
			return
		sheep.hunger = 0.0
	if sheep_menu.breed_button.text != "每日自动配对" or not sheep_menu.breed_button.disabled:
		_fail("Flock panel still requires manual breeding")
		return

	var litter_counts: Array[int] = [0, 0, 0, 0, 0]
	scene.profile_random.seed = 20260713
	for sample_index in 1000:
		litter_counts[scene._roll_litter_size(5) - 1] += 1
	if litter_counts.any(func(count: int) -> bool: return count <= 0) or litter_counts[0] <= litter_counts[4]:
		_fail("Weighted litter selection did not cover 1-5 lambs or make large litters rarer")
		return

	var counters := {"added": 0, "born": 0, "lambs": []}
	scene.sheep_added.connect(func(count: int) -> void: counters.added += count)
	scene.lamb_born.connect(
		func(lamb: Node, _mother: Node) -> void:
			counters.born += 1
			counters.lambs.append(lamb)
	)
	var available_before: int = scene.get_available_sheep_capacity()
	if not scene.run_automatic_breeding():
		_fail("Eligible flock did not form an automatic pair")
		return
	var mother: Node = null
	var father: Node = null
	for sheep in sheep_group.get_children():
		if sheep.is_pregnant():
			mother = sheep
		elif sheep.get_sex() == sheep.SEX_MALE and sheep.get_breeding_cooldown_days() == sheep.FATHER_COOLDOWN_DAYS:
			father = sheep
	if not mother or not father or not mother.breeding_icon.visible:
		_fail("Automatic mating did not set pregnancy, father cooldown, and status icon")
		return
	var expected_litter: int = mother.get_expected_lamb_count()
	if expected_litter < 1 or expected_litter > mini(5, available_before):
		_fail("Automatic pregnancy selected an invalid 1-5 litter")
		return
	if scene.get_reserved_lamb_count() != expected_litter or scene.get_available_sheep_capacity() != available_before - expected_litter:
		_fail("Automatic pregnancy did not reserve the complete litter capacity")
		return
	for sheep in sheep_group.get_children():
		if sheep != mother and sheep.get_sex() == sheep.SEX_FEMALE:
			sheep.start_breeding_cooldown(20)

	for day_index in 2:
		top_hud._age_sheep_one_day()
		if counters.born != 0:
			_fail("Lambs were born before the three-day pregnancy finished")
			return
	top_hud._age_sheep_one_day()
	if counters.born != expected_litter or counters.lambs.size() != expected_litter:
		_fail("Three-day pregnancy did not produce the reserved litter")
		return
	if counters.added != 0:
		_fail("Newborn lambs incorrectly counted as purchased lambs")
		return
	for lamb: Node in counters.lambs:
		if lamb.get_age_days() != 0 or lamb.is_adult():
			_fail("Newborn growth stage is incorrect")
			return
		for day_index in 6:
			lamb.advance_day()
		if not lamb.is_adult() or lamb.get_age_days() != 6:
			_fail("A lamb did not become adult at six days")
			return
	if mother.is_pregnant() or mother.get_breeding_cooldown_days() != mother.MOTHER_COOLDOWN_DAYS:
		_fail("Mother did not enter the four-day postpartum cooldown")
		return
	if scene.get_node("HUD/DailyReport").born_today != expected_litter:
		_fail("Daily report did not record batch births")
		return

	print("PASS: six-day growth, daily automatic pairing, weighted 1-5 litters, pregnancy, reservation, and cooldowns")
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	paused = false
	push_error(message)
	quit(1)
