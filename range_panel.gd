class_name RangePanel
extends PanelContainer
## Range safety display. The range safety team watches a rocket's path against a safe corridor. If it
## leaves the corridor, flies erratically, or its data goes dark, they can destroy it to protect
## people on the ground. (NASA: Artemis II launch day; the Eastern Range runs this for Kennedy launches.
## Which person presses the button is called different things on the Eastern Range, so the game says
## "range safety".)

signal terminate_pressed

var status := "IN CORRIDOR"
var deviation := 0.0          # -1..1, how far the path is from the planned line
var progress := 0.0           # 0..1 up the plot
var _plot: Control
var _status: Label
var _button: Button
var _trail: Array[Vector2] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel(16, 0.9))
	custom_minimum_size = Vector2(300, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	col.add_child(UiStyle.mono_label("RANGE SAFETY", 15, UiStyle.PHOSPHOR))
	col.add_child(UiStyle.mono_label("Eastern Range", 13, Color(UiStyle.NEAR_WHITE, 0.55)))

	_plot = Control.new()
	_plot.custom_minimum_size = Vector2(0, 190)
	_plot.draw.connect(_draw_plot)
	col.add_child(_plot)

	_status = UiStyle.mono_label(status, 18, UiStyle.PHOSPHOR)
	col.add_child(_status)

	var why := Label.new()
	why.text = "Terminate if the path leaves the corridor, the flight is erratic, or the data goes dark."
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_font_size_override("font_size", 14)
	why.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.7))
	why.custom_minimum_size = Vector2(0, 54)
	col.add_child(why)

	_button = Button.new()
	_button.text = "TERMINATE FLIGHT"
	_button.theme_type_variation = &"OutlineButton"
	_button.add_theme_font_size_override("font_size", 18)
	_button.custom_minimum_size = Vector2(0, 50)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UiStyle.CORAL, 0.16)
	s.set_border_width_all(2)
	s.border_color = UiStyle.CORAL
	s.set_corner_radius_all(10)
	for st in ["normal", "hover", "pressed", "focus"]:
		_button.add_theme_stylebox_override(st, s)
	_button.add_theme_color_override("font_color", UiStyle.CORAL)
	_button.pressed.connect(func(): terminate_pressed.emit())
	col.add_child(_button)


func set_state(new_status: String, new_deviation: float, new_progress: float) -> void:
	status = new_status
	deviation = new_deviation
	progress = new_progress
	_status.text = status
	var c := UiStyle.PHOSPHOR
	if status == "NO DATA":
		c = UiStyle.AMBER
	elif status != "IN CORRIDOR":
		c = UiStyle.CORAL
	_status.add_theme_color_override("font_color", c)
	if status != "NO DATA":
		_trail.append(_point())
		if _trail.size() > 40:
			_trail.pop_front()
	_plot.queue_redraw()


func is_threat() -> bool:
	return status != "IN CORRIDOR"


func set_enabled(on: bool) -> void:
	_button.disabled = not on


func _point() -> Vector2:
	var w := _plot.size.x
	var h := _plot.size.y
	return Vector2(w * 0.5 + deviation * w * 0.42, h - 8.0 - progress * (h - 20.0))


func _draw_plot() -> void:
	var w := _plot.size.x
	var h := _plot.size.y
	_plot.draw_rect(Rect2(0, 0, w, h), Color(UiStyle.MIDNIGHT, 0.7))
	_plot.draw_rect(Rect2(0, 0, w, h), Color(UiStyle.EDGE, 0.5), false, 1.5)
	# Safe corridor
	var left := w * 0.5 - w * 0.2
	var right := w * 0.5 + w * 0.2
	_plot.draw_rect(Rect2(left, 0, right - left, h), Color(UiStyle.PHOSPHOR, 0.07))
	_plot.draw_line(Vector2(left, 0), Vector2(left, h), Color(UiStyle.CORAL, 0.85), 2.0)
	_plot.draw_line(Vector2(right, 0), Vector2(right, h), Color(UiStyle.CORAL, 0.85), 2.0)
	_plot.draw_dashed_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, h), Color(UiStyle.NEAR_WHITE, 0.3), 1.0, 6.0)
	_plot.draw_string(UiStyle.MONO, Vector2(6, 16), "DESTRUCT LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UiStyle.CORAL, 0.85))
	# Path so far and the vehicle
	for i in range(1, _trail.size()):
		_plot.draw_line(_trail[i - 1], _trail[i], Color(UiStyle.NEAR_WHITE, 0.6), 2.0)
	var p := _point()
	var dot := UiStyle.PHOSPHOR
	if status == "NO DATA":
		dot = UiStyle.AMBER
		_plot.draw_string(UiStyle.MONO, Vector2(w * 0.5 - 40, h * 0.5), "NO DATA", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, UiStyle.AMBER)
	elif status != "IN CORRIDOR":
		dot = UiStyle.CORAL
	_plot.draw_circle(p, 9.0, Color(dot, 0.2))
	_plot.draw_circle(p, 4.5, dot)
