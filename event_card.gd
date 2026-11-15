class_name EventCard
extends Control
## A decision during operations (MissionEvents). Shows what happened and the choices with what each costs. After the
## player chooses it carries the choice out and says exactly what it did, including anyone hurt and why.

signal finished(result: Dictionary)

var run: MissionRun
var state: BuildState
var event := {}
var actor := 0

var _body: VBoxContainer
var _btns: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.02, 0.04, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(900, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(28, 0.97))
	center.add_child(p)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	p.add_child(_body)
	_body.add_child(UiStyle.mono_label("SOMETHING HAPPENED   -   GAME EVENT", 14, UiStyle.AMBER))
	var h := UiStyle.heading(String(event["title"]))
	h.add_theme_color_override("font_color", UiStyle.AMBER)
	_body.add_child(h)
	_body.add_child(_text(String(event["text"]), 22))
	for i in event["choices"].size():
		var ch: Dictionary = event["choices"][i]
		var why := MissionEvents.blocked(ch, state)
		var t := MissionEvents.time_cost(ch, state)
		var bits: Array[String] = []
		if t > 0.0:
			bits.append("%d MIN" % int(t))
		if float(ch.get("power", 0.0)) > 0.0:
			bits.append("%d POWER" % int(ch["power"]))
		if ch.has("hurt_all") or ch.has("hurt_one"):
			bits.append("RISK TO THE CREW")
		var b := Button.new()
		b.text = "%s\n%s" % [ch["label"], ("COSTS " + "   ".join(bits)) if not bits.is_empty() else "COSTS NOTHING NOW"] if why == "" else "%s\n%s" % [ch["label"], why]
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 19)
		b.custom_minimum_size = Vector2(0, 84)
		b.disabled = why != ""
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _choose(i))
		_body.add_child(b)
		_btns.append(b)
	Music.play("event")
	Sfx.play("error", -8.0, 0.8)


func _text(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(840, 0)
	return l


## Carry out choice i. Public so a test can stand in for the player's click.
func choose(i: int) -> void:
	_choose(i)


func _choose(i: int) -> void:
	if i < 0 or i >= _btns.size() or _btns[i].disabled:
		return
	var out := MissionEvents.apply(run, event, i, state, actor)
	Sfx.play("go")
	for c in _body.get_children():
		c.queue_free()
	_body.add_child(UiStyle.mono_label("WHAT YOU DID", 14, UiStyle.PHOSPHOR))
	var h := UiStyle.heading(String(event["choices"][i]["label"]))
	_body.add_child(h)
	for line in out["lines"]:
		_body.add_child(_text(String(line), 20))
	if out["lines"].is_empty():
		_body.add_child(_text("Nothing more came of it.", 20))
	var ok := Button.new()
	ok.text = "OK"
	ok.theme_type_variation = &"PrimaryButton"
	ok.add_theme_font_size_override("font_size", 26)
	ok.custom_minimum_size = Vector2(240, 70)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func(): finished.emit(out))
	_body.add_child(ok)
