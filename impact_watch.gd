class_name ImpactWatch
extends Control
## Contract 03, the flyer's side. A short far-side window (90 game seconds, shown at 1.5 times speed). The player looks through ONE
## window at a time, clicks where they see a flash to log a sighting, then spends a limited downlink budget (packets) on what to send.
## Only what is logged can be sent, and only what is sent can be reviewed. Everything here is a FICTIONAL, simulated scenario:
## the flashes, windows, positions and packet costs are game data (see ImpactScenario).
##
## The ship matters: the Observation Bay gives Window 1; a Flight Deck gives a second, independent window; a Science Lab gives a
## science camera; the close lens allows tight crops and the wide lens allows wide frames; each solar wing adds packets.

signal finished(result: Dictionary)

const RATE := 1.5
const VIEW := Vector2(800, 500)                       # the window view, in the scenario's own screen units
const HIT_PX := 90.0                                  # a click this close to a flash counts as logging it
const HIT_SEC := 1.6                                  # and this close in time (before or after the flash)
const EVENTS := [                                     # what is actually visible in each window, and when (the TRUTH, aboard only)
	{"cand": "A", "vp": "V1", "t": [21.5, 22.5], "pos": [412, 236], "alpha": 1.0},
	{"cand": "A", "vp": "V2", "t": [21.5, 25.0], "pos": [130, 301], "alpha": 0.9},     # a slower glow, so a player can catch it after Window 1
	{"cand": "B", "vp": "V3", "t": [49.0, 53.0], "pos": [260, 410], "alpha": 0.32},
	{"cand": "C", "vp": "V1", "t": [69.5, 71.5], "pos": [300, 180], "alpha": 1.0},
]
const SILENCE_WATCH := [18.0, 26.0]                   # the Science camera log "nothing seen" needs it to have been watched here
const SILENCE_NEED := 6.0

var state: BuildState
var crew: Array = []
var salt := ""                                        # makes the opaque ids differ between runs; set by the caller or by default

var _t := 0.0
var _phase := "brief"
var _vp := "V1"
var _avail := {}
var _watched := {"V1": 0.0, "V2": 0.0, "V3": 0.0}
var _silence_watched := 0.0
var _marks: Array[Dictionary] = []
var _chosen := {}
var _view: Control
var _clock: Label
var _head: Label
var _tabs := {}
var _body: VBoxContainer
var _stage: Control
var _send_list: GridContainer
var _budget_label: Label
var _send_btn: Button
var _stars: Array[Vector3] = []


# ---------------------------------------------------------------- logic (static, so tests can use it without the screen)

## Which windows this ship has. Window 1 needs the Observation Bay (every legal ship has one).
static func viewpoints_for(s: BuildState) -> Dictionary:
	return {"V1": s != null and s.has_room("observation"), "V2": s != null and s.has_room("flight-deck"), "V3": s != null and s.has_room("science-lab")}


## Did a logged click match this visible event? Marks are {vp, t, x, y}.
static func mark_matches(marks: Array, ev: Dictionary) -> bool:
	for m in marks:
		if String(m["vp"]) != String(ev["vp"]):
			continue
		if float(m["t"]) < float(ev["t"][0]) - HIT_SEC or float(m["t"]) > float(ev["t"][1]) + HIT_SEC:
			continue
		if Vector2(float(m["x"]), float(m["y"])).distance_to(Vector2(float(ev["pos"][0]), float(ev["pos"][1]))) <= HIT_PX:
			return true
	return false


static func _event_for(cand: String, vp: String) -> Dictionary:
	for e in EVENTS:
		if e["cand"] == cand and e["vp"] == vp:
			return e
	return {}


