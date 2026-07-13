extends Node2D

const CLOUD_TEXTURE := preload("res://assets/tiny_swords/decorations/cloud_01.png")
const CELL_SIZE := 480.0
const VISIBLE_RADIUS := 3

@onready var world_camera: Camera2D = get_node("../WorldCamera")

var current_camera_cell := Vector2i(999999, 999999)


func _ready() -> void:
	z_index = -5
	_rebuild_clouds()


func _process(_delta: float) -> void:
	var camera_cell := Vector2i(
		floori(world_camera.position.x / CELL_SIZE),
		floori(world_camera.position.y / CELL_SIZE)
	)
	if camera_cell != current_camera_cell:
		_rebuild_clouds()


func _rebuild_clouds() -> void:
	current_camera_cell = Vector2i(
		floori(world_camera.position.x / CELL_SIZE),
		floori(world_camera.position.y / CELL_SIZE)
	)
	for child in get_children():
		child.queue_free()
	for x in range(current_camera_cell.x - VISIBLE_RADIUS, current_camera_cell.x + VISIBLE_RADIUS + 1):
		for y in range(current_camera_cell.y - VISIBLE_RADIUS, current_camera_cell.y + VISIBLE_RADIUS + 1):
			_add_cloud_for_cell(Vector2i(x, y))


func _add_cloud_for_cell(cell: Vector2i) -> void:
	var random := RandomNumberGenerator.new()
	var seed_value := cell.x * 73856093 ^ cell.y * 19349663 ^ 83492791
	random.seed = seed_value & 0x7fffffff
	if random.randf() > 0.42:
		return
	var cloud := Sprite2D.new()
	cloud.texture = CLOUD_TEXTURE
	cloud.position = Vector2(cell) * CELL_SIZE + Vector2(
		random.randf_range(70.0, CELL_SIZE - 70.0),
		random.randf_range(70.0, CELL_SIZE - 70.0)
	)
	var cloud_scale := random.randf_range(0.34, 0.68)
	cloud.scale = Vector2(-cloud_scale if random.randf() < 0.5 else cloud_scale, cloud_scale)
	cloud.modulate = Color(1.0, 1.0, 1.0, random.randf_range(0.78, 1.0))
	add_child(cloud)
