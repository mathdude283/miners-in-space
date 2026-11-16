class_name ReturnPhase
extends Control
## The way home: crew module separation, the entry angle, re-entry, parachutes and splashdown, then recovery.
## The beats follow NASA's description of Orion's return on Artemis II (April 2026 flight-day pages). The controls (a timing
## press for the entry angle, holding to keep the g-load down, two parachute presses) are GAME. All numbers in the controls
## are game rules; the REAL lines say what NASA reported. Every injury has a reason, and a death names its cause.
##
## REAL (NASA, Artemis II, nasa.gov/blogs/missions/2026/04/10/ flight-day 10 pages):
##  - the crew module separates from the service module, which is meant to burn up over the Pacific;
##  - a crew module raise burn of about 18 seconds sets the entry angle and aligns the heat shield;
##  - entry interface at about 400,000 feet, nearly 35 times the speed of sound, up to 3.9 g planned;
##  - about six minutes of communications blackout while plasma forms;
##  - drogue parachutes near 22,000 feet, then three main parachutes near 6,000 feet, slowing Orion to about 20 mph;
##  - splashdown in the Pacific off San Diego, then recovery by Navy divers, a raft, helicopters and the USS John P. Murtha.

signal finished(result: Dictionary)

const G_LIMIT := 3.9                 # REAL: the planned peak load for the crew. The limit in the game too.
const ENTRY_TIME := 9.0
const DROGUE_ALT := 22000.0          # REAL: near 22,000 ft (the pre-flight press kit planned 25,000)
const MAIN_ALT := 6000.0             # REAL: near 6,000 ft
const DROGUE_WINDOW := 2500.0        # GAME: how far either side still counts as on time
const MAIN_WINDOW := 1500.0
const START_ALT := 40000.0
const SPLASH_MPH := 20.0             # REAL: about 20 mph at splashdown

var run: MissionRun

var _beat := "sep"
var _t := 0.0
var _held := false
var _quality := 1.0                  # entry angle, 0 to 1
var _over := 0.0                     # seconds above the g limit
var _slow := 0.0                     # seconds of lift held when it was not needed (the capsule lands off target)
var _alt := START_ALT
var _drogue_alt := -1.0
var _main_alt := -1.0
var _speed_mph := 0.0
var _notes: Array[String] = []
var _done := false

var _real: Label
var _title: Label
var _tip: Label
var _gauge: Control
var _btn: Button
var _fx: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/select/bg_earth_orbit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var layer := Decor.frame_layer(self)
	var p := PanelContainer.new()
	p.position = Vector2(400, 190)
	p.custom_minimum_size = Vector2(1120, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(24, 0.94))
	layer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UiStyle.mono_label("RETURN TO EARTH", 15, UiStyle.PHOSPHOR))
	_title = UiStyle.heading("")
	v.add_child(_title)
	_real = Label.new()
	_real.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_real.custom_minimum_size = Vector2(1060, 0)
	_real.add_theme_font_size_override("font_size", 18)
	_real.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.78))
	v.add_child(_real)
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(0, 190)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	v.add_child(_gauge)
	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(1060, 64)
	_tip.add_theme_font_size_override("font_size", 22)
	v.add_child(_tip)
	_btn = Button.new()
	_btn.theme_type_variation = &"PrimaryButton"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.add_theme_font_size_override("font_size", 26)
	_btn.custom_minimum_size = Vector2(0, 76)
	_btn.button_down.connect(func(): _hold(true))
	_btn.button_up.connect(func(): _hold(false))
	_btn.pressed.connect(_on_button)
	v.add_child(_btn)
	_enter("sep")


# ---------------------------------------------------------------- beats

func _enter(beat: String) -> void:
	_beat = beat
	_t = 0.0
	Sfx.play("stage")
	match beat:
		"sep":
			_title.text = "CREW MODULE SEPARATES"
			_real.text = "REAL (Artemis II): the crew module separates from the service module, which is meant to burn up over the Pacific. A crew module raise burn of about 18 seconds then sets the entry angle and lines up the heat shield."
			_tip.text = "Your service module has done its job. Next you set the entry angle."
			_btn.text = "CONTINUE   [SPACE]"
		"angle":
			_title.text = "SET THE ENTRY ANGLE"
			_real.text = "REAL: the raise burn sets the angle the capsule meets the air at. GAME control: press once while the marker is in the green. Too shallow or too steep means a harder entry."
			_tip.text = "Press when the marker is in the green."
			_btn.text = "FIRE THE RAISE BURN   [SPACE]"
		"entry":
			_title.text = "RE-ENTRY: KEEP THE LOAD DOWN"
			_real.text = "REAL: entry interface is about 400,000 feet up at nearly 35 times the speed of sound, with up to 3.9 g planned. Communications black out for about six minutes while plasma forms. GAME control: hold to lift the capsule and ease the load."
			_tip.text = "HOLD while the line is above the limit. Let go when it falls back."
			_btn.text = "HOLD TO EASE THE LOAD   [SPACE]"
		"chutes":
			_title.text = "PARACHUTES"
			_real.text = "REAL: drogue parachutes open near 22,000 feet, then three main parachutes near 6,000 feet, slowing Orion to about 20 mph for splashdown. GAME control: press once for each, inside the green band."
			_tip.text = "1.  Press for the DROGUES near 22,000 feet."
			_btn.text = "DEPLOY DROGUES   [SPACE]"
		"splash":
			_apply_splashdown()
			_btn.text = "CONTINUE   [SPACE]"
	_gauge.queue_redraw()


