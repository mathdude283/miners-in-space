class_name CountPanel
extends PanelContainer
## The terminal count. The Ground Launch Sequencer reads out the real milestones and the Launch
## Director answers the calls that need an answer. The count can be held until the automated launch
## sequencer takes it at about T-33 seconds; after that nothing can stop it.
##
## Hold rules (NASA, Artemis II launch day): a hold at T-6:00 can last as long as the launch window;
## between T-6:00 and T-1:30 a hold is limited to 3 minutes or the count recycles to T-10:00.

signal finished(result: String)    # "liftoff" | "scrub"
signal milestone(index: int)        # a call was read out
signal clock_changed(text: String)  # the one count clock changed; the flight HUD shows the same time

var _clock: Label
var _status: Label
var _log: VBoxContainer
var _prompt: Label
var _hold_btn: Button
var _go_btn: Button
var _rule: Label

var _t := -600.0
var _holding := false
var _hold_elapsed := 0.0
var _go_pressed := false
var _locked := false          # the automated sequencer has the count
var _recycle_late := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel(22, 0.92))
	custom_minimum_size = Vector2(580, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(UiStyle.mono_label("LAUNCH CONTROL  -  TERMINAL COUNT", 14, UiStyle.PHOSPHOR))
	_clock = Label.new()
	_clock.add_theme_font_override("font", UiStyle.DISPLAY)
	_clock.add_theme_font_size_override("font_size", 64)
	_clock.add_theme_color_override("font_color", UiStyle.NEAR_WHITE)
	_clock.text = "T-10:00"
	col.add_child(_clock)
	_status = UiStyle.mono_label("COUNTING", 17, UiStyle.PHOSPHOR)
	col.add_child(_status)

	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 4)
	_log.custom_minimum_size = Vector2(0, 150)
	col.add_child(_log)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 19)
	_prompt.add_theme_color_override("font_color", UiStyle.AMBER)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(0, 88)
	col.add_child(_prompt)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	_hold_btn = Button.new()
	_hold_btn.text = "HOLD"
	_hold_btn.theme_type_variation = &"OutlineButton"
	_hold_btn.add_theme_font_size_override("font_size", 20)
	_hold_btn.custom_minimum_size = Vector2(190, 72)
	_hold_btn.pressed.connect(_on_hold)
	buttons.add_child(_hold_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(sp)
	_go_btn = Button.new()
	_go_btn.text = "GO"
	_go_btn.theme_type_variation = &"PrimaryButton"
	_go_btn.add_theme_font_size_override("font_size", 34)
	_go_btn.custom_minimum_size = Vector2(250, 92)
	_go_btn.pressed.connect(func(): _go_pressed = true)
	_go_btn.hide()
	buttons.add_child(_go_btn)
	col.add_child(buttons)

	_rule = UiStyle.mono_label("", 14, Color(UiStyle.NEAR_WHITE, 0.6))
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule.custom_minimum_size = Vector2(0, 64)
	col.add_child(_rule)
	_show_clock()


static func fmt(t: float) -> String:
	var a := absf(t)
	var m := int(a) / 60
	var s := int(a) % 60
	var sign := "-" if t <= 0.0 else "+"
	return "T%s%d:%02d" % [sign, m, s]


func _add_log(label: String, text: String) -> void:
	var l := UiStyle.mono_label("%s   %s" % [label, text], 16, UiStyle.NEAR_WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_child(l)
	while _log.get_child_count() > 5:
		var old := _log.get_child(0)
		_log.remove_child(old)
		old.queue_free()
	for i in _log.get_child_count():
		(_log.get_child(i) as Label).add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.45 + 0.55 * float(i + 1) / _log.get_child_count()))


## The count clock has one state, _t. Every display of it and every hold rule reads it here.
func _show_clock() -> void:
	_clock.text = fmt(_t)
	clock_changed.emit(_clock.text)
	_update_rule()


func _zone() -> String:
	return GroundControl.hold_zone(_t, _locked)


func _update_rule() -> void:
	_rule.text = GroundControl.hold_guidance(_zone())


