extends Node

signal active_count_changed(count: int)
signal selected_dog_changed(dog: Node)
signal command_issued(mode: int)
signal sheep_driven(sheep: Node)
signal worker_stamina_low(worker: Node)

@onready var world_controller: Node = get_parent()
@onready var island: Node2D = get_node("../Island")
@onready var dog_template: AnimatedSprite2D = get_node("../Island/ShepherdDog")
@onready var build_controller: Node = get_node("../BuildController")

var dogs: Array[AnimatedSprite2D] = []
var selected_dog: AnimatedSprite2D


func _ready() -> void:
	dogs.append(dog_template)
	_connect_dog(dog_template)
	build_controller.building_placed.connect(_on_building_changed)
	build_controller.building_removed.connect(_on_building_changed)
	call_deferred("sync_dogs")


func sync_dogs() -> void:
	var houses: Array[Node2D] = build_controller.get_buildings_by_type(&"dog_house")
	while dogs.size() < houses.size():
		var dog := AnimatedSprite2D.new()
		dog.name = "ShepherdDog%d" % (dogs.size() + 1)
		dog.set_script(dog_template.get_script())
		dog.dog_index = dogs.size()
		island.add_child(dog)
		dogs.append(dog)
		_connect_dog(dog)
	for index in dogs.size():
		if index < houses.size():
			dogs[index].configure(index, houses[index].global_position)
		elif index == 0:
			dogs[index].deactivate()
	for index in range(dogs.size() - 1, maxi(0, houses.size() - 1), -1):
		if index == 0:
			continue
		var dog := dogs[index]
		if selected_dog == dog:
			select_dog(null)
		dogs.remove_at(index)
		dog.queue_free()
	active_count_changed.emit(get_active_dog_count())


func get_dogs() -> Array[AnimatedSprite2D]:
	return dogs.filter(func(dog: AnimatedSprite2D) -> bool: return dog.active and not dog.is_queued_for_deletion())


func get_active_dog_count() -> int:
	return get_dogs().size()


func has_active_dog() -> bool:
	return get_active_dog_count() > 0


func find_dog_at(world_position: Vector2, radius := 34.0) -> AnimatedSprite2D:
	var nearest: AnimatedSprite2D
	var nearest_distance := radius * radius
	for dog in get_dogs():
		if dog.resting:
			continue
		var distance := dog.global_position.distance_squared_to(world_position)
		if distance <= nearest_distance:
			nearest = dog
			nearest_distance = distance
	return nearest


func select_dog(dog: Variant) -> void:
	var next_dog := dog as AnimatedSprite2D
	if next_dog and (not next_dog.active or next_dog.is_queued_for_deletion()):
		next_dog = null
	if selected_dog == next_dog:
		return
	if is_instance_valid(selected_dog):
		selected_dog.set_selected(false)
	selected_dog = next_dog
	if selected_dog:
		selected_dog.set_selected(true)
	selected_dog_changed.emit(selected_dog)


func get_selected_dog() -> AnimatedSprite2D:
	return selected_dog if is_instance_valid(selected_dog) else null


func start_auto_roundup(target: Vector2) -> void:
	for dog in get_dogs():
		dog.set_command_mode(dog.CommandMode.DRIVE, false)
		dog.set_command_target(target, false)


func stop_auto_roundup() -> void:
	for dog in get_dogs():
		if not dog.going_to_rest and not dog.resting:
			dog.set_command_mode(dog.CommandMode.FOLLOW, false)


func send_dog_to_house(building: Node2D) -> bool:
	var houses: Array[Node2D] = build_controller.get_buildings_by_type(&"dog_house")
	var index: int = houses.find(building)
	if index < 0 or index >= dogs.size():
		return false
	if not dogs[index].send_to_rest(building.global_position):
		return false
	if selected_dog == dogs[index]:
		select_dog(null)
	return true


func wake_all() -> void:
	for dog in get_dogs():
		dog.wake_up()


func get_save_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dog in get_dogs():
		result.append(dog.get_save_data())
	return result


func restore_save_data(data: Variant) -> void:
	sync_dogs()
	var saved_dogs: Array = data if data is Array else ([data] if data is Dictionary and not data.is_empty() else [])
	for index in mini(saved_dogs.size(), get_dogs().size()):
		if saved_dogs[index] is Dictionary:
			dogs[index].restore_save_data(saved_dogs[index])
	select_dog(null)


func _connect_dog(dog: AnimatedSprite2D) -> void:
	if not dog.command_issued.is_connected(_on_dog_command_issued):
		dog.command_issued.connect(_on_dog_command_issued)
	if not dog.sheep_driven.is_connected(_on_sheep_driven):
		dog.sheep_driven.connect(_on_sheep_driven)
	if not dog.stamina_low.is_connected(_on_dog_stamina_low.bind(dog)):
		dog.stamina_low.connect(_on_dog_stamina_low.bind(dog))


func _on_building_changed(item_id: StringName) -> void:
	if item_id == &"dog_house":
		call_deferred("sync_dogs")


func _on_dog_command_issued(mode: int) -> void:
	command_issued.emit(mode)


func _on_sheep_driven(sheep: Node) -> void:
	sheep_driven.emit(sheep)


func _on_dog_stamina_low(dog: Node) -> void:
	worker_stamina_low.emit(dog)