func _on_button() -> void:
	press()


## The one control. A press means different things in each beat. Public so a test can stand in for the player.
func press() -> void:
	if _done:
		return
	match _beat:
		"sep":
			_enter("angle")
		"angle":
			var m := _marker()
			_quality = clampf(1.0 - absf(m - 0.5) / 0.4, 0.0, 1.0)
			if _quality >= 0.8:
				_notes.append("Entry angle: clean.")
				Sfx.play("go")
			else:
				_notes.append("Entry angle: %s." % ("too shallow" if m < 0.5 else "too steep"))
				Sfx.play("nogo")
			_enter("entry")
		"chutes":
			if _drogue_alt < 0.0:
				_drogue_alt = _alt
				Sfx.play("go")
				_tip.text = "2.  Press for the MAIN parachutes near 6,000 feet."
				_btn.text = "DEPLOY MAIN PARACHUTES   [SPACE]"
			elif _main_alt < 0.0:
				_main_alt = _alt
				Sfx.play("go")
		"splash":
			_finish()


func _hold(on: bool) -> void:
	if _beat == "entry":
		_held = on


func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or event.echo or event.keycode != KEY_SPACE:
		return
	if _beat == "entry":
		_hold(event.pressed)
	elif event.pressed:
		press()
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- the numbers (pure, so they can be tested)

## 0 to 1, sweeping back and forth. The green zone is around 0.5.
func _marker() -> float:
	return 0.5 + 0.5 * sin(_t * 2.1)


## The peak load for an entry angle of quality q (1 is clean). A clean entry peaks at the planned 3.9 g.
static func peak_g(q: float) -> float:
	return G_LIMIT * (1.0 + (1.0 - q) * 0.55)


static func g_at(t: float, q: float) -> float:
	return peak_g(q) * exp(-pow(t - ENTRY_TIME * 0.5, 2.0) / (2.0 * 1.5 * 1.5))


## Splashdown speed in mph from where the two parachute presses happened (altitude in feet, or -1 if never pressed).
## On time is about 20 mph, as NASA reported. Pressing off the band costs speed.
static func splash_speed(drogue_alt: float, main_alt: float) -> float:
	var speed := SPLASH_MPH
	if drogue_alt < 0.0 or absf(drogue_alt - DROGUE_ALT) > DROGUE_WINDOW:
		speed += 8.0
	if main_alt < 0.0:
		speed += 45.0
	elif main_alt < MAIN_ALT - MAIN_WINDOW:
		speed += minf((MAIN_ALT - MAIN_WINDOW - main_alt) / 1500.0 * 22.0, 45.0)
	elif main_alt > MAIN_ALT + MAIN_WINDOW:
		speed += 10.0
	return speed


## Health lost at splashdown from the speed (a hard landing hurts). 30 mph and under is fine.
static func splash_damage(speed_mph: float) -> float:
	return maxf(speed_mph - 30.0, 0.0) * 1.1


## Health lost to the entry load from the seconds spent above the limit.
static func entry_damage(over_seconds: float) -> float:
	return minf(over_seconds * 7.0, 40.0)


# ---------------------------------------------------------------- the clock

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	match _beat:
		"angle":
			if _t > 12.0:
				press()                     # nobody pressed: the burn fires at the wrong moment
		"entry":
			var g := g_at(_t, _quality)
			var eff := g * (0.72 if _held else 1.0)
			if eff > G_LIMIT:
				_over += delta
			if _held and g < G_LIMIT * 0.6:
				_slow += delta
			if _t >= ENTRY_TIME:
				_finish_entry()
		"chutes":
			var rate := 2600.0
			if _drogue_alt >= 0.0:
				rate = 1500.0
			if _main_alt >= 0.0:
				rate = 500.0
			_alt = maxf(_alt - rate * delta, 0.0)
			if _drogue_alt < 0.0 and _alt <= 15000.0:
				_drogue_alt = _alt           # the drogues open on their own, late
				_notes.append("Drogues opened late: nobody pressed in time.")
				_tip.text = "2.  Press for the MAIN parachutes near 6,000 feet."
				_btn.text = "DEPLOY MAIN PARACHUTES   [SPACE]"
			if _drogue_alt >= 0.0 and _main_alt < 0.0 and _alt <= 2000.0:
				_main_alt = _alt
				_notes.append("Main parachutes opened late: nobody pressed in time.")
			if _alt <= 0.0 or (_drogue_alt >= 0.0 and _main_alt >= 0.0 and _alt <= 1000.0):
				_enter("splash")
	_gauge.queue_redraw()
	_fx.queue_redraw()