func _on_hold() -> void:
	if _locked:
		return
	_recycle_late = _zone() == "late"
	_holding = not _holding
	Sfx.play("hold")
	_hold_btn.text = "RESUME COUNT" if _holding else "HOLD"
	_hold_elapsed = 0.0


## Runs the whole count. Returns "liftoff" or "scrub".
func run() -> String:
	_add_log("T-10:00", GroundControl.COUNT[0]["text"])
	var idx := 1
	var result := "liftoff"
	while idx < GroundControl.COUNT.size():
		var m: Dictionary = GroundControl.COUNT[idx]
		var from_t := _t
		var target := float(m["t"])
		var dur := float(m["dur"])
		var elapsed := 0.0
		var recycled := false
		while elapsed < dur:
			var d := get_process_delta_time()
			await get_tree().process_frame
			d = get_process_delta_time()
			if _holding and not _locked:
				var cr := _hold_tick(d)
				if cr == "recycle":
					recycled = true
					break
				continue
			elapsed += d
			_t = lerpf(from_t, target, minf(elapsed / maxf(dur, 0.001), 1.0))
			_show_clock()
		if recycled:
			_recycle()
			idx = 1
			continue
		_t = target
		_show_clock()
		_add_log(String(m["label"]), String(m["text"]))
		milestone.emit(idx)
		if m.has("prompt"):
			var r := await _ask(String(m["prompt"]))
			if r == "recycle":
				_recycle()
				idx = 1
				continue
		if m.get("last_hold", false):
			_locked = true
			_hold_btn.disabled = true
			_hold_btn.text = "NO HOLD"
			_update_rule()
			_status.text = "AUTOMATED SEQUENCER HAS THE COUNT"
			_status.add_theme_color_override("font_color", UiStyle.AMBER)
		idx += 1
	_status.text = "LIFTOFF"
	_status.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	return result


## A hold in progress. Returns "recycle" if the hold limit ran out.
func _hold_tick(d: float) -> String:
	_hold_elapsed += d
	_status.text = "HOLD  %s" % _hold_text()
	_status.add_theme_color_override("font_color", UiStyle.AMBER)
	if _zone() == "late":
		return "recycle"            # a stop after T-1:30 and before the sequencer recycles to T-10:00 (press kit)
	if _zone() != "limited":
		return ""
	if _hold_elapsed * GroundControl.HOLD_TIME_SCALE >= GroundControl.HOLD_LIMIT_SECONDS:
		return "recycle"
	return ""


func _hold_text() -> String:
	if _zone() == "late":
		return "(recycles to T-10:00)"
	if _zone() != "limited":
		return "(no limit)"
	var left := GroundControl.HOLD_LIMIT_SECONDS - _hold_elapsed * GroundControl.HOLD_TIME_SCALE
	return "limit %d:%02d" % [int(maxf(left, 0.0)) / 60, int(maxf(left, 0.0)) % 60]


func _recycle() -> void:
	Sfx.play("fail", -4.0)
	_t = -600.0
	_show_clock()
	_holding = false
	_hold_btn.text = "HOLD"
	_go_btn.hide()
	_prompt.text = ""
	for c in _log.get_children():
		c.queue_free()
	_add_log("T-10:00", "The count was stopped too late to hold. It recycles to T-10:00." if _recycle_late else "The hold ran past 3 minutes. The count recycles to T-10:00.")
	_recycle_late = false
	_status.text = "RECYCLED TO T-10:00"
	_status.add_theme_color_override("font_color", UiStyle.AMBER)


func _ask(text: String) -> String:
	_prompt.text = "GLS: " + text
	Sfx.play("stage")
	_go_pressed = false
	_go_btn.show()
	_go_btn.grab_focus()
	_status.text = "WAITING FOR YOUR CALL"
	_status.add_theme_color_override("font_color", UiStyle.AMBER)
	while not _go_pressed:
		await get_tree().process_frame
		if _holding and not _locked:
			var cr := _hold_tick(get_process_delta_time())
			if cr == "recycle":
				return "recycle"
	_go_btn.hide()
	_prompt.text = ""
	_status.text = "COUNTING"
	_status.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	return "go"
