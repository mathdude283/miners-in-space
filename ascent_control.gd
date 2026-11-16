class_name AscentControl
extends Control
## Controls the player can use in the air. Two of them:
##   "maxq": through maximum dynamic pressure, HOLD space (or the button) to ease the throttle while the
##           pressure is in the red, and let go when it falls. Too much pressure strains the crew; easing when
##           you do not need to just slows the ship.
##   "sep":  as the boosters burn out, press space once while their thrust is in the green window to separate.
##           Too early or too late and the separation is rough.
## The real separation is automatic and flown by the flight computers; pressing it yourself is a GAME control.
## Returns {quality: 0..1, text: String}.

signal done(result: Dictionary)
signal level(value: float)       # how hard the ship is shaking right now, 0..1.3

const MAXQ_TIME := 8.0
const SEP_TIME := 7.5
const EASE := 0.72
const WINDOW_LO := 0.06
const WINDOW_HI := 0.25

var mode := "maxq"
## The first live attempt of each control starts with a short preview and waits for READY before any timed input.
var preview := false
## Controls already seen this session, so the preview shows once.
static var _seen := {}
var _ready_wait := false
var _hold_on_at := -1.0
var _holds: Array[Vector2] = []              # [start, end] of each hold, in control time
var _first_over_at := -1.0
var _press_th := -1.0
var _t := 0.0
var _held := false
var _over := false
var _stress := 0.0
var _slow := 0.0
var _pressed := false
var _quality := 1.0
var _text := ""
var _end_at := -1.0
var _finished := false
var _gauge: Control
var _title: Label
var _tip: Label
var _btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = -450.0
	p.offset_right = 450.0
	p.offset_top = -400.0
	p.offset_bottom = -100.0
	p.custom_minimum_size = Vector2(900, 280)
	p.add_theme_stylebox_override("panel", UiStyle.panel(18, 0.92))
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiStyle.mono_label("YOUR CONTROL  -  GAME", 13, UiStyle.AMBER))
	_title = UiStyle.heading("MAX Q: EASE THE THROTTLE" if mode == "maxq" else "BOOSTERS BURNING OUT: SEPARATE")
	v.add_child(_title)
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(0, 64)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	v.add_child(_gauge)
	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_font_size_override("font_size", 22)
	_tip.custom_minimum_size = Vector2(0, 62)
	v.add_child(_tip)
	_btn = Button.new()
	_btn.text = "HOLD TO EASE THE THROTTLE   [SPACE]" if mode == "maxq" else "SEPARATE   [SPACE]"
	_btn.theme_type_variation = &"PrimaryButton"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.add_theme_font_size_override("font_size", 24)
	_btn.custom_minimum_size = Vector2(0, 70)
	if mode == "maxq":
		_btn.button_down.connect(func(): _hold(true))
		_btn.button_up.connect(func(): _hold(false))
	else:
		_btn.pressed.connect(_press)
	v.add_child(_btn)
	if preview:
		_ready_wait = true
		_tip.text = _preview_text()
		_btn.text = "READY   [SPACE]"
	Sfx.play("stage")


func _preview_text() -> String:
	if mode == "maxq":
		return "HOW THIS WORKS.  The bar is the air pressure on the rocket. When it crosses the white LIMIT line, HOLD SPACE to ease the throttle. Let go when it falls back. Hold too early and you only slow the ship. Press READY when you are set. (You can also try it in PRACTICE on Mission Select.)"
	return "HOW THIS WORKS.  The boosters burn out and their thrust drops. Press SPACE ONCE while the bar is inside the green window. Too early and the boosters still push; too late and they are dead weight. Press READY when you are set. (You can also try it in PRACTICE on Mission Select.)"


## Pressure through max Q: rises, peaks, falls. 1.0 is the limit the structure is happy with.
func _q(t: float) -> float:
	return 1.35 * exp(-pow(t - MAXQ_TIME * 0.5, 2.0) / (2.0 * 1.36 * 1.36))


## Booster thrust: steady, then tails off.
func _thrust(t: float) -> float:
	return 1.0 if t < 2.5 else exp(-(t - 2.5) * 1.2)


func _unhandled_input(event: InputEvent) -> void:
	if _finished or not (event is InputEventKey) or event.echo or event.keycode != KEY_SPACE:
		return
	if _ready_wait:
		if event.pressed:
			_start_timed()
		get_viewport().set_input_as_handled()
		return
	if mode == "maxq":
		_hold(event.pressed)
	elif event.pressed:
		_press()
	get_viewport().set_input_as_handled()


