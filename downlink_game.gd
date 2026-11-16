class_name DownlinkGame
extends Control
## Sending the photos home. The player steers the ship's dish at Earth to keep the signal strong while
## the data goes out. Only a photo that arrives COMPLETE counts, so the order matters. Partway through,
## the ship passes behind the Moon and the signal is lost until it clears the Moon again.
##
## NASA (Artemis II): the Near Space Network and Deep Space Network antennas on Earth pick up the ship's
## signal; Orion had a planned blackout of about 41 minutes behind the Moon, where the Moon blocks radio.
## Telemetry is what the ship tells us; commands are what we tell the ship. The dish aiming and the
## blackout timing here are simplified game rules.
## nasa.gov/missions/artemis/networks-keeping-nasas-artemis-ii-mission-connected/

signal finished(result: Dictionary)

const WINDOW := 32.0
## One forecast blackout while the Moon is between the ship and Earth (game seconds). REAL: NASA planned about 40 minutes
## without contact behind the Moon on flight day 6 (6:44 to 7:25 p.m. EDT). The timing here is a GAME compression.
const LOS_WINDOWS := [[11.0, 17.0]]
const PACKETS := {"wide": 8, "close": 10}
const CENTER := Vector2(520, 560)
const PULSE: Texture2D = preload("res://assets/ui/play/overlay_radio_signal_pulse.png")

## What the ship gives you (GAME rules): beam is how wide the radio lock is.
var perks := {"beam": 0.30, "rows": []}
var photos: Array[Dictionary] = []        # {lens, stars, tex, confidence}
var _order: Array[String] = []
var _progress := {}                       # lens -> packets sent
var _t := 0.0
var _phase := "brief"
var _dish := 0.0
var _signal := 0.0
var _los := false
var _sent: Array[String] = []
var _fast := false                         # data rate: SLOW is forgiving, FAST needs a better aim
var _rate_btn: Button
var _coach: Label
var _ever_locked := false
var _deco: Control
var _was_locked := false
var _was_los := false
var _pk_last := 0
var _t_open := 0.0                 # seconds the radio could be used (not behind the Moon)
var _t_locked := 0.0               # of those, seconds with a good lock
var _t_fast := 0.0                 # of those, seconds sending FAST
var _goal_panel: Control
var _goal: Label
var _streak := 0.0                         # seconds of clean lock in a row

var _scope: Control
var _status: Label
var _timer: Label
var _queue_box: VBoxContainer
var _bars := {}
var _panel: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.97)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE      # a ColorRect stops the mouse by default, which froze the dish
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	for ph in photos:
		_order.append(_key(ph))
		_progress[_key(ph)] = 0.0
	_show_brief()


## How a photo is told apart in the queue: its own key if it has one (contract 02), else its lens.
func _key(ph: Dictionary) -> String:
	return String(ph.get("key", ph["lens"]))


func _photo(lens: String) -> Dictionary:
	for p in photos:
		if _key(p) == lens:
			return p
	return {}


func _need(key: String) -> int:
	var ph := _photo(key)
	return int(PACKETS.get(String(ph.get("lens", key)), 8))


func _name(key: String) -> String:
	var ph := _photo(key)
	if ph.has("label"):
		return String(ph["label"])
	return "WIDE" if String(ph.get("lens", key)) == "wide" else "CLOSE-UP"


## Seconds until contact returns, while the Moon blocks it.
func _contact_returns_in() -> float:
	for w in LOS_WINDOWS:
		if _t >= w[0] and _t < w[1]:
			return float(w[1]) - _t
	return 0.0


func _earth_angle() -> float:
	return _earth_angle_at(_t)


func _earth_angle_at(t: float) -> float:
	return sin(t * 0.55 + 1.2) * 0.9 + sin(t * 1.4) * 0.22


func _in_los() -> bool:
	for w in LOS_WINDOWS:
		if _t >= w[0] and _t < w[1]:
			return true
	return false


# ---------------------------------------------------------------- brief

