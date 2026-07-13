extends Control

var day_progress := 0.25


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_style_box(_panel_style(), panel)

	var inner := panel.grow(-4.0)
	var sky_color := _sky_color(day_progress)
	draw_rect(inner, sky_color)

	var horizon_y := inner.end.y - 5.0
	draw_line(
		Vector2(inner.position.x + 3.0, horizon_y),
		Vector2(inner.end.x - 3.0, horizon_y),
		Color(0.18, 0.16, 0.24, 0.8),
		2.0
	)

	var sun_position := _body_position(day_progress, inner)
	if day_progress < 0.75:
		draw_circle(sun_position, 5.0, Color(1.0, 0.84, 0.3))
		draw_circle(sun_position, 3.0, Color(1.0, 0.96, 0.58))
	else:
		draw_circle(sun_position, 5.0, Color(0.85, 0.9, 1.0))
		draw_circle(sun_position + Vector2(2.0, -1.0), 4.0, sky_color)


func set_day_progress(value: float) -> void:
	day_progress = wrapf(value, 0.0, 1.0)
	queue_redraw()


func _body_position(progress: float, area: Rect2) -> Vector2:
	var phase := progress / 0.75 if progress < 0.75 else (progress - 0.75) / 0.25
	var x := lerpf(area.position.x + 7.0, area.end.x - 7.0, phase)
	var arc := sin(phase * PI)
	var y := lerpf(area.end.y - 8.0, area.position.y + 7.0, arc)
	return Vector2(x, y)


func _sky_color(progress: float) -> Color:
	if progress < 0.2:
		return Color("e9a45e").lerp(Color("75c9dd"), progress / 0.2)
	if progress < 0.58:
		return Color("75c9dd")
	if progress < 0.75:
		return Color("75c9dd").lerp(Color("d77b55"), (progress - 0.58) / 0.17)
	return Color("172142").lerp(Color("56355c"), sin((progress - 0.75) / 0.25 * PI))


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("22213a")
	style.border_color = Color("111225")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style