## What the player can send, given the ship, what they logged and what they watched: {product id: why-not or ""}. "" means available.
static func availability(s: BuildState, marks: Array, silence_watched: float) -> Dictionary:
	var vps := viewpoints_for(s)
	var out := {}
	for p in ImpactScenario.products():
		var id := String(p["id"])
		var vp := String(p["viewpoint"])
		var why := ""
		if id == "N1":
			if not bool(vps["V3"]):
				why = "needs a Science Lab"
			elif silence_watched < SILENCE_NEED:
				why = "the Science camera was not watched during that time"
		elif id == "B3":
			if not bool(vps["V2"]):
				why = "needs a Flight Deck"
			elif String(out.get("B1", "x")) != "":
				why = "nothing to retell: B1 was never logged"
		else:
			var cand := String(p["cand"])
			var ev := _event_for(cand, vp)
			if not bool(vps[vp]):
				why = "needs " + ("an Observation Bay" if vp == "V1" else ("a Flight Deck" if vp == "V2" else "a Science Lab"))
			elif ev.is_empty() or not mark_matches(marks, ev):
				why = "not logged"
			elif String(p["type"]) == "tight_crop" and not s.close:
				why = "needs the close lens"
			elif String(p["type"]) == "wide_context" and not s.wide:
				why = "needs the wide lens"
		out[id] = why
		# B3 depends on B1's availability, which is decided before it in the product order
	return out


## The packets this ship can deliver.
static func packets(s: BuildState) -> int:
	return ImpactScenario.budget(s.wings if s != null else 0)


## The cost of a set of product ids.
static func cost_of(ids: Array) -> int:
	var c := 0
	for id in ids:
		c += int(ImpactScenario.product(String(id)).get("cost", 0))
	return c


## Build the delivered case from chosen products. Returns {ok, error, case, map, sent_cost, budget}.
static func deliver(s: BuildState, chosen: Array, salt_in: String, observers := {}) -> Dictionary:
	var budget := packets(s)
	var sent := cost_of(chosen)
	if chosen.is_empty():
		return {"ok": false, "error": "Nothing is chosen to send."}
	if sent > budget:
		return {"ok": false, "error": "That is %d packets and only %d fit." % [sent, budget]}
	var ex := ImpactCase.build_export(chosen, salt_in, observers)
	var v := ImpactCase.validate(ex["case"])
	if not bool(v["ok"]):
		return {"ok": false, "error": String(v["error"])}
	return {"ok": true, "error": "", "case": ex["case"], "map": ex["map"], "sent_cost": sent, "budget": budget}


## The crew's own names for the reviewer file (the Commander at Window 1, the Pilot at the Flight Deck, the Scientist at the camera).
static func observer_names(crew_in: Array) -> Dictionary:
	var out := {}
	var want := {"V1": "Commander", "V2": "Pilot", "V3": "Scientist"}
	for vp in want:
		for c in crew_in:
			if String(c.get("role", "")) == String(want[vp]) and float(c.get("health", 100.0)) > 0.0:
				out[vp] = String(c["name"])
	return out


# ---------------------------------------------------------------- the screen

func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if state == null:
		state = PlayerData.get_build()
	if crew.is_empty():
		crew = PlayerData.crew
	if salt == "":
		salt = str(Time.get_ticks_usec()) + str(randi())
	_avail = viewpoints_for(state)
	if not bool(_avail["V1"]):
		_avail["V1"] = true                            # a ship cannot get here without an Observation Bay, but never leave the player with no window
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 90:
		_stars.append(Vector3(rng.randf() * VIEW.x, rng.randf() * VIEW.y, rng.randf_range(0.3, 1.0)))
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.97)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	margin.add_child(_body)
	_show_brief()
	Music.play("orbit")


func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()
	_tabs.clear()


