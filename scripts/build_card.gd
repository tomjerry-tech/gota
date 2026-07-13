extends Button

var item_id: StringName
var item_data: Dictionary


func get_build_drag_data() -> Variant:
	if item_id == &"land_expand":
		return null
	return {
		"type": &"build_item",
		"item_id": item_id,
		"price": item_data.price,
		"display_name": item_data.display_name,
	}