func _start_timed() -> void:
	if not _ready_wait:
		return
	_ready_wait = false
	_t = 0.0
	_btn.text = "HOLD TO EASE THE THROTTLE   [SPACE]" if mode == "maxq" else "SEPARATE   [SPACE]"
	Sfx.play("go")


func _hold(on: bool) -> void:
	if _ready_wait:
		if on:
			_start_timed()
		return
	if _finished:
		return
	if on and not _held:
		_hold_on_at = _t
	elif not on and _held and _hold_on_at >= 0.0:
		_holds.append(Vector2(_hold_on_at, _t))
		_hold_on_at = -1.0
	_held = on


func _press() -> void:
	if _ready_wait:
		_start_timed()
		return
	if _finished or _pressed or mode != "sep":
		return
	_pressed = true
	var th := _thrust(_t)
	_press_th = th
	if th >= WINDOW_LO and th <= WINDOW_HI:
		_quality = 1.0
		_text = "CLEAN SEPARATION. You pressed in the window."
		Sfx.play("go")
	elif th > WINDOW_HI:
		_quality = clampf(0.9 - th * 0.6, 0.25, 0.75)
		_text = "TOO EARLY. The boosters were still pushing. Rough separation."
		Sfx.play("nogo")
	else:
		_quality = 0.7
		_text = "A LITTLE LATE. The boosters were nearly dead weight."
		Sfx.play("chime_ok")
	_end_at = _t + 1.3


func _process(delta: float) -> void:
	if _finished:
		return
	if _ready_wait:
		_gauge.queue_redraw()
		return
	_t += delta
	if mode == "maxq":
		var q := _q(_t)
		var eff := q * (EASE if _held else 1.0)
		_over = eff > 1.0
		if _over:
			_stress += delta
			if _first_over_at < 0.0:
				_first_over_at = _t
		if _held and q < 0.75:
			_slow += delta
		level.emit(minf(eff, 1.3))
		if _t >= MAXQ_TIME:
			_quality = clampf(1.0 - 0.3 * _stress - 0.12 * _slow, 0.0, 1.0)
			_text = "SMOOTH. The crew barely felt it." if _quality > 0.85 else ("ROUGH. The ship shook hard." if _stress > 0.6 else "A little slow. You eased too long.")
			_finish()
		else:
			_tip.text = _coach(q)
			_tip.add_theme_color_override("font_color", UiStyle.CORAL if _over else (UiStyle.PHOSPHOR if _held else UiStyle.NEAR_WHITE))
	else:
		level.emit(0.5 if _thrust(_t) > 0.3 else 0.15)
		if not _pressed:
			var th := _thrust(_t)
			_tip.text = "Watch the bar. Press SEPARATE when it drops into the GREEN window." if th > WINDOW_HI else ("NOW. Press SEPARATE." if th >= WINDOW_LO else "The window is closing...")
			_tip.add_theme_color_override("font_color", UiStyle.PHOSPHOR if th <= WINDOW_HI and th >= WINDOW_LO else UiStyle.NEAR_WHITE)
			if _t >= SEP_TIME:
				_pressed = true
				_quality = 0.5
				_text = "LATE. The flight computer separated them for you."
				_end_at = _t + 1.0
				Sfx.play("nogo")
		else:
			_tip.text = _text
		if _end_at >= 0.0 and _t >= _end_at:
			_finish()
	_gauge.queue_redraw()


func _coach(q: float) -> String:
	if _held and q < 0.75:
		return "RELEASE. The pressure is low, so you are only slowing the ship."
	if _held:
		return "Good. Holding eases the throttle. Let go when the pressure drops."
	if q >= 0.85:
		return "PRESSURE CLIMBING. HOLD SPACE NOW."
	if _t < MAXQ_TIME * 0.5:
		return "Pressure is rising. Get ready to hold SPACE when the bar nears the red."
	return "Past the peak. Stay released."


