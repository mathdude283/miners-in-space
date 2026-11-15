class_name CrewAlerts
extends Control
## Tells the player exactly what happened to the crew, the moment it happens.
##   Every time someone loses health: ONE short notice per event (people hurt by the same thing are grouped), saying who,
##   how much, and WHY. It sits at the right, beside the crew panel, so it never covers a poll. Each notice has an X.
##   Every time someone dies: a pop-up in the middle of the screen with their portrait and the cause (people who died of
##   the same cause share one pop-up). It stays until the player clicks OK or X, and they are taken off the ship.
## Each person's own hearts still change one by one. Add one to any screen that has a MissionRun and call setup(run).

signal death_acknowledged(index: int)

const GROUP_WINDOW := 0.3           # seconds to wait for the others hurt by the same event

var _run: MissionRun
var _toasts: VBoxContainer
var _popup: PanelContainer
var _queue: Array[Dictionary] = []     # {indices, cause}
var _showing := false
var _hurt_pending: Array[Dictionary] = []
var _dead_pending: Array[int] = []
var _flush_set := false


func setup(run: MissionRun) -> void:
	_run = run
	run.crew_hurt.connect(_on_hurt)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_top = 380.0
	_toasts.offset_right = -28.0
	_toasts.offset_left = -384.0
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


func _hearts_text(amount: float) -> String:
	var h := amount / 20.0
	if h >= 0.95:
		return "%d heart%s" % [roundi(h), "" if roundi(h) == 1 else "s"]
	return "part of a heart"


func _on_hurt(index: int, amount: float, reason: String, died: bool) -> void:
	if died:
		_dead_pending.append(index)
		Sfx.play("fail")
	else:
		_hurt_pending.append({"index": index, "amount": amount, "reason": reason})
		Sfx.play("error", -6.0)
	if not _flush_set:
		_flush_set = true
		get_tree().create_timer(GROUP_WINDOW, true, false, true).timeout.connect(_flush)


## Turn everything that happened in the last moment into one notice per reason.
func _flush() -> void:
	_flush_set = false
	var groups := {}
	var order: Array[String] = []
	for h in _hurt_pending:
		var r := String(h["reason"])
		if not groups.has(r):
			groups[r] = []
			order.append(r)
		groups[r].append(h)
	_hurt_pending.clear()
	for r in order:
		var list: Array = groups[r]
		var names: Array[String] = []
		var chars: Array[String] = []
		var amount := 0.0
		for h in list:
			var c: Dictionary = _run.crew[int(h["index"])]
			names.append(String(c["name"]).to_upper())
			chars.append(String(c["char"]))
			amount = maxf(amount, float(h["amount"]))
		var who := _join(names)
		var text := ""
		if names.size() == 1:
			text = "%s lost %s: %s" % [who, _hearts_text(amount), r]
		else:
			text = "%s each lost %s: %s" % [who, _hearts_text(amount), r]
		_toast(text, chars)
	var dgroups := {}
	var dorder: Array[String] = []
	for i in _dead_pending:
		var cause := String(_run.crew[i].get("cause", ""))
		if not dgroups.has(cause):
			dgroups[cause] = []
			dorder.append(cause)
		dgroups[cause].append(i)
	_dead_pending.clear()
	for cause in dorder:
		var idx: Array[int] = []
		for i in dgroups[cause]:
			idx.append(int(i))
		_queue.append({"indices": idx, "cause": cause})
	_next_death()


func _join(names: Array[String]) -> String:
	if names.size() <= 1:
		return names[0] if names.size() == 1 else ""
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


func _toast(text: String, chars: Array[String]) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiStyle.panel(10, 0.94))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var faces := VBoxContainer.new()
	faces.add_theme_constant_override("separation", 2)
	faces.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for ch in chars.slice(0, 3):
		var pic := TextureRect.new()
		pic.texture = CrewData.portrait(ch)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(40, 40) if chars.size() > 1 else Vector2(52, 52)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		faces.add_child(pic)
	h.add_child(faces)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(236, 0)
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", UiStyle.AMBER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	h.add_child(_x_button(func(): p.queue_free()))
	_toasts.add_child(p)
	var tw := create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


## A small X that closes a notice so the screen underneath can be seen.
func _x_button(on_press: Callable) -> Button:
	var b := Button.new()
	b.text = "X"
	b.tooltip_text = "Close"
	b.theme_type_variation = &"OutlineButton"
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(on_press)
	return b


func _next_death() -> void:
	if _showing or _queue.is_empty():
		return
	_showing = true
	var d: Dictionary = _queue.pop_front()
	var indices: Array = d["indices"]
	var names: Array[String] = []
	for i in indices:
		names.append(String(_run.crew[int(i)]["name"]))
	var upper: Array[String] = []
	for n in names:
		upper.append(n.to_upper())
	_popup = PanelContainer.new()
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_popup.custom_minimum_size = Vector2(820, 0)
	_popup.add_theme_stylebox_override("panel", UiStyle.panel(26, 0.97))
	add_child(_popup)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	_popup.add_child(h)
	var faces := HBoxContainer.new()
	faces.add_theme_constant_override("separation", -30 if indices.size() > 1 else 0)
	faces.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in indices:
		var pic := TextureRect.new()
		pic.texture = CrewData.portrait(String(_run.crew[int(i)]["char"]))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(150, 150) if indices.size() > 1 else Vector2(170, 170)
		pic.modulate = Color(0.45, 0.45, 0.5)
		faces.add_child(pic)
	h.add_child(faces)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HBoxContainer.new()
	var lost_label := UiStyle.mono_label("CREW MEMBER LOST" if indices.size() == 1 else "CREW LOST", 14, UiStyle.CORAL)
	lost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lost_label)
	v.add_child(top)
	var head := UiStyle.heading("%s DIED" % _join(upper) if indices.size() == 1 else "%s DIED" % _join(upper))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(520, 0)
	head.add_theme_color_override("font_color", UiStyle.CORAL)
	v.add_child(head)
	var why := Label.new()
	why.text = "Cause: " + String(d["cause"])
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(560, 0)
	why.add_theme_font_size_override("font_size", 22)
	v.add_child(why)
	var note := Label.new()
	var nn := _join(names)
	note.text = ("%s is taken off the ship and is gone for good. The rest of the crew carries on." % nn) if indices.size() == 1 else ("%s are taken off the ship and are gone for good." % nn)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.75))
	v.add_child(note)
	var ok := Button.new()
	ok.text = "OK"
	ok.theme_type_variation = &"PrimaryButton"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(220, 72)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.add_theme_font_size_override("font_size", 26)
	var close_popup := func():
		if _popup == null or not is_instance_valid(_popup):
			return
		_popup.queue_free()
		_popup = null
		_showing = false
		for i in indices:
			death_acknowledged.emit(int(i))
		_next_death()
	ok.pressed.connect(close_popup)
	top.add_child(_x_button(close_popup))
	v.add_child(ok)
	# Click only: a stray key press must not hide the explanation.
	ok.disabled = true
	get_tree().create_timer(0.7, true, false, true).timeout.connect(func():
		if is_instance_valid(ok):
			ok.disabled = false)
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
