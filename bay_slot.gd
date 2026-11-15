class_name BaySlot
extends Button
## One bay on the ship. Empty: a dashed outline with a plus. Filled: the room art with the hull
## frame over its edges, and the room name in words (what a room does is never left to the picture).
## Click to aim the next room at this bay. The small X, or Delete, takes a room out.

signal remove_requested(index: int)
signal hovered(index: int)        # -1 when the pointer leaves

const FRAME: Texture2D = preload("res://assets/ui/build/hull/shell-bay-frame.webp")

var index := 0
var room_id := ""
var read_only := false
var _room_art: TextureRect
var _frame: TextureRect
var _name: Label
var _x: Button
var _t := 0.0


static func make(i: int, group: ButtonGroup) -> BaySlot:
	var b := BaySlot.new()
	b.index = i
	b.button_group = group
	b.toggle_mode = true
	b.theme_type_variation = &"BayButton"
	b.focus_mode = Control.FOCUS_ALL
	return b


func _ready() -> void:
	_room_art = TextureRect.new()
	_room_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_room_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_room_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_room_art)

	_frame = TextureRect.new()
	_frame.texture = FRAME
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_name = UiStyle.mono_label("", 13)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_stylebox_override("normal", UiStyle.chip(UiStyle.MIDNIGHT, true))
	_name.add_theme_color_override("font_color", UiStyle.NEAR_WHITE)
	_name.visible = false
	add_child(_name)

	_x = Button.new()
	_x.text = "x"
	_x.focus_mode = Control.FOCUS_NONE
	_x.tooltip_text = "Take this room out"
	_x.custom_minimum_size = Vector2(34, 34)
	_x.add_theme_font_override("font", UiStyle.MONO)
	_x.add_theme_font_size_override("font_size", 18)
	_x.add_theme_color_override("font_color", UiStyle.NEAR_WHITE)
	var xs := StyleBoxFlat.new()
	xs.bg_color = Color(UiStyle.MIDNIGHT, 0.92)
	xs.set_border_width_all(2)
	xs.border_color = UiStyle.CORAL
	xs.set_corner_radius_all(17)
	for state in ["normal", "hover", "pressed", "focus"]:
		_x.add_theme_stylebox_override(state, xs)
	_x.pressed.connect(func(): remove_requested.emit(index))
	_x.mouse_entered.connect(_on_hover.bind(true))
	_x.visible = false
	add_child(_x)

	resized.connect(_layout)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))
	_layout()


func _layout() -> void:
	var w := size.x
	_room_art.position = Vector2.ZERO
	_room_art.size = Vector2(w, w)
	_frame.position = Vector2(0, -1)
	_frame.size = Vector2(w, w * 1.022)
	_name.size = Vector2(w - 8, 22)
	_name.position = Vector2(4, w - 28)
	_x.size = Vector2(34, 34)
	_x.position = Vector2(w - 38, 4)


func set_room(id: String) -> void:
	room_id = id
	if id == "":
		_room_art.texture = null
		_name.visible = false
	else:
		_room_art.texture = ShipData.room_texture(id)
		_name.text = String(ShipData.room(id)["short"])
		_name.visible = not read_only
	_x.visible = id != "" and not read_only
	queue_redraw()


func pop() -> void:
	_room_art.pivot_offset = _room_art.size * 0.5
	_room_art.scale = Vector2(0.86, 0.86)
	create_tween().tween_property(_room_art, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_hover(inside: bool) -> void:
	hovered.emit(index if inside else -1)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if room_id != "":
				remove_requested.emit(index)
				accept_event()


func _draw() -> void:
	if room_id != "" or read_only:
		return
	var w := size.x
	var col := UiStyle.EDGE
	if button_pressed:
		col = UiStyle.PHOSPHOR
	elif is_hovered() or has_focus():
		col = Color(UiStyle.NEAR_WHITE, 0.95)
	var r := Rect2(16, 18, w - 32, w - 36)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], col, 2.0, 8.0)
	draw_rect(r, Color(UiStyle.COBALT, 0.12))
	var c := r.get_center()
	draw_line(c + Vector2(-16, 0), c + Vector2(16, 0), col, 3.0)
	draw_line(c + Vector2(0, -16), c + Vector2(0, 16), col, 3.0)
	draw_string(UiStyle.MONO, Vector2(0, w - 8), "BAY %d" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(col, 0.9))