## What to do differently, from the inputs the game recorded.
func advice() -> String:
	if mode == "maxq":
		if _hold_on_at >= 0.0:
			_holds.append(Vector2(_hold_on_at, _t))
			_hold_on_at = -1.0
		var held := 0.0
		for h in _holds:
			held += h.y - h.x
		if _stress > 0.6 and _holds.is_empty():
			return "You never held SPACE. The pressure was over the limit for %.1f s. Hold SPACE as soon as the bar passes the LIMIT line." % _stress
		if _stress > 0.6 and _holds.size() > 0 and _first_over_at >= 0.0 and _holds[0].x - _first_over_at > 0.6:
			return "You started holding %.1f s after the pressure passed the limit. Press SPACE sooner, when the bar reaches the line." % (_holds[0].x - _first_over_at)
		if _stress > 0.6:
			return "You held too briefly: the pressure was over the limit for %.1f s while you were off the key. Keep holding until the bar falls below the line." % _stress
		if _slow > 0.6:
			return "You held for %.1f s while the pressure was low, which only slows the ship. Let go as soon as the bar drops under the limit." % _slow
		return "Well done: you held through the peak and let go at the right time."
	if _press_th < 0.0:
		return "You never pressed. The flight computer separated the boosters late. Press SPACE once the bar is in the green window."
	if _press_th > WINDOW_HI:
		return "You separated too early: the boosters were still pushing (thrust %d%%, the green window is %d to %d%%). Wait for the bar to drop into the green." % [int(_press_th * 100.0), int(WINDOW_LO * 100.0), int(WINDOW_HI * 100.0)]
	if _press_th < WINDOW_LO:
		return "You separated a little late: thrust had already dropped to %d%%. Press as the bar enters the green window." % int(_press_th * 100.0)
	return "Clean: you pressed inside the green window."


func _finish() -> void:
	if _finished:
		return
	_finished = true
	level.emit(0.0)
	AscentControl._seen[mode] = true
	var adv := advice()
	_tip.text = "%s   %s" % [_text, adv]
	_btn.hide()
	var result := {"quality": _quality, "text": _text, "advice": adv}
	# Give the player a moment to read what happened before the flight goes on
	await get_tree().create_timer(2.8, true, false, true).timeout
	done.emit(result)


func _draw_gauge() -> void:
	var w := _gauge.size.x
	var h := 34.0
	var y := 14.0
	_gauge.draw_rect(Rect2(0, y, w, h), Color(UiStyle.COBALT, 0.3))
	if mode == "maxq":
		var sc := w / 1.5
		var q := _q(_t) * (EASE if _held else 1.0)
		_gauge.draw_rect(Rect2(sc * 1.0, y, w - sc * 1.0, h), Color(UiStyle.CORAL, 0.35))
		_gauge.draw_rect(Rect2(0, y, sc * clampf(q, 0.0, 1.5), h), UiStyle.CORAL if q > 1.0 else UiStyle.PHOSPHOR)
		_gauge.draw_line(Vector2(sc, y - 6), Vector2(sc, y + h + 6), Color.WHITE, 3.0)
		_gauge.draw_string(UiStyle.MONO, Vector2(sc + 8.0, y + h + 22.0), "LIMIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.CORAL)
		_gauge.draw_string(UiStyle.MONO, Vector2(0, y + h + 22.0), "DYNAMIC PRESSURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UiStyle.NEAR_WHITE, 0.7))
		_gauge.draw_rect(Rect2(0, 0, w * clampf(_t / MAXQ_TIME, 0.0, 1.0), 5.0), Color(UiStyle.NEAR_WHITE, 0.5))
	else:
		_gauge.draw_rect(Rect2(w * WINDOW_LO, y - 4.0, w * (WINDOW_HI - WINDOW_LO), h + 8.0), Color(UiStyle.PHOSPHOR, 0.35))
		_gauge.draw_rect(Rect2(w * WINDOW_LO, y - 4.0, w * (WINDOW_HI - WINDOW_LO), h + 8.0), UiStyle.PHOSPHOR, false, 3.0)
		var th := _thrust(_t)
		_gauge.draw_rect(Rect2(0, y, w * th, h), UiStyle.AMBER if th > WINDOW_HI else UiStyle.PHOSPHOR)
		_gauge.draw_string(UiStyle.MONO, Vector2(w * WINDOW_LO, y + h + 22.0), "SEPARATE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.PHOSPHOR)
		_gauge.draw_string(UiStyle.MONO, Vector2(w - 220.0, y + h + 22.0), "BOOSTER THRUST", HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 14, Color(UiStyle.NEAR_WHITE, 0.7))
	_gauge.draw_rect(Rect2(0, y, w, h), Color(UiStyle.CHROME, 0.7), false, 2.0)