func _label(t: String, size := 20, color := UiStyle.NEAR_WHITE, minw := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if minw > 0.0:
		l.custom_minimum_size = Vector2(minw, 0)
	return l


func _button(t: String, primary := false, size := 22, h := 64) -> Button:
	var b := Button.new()
	b.text = t
	b.theme_type_variation = &"PrimaryButton" if primary else &"OutlineButton"
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _show_brief() -> void:
	_clear()
	_phase = "brief"
	_body.add_child(UiStyle.mono_label("CONTRACT 03   -   FICTIONAL SIMULATION, NOT NASA DATA", 14, UiStyle.AMBER))
	_body.add_child(UiStyle.heading("IMPACT WATCH: NOBODY SAW THE SAME MOON"))
	_body.add_child(_label("For 90 seconds the far side of the Moon passes below. Something may flash. You can only look through ONE window at a time. Click where you see a flash to log it. Then you choose what to send: you cannot send everything.", 24, UiStyle.NEAR_WHITE, 1500))
	var names := {"V1": "Window 1 (Observation Bay)", "V2": "Flight Deck window", "V3": "Science camera"}
	var needs := {"V1": "", "V2": "needs a Flight Deck", "V3": "needs a Science Lab"}
	for vp in ["V1", "V2", "V3"]:
		var ok: bool = _avail[vp]
		_body.add_child(_label("%s  %s%s" % ["YES" if ok else "NO ", names[vp], "" if ok else "  -  " + needs[vp]], 22, UiStyle.PHOSPHOR if ok else Color(UiStyle.NEAR_WHITE, 0.55), 1500))
	_body.add_child(_label("Lenses: tight crops need the close lens (%s). Wide frames need the wide lens (%s). Downlink: %d packets (a base of %d, plus %d for each solar wing)." % ["fitted" if state.close else "not fitted", "fitted" if state.wide else "not fitted", packets(state), ImpactScenario.BASE_BUDGET, ImpactScenario.WING_BUDGET], 20, Color(UiStyle.NEAR_WHITE, 0.85), 1500))
	_body.add_child(_label("A second window gives an INDEPENDENT view. Mission Control cannot count two records from one window as two witnesses.", 20, UiStyle.AMBER, 1500))
	var go := _button("START WATCHING", true, 30, 96)
	go.custom_minimum_size = Vector2(420, 96)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(_start_watch)
	_body.add_child(go)


func _start_watch() -> void:
	_clear()
	_phase = "watch"
	_t = 0.0
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_body.add_child(top)
	_head = _label("LOOK THROUGH A WINDOW. CLICK ON A FLASH TO LOG IT.", 22, UiStyle.PHOSPHOR)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_head)
	_clock = UiStyle.mono_label("MISSION CLOCK  0:00 / 1:30", 24, UiStyle.NEAR_WHITE)
	top.add_child(_clock)
	var names := {"V1": "WINDOW 1", "V2": "FLIGHT DECK", "V3": "SCIENCE CAMERA"}
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	_body.add_child(tabs)
	for vp in ["V1", "V2", "V3"]:
		var b := _button(names[vp] if _avail[vp] else names[vp] + "  (NOT FITTED)", false, 20, 56)
		b.custom_minimum_size = Vector2(300, 56)
		b.disabled = not bool(_avail[vp])
		b.pressed.connect(func(): _set_vp(vp))
		tabs.add_child(b)
		_tabs[vp] = b
	_set_vp("V1")
	_view = Control.new()
	_view.custom_minimum_size = VIEW + Vector2(0, 0)
	_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.clip_contents = true
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_view_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_body.add_child(row)
	row.add_child(_view)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.custom_minimum_size = Vector2(560, 0)
	row.add_child(side)
	side.add_child(_label("WHAT YOU LOGGED", 18, UiStyle.AMBER))
	_stage = side
	side.add_child(_label("Nothing yet.", 20, Color(UiStyle.NEAR_WHITE, 0.7), 540))


func _set_vp(vp: String) -> void:
	if not _avail.get(vp, false):
		return
	_vp = vp
	for k in _tabs:
		var b: Button = _tabs[k]
		b.theme_type_variation = &"PrimaryButton" if k == vp else &"OutlineButton"


func _process(delta: float) -> void:
	if _phase != "watch":
		return
	var dt := delta * RATE
	_t += dt
	_watched[_vp] = float(_watched[_vp]) + dt
	if _vp == "V3" and _t >= SILENCE_WATCH[0] and _t <= SILENCE_WATCH[1]:
		_silence_watched += dt
	_clock.text = "MISSION CLOCK  %d:%02d / 1:30" % [int(_t) / 60, int(_t) % 60]
	if _view != null:
		_view.queue_redraw()
	if _t >= ImpactScenario.WINDOW_SECONDS:
		_end_watch()


## Log a sighting where the player clicked, in the current window, at the current time. Public so a test can stand in for the click.
func log_sighting(x: float, y: float, vp := "") -> void:
	if _phase != "watch":
		return
	_marks.append({"vp": _vp if vp == "" else vp, "t": _t, "x": x, "y": y})
	Sfx.play("click", -6.0)
	_refresh_marks()