func _show_brief() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = center
	# Y2K decoration pack from the team Drive, beside the panel (never over it, never clickable)
	_deco = Decor.frame_layer(self, center)
	Decor.add(_deco, "glossy_radar_burst", Rect2(80, 360, 360, 360), {"alpha": 0.95, "spin": 60.0})
	Decor.add(_deco, "glossy_orbital_chrome_cluster", Rect2(1480, 360, 360, 360), {"alpha": 0.95, "bob": 7.0})
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(980, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(30, 0.95))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	col.add_child(UiStyle.mono_label("05  RADIO", 15, UiStyle.PHOSPHOR))
	col.add_child(UiStyle.heading("SEND IT HOME"))
	var goal := Label.new()
	goal.text = "You send the photos yourself. Your photos only count once they reach Earth."
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.add_theme_font_size_override("font_size", 21)
	col.add_child(goal)
	for line in [
		["1  AIM", "Move the mouse. The green beam points at the mouse. Put it on EARTH (the blue ball)."],
		["2  KEEP IT THERE", "Earth drifts, so keep following it. While the beam is on Earth the bars fill. A photo only counts when its bar is full."],
		["BLACKOUT", "One blackout is forecast. The Moon blocks the radio and nothing sends until contact returns. You can reorder the queue while it lasts."],
		["YOUR SHIP", ShipData.perk_summary(perks, "radio")],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var tag := UiStyle.mono_label(line[0], 14, UiStyle.PHOSPHOR)
		tag.custom_minimum_size = Vector2(150, 0)
		row.add_child(tag)
		var l := Label.new()
		l.text = line[1]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.9))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		col.add_child(row)
	var note := UiStyle.mono_label("NASA: antennas on Earth, including the Deep Space Network, pick up the ship's signal. Artemis II was planned to lose contact for about 41 minutes behind the Moon. Dish aiming and data rates here are game rules.", 13, Color(UiStyle.NEAR_WHITE, 0.55))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	var go := Button.new()
	go.text = "START SENDING"
	go.theme_type_variation = &"PrimaryButton"
	go.add_theme_font_size_override("font_size", 28)
	go.custom_minimum_size = Vector2(400, 100)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.pressed.connect(_start)
	go.focus_mode = Control.FOCUS_NONE   # click only: the instructions stay up until you click
	col.add_child(go)


func _start() -> void:
	if _deco != null:
		_deco.queue_free()
		_deco = null
	_panel.queue_free()
	_phase = "send"
	_t = 0.0
	_build_hud()


func _build_hud() -> void:
	_scope = Control.new()
	_scope.position = Vector2(90, 150)
	_scope.size = Vector2(900, 760)
	_scope.draw.connect(_draw_scope)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scope)
	_panel = Control.new()
	add_child(_panel)
	# The how-to stays up until the player clicks GOT IT
	var howto := HowToCard.new()
	howto.position = Vector2(1040, 560)
	_panel.add_child(howto)
	# Pinned goal strip
	var gp := PanelContainer.new()
	gp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	gp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	gp.offset_left = -470.0
	gp.offset_right = 470.0
	gp.offset_top = 22.0
	gp.offset_bottom = 70.0
	gp.custom_minimum_size = Vector2(940, 48)
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gp.add_theme_stylebox_override("panel", UiStyle.panel(12, 0.86))
	add_child(gp)
	_goal = UiStyle.mono_label("", 17, UiStyle.NEAR_WHITE)
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gp.add_child(_goal)
	_goal_panel = gp
	howto.setup("HOW TO SEND THE PHOTOS", [
		["1  AIM", "Move the mouse. The green beam points at it. Put the beam on Earth."],
		["2  KEEP IT THERE", "Keep following Earth. While the beam is on it, the bars fill."],
		["FULL BAR", "A photo counts only when its bar is full."],
	])

	var title := UiStyle.heading("RADIO LINK")
	title.position = Vector2(90, 100)
	_panel.add_child(title)
	_timer = UiStyle.mono_label("", 20, UiStyle.NEAR_WHITE)
	_timer.position = Vector2(500, 106)
	_panel.add_child(_timer)
	var fc := UiStyle.mono_label("BLACKOUT FORECAST: the Moon blocks contact from %d s to %d s (silent for %d s). Contact returns at %d s. REAL: NASA planned about 40 minutes without contact behind the Moon. The game compresses it." % [int(LOS_WINDOWS[0][0]), int(LOS_WINDOWS[0][1]), int(LOS_WINDOWS[0][1] - LOS_WINDOWS[0][0]), int(LOS_WINDOWS[0][1])], 14, UiStyle.AMBER)
	fc.position = Vector2(90, 918)
	fc.size = Vector2(900, 60)
	fc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(fc)

	var qp := PanelContainer.new()
	qp.position = Vector2(1040, 150)
	qp.custom_minimum_size = Vector2(790, 0)
	qp.add_theme_stylebox_override("panel", UiStyle.panel(18, 0.9))
	_panel.add_child(qp)
	var qc := VBoxContainer.new()
	qc.add_theme_constant_override("separation", 10)
	qp.add_child(qc)
	qc.add_child(UiStyle.mono_label("PHOTOS TO SEND   (the top one goes first)", 14, UiStyle.PHOSPHOR))
	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 10)
	qc.add_child(_queue_box)
	_update_rate_button()
	_status = UiStyle.mono_label("AIM AT EARTH", 22, UiStyle.AMBER)
	qc.add_child(_status)
	_coach = Label.new()
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach.custom_minimum_size = Vector2(0, 80)
	_coach.add_theme_font_size_override("font_size", 20)
	_coach.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.92))
	qc.add_child(_coach)
	_rebuild_queue()


