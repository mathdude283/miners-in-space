class_name PassCard
extends Control
## Flight Deck job for Contract 02: choose which crater to observe second, and plan the Sun pass for the next photo.
## Light decides what a photo shows (REAL: LROC "Sun Angles"). The three passes and the waiting times are GAME rules.
## Nothing is spent until the player confirms; cancelling costs nothing.

signal finished(result: Dictionary)

var mission := {}
var branch := ""                 # the second observation, once chosen ("reobserve" or "ohm")
var observation := 0             # 0 = first photo, 1 = second photo
var used: Array = []             # {crater, pass} already observed
var time_left := 0.0
var power_left := 0.0

var _branch_choice := ""
var _pass_choice := ""
var _branch_btns := {}
var _pass_btns := {}
var _go: Button
var _crater_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_branch_choice = branch
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1100, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(28, 0.97))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	col.add_child(UiStyle.mono_label("FLIGHT DECK", 15, UiStyle.PHOSPHOR))
	col.add_child(UiStyle.heading("PLAN THE SUN PASS"))
	col.add_child(_text("Light decides what a photo shows. Low Sun: long shadows show a crater's shape. High Sun: no shadows, so bright rays stand out. Waiting for the Sun costs time.", 19))
	col.add_child(UiStyle.mono_label("REAL: low and high Sun effects follow LROC 'Sun Angles'. GAME: the three passes and the waiting times.", 13, Color(UiStyle.NEAR_WHITE, 0.55)))

	if observation == 0 and branch == "":
		col.add_child(UiStyle.mono_label("1   CHOOSE YOUR SECOND OBSERVATION", 14, UiStyle.PHOSPHOR))
		var br: Dictionary = mission.get("branch", {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		col.add_child(row)
		var blurb := {"reobserve": "Go back to Glushko. You need the Sun to be close to the first photo's, or the two cannot be compared fairly.",
			"ohm": "Observe Ohm instead. Its rays are long, so the Sun should be high when you photograph both craters."}
		for ch in br.get("choices", []):
			var cid := String(ch["id"])
			var b := _choice_button(String(ch["label"]), String(blurb.get(cid, "")))
			b.pressed.connect(func():
				_branch_choice = cid
				_refresh())
			row.add_child(b)
			_branch_btns[cid] = b
	else:
		var which := "Ohm" if branch == "ohm" else "Glushko, in more comparable light"
		if observation == 0:
			col.add_child(UiStyle.mono_label("SECOND OBSERVATION: %s" % which, 14, Color(UiStyle.NEAR_WHITE, 0.7)))
		else:
			col.add_child(UiStyle.mono_label("SECOND OBSERVATION: %s" % which, 14, UiStyle.PHOSPHOR))
	_crater_label = UiStyle.mono_label("", 16, UiStyle.AMBER)
	col.add_child(_crater_label)
	col.add_child(UiStyle.mono_label("%s   PICK THE SUN PASS" % ("2" if observation == 0 and branch == "" else "-"), 14, UiStyle.PHOSPHOR))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 14)
	col.add_child(prow)
	for pa in CraterScience.PASSES:
		var pid := String(pa["id"])
		var b := _choice_button(String(pa["label"]), "")
		b.pressed.connect(func():
			_pass_choice = pid
			_refresh())
		prow.add_child(b)
		_pass_btns[pid] = b
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	var cancel := Button.new()
	cancel.text = "CANCEL (costs nothing)"
	cancel.theme_type_variation = &"OutlineButton"
	cancel.add_theme_font_size_override("font_size", 18)
	cancel.custom_minimum_size = Vector2(0, 66)
	cancel.pressed.connect(func(): finished.emit({"cancelled": true}))
	foot.add_child(cancel)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	_go = Button.new()
	_go.text = "PLAN THIS PASS"
	_go.theme_type_variation = &"PrimaryButton"
	_go.add_theme_font_size_override("font_size", 26)
	_go.custom_minimum_size = Vector2(380, 80)
	_go.pressed.connect(_confirm)
	foot.add_child(_go)
	_refresh()
	Sfx.play("stage")


func _text(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(1040, 0)
	return l


func _choice_button(title: String, blurb: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"OutlineButton"
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(330, 120)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = title if blurb == "" else "%s\n%s" % [title, blurb]
	b.focus_mode = Control.FOCUS_NONE
	return b


func _crater() -> String:
	var b := _branch_choice
	return CraterScience.crater_for(observation, b)


func _wait(pid: String) -> float:
	return CraterScience.wait_for(_crater(), pid, used)


func _afford(pid: String) -> String:
	var w := _wait(pid)
	if w > time_left:
		return "Not enough time left: this pass needs %d minutes." % int(w)
	if power_left < 1.0:
		return "Not enough power."
	return ""


func _refresh() -> void:
	for k in _branch_btns:
		(_branch_btns[k] as Button).button_pressed = _branch_choice == k
	var crater_known := observation == 0 or _branch_choice != ""
	var cname := String(CraterScience.CRATERS[_crater()]["name"])
	_crater_label.text = ("THIS PHOTO IS OF:  %s" % cname.to_upper()) if crater_known else "Choose the second observation first."
	for pa in CraterScience.PASSES:
		var pid := String(pa["id"])
		var b: Button = _pass_btns[pid]
		var w := _wait(pid)
		var why := _afford(pid) if crater_known else ""
		var repeat := w == CraterScience.REPEAT_WAIT and used.any(func(u): return u["crater"] == _crater() and u["pass"] == pid)
		b.text = "%s\n%s\nWAIT %d MIN%s" % [pa["label"], pa["text"], int(w), "  (next orbit)" if repeat else ""]
		b.disabled = why != "" or not crater_known
		b.tooltip_text = why
		b.button_pressed = _pass_choice == pid
	_go.disabled = not crater_known or _pass_choice == "" or _afford(_pass_choice) != ""


func _confirm() -> void:
	if _go.disabled:
		return
	Sfx.play("go")
	finished.emit({"cancelled": false, "branch": _branch_choice, "pass": _pass_choice, "crater": _crater(), "wait": _wait(_pass_choice)})