func _finish_entry() -> void:
	var dmg := entry_damage(_over)
	if dmg > 0.0:
		_notes.append("Re-entry load stayed above %.1f g for %.1f s." % [G_LIMIT, _over])
		run.hurt_all(dmg, "The re-entry load stayed above %.1f g for %.1f seconds, so the crew was crushed into their seats." % [G_LIMIT, _over], "Hurt by re-entry g-load")
	else:
		_notes.append("Re-entry: the load stayed inside the limit.")
	if _slow > 1.5:
		_notes.append("You held lift when it was not needed, so the capsule landed far from the target ship.")
	_enter("chutes")


func _apply_splashdown() -> void:
	_speed_mph = splash_speed(_drogue_alt, _main_alt)
	var dmg := splash_damage(_speed_mph)
	_title.text = "SPLASHDOWN"
	if dmg > 0.0:
		_notes.append("Splashdown at %d mph." % int(round(_speed_mph)))
		run.hurt_all(dmg, "The capsule hit the water at %d mph because the parachutes opened late or too early, and the crew took the impact." % int(round(_speed_mph)), "Hurt by a hard splashdown")
		_real.text = "REAL: Orion splashed down at about 20 mph in the Pacific off San Diego. Yours hit at %d mph. That is a hard landing." % int(round(_speed_mph))
	else:
		_notes.append("Splashdown at %d mph: soft." % int(round(_speed_mph)))
		_real.text = "REAL: Orion splashed down at about 20 mph in the Pacific off San Diego. Yours hit at %d mph. A soft landing." % int(round(_speed_mph))
	_tip.text = "Recovery teams reach the capsule. REAL (Artemis II): Navy divers help the crew onto a raft, helicopters carry them to the recovery ship, and the capsule is brought back to San Diego. Crew alive: %d of %d." % [run.alive_count(), run.crew.size()]
	_gauge.queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit({"landed": run.alive_count() > 0, "speed_mph": _speed_mph, "notes": _notes.duplicate(), "angle": _quality,
		"over_seconds": _over, "drogue_alt": _drogue_alt, "main_alt": _main_alt, "alive": run.alive_count()})


# ---------------------------------------------------------------- drawing

func _draw_fx() -> void:
	if _beat == "entry":
		# A glow around the capsule while the plasma forms
		var f := clampf(sin(_t / ENTRY_TIME * PI), 0.0, 1.0)
		var c := Vector2(size.x * 0.5, size.y - 160.0)
		_fx.draw_circle(c, 70.0 + 40.0 * f, Color(1.0, 0.5, 0.15, 0.25 * f))
		_fx.draw_circle(c, 40.0 + 20.0 * f, Color(1.0, 0.8, 0.4, 0.35 * f))
	if _beat == "chutes" or _beat == "splash":
		var c2 := Vector2(size.x * 0.5, size.y - 120.0)
		if _drogue_alt >= 0.0 and _beat == "chutes":
			_fx.draw_arc(c2 + Vector2(0, -90), 40.0, PI, TAU, 24, Color(UiStyle.AMBER, 0.9), 5.0, true)
		if _main_alt >= 0.0 and _beat == "chutes":
			for k in 3:
				_fx.draw_arc(c2 + Vector2((k - 1) * 90.0, -150), 55.0, PI, TAU, 24, Color(UiStyle.PHOSPHOR, 0.9), 6.0, true)
	if _beat == "splash":
		_fx.draw_rect(Rect2(0, size.y - 110, size.x, 110), Color(0.1, 0.3, 0.7, 0.55))


