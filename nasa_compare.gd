class_name NasaCompare
extends Control
## One useful comparison: NASA's real, annotated view of the Orientale basin next to the player's simulated photo.
## The player finds two things in NASA's image: the dark basin interior and the bright mountain rings around it.
## The image is REAL (credit: NASA, from the Artemis II flight day 6 lunar flyby blog, 6 April 2026). The player's photo is
## SIMULATED. Framing, steadiness and illumination of the player's shot stay separate factors, shown below.

signal finished(result: Dictionary)

const IMAGE := "res://assets/nasa/orientale_crop.jpg"
const SOURCE_URL := "https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/"
const SIZE := 560.0                    # the crop is shown this big (it is 640 px)
const SCALE := SIZE / 640.0
## In the 640 px crop: the dark interior is an ellipse, the bright rings are a band around its centre.
const INTERIOR_C := Vector2(322.0, 352.0)
const INTERIOR_R := Vector2(88.0, 72.0)
const RING_C := Vector2(330.0, 350.0)
const RING_IN := 118.0
const RING_OUT := 245.0

var framing := 0.0                     # the player's own shot: three separate factors, 0 to 1, or -1 if not captured
var steady := 0.0
var light := 0.0

var _step := 0
var _interior_ok := false
var _rings_ok := false
var _pic: TextureRect
var _task: Label
var _feedback: Label
var _done_btn: Button
var _marks: Control
var _click := Vector2(-1, -1)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(22, 0.97))
	center.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	p.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	_pic = TextureRect.new()
	_pic.texture = load(IMAGE)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.custom_minimum_size = Vector2(SIZE, SIZE)
	_pic.mouse_filter = Control.MOUSE_FILTER_STOP
	_pic.gui_input.connect(_on_pic_input)
	left.add_child(_pic)
	_marks = Control.new()
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	_pic.add_child(_marks)
	left.add_child(UiStyle.mono_label("REAL: NASA's annotated far-side view, Artemis II flyby. Credit: NASA.", 12, Color(UiStyle.NEAR_WHITE, 0.7)))
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(520, 0)
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	right.add_child(UiStyle.mono_label("COMPARE WITH NASA", 14, UiStyle.PHOSPHOR))
	right.add_child(UiStyle.heading("FIND THE BASIN"))
	_task = Label.new()
	_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task.custom_minimum_size = Vector2(500, 90)
	_task.add_theme_font_size_override("font_size", 22)
	right.add_child(_task)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(500, 150)
	_feedback.add_theme_font_size_override("font_size", 18)
	_feedback.add_theme_color_override("font_color", UiStyle.AMBER)
	right.add_child(_feedback)
	var factors := "YOUR PHOTO (game scores)   FRAMED %d%%   STEADY %d%%   LIGHT %d%%" % [int(framing * 100.0), int(steady * 100.0), int(light * 100.0)] if framing >= 0.0 else "YOUR PHOTO: none to compare."
	right.add_child(UiStyle.mono_label(factors, 13, Color(UiStyle.NEAR_WHITE, 0.8)))
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(500, 0)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.75))
	note.text = "Three things shape a photo, and they are separate: how well it is FRAMED, how STEADY the camera was, and the ILLUMINATION. In NASA's view the Sun is high enough that the dark interior and the bright rings both stand out. Low Sun would show shadows and ridges instead (LROC Sun Angles)."
	right.add_child(note)
	_done_btn = Button.new()
	_done_btn.text = "SKIP"
	_done_btn.theme_type_variation = &"OutlineButton"
	_done_btn.add_theme_font_size_override("font_size", 22)
	_done_btn.custom_minimum_size = Vector2(0, 64)
	_done_btn.focus_mode = Control.FOCUS_NONE
	_done_btn.pressed.connect(_finish)
	right.add_child(_done_btn)
	_set_step(0)


func _set_step(n: int) -> void:
	_step = n
	match n:
		0:
			_task.text = "1.  Click the DARK basin interior: the smooth, darker patch inside the basin."
		1:
			_task.text = "2.  Now click one of the BRIGHT mountain rings: the rough, lighter bands around the dark interior."
		_:
			_task.text = "Done. Dark interior: %s.  Bright rings: %s." % ["found" if _interior_ok else "missed", "found" if _rings_ok else "missed"]
			_done_btn.text = "CONTINUE"
			_done_btn.theme_type_variation = &"PrimaryButton"


func _on_pic_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position / SCALE
	_click = event.position
	choose(p)
	_marks.queue_redraw()


## Judge a click at a point in the 640 px crop. Public so a test can stand in for the player.
func choose(p: Vector2) -> void:
	if _step == 0:
		var d := (p - INTERIOR_C) / INTERIOR_R
		_interior_ok = d.length() <= 1.0
		_feedback.text = ("Yes. That smooth dark patch is the basin interior." if _interior_ok else "Not quite. The dark interior is the smooth, darker patch near the centre, under the label.")
		_set_step(1)
	elif _step == 1:
		var r := p.distance_to(RING_C)
		_rings_ok = r >= RING_IN and r <= RING_OUT and (p - INTERIOR_C).length() > 60.0
		_feedback.text = ("Yes. Those lighter, rougher bands are rings of raised ground around the basin." if _rings_ok else "Not quite. The rings are the lighter, rougher bands that circle the dark interior.")
		_set_step(2)


func _finish() -> void:
	finished.emit({"interior": _interior_ok, "rings": _rings_ok, "done": _step >= 2})
	queue_free()


func _draw_marks() -> void:
	if _click.x >= 0.0:
		_marks.draw_arc(_click, 14.0, 0, TAU, 24, UiStyle.PHOSPHOR if (_step == 1 and _interior_ok) or (_step == 2 and _rings_ok) else UiStyle.CORAL, 3.0, true)