func _toggle_rate() -> void:
	_fast = not _fast
	Sfx.play("lock" if _fast else "back", -4.0, 1.2 if _fast else 1.0)
	_update_rate_button()


func _update_rate_button() -> void:
	if _rate_btn == null:
		return
	_rate_btn.text = "DATA RATE: FAST   (needs a strong signal)   [SPACE]" if _fast else "DATA RATE: SLOW   (forgiving)   [SPACE]"


func _lock_needed() -> float:
	return 0.35


func _rebuild_queue() -> void:
	for c in _queue_box.get_children():
		c.queue_free()
	_bars.clear()
	for i in _order.size():
		var lens := _order[i]
		var ph := _photo(lens)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiStyle.panel(10, 0.85))
		_queue_box.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		row.add_child(h)
		var t := TextureRect.new()
		t.texture = ph.get("tex")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(150, 92)
		h.add_child(t)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_theme_constant_override("separation", 4)
		h.add_child(v)
		v.add_child(UiStyle.mono_label("%d.  %s  %s  %s   VALUE %d   %d PACKETS" % [i + 1, _name(lens), "*".repeat(int(ph.get("stars", 1))), ph.get("confidence", ""), int(ph.get("stars", 1)), _need(lens)], 15, UiStyle.NEAR_WHITE))
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 26)
		bar.draw.connect(_draw_bar.bind(bar, lens))
		v.add_child(bar)
		_bars[lens] = bar
		if _order.size() > 1 and _phase == "send":
			# Reordering is the decision the blackout offers: nothing can be sent while the Moon blocks contact
			var b := Button.new()
			b.text = "SEND FIRST" if i > 0 else "FIRST"
			b.disabled = i == 0 or not _los
			b.tooltip_text = "You can reorder the queue during the blackout." if not _los else ""
			b.theme_type_variation = &"OutlineButton"
			b.add_theme_font_size_override("font_size", 15)
			b.custom_minimum_size = Vector2(130, 44)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func():
				_order.erase(lens)
				_order.insert(0, lens)
				_rebuild_queue())
			h.add_child(b)