func _draw_gauge() -> void:
	var g := _gauge
	var w := g.size.x
	var h := g.size.y
	g.draw_rect(Rect2(0, 0, w, h), Color(UiStyle.MIDNIGHT, 0.7))
	g.draw_rect(Rect2(0, 0, w, h), Color(UiStyle.EDGE, 0.6), false, 2.0)
	match _beat:
		"angle":
			g.draw_rect(Rect2(w * 0.4, 20, w * 0.2, h - 40), Color(UiStyle.PHOSPHOR, 0.25))
			g.draw_rect(Rect2(w * 0.4, 20, w * 0.2, h - 40), UiStyle.PHOSPHOR, false, 3.0)
			var mx := w * _marker()
			g.draw_line(Vector2(mx, 10), Vector2(mx, h - 10), UiStyle.AMBER, 6.0)
			g.draw_string(UiStyle.MONO, Vector2(20, h - 12), "TOO SHALLOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UiStyle.NEAR_WHITE, 0.6))
			g.draw_string(UiStyle.MONO, Vector2(w - 160, h - 12), "TOO STEEP", HORIZONTAL_ALIGNMENT_RIGHT, 140, 15, Color(UiStyle.NEAR_WHITE, 0.6))
		"entry":
			var top := 12.0
			var bottom := h - 28.0
			var ymax := 6.5
			var limit_y := bottom - (G_LIMIT / ymax) * (bottom - top)
			g.draw_line(Vector2(0, limit_y), Vector2(w, limit_y), UiStyle.CORAL, 3.0)
			g.draw_string(UiStyle.MONO, Vector2(10, limit_y - 6), "LIMIT %.1f g" % G_LIMIT, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.CORAL)
			var prev := Vector2.ZERO
			for i in 61:
				var tt := ENTRY_TIME * float(i) / 60.0
				var gg := g_at(tt, _quality)
				var pt := Vector2(w * float(i) / 60.0, bottom - (gg / ymax) * (bottom - top))
				if i > 0:
					g.draw_line(prev, pt, Color(UiStyle.NEAR_WHITE, 0.35), 2.0)
				prev = pt
			var now_g := g_at(_t, _quality)
			var eff := now_g * (0.72 if _held else 1.0)
			var nx := w * clampf(_t / ENTRY_TIME, 0.0, 1.0)
			var ny := bottom - (eff / ymax) * (bottom - top)
			g.draw_circle(Vector2(nx, ny), 9.0, UiStyle.CORAL if eff > G_LIMIT else UiStyle.PHOSPHOR)
			g.draw_string(UiStyle.MONO, Vector2(w - 330, 24), "LOAD %.1f g" % eff, HORIZONTAL_ALIGNMENT_RIGHT, 310, 20, UiStyle.CORAL if eff > G_LIMIT else UiStyle.PHOSPHOR)
			if _t > 1.5 and _t < 7.5:
				g.draw_string(UiStyle.MONO, Vector2(10, h - 8), "COMMS BLACKOUT (about six minutes in real life)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.AMBER)
		"chutes":
			var ay := func(alt: float) -> float: return 10.0 + (1.0 - alt / START_ALT) * (h - 30.0)
			g.draw_line(Vector2(w * 0.5, 10), Vector2(w * 0.5, h - 20), Color(UiStyle.NEAR_WHITE, 0.25), 2.0)
			g.draw_rect(Rect2(w * 0.3, ay.call(DROGUE_ALT + DROGUE_WINDOW), w * 0.4, ay.call(DROGUE_ALT - DROGUE_WINDOW) - ay.call(DROGUE_ALT + DROGUE_WINDOW)), Color(UiStyle.PHOSPHOR, 0.22))
			g.draw_rect(Rect2(w * 0.3, ay.call(MAIN_ALT + MAIN_WINDOW), w * 0.4, ay.call(MAIN_ALT - MAIN_WINDOW) - ay.call(MAIN_ALT + MAIN_WINDOW)), Color(UiStyle.PHOSPHOR, 0.22))
			g.draw_string(UiStyle.MONO, Vector2(w * 0.72, ay.call(DROGUE_ALT) + 5), "DROGUES  ~22,000 ft", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.PHOSPHOR)
			g.draw_string(UiStyle.MONO, Vector2(w * 0.72, ay.call(MAIN_ALT) + 5), "MAINS  ~6,000 ft", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.PHOSPHOR)
			var yy: float = ay.call(_alt)
			g.draw_circle(Vector2(w * 0.5, yy), 10.0, UiStyle.AMBER)
			g.draw_string(UiStyle.MONO, Vector2(20, 26), "ALTITUDE  %d ft" % int(round(_alt / 100.0) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiStyle.NEAR_WHITE)
		"splash":
			g.draw_string(UiStyle.MONO, Vector2(30, 60), "SPLASHDOWN SPEED   %d mph   (NASA: about 20 mph)" % int(round(_speed_mph)), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiStyle.PHOSPHOR if _speed_mph <= 30.0 else UiStyle.CORAL)
			var y := 100.0
			for n in _notes:
				g.draw_string(UiStyle.MONO, Vector2(30, y), "- " + n, HORIZONTAL_ALIGNMENT_LEFT, w - 60, 15, Color(UiStyle.NEAR_WHITE, 0.85))
				y += 24.0
		_:
			g.draw_string(UiStyle.MONO, Vector2(30, h * 0.5), "Crew module and service module part ways.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UiStyle.NEAR_WHITE, 0.8))
