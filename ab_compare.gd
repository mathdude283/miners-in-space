class_name AbCompare
extends Control
## Science Lab job for Contract 02: put the two photos side by side and compare them. A third kind of interaction,
## different from taking a photo and aiming a radio: the player reads the light from the pictures, then decides.
##
## 1. Drag the line to slide between photo A and photo B.
## 2. Say which way the Sun was shining in each photo. Shadows fall away from the Sun, and overhead Sun leaves none.
## 3. Say which photo shows the rays best.
## The marking is CraterScience.evaluate. The Sun-angle rule is REAL (LROC "Sun Angles"); the comparability score is GAME.

signal finished(result: Dictionary)

const FRAME := Vector2(860, 290)

var photo_a := {}
var photo_b := {}
var branch := "reobserve"
var scientist := false            # a fit scientist reads the pictures faster (shown as a note; the time saving is in the task)

var _split := 0.5
var _clip: Control
var _line: ColorRect
var _frame: Control
var _dir_btns := {"a": {}, "b": {}}
var _says := {}
var _rays_btns := {}
var _confirm_btn: Button
var _body: VBoxContainer
var _dragging := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1000, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(24, 0.97))
	center.add_child(p)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	p.add_child(_body)
	_build_questions()
	Sfx.play("stage")


func _name_of(ph: Dictionary) -> String:
	return String(CraterScience.CRATERS.get(String(ph.get("crater", "glushko")), {}).get("name", "Crater")).to_upper()


func _build_questions() -> void:
	_body.add_child(UiStyle.mono_label("SCIENCE LAB", 15, UiStyle.PHOSPHOR))
	_body.add_child(UiStyle.heading("COMPARE THE TWO PHOTOS"))
	_body.add_child(_text("Drag the line to slide between A and B. Then read the light from the pictures.", 18))
	# The comparison frame: B underneath, A clipped to the left of the line
	_frame = Control.new()
	_frame.custom_minimum_size = FRAME
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.gui_input.connect(_on_frame_input)
	_body.add_child(_frame)
	_frame.add_child(_pic(photo_b))
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.size = Vector2(FRAME.x * _split, FRAME.y)
	_frame.add_child(_clip)
	_clip.add_child(_pic(photo_a))
	_line = ColorRect.new()
	_line.color = UiStyle.PHOSPHOR
	_line.size = Vector2(4, FRAME.y)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_line)
	_set_split(0.5)
	for side in ["a", "b"]:
		var tag := UiStyle.mono_label("A  %s" % _name_of(photo_a) if side == "a" else "B  %s" % _name_of(photo_b), 15, UiStyle.NEAR_WHITE)
		tag.position = Vector2(10, 8) if side == "a" else Vector2(FRAME.x - 190, 8)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(tag)
	var sim := UiStyle.mono_label("SIMULATED", 13, Color(UiStyle.AMBER, 0.9))
	sim.position = Vector2(FRAME.x * 0.5 - 40, FRAME.y - 24)
	sim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(sim)

	_body.add_child(UiStyle.mono_label("1   WHICH WAY WAS THE SUN SHINING?   (shadows fall away from the Sun)", 14, UiStyle.PHOSPHOR))
	for side in ["a", "b"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lab := UiStyle.mono_label("PHOTO %s" % side.to_upper(), 15, UiStyle.NEAR_WHITE)
		lab.custom_minimum_size = Vector2(110, 0)
		lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lab)
		for d in [-1, 0, 1]:
			var b := _toggle(CraterScience.direction_name(d))
			b.pressed.connect(func():
				_says["dir_" + side] = d
				_sync())
			row.add_child(b)
			_dir_btns[side][d] = b
		_body.add_child(row)
	_body.add_child(UiStyle.mono_label("2   WHICH PHOTO SHOWS THE CRATER RAYS BEST?", 14, UiStyle.PHOSPHOR))
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 10)
	for k in [["a", "PHOTO A"], ["b", "PHOTO B"], ["same", "ABOUT THE SAME"]]:
		var b := _toggle(k[1])
		var key: String = k[0]
		b.pressed.connect(func():
			_says["rays"] = key
			_sync())
		rr.add_child(b)
		_rays_btns[key] = b
	_body.add_child(rr)
	var foot := HBoxContainer.new()
	var note := UiStyle.mono_label("The Sun-angle rule is REAL (LROC). The comparison score is a GAME rule.", 13, Color(UiStyle.NEAR_WHITE, 0.55))
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(note)
	_confirm_btn = Button.new()
	_confirm_btn.text = "COMPARE"
	_confirm_btn.theme_type_variation = &"PrimaryButton"
	_confirm_btn.add_theme_font_size_override("font_size", 26)
	_confirm_btn.custom_minimum_size = Vector2(320, 76)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_confirm)
	foot.add_child(_confirm_btn)
	_body.add_child(foot)


func _text(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(940, 0)
	return l


func _toggle(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.toggle_mode = true
	b.theme_type_variation = &"OutlineButton"
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	return b


func _pic(ph: Dictionary) -> TextureRect:
	var t := TextureRect.new()
	t.texture = ph.get("tex")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.size = FRAME
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _on_frame_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_split(event.position.x / FRAME.x)
	elif event is InputEventMouseMotion and _dragging:
		_set_split(event.position.x / FRAME.x)


func _set_split(f: float) -> void:
	_split = clampf(f, 0.02, 0.98)
	_clip.size = Vector2(FRAME.x * _split, FRAME.y)
	_line.position = Vector2(FRAME.x * _split - 2.0, 0)


func _sync() -> void:
	for side in ["a", "b"]:
		for d in _dir_btns[side]:
			(_dir_btns[side][d] as Button).button_pressed = _says.get("dir_" + side, 99) == d
	for k in _rays_btns:
		(_rays_btns[k] as Button).button_pressed = _says.get("rays", "") == k
	_confirm_btn.disabled = not (_says.has("dir_a") and _says.has("dir_b") and _says.has("rays"))


func _confirm() -> void:
	if _confirm_btn.disabled:
		return
	var says := {"dir_a": int(_says["dir_a"]), "dir_b": int(_says["dir_b"]), "rays": String(_says["rays"])}
	var ev := CraterScience.evaluate(branch, photo_a, photo_b, says)
	Sfx.play("chime_good" if ev["usable"] else "chime_poor")
	for c in _body.get_children():
		c.queue_free()
	_body.add_child(UiStyle.mono_label("SCIENCE LAB", 15, UiStyle.PHOSPHOR))
	var head := UiStyle.heading("COMPARISON DONE   -   %s" % String(ev["confidence"]))
	head.add_theme_color_override("font_color", UiStyle.PHOSPHOR if ev["usable"] else UiStyle.CORAL)
	_body.add_child(head)
	for line in ev["lines"]:
		_body.add_child(_text(String(line), 19))
	if not bool(ev["usable"]):
		_body.add_child(_text("PROBLEM: " + String(ev["why"]), 19))
		_body.add_child(_text("NEXT TIME: " + String(ev["fix"]), 18))
	_body.add_child(_text("REAL: low Sun casts sharp shadows that show texture. High Sun casts none, so brightness differences like rays stand out. (LROC Sun Angles)", 16))
	var done := Button.new()
	done.text = "DONE"
	done.theme_type_variation = &"PrimaryButton"
	done.add_theme_font_size_override("font_size", 26)
	done.custom_minimum_size = Vector2(260, 70)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.pressed.connect(func(): finished.emit({"says": says, "eval": ev}))
	_body.add_child(done)
