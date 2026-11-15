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
	Sfx.play("stage")


## Pressure through max Q: rises, peaks, falls. 1.0 is the limit the structure is happy with.
func _q(t: float) -> float:
	return 1.35 * exp(-pow(t - MAXQ_TIME * 0.5, 2.0) / (2.0 * 1.36 * 1.36))


## Booster thrust: steady, then tails off.
func _thrust(t: float) -> float:
	return 1.0 if t < 2.5 else exp(-(t - 2.5) * 1.2)


func _unhandled_input(event: InputEvent) -> void:
	if _finished or not (event is InputEventKey) or event.echo or event.keycode != KEY_SPACE:
		return
	if mode == "maxq":
		_hold(event.pressed)
	elif event.pressed:
		_press()
	get_viewport().set_input_as_handled()


func _hold(on: bool) -> void:
	if not _finished:
		_held = on


func _press() -> void:
	if _finished or _pressed or mode != "sep":
		return
	_pressed = true
	var th := _thrust(_t)
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
	_t += delta
	if mode == "maxq":
		var q := _q(_t)
		var eff := q * (EASE if _held else 1.0)
		_over = eff > 1.0
		if _over:
			_stress += delta
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


func _finish() -> void:
	if _finished:
		return
	_finished = true
	level.emit(0.0)
	done.emit({"quality": _quality, "text": _text})


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