## For tests: put the clock at a given time, and look through a window.
func set_time(t: float, vp: String) -> void:
	_t = t
	_set_vp(vp)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		log_sighting(event.position.x, event.position.y)
		_view.accept_event()


func _refresh_marks() -> void:
	if _stage == null:
		return
	for i in range(_stage.get_child_count() - 1, 0, -1):
		_stage.get_child(i).queue_free()
	if _marks.is_empty():
		_stage.add_child(_label("Nothing yet.", 20, Color(UiStyle.NEAR_WHITE, 0.7), 540))
		return
	var names := {"V1": "Window 1", "V2": "Flight Deck", "V3": "Science camera"}
	for m in _marks.slice(maxi(_marks.size() - 8, 0)):
		_stage.add_child(_label("%s at %d:%02d" % [names[m["vp"]], int(m["t"]) / 60, int(m["t"]) % 60], 20, UiStyle.NEAR_WHITE, 540))


func _draw_view() -> void:
	var rect := Rect2(Vector2.ZERO, VIEW)
	_view.draw_rect(rect, Color(0.01, 0.015, 0.045))
	for s in _stars:
		_view.draw_circle(Vector2(s.x, s.y), 1.2 + s.z, Color(1, 1, 1, 0.25 + 0.35 * s.z))
	# the Moon's far side drifting past: a big dark disk with a faint edge, different in each window
	var drift := fmod(_t * 7.0, 60.0)
	var centre := Vector2(VIEW.x * 0.5 - drift, VIEW.y + 380.0 - {"V1": 0.0, "V2": 40.0, "V3": 90.0}[_vp])
	_view.draw_circle(centre, 560.0, Color(0.14, 0.15, 0.19))
	_view.draw_arc(centre, 560.0, 0, TAU, 96, Color(0.55, 0.58, 0.68, 0.7), 3.0)
	for k in 14:
		var a := float(k) * 2.399
		var c2 := centre + Vector2(cos(a), sin(a)) * (140.0 + 28.0 * float(k % 7))
		_view.draw_arc(c2, 16.0 + float(k % 5) * 9.0, 0, TAU, 20, Color(0.24, 0.25, 0.3), 2.0)
	# a window frame that sways a little (the Window 1 reflection moves with this, not with the Moon)
	var sway := Vector2(sin(_t * 1.3) * 10.0, cos(_t * 1.1) * 6.0)
	for e in EVENTS:
		if String(e["vp"]) != _vp:
			continue
		if _t < float(e["t"][0]) or _t > float(e["t"][1]):
			continue
		var pos := Vector2(float(e["pos"][0]), float(e["pos"][1]))
		var a: float = float(e["alpha"]) * (1.0 - 0.45 * (_t - float(e["t"][0])) / maxf(float(e["t"][1]) - float(e["t"][0]), 0.1))
		if e["cand"] == "C":
			pos += sway                                   # moves with the window, not with the Moon
			_view.draw_circle(pos, 14.0, Color(1, 0.97, 0.8, a))
			_view.draw_circle(pos, 6.0, Color(1, 1, 1, a))
		elif e["cand"] == "B":
			_view.draw_circle(pos, 9.0, Color(1, 0.95, 0.8, a * 0.5))
		else:
			_view.draw_circle(pos, 20.0, Color(1, 0.95, 0.8, a * 0.5))
			_view.draw_circle(pos, 8.0, Color(1, 1, 1, a))
	_view.draw_rect(Rect2(sway - Vector2(6, 6), VIEW + Vector2(12, 12)), Color(0.35, 0.4, 0.52), false, 14.0)
	# logged marks stay on screen for a few seconds
	for m in _marks:
		if String(m["vp"]) == _vp and _t - float(m["t"]) < 4.0:
			_view.draw_arc(Vector2(float(m["x"]), float(m["y"])), 26.0, 0, TAU, 24, UiStyle.PHOSPHOR, 3.0)
	_view.draw_rect(rect, UiStyle.EDGE, false, 2.0)


func _end_watch() -> void:
	_phase = "send"
	_show_send()


# ---------------------------------------------------------------- choosing what to send