func _draw_bar(bar: Control, lens: String) -> void:
	var need: int = _need(lens)
	var done: float = float(_progress.get(lens, 0.0))
	var w := bar.size.x
	var seg := (w - 3.0 * (need - 1)) / need
	for i in need:
		var r := Rect2(i * (seg + 3.0), 0, seg, bar.size.y)
		var full := done >= i + 1
		var part := clampf(done - i, 0.0, 1.0)
		bar.draw_rect(r, Color(UiStyle.COBALT, 0.3))
		if full:
			bar.draw_rect(r, UiStyle.PHOSPHOR)
		elif part > 0.0:
			bar.draw_rect(Rect2(r.position, Vector2(r.size.x * part, r.size.y)), Color(UiStyle.PHOSPHOR, 0.7))
	if done >= need:
		bar.draw_string(UiStyle.MONO, Vector2(w - 90, 19), "RECEIVED", HORIZONTAL_ALIGNMENT_RIGHT, 88, 14, UiStyle.MIDNIGHT)


# ---------------------------------------------------------------- the link

func _draw_earth(s: Control, c: Vector2, r: float) -> void:
	s.draw_circle(c, r + 10.0, Color(0.3, 0.6, 1.0, 0.12))
	s.draw_circle(c, r + 4.0, Color(0.4, 0.7, 1.0, 0.25))
	s.draw_circle(c, r, Color(0.05, 0.2, 0.62, 1))
	for blob in [[Vector2(-12, -8), 11.0], [Vector2(-4, -12), 8.0], [Vector2(12, 6), 9.0], [Vector2(8, 16), 6.0]]:
		s.draw_circle(c + blob[0], blob[1], Color(0.22, 0.5, 0.3, 0.95))
	for k in 3:
		s.draw_arc(c + Vector2(0, -10 + k * 14), r * 0.8, 0.2, 2.6, 16, Color(1, 1, 1, 0.35), 3.0, true)
	s.draw_circle(c + Vector2(10, 8), r * 0.92, Color(0.0, 0.02, 0.1, 0.38))
	s.draw_arc(c, r, 0, TAU, 40, Color(0.7, 0.9, 1.0, 0.9), 2.0, true)


