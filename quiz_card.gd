class_name QuizCard
extends Control
## Mission Control's quiz: a few questions about what you just did (or about real mission designs), answered with one click each.
## Every answer explains why and says whether the fact is REAL (with its source) or a GAME rule. Right answers earn points, and a
## streak of right answers earns more. Wrong answers cost nothing but show the reason.

signal finished(result: Dictionary)

const POINTS_RIGHT := 100
const POINTS_STREAK := 25

var questions: Array = []
var title_text := "MISSION CONTROL QUIZ"

var _i := 0
var _correct := 0
var _points := 0
var _streak := 0
var _answered := false
var _order: Array[int] = []
var _head: Label
var _q: Label
var _opts: VBoxContainer
var _why: Label
var _src: Label
var _score: Label
var _next: Button
var _coach_box: Control


func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(28, 0.97))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(1200, 0)
	p.add_child(col)
	var top := HBoxContainer.new()
	_head = UiStyle.mono_label("", 14, UiStyle.AMBER)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_head)
	_score = UiStyle.mono_label("", 16, UiStyle.PHOSPHOR)
	top.add_child(_score)
	col.add_child(top)
	_q = Label.new()
	_q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_q.add_theme_font_size_override("font_size", 28)
	_q.custom_minimum_size = Vector2(1140, 0)
	col.add_child(_q)
	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 10)
	col.add_child(_opts)
	_why = Label.new()
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.add_theme_font_size_override("font_size", 20)
	_why.custom_minimum_size = Vector2(1140, 0)
	col.add_child(_why)
	_src = UiStyle.mono_label("", 13, Color(UiStyle.NEAR_WHITE, 0.65))
	_src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_src.custom_minimum_size = Vector2(1140, 0)
	col.add_child(_src)
	_next = Button.new()
	_next.theme_type_variation = &"PrimaryButton"
	_next.add_theme_font_size_override("font_size", 26)
	_next.custom_minimum_size = Vector2(360, 84)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(_advance)
	col.add_child(_next)
	_show()


func _show() -> void:
	_answered = false
	var q: Dictionary = questions[_i]
	_head.text = "%s   -   %s   -   QUESTION %d OF %d" % [title_text, String(q.get("mission", "")), _i + 1, questions.size()] if q.has("mission") else "%s   -   QUESTION %d OF %d" % [title_text, _i + 1, questions.size()]
	_score.text = "%d POINTS%s" % [_points, ("   STREAK x%d" % _streak) if _streak >= 2 else ""]
	_q.text = String(q["q"])
	_why.text = ""
	_src.text = ""
	_next.visible = false
	for c in _opts.get_children():
		_opts.remove_child(c)
		c.queue_free()
	# the right answer is never always the first one: shuffle with a fixed seed per question
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(q["q"]))
	_order.clear()
	for k in (q["options"] as Array).size():
		_order.append(k)
	for k in range(_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t := _order[k]
		_order[k] = _order[j]
		_order[j] = t
	for slot in _order.size():
		var b := Button.new()
		b.text = String(q["options"][_order[slot]])
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 21)
		b.custom_minimum_size = Vector2(0, 76)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): answer(slot))
		_opts.add_child(b)


## Choose the option in this position. Public so a test can stand in for the click.
func answer(slot: int) -> void:
	if _answered or slot < 0 or slot >= _order.size():
		return
	_answered = true
	var q: Dictionary = questions[_i]
	var right := _order[slot] == int(q["answer"])
	if right:
		_correct += 1
		_streak += 1
		_points += POINTS_RIGHT + POINTS_STREAK * maxi(_streak - 1, 0)
		Sfx.play("chime_good")
	else:
		_streak = 0
		Sfx.play("chime_poor")
	for k in _opts.get_child_count():
		var b: Button = _opts.get_child(k)
		b.disabled = true
		if _order[k] == int(q["answer"]):
			b.add_theme_color_override("font_disabled_color", UiStyle.PHOSPHOR)
			b.text = "RIGHT:  " + b.text
		elif k == slot:
			b.add_theme_color_override("font_disabled_color", UiStyle.CORAL)
			b.text = "NOT QUITE:  " + b.text
	_why.text = ("Correct. " if right else "Here is why. ") + String(q["why"])
	_why.add_theme_color_override("font_color", UiStyle.PHOSPHOR if right else UiStyle.AMBER)
	_src.text = String(q.get("source", ""))
	_score.text = "%d POINTS%s" % [_points, ("   STREAK x%d" % _streak) if _streak >= 2 else ""]
	_next.text = "NEXT QUESTION" if _i < questions.size() - 1 else "FINISH"
	_next.visible = true


func _advance() -> void:
	if not _answered:
		return
	if _i < questions.size() - 1:
		_i += 1
		_show()
	else:
		finished.emit({"correct": _correct, "total": questions.size(), "points": _points})
		queue_free()


## Go on to the next question or finish. Public so a test can stand in for the click.
func advance() -> void:
	_advance()