## For tests: jump straight to the send step.
func end_watch_now() -> void:
	_end_watch()


func _show_send() -> void:
	_clear()
	_chosen.clear()
	var av := availability(state, _marks, _silence_watched)
	_body.add_child(UiStyle.mono_label("YOU CANNOT SEND EVERYTHING", 14, UiStyle.AMBER))
	_body.add_child(UiStyle.heading("CHOOSE WHAT REACHES MISSION CONTROL"))
	_budget_label = _label("", 24, UiStyle.PHOSPHOR, 1500)
	_body.add_child(_budget_label)
	_body.add_child(_label("Only what you logged can be sent. A log is cheap. A tight crop looks convincing. A wide frame shows context. Mission Control sees nothing you leave out, and they do not know which candidates are real.", 20, Color(UiStyle.NEAR_WHITE, 0.9), 1500))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_send_list = grid
	var type_names := {"crew_log": "LOG", "tight_crop": "TIGHT CROP", "wide_context": "WIDE FRAME"}
	for p in ImpactScenario.products():
		var id := String(p["id"])
		var why: String = av[id]
		var b := Button.new()
		b.toggle_mode = true
		b.disabled = why != ""
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 17)
		b.custom_minimum_size = Vector2(840, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var vpn: String = String(ImpactScenario.VIEWPOINTS[p["viewpoint"]]["label"])
		b.text = "%s   %s   %d packet%s
%s" % [type_names[p["type"]], vpn, int(p["cost"]), "" if int(p["cost"]) == 1 else "s", ("not available: " + why) if why != "" else "your sighting, %d:%02d" % [int(p["t"][0]) / 60, int(float(p["t"][0])) % 60]]
		b.toggled.connect(func(on): _toggle(id, on, b))
		_send_list.add_child(b)
		b.set_meta("pid", id)
	_send_btn = _button("SEND TO MISSION CONTROL", true, 26, 84)
	_send_btn.custom_minimum_size = Vector2(520, 84)
	_send_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_send_btn.disabled = true
	_send_btn.pressed.connect(_send)
	_body.add_child(_send_btn)
	var none := _button("SEND NOTHING AND END THE WATCH", false, 18, 52)
	none.custom_minimum_size = Vector2(520, 52)
	none.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	none.pressed.connect(func(): finished.emit({"ok": false, "budget": packets(state), "sent_cost": 0, "marks": _marks.duplicate(true)}))
	_body.add_child(none)
	_refresh_budget()


func _toggle(id: String, on: bool, b: Button) -> void:
	if on:
		var trial := _chosen.keys() + [id]
		if cost_of(trial) > packets(state):
			b.set_pressed_no_signal(false)
			_budget_label.text = "Not enough packets for that one. Take something else out first."
			_budget_label.add_theme_color_override("font_color", UiStyle.CORAL)
			return
		_chosen[id] = true
	else:
		_chosen.erase(id)
	_refresh_budget()


## Choose or un-choose a product. Public so a test can stand in for the click.
func choose_product(id: String, on := true) -> void:
	for b in _send_list.get_children():
		if String(b.get_meta("pid", "")) == id and not b.disabled:
			b.button_pressed = on


func _refresh_budget() -> void:
	var used := cost_of(_chosen.keys())
	_budget_label.text = "PACKETS  %d of %d used.   %d left." % [used, packets(state), packets(state) - used]
	_budget_label.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	_send_btn.disabled = _chosen.is_empty()


func _send() -> void:
	var r := deliver(state, _chosen.keys(), salt, observer_names(crew))
	if not bool(r["ok"]):
		_budget_label.text = String(r["error"])
		_budget_label.add_theme_color_override("font_color", UiStyle.CORAL)
		return
	DirAccess.make_dir_recursive_absolute("user://impact_cases")
	var path := "user://impact_cases/" + ImpactCase.random_name()
	var err := ImpactCase.save_case(r["case"], path)
	if err != "":
		_budget_label.text = err
		return
	ImpactCase.save_run(r["case"], r["map"], int(r["sent_cost"]), int(r["budget"]))
	r["path"] = path
	r["marks"] = _marks.duplicate(true)
	r["delivered"] = _chosen.keys()
	finished.emit(r)