func _draw_scope() -> void:
	var s := _scope
	var o := CENTER - s.position
	s.draw_rect(Rect2(Vector2.ZERO, s.size), Color(UiStyle.MIDNIGHT, 1.0))
	for i in 40:
		var sp := Vector2(fposmod(i * 197.0, s.size.x), fposmod(i * 331.0, s.size.y))
		s.draw_circle(sp, 1.2 + float(i % 3) * 0.5, Color(1, 1, 1, 0.25 + 0.1 * float(i % 4)))
	s.draw_rect(Rect2(Vector2.ZERO, s.size), Color(UiStyle.EDGE, 0.6), false, 2.0)
	# Chrome radar burst behind the ship and a slow HUD ring around it (Y2K decoration pack)
	var burst := Decor.tex("glossy_radar_burst")
	s.draw_texture_rect(burst, Rect2(o - Vector2(330, 330), Vector2(660, 660)), false, Color(1, 1, 1, 0.16))
	var ring := Decor.tex("decor_radial_interface_arc")
	s.draw_set_transform(o, _t * 0.4, Vector2.ONE)
	s.draw_texture_rect(ring, Rect2(Vector2(-170, -170), Vector2(340, 340)), false, Color(1, 1, 1, 0.5))
	s.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Arc where Earth moves
	s.draw_arc(o, 330.0, -PI / 2.0 - 1.3, -PI / 2.0 + 1.3, 60, Color(UiStyle.EDGE, 0.4), 1.5, true)
	var ea := _earth_angle()
	var earth := o + Vector2.UP.rotated(ea) * 330.0
	if _phase == "send":
		# Where Earth is heading: aim a little ahead of it
		for k in 3:
			var fa := _earth_angle_at(_t + 0.45 * (k + 1))
			s.draw_circle(o + Vector2.UP.rotated(fa) * 330.0, 4.5 - k, Color(UiStyle.NEAR_WHITE, 0.55 - 0.15 * k))
	_draw_earth(s, earth, 38.0)
	if _signal > _lock_needed() and not _los and _phase == "send":
		# Radio pulse rings travel out of Earth while the link holds
		for k in 2:
			var f := fposmod(_t * (1.6 if _fast else 0.9) + k * 0.5, 1.0)
			var sz := lerpf(70.0, 190.0, f)
			s.draw_texture_rect(PULSE, Rect2(earth - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, (1.0 - f) * 0.75))
	if not _ever_locked and _phase == "send":
		s.draw_arc(earth, 56.0 + sin(_t * 6.0) * 5.0, 0, TAU, 48, Color(UiStyle.AMBER, 0.9), 3.0, true)
		s.draw_string(UiStyle.MONO, earth + Vector2(-110, -66), "PUT THE BEAM HERE", HORIZONTAL_ALIGNMENT_CENTER, 220, 14, UiStyle.AMBER)
	if _signal > _lock_needed() and not _los:
		s.draw_arc(earth, 52.0 + sin(_t * 8.0) * 3.0, 0, TAU, 48, Color(UiStyle.PHOSPHOR, 0.8), 3.0, true)
	s.draw_string(UiStyle.MONO, earth + Vector2(-30, 74), "EARTH", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(0.7, 0.9, 1.0, 0.9))
	# The Moon slides across the line to Earth during a blackout
	var moon_x := 0.0
	for w in LOS_WINDOWS:
		if _t >= w[0] - 1.0 and _t < w[1] + 1.0:
			var f: float = (_t - (w[0] - 1.0)) / (w[1] - w[0] + 2.0)
			moon_x = lerpf(-520.0, 520.0, f)
			var mp := o + Vector2(moon_x, -170.0)
			s.draw_circle(mp, 150.0, Color(0.55, 0.58, 0.66, 1.0))
			for cr in [[Vector2(-60, -40), 26.0], [Vector2(40, 30), 38.0], [Vector2(-20, 70), 16.0], [Vector2(70, -60), 14.0]]:
				s.draw_arc(mp + cr[0], cr[1], 0, TAU, 28, Color(0.3, 0.33, 0.42, 0.8), 3.0, true)
			s.draw_arc(mp, 150.0, 0, TAU, 64, Color(UiStyle.CHROME, 0.7), 3.0, true)
			s.draw_string(UiStyle.MONO, mp + Vector2(-30, 6), "MOON", HORIZONTAL_ALIGNMENT_CENTER, 60, 16, Color(0.1, 0.12, 0.2, 0.9))
	# Ship: a chrome hull seen from above
	var hull := PackedVector2Array([o + Vector2(-46, 0), o + Vector2(-26, -20), o + Vector2(30, -20), o + Vector2(52, 0), o + Vector2(30, 20), o + Vector2(-26, 20)])
	s.draw_colored_polygon(hull, Color(0.46, 0.52, 0.7, 1))
	s.draw_polyline(hull + PackedVector2Array([hull[0]]), Color(UiStyle.CHROME, 0.95), 2.5)
	s.draw_line(o + Vector2(-26, -20), o + Vector2(-26, 20), Color(UiStyle.COBALT, 0.9), 2.0)
	s.draw_rect(Rect2(o + Vector2(-64, -6), Vector2(18, 12)), Color(UiStyle.COBALT, 0.95))
	# Dish and beam
	var tip := o + Vector2.UP.rotated(_dish) * 300.0
	var side := Vector2.UP.rotated(_dish + PI / 2.0) * 34.0 * (float(perks.get("beam", 0.30)) / 0.30)
	var beam_col := UiStyle.PHOSPHOR if _signal > _lock_needed() and not _los else (UiStyle.CORAL if _los else UiStyle.AMBER)
	s.draw_colored_polygon(PackedVector2Array([o, tip + side, tip - side]), Color(beam_col, 0.10 + 0.18 * _signal))
	s.draw_line(o, tip, Color(beam_col, 0.9), 3.0)
	s.draw_circle(o, 12.0, beam_col)
	# Data packets riding the beam to Earth
	if _signal > _lock_needed() and not _los and _phase == "send":
		for i in (12 if _fast else 6):
			var f := fposmod(_t * (1.8 if _fast else 0.9) + i / (12.0 if _fast else 6.0), 1.0)
			s.draw_circle(o.lerp(earth, f), 5.0, Color(UiStyle.PHOSPHOR, 0.9 * (1.0 - f * 0.5)))
	# Steady-lock bonus readout
	var holding := _signal > _lock_needed() and not _los
	s.draw_string(UiStyle.MONO, Vector2(s.size.x - 300.0, 36.0), "LOCK  %.1f s" % _streak, HORIZONTAL_ALIGNMENT_RIGHT, 280.0, 18, UiStyle.PHOSPHOR if holding else Color(UiStyle.NEAR_WHITE, 0.5))
	s.draw_string(UiStyle.MONO, Vector2(s.size.x - 300.0, 60.0), "STEADY BONUS  +%d%%" % int(minf(_streak, 4.0) * 8.0), HORIZONTAL_ALIGNMENT_RIGHT, 280.0, 16, UiStyle.AMBER if _streak > 0.5 else Color(UiStyle.NEAR_WHITE, 0.4))
	# Signal meter
	var mx := 20.0
	var my := s.size.y - 54.0
	s.draw_string(UiStyle.MONO, Vector2(mx, my - 8), "SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UiStyle.NEAR_WHITE, 0.8))
	for i in 12:
		var r := Rect2(mx + i * 26.0, my, 22.0, 24.0)
		s.draw_rect(r, Color(UiStyle.COBALT, 0.3))
		if (i + 1) / 12.0 <= _signal + 0.001:
			s.draw_rect(r, UiStyle.PHOSPHOR if _signal > 0.6 else UiStyle.AMBER)


## The dish follows the mouse. This control stops mouse events, so they arrive here and not in _unhandled_input.
func _gui_input(event: InputEvent) -> void:
	if _phase == "send" and event is InputEventMouseMotion:
		var d: Vector2 = event.position - CENTER
		_dish = clampf(atan2(d.x, -d.y), -1.4, 1.4)
		accept_event()


func _process(delta: float) -> void:
	if _phase != "send":
		return
	_t += delta
	_los = _in_los()
	var diff := absf(_dish - _earth_angle())
	_signal = 0.0 if _los else clampf(1.0 - diff / float(perks.get("beam", 0.30)), 0.0, 1.0)
	if _signal > _lock_needed():
		_streak += delta
		# Holding the beam steady builds a bonus (up to +32%)
		var rate := 2.0 * _signal * (1.0 + minf(_streak, 4.0) * 0.08)
		for lens in _order:
			var need: int = _need(lens)
			if float(_progress[lens]) < need:
				_progress[lens] = minf(float(_progress[lens]) + rate * delta, float(need))
				break
	if _signal <= _lock_needed():
		_streak = 0.0
	if _los:
		_status.text = "LOSS OF SIGNAL: behind the Moon"
		_status.add_theme_color_override("font_color", UiStyle.CORAL)
	elif _signal > _lock_needed():
		_status.text = "SENDING  -  BEAM ON EARTH"
		_status.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	else:
		_status.text = "OFF TARGET  -  MOVE THE BEAM TO EARTH"
		_status.add_theme_color_override("font_color", UiStyle.AMBER)
	var locked := _signal > _lock_needed() and not _los
	if locked and not _was_locked:
		Sfx.play("lock")
	elif _was_locked and not locked and not _los:
		Sfx.play("lost", -4.0)
	_was_locked = locked
	if not _los:
		_t_open += delta
		if locked:
			_t_locked += delta
			if _fast:
				_t_fast += delta
	if _los and not _was_los:
		Sfx.play("static")
		_rebuild_queue()
	elif _was_los and not _los:
		Sfx.play("lock", -3.0)
		_rebuild_queue()
	_was_los = _los
	var total := 0
	for lens in _order:
		total += int(floor(float(_progress[lens])))
	if total > _pk_last:
		Sfx.play("packet", -6.0, 1.0 + 0.03 * float(total % 8))
	_pk_last = total
	if _signal > _lock_needed() and not _los:
		_ever_locked = true
	var tip := ""
	var next_los := false
	for w in LOS_WINDOWS:
		if _t >= w[0] - 3.0 and _t < w[0]:
			next_los = true
	if _los:
		tip = "BLACKOUT. Contact returns in %d s. Nothing sends now. Use the time to decide which photo goes first (SEND FIRST)." % int(ceil(_contact_returns_in()))
	elif next_los:
		tip = "The Moon is about to block the signal. Send as much as you can now."
	elif not _ever_locked:
		tip = "Move the mouse until the green beam is on Earth (the blue ball)."
	elif _signal <= _lock_needed():
		tip = "You lost Earth. Move the beam back onto it. The SIGNAL bar shows how close you are."
	else:
		tip = "Sending. Keep following Earth. The bars fill while the beam is on it."
	_coach.text = tip
	if _goal != null:
		var got := 0
		for lens in _order:
			if float(_progress[lens]) >= float(_need(lens)):
				got += 1
		_goal.text = "GOAL: get every photo to Earth before the window closes     RECEIVED %d / %d" % [got, _order.size()]
	_timer.text = "DOWNLINK WINDOW  %d s" % int(ceil(maxf(WINDOW - _t, 0.0)))
	_scope.queue_redraw()
	for k in _bars:
		_bars[k].queue_redraw()
	var all_in := true
	for lens in _order:
		if float(_progress[lens]) < float(_need(lens)):
			all_in = false
	if _t >= WINDOW or all_in:
		_done()


func _done() -> void:
	_phase = "done"
	var received: Array[String] = []
	var lost: Array[String] = []
	for lens in _order:
		if float(_progress[lens]) >= float(_need(lens)):
			received.append(lens)
		else:
			lost.append(lens)
	Sfx.play("received" if not received.is_empty() else "fail")
	if _goal_panel != null:
		_goal_panel.queue_free()
		_goal_panel = null
		_goal = null
	if not received.is_empty():
		var spark := Decor.frame_layer(self)
		Decor.add(spark, "decor_chrome_star_cluster", Rect2(300, 330, 230, 230), {"pulse": 0.6})
		Decor.add(spark, "decor_chrome_star_cluster", Rect2(1390, 330, 230, 230), {"pulse": 0.6, "flip_h": true})
	_scope.queue_free()
	_panel.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(900, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(30, 0.96))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	col.add_child(UiStyle.mono_label("DOWNLINK COMPLETE", 15, UiStyle.PHOSPHOR))
	var head := UiStyle.heading("RECEIVED ON EARTH" if not received.is_empty() else "NOTHING ARRIVED")
	head.add_theme_color_override("font_color", UiStyle.PHOSPHOR if not received.is_empty() else UiStyle.CORAL)
	col.add_child(head)
	for lens in _order:
		var ok := received.has(lens)
		var l := Label.new()
		var name := _name(lens)
		l.text = "%s   %s" % [name, "received. It is evidence now." if ok else "did not finish. It was lost when the window closed."]
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", UiStyle.PHOSPHOR if ok else UiStyle.CORAL)
		col.add_child(l)
	# One tip, chosen from how the link actually went
	var share := _t_locked / maxf(_t_open, 0.1)
	var tip := ""
	if share < 0.6:
		tip = "Tip: you were off Earth for much of the time. Aim a little ahead of it, at the white dots."
	elif not lost.is_empty():
		tip = "Tip: if time is short, send the photo with the best value for its packets first."
	else:
		tip = "Strong link. Holding the beam steady built your bonus."
	var tip_label := Label.new()
	tip_label.text = tip
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_font_size_override("font_size", 18)
	tip_label.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.85))
	col.add_child(tip_label)
	var go := Button.new()
	go.text = "CONTINUE"
	go.theme_type_variation = &"PrimaryButton"
	go.add_theme_font_size_override("font_size", 30)
	go.custom_minimum_size = Vector2(340, 96)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.disabled = true
	go.pressed.connect(func(): finished.emit({"received": received, "lost": lost}))
	col.add_child(go)
	get_tree().create_timer(0.8).timeout.connect(func():
		go.disabled = false
		go.grab_focus())
