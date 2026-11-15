class_name ShipInterior
extends Control
## "Mission Operations": the player walks the crew around the ship they built and does the jobs themselves.
## Side-view cutaway. The built rooms sit in a row (empty bays do not exist), a deck runs underneath, and each
## room has a pad. Stand on a pad and press E. Jobs cost TIME, POWER and the actor's ENERGY, and walking costs
## time and energy, so the player has to choose what is worth doing. All numbers are GAME rules.
##
## Controls: A / D or the arrow keys to walk (or click a pad), E to do the job, 1 / 2 / 3 or click a portrait
## to take control of someone else, H for the how-to card.
## The photo and the send-home are the same two mini-games as before; they now start from the room they belong to.

signal finished(result: Dictionary)

const HUD := preload("res://hud_frame.gd")
const SPEED := 380.0
const TIME_PER_100PX := 0.3
const ENERGY_PER_100PX := 0.5
const DECK_Y := 560.0
const SHIP_SCALE := 1.8
const NEAR := 70.0
const METABOLISM := 0.6        # energy every crew member loses per minute that passes
const STARVE_CHUNK := 8.0      # starvation damage is applied in chunks so the messages are not a flood

## What each room lets you do. energy is what the job costs the person doing it (negative = restores).
const TASKS := {
	"observation": {"label": "TAKE THE MOON PHOTO", "kind": "photo", "time": 8.0, "power": 4.0, "energy": 10.0,
		"desc": "Use the camera yourself. A rested pilot has steadier hands. Another session can beat your best shot."},
	"communications": {"label": "SEND PHOTOS HOME", "kind": "send", "time": 6.0, "power": 5.0, "energy": 8.0,
		"desc": "Point the dish and send what you shot. Only complete photos arrive."},
	"crew-quarters": {"label": "REST", "kind": "rest", "time": 6.0, "power": 0.0, "energy": -40.0,
		"desc": "Sleep to win back energy."},
	"galley": {"label": "EAT", "kind": "eat", "time": 3.0, "power": 0.0, "energy": -25.0,
		"desc": "A hot meal wins back some energy, faster than sleep."},
	"medical": {"label": "TREAT", "kind": "heal", "time": 5.0, "power": 1.0, "energy": 0.0,
		"desc": "Treat whoever you are steering. It mends their health."},
}

## Contract 02 changes what some rooms do. The Flight Deck plans the Sun pass, the Observation Bay photographs a crater,
## and the Science Lab compares the two photos. Every other room keeps its normal job.
const CRATER_TASKS := {
	"flight-deck": {"label": "PLAN THE SUN PASS", "kind": "plan", "time": 0.0, "power": 1.0, "energy": 4.0,
		"desc": "Choose the Sun pass for the next photo, and which crater is second. Waiting for the Sun costs time. Cancel costs nothing."},
	"observation": {"label": "OBSERVE THE CRATER", "kind": "crater_photo", "time": 8.0, "power": 4.0, "energy": 10.0,
		"desc": "Take the photo yourself, under the Sun pass you planned. Low Sun shows shadows and shape. High Sun shows bright rays."},
	"science-lab": {"label": "COMPARE THE PHOTOS", "kind": "compare", "time": 8.0, "power": 3.0, "energy": 6.0,
		"desc": "Put the two photos side by side and read the light. A scientist on board works 25% faster."},
}
const EVENT_MARKS := [0.25, 0.6]       # fractions of the time budget used when a random event can happen

var state: BuildState
var run: MissionRun
var mission_id := 0

var _mission: Dictionary
var _layer: Control
var _ship: ShipView
var _deck: Control
var _pads: Array[Dictionary] = []          # {room, x, task, btn}
var _astros: Array[Astronaut] = []
var _sel := 0
var _target_x := -1.0
var _busy := false
var _ended := false
var _min_x := 400.0
var _max_x := 1500.0
var _step := 0.0
var _msg := ""
var _removed: Array[bool] = []
var _starve: Array[float] = []
var _msg_t := 0.0
var _confirm_t := 0.0
var _shots := {}                            # lens -> best photo so far
var _received: Array[String] = []
var _obj_labels: Array[Label] = []
var _time_label: Label
var _power_label: Label
var _time_bar: Control
var _power_bar: Control
var _chips: Array[Dictionary] = []          # {panel, energy, health}
var _prompt_title: Label
var _prompt_body: Label
var _prompt_cost: Label
var _prompt_status: Label
var _finish_btn: Button
var _howto: HowToCard
var _crater := false                         # Contract 02: crater observations and a comparison
var _branch := ""                            # "reobserve" or "ohm", chosen when the first pass is planned
var _planned := {}                           # the Sun pass planned for the next photo
var _used: Array = []                        # {crater, pass} already observed (a repeat has to wait for the next orbit)
var _obs := 0                                # observations made so far
var _compare := {}                           # the Science Lab result: {says, eval}
var _events: Array[Dictionary] = []
var _event_i := 0


func _ready() -> void:
	if run == null:
		run = PlayerData.run if PlayerData.run != null else PlayerData.start_run()
	if state == null:
		state = PlayerData.get_build()
	_mission = Missions.get_mission(mission_id)
	_crater = String(_mission.get("science", "")) == "crater"
	if int(_mission.get("events", 0)) > 0:
		_events = MissionEvents.pick(run, int(_mission["events"]))
	if theme == null:
		theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_backdrop()
	_layer = Decor.frame_layer(self)
	_build_ship()
	_build_deck()
	_build_astronauts()
	_build_hud()
	_refresh()
	Sfx.play("stage")


func _task_for(room_id: String) -> Dictionary:
	if _crater and CRATER_TASKS.has(room_id):
		return CRATER_TASKS[room_id]
	if _crater and room_id == "communications":
		var t: Dictionary = (TASKS["communications"] as Dictionary).duplicate()
		t["desc"] = "Send both photos and the comparison home. Both have to arrive."
		return t
	return TASKS.get(room_id, {})


## Minutes a job takes. A fit scientist is quicker in the lab (GAME rule).
func _time_of(task: Dictionary) -> float:
	var t := float(task["time"])
	if String(task["kind"]) == "compare" and run.crew_fit("SCIENTIST"):
		t *= 0.75
	return t


# ---------------------------------------------------------------- building the scene

func _build_backdrop() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/select/bg_earth_orbit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.027, 0.043, 0.133, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var hud: Control = HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.inset = 28.0
	hud.arm = 46.0
	hud.show_ruler = false
	add_child(hud)


func _build_ship() -> void:
	_ship = ShipView.new()
	_layer.add_child(_ship)
	_ship.size = Vector2(1000, 336)
	_ship.scale = Vector2.ONE * SHIP_SCALE
	_ship.position = Vector2(60, 140)
	_ship.bind(state)
	_ship.set_flight_mode()
	_ship._wing_down.visible = false      # the lower wing would hang over the pads and their labels
	# One pad under each room that was built, in the order they sit on the ship
	for i in state.bays.size():
		var id: String = state.bays[i]
		if id == "":
			continue
		var slot := _ship.bay_slot(i)
		var cx := _ship.position.x + (slot.position.x + slot.size.x * 0.5) * SHIP_SCALE
		_pads.append({"room": id, "x": cx, "task": _task_for(id), "btn": null})
	if not _pads.is_empty():
		_min_x = float(_pads[0]["x"]) - 70.0
		_max_x = float(_pads[_pads.size() - 1]["x"]) + 70.0


func _build_deck() -> void:
	_deck = Control.new()
	_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck.size = Vector2(1920, 1080)
	_deck.draw.connect(_draw_deck)
	_layer.add_child(_deck)
	for p in _pads:
		var b := Button.new()
		var task: Dictionary = p["task"]
		b.text = String(task["label"]) if not task.is_empty() else String(ShipData.room(p["room"])["short"])
		b.theme_type_variation = &"OutlineButton"
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size = Vector2(172, 58)
		b.position = Vector2(float(p["x"]) - 86.0, DECK_Y + 34.0)
		b.modulate = Color(1, 1, 1, 1.0 if not task.is_empty() else 0.55)
		var idx := _pads.find(p)
		b.pressed.connect(func(): _pad_pressed(idx))
		_layer.add_child(b)
		p["btn"] = b


func _build_astronauts() -> void:
	for i in run.crew.size():
		var a := Astronaut.new()
		a.char_id = String(run.crew[i]["char"])
		a.crew_name = String(run.crew[i]["name"])
		a.role = String(run.crew[i]["role"])
		_removed.append(false)
		_starve.append(0.0)
		_layer.add_child(a)
		var px := 960.0
		if not _pads.is_empty():
			px = float(_pads[mini(i, _pads.size() - 1)]["x"]) + (i - 1) * 46.0
		a.position = Vector2(px - Astronaut.W * 0.5, DECK_Y - Astronaut.H + 4.0)
		_astros.append(a)
	_select_next_alive(0)


func _bar(color: Color, fraction: Callable, height := 14.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var f := clampf(float(fraction.call()), 0.0, 1.0)
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(UiStyle.COBALT, 0.3))
		var col := color if f > 0.25 else UiStyle.CORAL
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(c.size.x * f, c.size.y)), col)
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(UiStyle.CHROME, 0.7), false, 1.5))
	return c


func _build_hud() -> void:
	# Header
	var head := UiStyle.heading("MISSION OPERATIONS")
	head.position = Vector2(0, 38)
	head.size = Vector2(1920, 50)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(head)
	var sub := UiStyle.mono_label("%s   -   RUN THE SHIP YOURSELF" % String(_mission["name"]), 15, UiStyle.PHOSPHOR)
	sub.position = Vector2(0, 92)
	sub.size = Vector2(1920, 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(sub)

	# Objectives (left)
	var op := PanelContainer.new()
	op.position = Vector2(60, 110)
	op.custom_minimum_size = Vector2(420, 0)
	op.add_theme_stylebox_override("panel", UiStyle.panel(16, 0.9))
	_layer.add_child(op)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 6)
	op.add_child(ov)
	ov.add_child(UiStyle.mono_label("OBJECTIVES", 14, UiStyle.PHOSPHOR))
	for o in run.objectives:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 18)
		ov.add_child(l)
		_obj_labels.append(l)

	# Resources (right)
	var rp := PanelContainer.new()
	rp.position = Vector2(1440, 110)
	rp.custom_minimum_size = Vector2(420, 0)
	rp.add_theme_stylebox_override("panel", UiStyle.panel(16, 0.9))
	_layer.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rp.add_child(rv)
	rv.add_child(UiStyle.mono_label("WHAT YOU CAN SPEND", 14, UiStyle.PHOSPHOR))
	_time_label = UiStyle.mono_label("", 17, UiStyle.NEAR_WHITE)
	rv.add_child(_time_label)
	_time_bar = _bar(UiStyle.PHOSPHOR, func(): return run.fraction("time"))
	rv.add_child(_time_bar)
	_power_label = UiStyle.mono_label("", 17, UiStyle.NEAR_WHITE)
	rv.add_child(_power_label)
	_power_bar = _bar(UiStyle.AMBER, func(): return run.fraction("power"))
	rv.add_child(_power_bar)

	# Crew chips (bottom)
	var row := HBoxContainer.new()
	row.position = Vector2(530, 880)
	row.add_theme_constant_override("separation", 14)
	_layer.add_child(row)
	for i in run.crew.size():
		row.add_child(_chip(i))

	# What the pad under you does
	var pp := PanelContainer.new()
	pp.position = Vector2(530, 712)
	pp.custom_minimum_size = Vector2(1108, 140)
	pp.add_theme_stylebox_override("panel", UiStyle.panel(16, 0.92))
	_layer.add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	pp.add_child(pv)
	_prompt_title = UiStyle.mono_label("", 17, UiStyle.PHOSPHOR)
	pv.add_child(_prompt_title)
	_prompt_body = Label.new()
	_prompt_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_body.add_theme_font_size_override("font_size", 19)
	_prompt_body.custom_minimum_size = Vector2(1060, 0)
	pv.add_child(_prompt_body)
	_prompt_cost = UiStyle.mono_label("", 15, Color(UiStyle.NEAR_WHITE, 0.75))
	pv.add_child(_prompt_cost)
	_prompt_status = UiStyle.mono_label("", 18, UiStyle.NEAR_WHITE)
	pv.add_child(_prompt_status)

	# Finish
	_finish_btn = Button.new()
	_finish_btn.text = "FINISH"
	_finish_btn.theme_type_variation = &"PrimaryButton"
	_finish_btn.add_theme_font_size_override("font_size", 28)
	_finish_btn.custom_minimum_size = Vector2(210, 90)
	_finish_btn.position = Vector2(1660, 886)
	_finish_btn.focus_mode = Control.FOCUS_NONE
	_finish_btn.pressed.connect(_on_finish_pressed)
	_layer.add_child(_finish_btn)

	# The how-to stays up until the player clicks GOT IT
	_howto = HowToCard.new()
	_howto.position = Vector2(60, 706)
	_layer.add_child(_howto)
	if _crater:
		_howto.setup("HOW TO RUN THE SHIP", [
			["MOVE", "A / D or arrows, or click a pad. Press E to do the job."],
			["ORDER", "Plan the pass (Flight Deck), observe, twice. Then compare (Science Lab). Then send."],
			["EVENTS", "Things go wrong. Each choice costs something. Read it first."],
			["END", "FINISH when done. Skipped jobs are lost."],
		])
	else:
		_howto.setup("HOW TO RUN THE SHIP", [
			["MOVE", "A / D or arrows, or click a pad. Press E to do the job."],
			["CREW", "1, 2, 3 or click a portrait to steer someone else."],
			["SPEND", "Jobs and walking cost time, power and energy. Rest and meals win energy back."],
			["END", "FINISH when done. Skipped jobs are lost."],
		])


func _chip(i: int) -> Control:
	var c: Dictionary = run.crew[i]
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(360, 118)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var pic := TextureRect.new()
	pic.texture = CrewData.portrait(String(c["char"]))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(72, 72)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	v.add_child(UiStyle.mono_label("%d  %s  (%s)" % [i + 1, String(c["name"]).to_upper(), c["role"]], 14, UiStyle.NEAR_WHITE))
	var en := _bar(UiStyle.PHOSPHOR, func(): return float(run.crew[i]["energy"]) / 100.0, 10.0)
	var he := Control.new()
	he.custom_minimum_size = Vector2(0, 22)
	he.mouse_filter = Control.MOUSE_FILTER_IGNORE
	he.draw.connect(func(): CrewHearts.draw_row(he, Vector2.ZERO, 19.0, run.hearts(i), UiStyle.CORAL, Color(UiStyle.CORAL, 0.18)))
	var st := UiStyle.mono_label("", 12, Color(UiStyle.NEAR_WHITE, 0.8))
	st.clip_text = true
	v.add_child(UiStyle.mono_label("ENERGY", 11, Color(UiStyle.NEAR_WHITE, 0.6)))
	v.add_child(en)
	v.add_child(he)
	v.add_child(st)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func(): _select(i))
	p.add_child(b)
	_chips.append({"panel": p, "energy": en, "health": he, "status": st})
	return p


func _draw_deck() -> void:
	var x0 := _min_x - 60.0
	var x1 := _max_x + 60.0
	_deck.draw_rect(Rect2(x0, DECK_Y, x1 - x0, 12.0), Color(UiStyle.CHROME, 0.85))
	_deck.draw_rect(Rect2(x0, DECK_Y + 12.0, x1 - x0, 4.0), Color(UiStyle.COBALT, 0.9))
	var t := Time.get_ticks_msec() / 1000.0
	for p in _pads:
		var task: Dictionary = p["task"]
		var usable := not task.is_empty() and check_task(task) == ""
		var col := UiStyle.PHOSPHOR if usable else (Color(UiStyle.CHROME, 0.5) if not task.is_empty() else Color(UiStyle.CHROME, 0.25))
		var px := float(p["x"])
		var glow := 0.25 + 0.2 * sin(t * 4.0) if usable else 0.12
		_deck.draw_circle(Vector2(px, DECK_Y + 6.0), 34.0, Color(col, glow))
		_deck.draw_rect(Rect2(px - 40.0, DECK_Y + 2.0, 80.0, 8.0), Color(col, 0.95))


# ---------------------------------------------------------------- crew and movement

func _select(i: int) -> void:
	if i < 0 or i >= _astros.size() or run.is_dead(i):
		return
	_sel = i
	for k in _astros.size():
		_astros[k].selected = k == i
		if k != i:
			_astros[k].walking = false        # the one who was walking stops mid-stride the moment you switch away
	_target_x = -1.0
	_refresh()


func _select_next_alive(from: int) -> void:
	for k in _astros.size():
		var i := (from + k) % _astros.size()
		if not run.is_dead(i):
			_select(i)
			return


func _x(i: int) -> float:
	return _astros[i].position.x + Astronaut.W * 0.5


func teleport_to(room_id: String) -> void:
	for p in _pads:
		if p["room"] == room_id:
			_astros[_sel].position.x = float(p["x"]) - Astronaut.W * 0.5
			_target_x = -1.0


func _pad_pressed(idx: int) -> void:
	if _busy or _ended:
		return
	if absf(_x(_sel) - float(_pads[idx]["x"])) <= NEAR:
		interact()
	else:
		_target_x = float(_pads[idx]["x"])


func _near_pad() -> Dictionary:
	var best := {}
	var d := NEAR
	for p in _pads:
		var dx := absf(_x(_sel) - float(p["x"]))
		if dx <= d:
			d = dx
			best = p
	return best


func _process(delta: float) -> void:
	if _ended:
		return
	_msg_t = maxf(_msg_t - delta, 0.0)
	if _confirm_t > 0.0:
		_confirm_t -= delta
		if _confirm_t <= 0.0:
			_finish_btn.text = "FINISH"
	if not _busy:
		_walk(delta)
	_check_deaths()
	check_events()
	_refresh()
	_deck.queue_redraw()
	if run.alive_count() == 0:
		_end(false)
	elif run.left("time") <= 0.0 and not _busy:
		_end(true)


## Minutes pass: the clock runs down and everyone burns energy. Someone with no energy left starts losing health,
## and the message says exactly why.
func _pass_time(minutes: float) -> void:
	run.drain("time", minutes)
	_metabolize(minutes)


func _metabolize(minutes: float) -> void:
	for i in run.crew.size():
		if run.is_dead(i):
			continue
		run.tire(i, minutes * METABOLISM)
		if float(run.crew[i]["energy"]) <= 0.0:
			_starve[i] += minutes * 3.0
			if _starve[i] >= STARVE_CHUNK:
				var r := _starve_reason(i)
				run.hurt(i, _starve[i], r[0], r[1])
				_starve[i] = 0.0


func _starve_reason(i: int) -> Array:
	var who := String(run.crew[i]["name"])
	var fed := false
	for p in _pads:
		if p["room"] == "galley" or p["room"] == "crew-quarters":
			fed = true
	if not fed:
		return ["%s is starving and worn out: the ship has no Galley or Crew Quarters, so there is no food or rest to win energy back." % who, "Starving: no food or rest"]
	return ["%s has run out of energy and is exhausted. Eat in the Galley or rest in Crew Quarters before working any more." % who, "Exhausted: no energy left"]


## When enough of the time budget has gone, the next random event happens and the player has to decide.
func check_events() -> void:
	if _busy or _ended or _event_i >= _events.size() or run.alive_count() == 0:
		return
	var used := 1.0 - run.fraction("time")
	if used >= float(EVENT_MARKS[mini(_event_i, EVENT_MARKS.size() - 1)]):
		_run_event()


func _run_event() -> void:
	_busy = true
	_astros[_sel].walking = false
	var ev: Dictionary = _events[_event_i]
	_event_i += 1
	var card := EventCard.new()
	card.run = run
	card.state = state
	card.event = ev
	card.actor = _sel
	add_child(card)
	var out: Dictionary = await card.finished
	card.queue_free()
	Music.play("orbit")
	_say("Event: %s." % String(ev["title"]).capitalize())
	_busy = false


## Anyone who has just died is taken off the ship: they fade out and the deck is theirs no longer.
func _check_deaths() -> void:
	for i in _astros.size():
		if run.is_dead(i) and not _removed[i]:
			_removed[i] = true
			var a := _astros[i]
			a.selected = false
			a.walking = false
			var tw := create_tween()
			tw.tween_property(a, "modulate:a", 0.0, 1.0)
			tw.tween_callback(a.hide)
			if i == _sel:
				_target_x = -1.0
				_select_next_alive(0)


func _walk(delta: float) -> void:
	var a := _astros[_sel]
	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if dir != 0.0:
		_target_x = -1.0
	elif _target_x >= 0.0:
		var dx := _target_x - _x(_sel)
		if absf(dx) < 8.0:
			_astros[_sel].position.x = _target_x - Astronaut.W * 0.5
			_target_x = -1.0
			Sfx.play("tick", -6.0, 1.2)
		else:
			dir = signf(dx)
	var before := _x(_sel)
	if dir != 0.0:
		var nx := clampf(before + dir * SPEED * delta, _min_x, _max_x)
		a.position.x = nx - Astronaut.W * 0.5
		a.facing = dir
	var moved := absf(_x(_sel) - before)
	a.walking = moved > 0.01
	if moved > 0.0:
		_pass_time(moved / 100.0 * TIME_PER_100PX)
		run.tire(_sel, moved / 100.0 * ENERGY_PER_100PX)
		_step += delta
		if _step > 0.28:
			_step = 0.0
			Sfx.play("tick", -14.0, 0.55)


func _unhandled_input(event: InputEvent) -> void:
	if _ended or _busy or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_E:
			interact()
		KEY_1:
			_select(0)
		KEY_2:
			_select(1)
		KEY_3:
			_select(2)


# ---------------------------------------------------------------- jobs

## Empty string when the job can be done now, otherwise the plain reason it cannot.
func check_task(task: Dictionary) -> String:
	var a: Dictionary = run.crew[_sel]
	var who := String(a["name"])
	if float(a["health"]) <= 0.0:
		return "%s cannot work." % who
	match String(task["kind"]):
		"send":
			if _shots.is_empty():
				return "Take a photo first."
			if _unsent().is_empty():
				return "Everything has been sent."
			if _crater and _compare.is_empty():
				return "Compare the photos in the Science Lab first."
		"plan":
			if _obs >= 2:
				return "Both observations are done."
			if not _planned.is_empty():
				return "A pass is already planned. Observe the crater first."
		"crater_photo":
			if _obs >= 2:
				return "Both observations are done."
			if _planned.is_empty():
				return "Plan the Sun pass at the Flight Deck first."
		"compare":
			if _obs < 2:
				return "You need both photos first."
			if not _compare.is_empty():
				return "The photos are already compared."
		"rest", "eat":
			if float(a["energy"]) >= 99.5:
				return "%s is not tired." % who
		"heal":
			if float(a["health"]) >= 99.5:
				return "%s is healthy." % who
	if run.left("time") < _time_of(task):
		return "Not enough time left."
	if run.left("power") < float(task["power"]):
		return "Not enough power."
	if float(task["energy"]) > 0.0 and float(a["energy"]) < float(task["energy"]):
		return "%s is too tired. Rest in Crew Quarters or eat in the Galley." % who
	return ""


func _unsent() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lens in _shots:
		if not _received.has(lens):
			out.append(_shots[lens])
	return out


func interact() -> void:
	if _busy or _ended:
		return
	var pad := _near_pad()
	if pad.is_empty():
		_say("Walk to a pad first, then press E.")
		Sfx.play("error", -6.0)
		return
	var task: Dictionary = pad["task"]
	if task.is_empty():
		_say("Nothing to do in this room for this contract.")
		Sfx.play("error", -6.0)
		return
	var why := check_task(task)
	if why != "":
		_say(why)
		Sfx.play("error")
		return
	await _perform(task)


func _perform(task: Dictionary) -> void:
	_busy = true
	_astros[_sel].walking = false
	if String(task["kind"]) == "plan":
		await _do_plan(task)
		_busy = false
		return
	run.spend("time", _time_of(task))
	run.spend("power", float(task["power"]))
	_metabolize(_time_of(task))
	var e := float(task["energy"])
	if e > 0.0:
		run.tire(_sel, e)
	else:
		run.crew[_sel]["energy"] = minf(float(run.crew[_sel]["energy"]) - e, 100.0)
	match String(task["kind"]):
		"photo":
			await _do_photo()
		"crater_photo":
			await _do_crater_photo()
		"compare":
			await _do_compare()
		"send":
			await _do_send()
		"rest", "eat":
			Sfx.play("go")
			_say("%s feels better." % run.crew[_sel]["name"])
		"heal":
			run.crew[_sel]["health"] = minf(float(run.crew[_sel]["health"]) + 30.0, 100.0)
			Sfx.play("go")
			_say("%s is treated." % run.crew[_sel]["name"])
	_busy = false


func _do_photo() -> void:
	var actor: Dictionary = run.crew[_sel]
	var perks := ShipData.flight_perks(state, [actor])
	if float(actor["energy"]) < 40.0:
		perks["shake"] = float(perks["shake"]) * 1.15
		perks["rows"].append({"game": "photo", "label": "TIRED", "on": true, "text": "shakier hands", "off": ""})
	var g := PhotoGame.new()
	g.has_lens = {"wide": state.wide, "close": state.close}
	g.met_at_start = 34 + int(float(run.resources["time"]["max"]) - run.left("time"))
	g.target = _mission["target"]
	g.perks = perks
	add_child(g)
	var r: Dictionary = await g.finished
	g.queue_free()
	for ph in r.get("photos", []):
		var lens := String(ph["lens"])
		if not _shots.has(lens) or float(ph["score"]) > float(_shots[lens]["score"]):
			_shots[lens] = ph
			_received.erase(lens)        # a better photo has to be sent again
	if not _shots.is_empty():
		run.complete("photo")
		run.complete("tag")
		_say("Photos kept: %s." % ", ".join(_shots.keys().map(func(k): return "%s %s" % [k, "*".repeat(int(_shots[k]["stars"]))])))
	else:
		_say("The window closed without a photo.")


## The Flight Deck job. The player picks the second observation (once) and the Sun pass; waiting for the Sun costs time.
func _do_plan(task: Dictionary) -> void:
	var card := PassCard.new()
	card.mission = _mission
	card.branch = _branch
	card.observation = _obs
	card.used = _used
	card.time_left = run.left("time")
	card.power_left = run.left("power")
	add_child(card)
	var r: Dictionary = await card.finished
	card.queue_free()
	if bool(r.get("cancelled", true)):
		_say("Planning cancelled. Nothing was spent.")
		return
	commit_plan(String(r["branch"]), String(r["pass"]))


## Carry out a plan the player confirmed: spend the waiting time and power, remember the pass.
func commit_plan(branch: String, pass_id: String) -> void:
	if _branch == "" and branch != "":
		_branch = branch
		run.choose("second", branch)
		for o in run.objectives:
			if o["id"] == "second":
				o["label"] = "Observe Ohm (second observation)" if branch == "ohm" else "Re-observe Glushko in comparable light"
	var crater := CraterScience.crater_for(_obs, _branch)
	var wait := CraterScience.wait_for(crater, pass_id, _used)
	run.spend("time", wait)
	_metabolize(wait)
	run.spend("power", 1.0)
	run.tire(_sel, 4.0)
	var pa := CraterScience.pass_by_id(pass_id).duplicate()
	pa["crater"] = crater
	_planned = pa
	Sfx.play("go")
	_say("Planned: %s at %s. Waited %d minutes for the Sun." % [String(pa["text"]).to_lower(), String(CraterScience.CRATERS[crater]["name"]), int(wait)])


func _do_crater_photo() -> void:
	var actor: Dictionary = run.crew[_sel]
	var perks := ShipData.flight_perks(state, [actor])
	if float(actor["energy"]) < 40.0:
		perks["shake"] = float(perks["shake"]) * 1.15
		perks["rows"].append({"game": "photo", "label": "TIRED", "on": true, "text": "shakier hands", "off": ""})
	var crater: String = String(_planned["crater"])
	var info: Dictionary = CraterScience.CRATERS[crater]
	var g := PhotoGame.new()
	# One lens does this job: the wide one if the ship has it
	g.has_lens = {"wide": state.wide, "close": state.close and not state.wide}
	g.met_at_start = 34 + int(float(run.resources["time"]["max"]) - run.left("time"))
	g.target = {"name": info["name"], "desc": info["desc"], "noun": "crater", "kind": "crater"}
	g.sun = _planned
	g.crater_id = crater
	g.perks = perks
	add_child(g)
	var r: Dictionary = await g.finished
	g.queue_free()
	var photos: Array = r.get("photos", [])
	finish_crater_photo(photos[0] if not photos.is_empty() else {})


## Keep (or lose) the photo of the planned pass. Public so a test can stand in for the finished mini-game.
func finish_crater_photo(ph: Dictionary) -> void:
	var crater := String(_planned.get("crater", "glushko"))
	var key := "first" if _obs == 0 else "second"
	_used.append({"crater": crater, "pass": String(_planned.get("id", ""))})
	_planned = {}
	_obs += 1
	if ph.is_empty():
		_say("The window closed without a photo. That pass is gone.")
		return
	ph = ph.duplicate()
	ph["key"] = key
	ph["label"] = "%s PHOTO %s" % [String(CraterScience.CRATERS[crater]["name"]).to_upper(), "A" if key == "first" else "B"]
	_shots[key] = ph
	run.complete(key)
	_say("Photo kept: %s %s, %s." % [String(CraterScience.CRATERS[crater]["name"]), "*".repeat(int(ph["stars"])), String(ph["confidence"]).to_lower()])


func _do_compare() -> void:
	if not (_shots.has("first") and _shots.has("second")):
		_say("You need both photos to compare.")
		return
	var card := AbCompare.new()
	card.photo_a = _shots["first"]
	card.photo_b = _shots["second"]
	card.branch = _branch if _branch != "" else "reobserve"
	add_child(card)
	var r: Dictionary = await card.finished
	card.queue_free()
	finish_compare(r)


func finish_compare(r: Dictionary) -> void:
	_compare = r
	run.complete("compare")
	_say("Compared. Confidence: %s." % String(r["eval"]["confidence"]).to_lower())


func _do_send() -> void:
	var g := DownlinkGame.new()
	g.photos = _unsent()
	g.perks = ShipData.flight_perks(state, [run.crew[_sel]])
	add_child(g)
	var r: Dictionary = await g.finished
	g.queue_free()
	for lens in r.get("received", []):
		if not _received.has(String(lens)):
			_received.append(String(lens))
	if _crater:
		if _received.has("first") and _received.has("second"):
			run.complete("send")
	elif not _received.is_empty():
		run.complete("send")
	var lost: Array = r.get("lost", [])
	_say("Sent. %d reached Earth%s." % [r.get("received", []).size(), (", %d did not finish" % lost.size()) if not lost.is_empty() else ""])


# ---------------------------------------------------------------- finishing

func _on_finish_pressed() -> void:
	if _busy or _ended:
		return
	if run.all_done() or _confirm_t > 0.0:
		_end(false)
	else:
		_confirm_t = 3.0
		_finish_btn.text = "SURE?"


func finish_ops() -> void:
	_end(false)


func _end(time_out: bool) -> void:
	if _ended:
		return
	_ended = true
	var photos: Array = []
	for lens in (["first", "second"] if _crater else ["wide", "close"]):
		if _shots.has(lens):
			photos.append(_shots[lens])
	var tags_ok := 0
	for ph in photos:
		if ph.get("tag_ok", false):
			tags_ok += 1
	var lost: Array[String] = []
	var notes: Array[String] = []
	for ph in photos:
		var key := String(ph.get("key", ph["lens"]))
		var nm := String(ph.get("label", "")).capitalize() if _crater else ("Wide" if ph["lens"] == "wide" else "Close-up")
		if _crater:
			notes.append("%s: %s, %s." % [nm, String(ph["confidence"]).to_lower(), String(CraterScience.pass_by_id(String(ph.get("pass", "")))["text"]).to_lower()])
		else:
			notes.append("%s photo: %s, %s." % [nm, String(ph["confidence"]).to_lower(), "tagged correctly" if ph.get("tag_ok", false) else "tagged the wrong way round"])
		if _received.has(key):
			notes.append("%s reached Earth." % nm)
		else:
			lost.append(key)
			notes.append("%s was not sent." % nm)
	if _crater and not _compare.is_empty():
		for line in _compare["eval"]["lines"]:
			notes.append(String(line))
	if time_out:
		notes.append("Operations ran out of time.")
	finished.emit({
		"shots": {"photos": photos, "tags_ok": tags_ok},
		"sent": {"received": _received.duplicate(), "lost": lost},
		"time_out": time_out, "notes": notes,
		"science": {"crater": _crater, "branch": _branch, "done": not _compare.is_empty(), "eval": _compare.get("eval", {}), "says": _compare.get("says", {}),
			"observations": _obs},
	})


# ---------------------------------------------------------------- the screen text

func _say(text: String) -> void:
	_msg = text
	_msg_t = 4.0


func _refresh() -> void:
	if _time_label == null:
		return   # the screen is still being built
	var left_t := int(ceil(run.left("time")))
	_time_label.text = "TIME LEFT   %d MIN" % left_t
	_power_label.text = "POWER LEFT   %d" % int(ceil(run.left("power")))
	_time_bar.queue_redraw()
	_power_bar.queue_redraw()
	for i in run.objectives.size():
		var o: Dictionary = run.objectives[i]
		_obj_labels[i].text = ("[X]  " if o["done"] else "[  ]  ") + String(o["label"])
		_obj_labels[i].add_theme_color_override("font_color", UiStyle.PHOSPHOR if o["done"] else Color(UiStyle.NEAR_WHITE, 0.92))
	for i in _chips.size():
		var sb := UiStyle.panel(12, 0.9)
		if i == _sel:
			sb = StyleBoxFlat.new()
			sb.bg_color = Color(UiStyle.COBALT, 0.45)
			sb.set_border_width_all(3)
			sb.border_color = UiStyle.PHOSPHOR
			sb.set_corner_radius_all(12)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
		_chips[i]["panel"].add_theme_stylebox_override("panel", sb)
		_chips[i]["energy"].queue_redraw()
		_chips[i]["health"].queue_redraw()
		var stl: Label = _chips[i]["status"]
		stl.text = run.status_line(i)
		stl.add_theme_color_override("font_color", UiStyle.CORAL if float(run.crew[i]["health"]) < 100.0 else Color(UiStyle.NEAR_WHITE, 0.8))
	_refresh_prompt()


func _refresh_prompt() -> void:
	var pad := _near_pad()
	var who := String(run.crew[_sel]["name"])
	if _busy:
		_prompt_title.text = "WORKING..."
		_prompt_body.text = ""
		_prompt_cost.text = ""
		_prompt_status.text = ""
		return
	if pad.is_empty():
		_prompt_title.text = "%s IS STEERING" % who.to_upper()
		_prompt_body.text = "Walk to a pad with A / D or the arrow keys, or click one. Stand on it and press E."
		_prompt_cost.text = "WALKING COSTS TIME AND ENERGY"
		_prompt_status.text = _msg if _msg_t > 0.0 else ""
		_prompt_status.add_theme_color_override("font_color", UiStyle.AMBER)
		return
	var room: Dictionary = ShipData.room(pad["room"])
	var task: Dictionary = pad["task"]
	if task.is_empty():
		_prompt_title.text = String(room["name"]).to_upper()
		_prompt_body.text = "Nothing to do here in this contract. Later contracts use this room."
		_prompt_cost.text = ""
		_prompt_status.text = _msg if _msg_t > 0.0 else ""
		return
	_prompt_title.text = "%s   -   %s" % [String(room["name"]).to_upper(), task["label"]]
	_prompt_body.text = String(task["desc"])
	var e := float(task["energy"])
	var bits: Array[String] = []
	bits.append(("%d MIN" % int(round(_time_of(task)))) if String(task["kind"]) != "plan" else "WAIT FOR THE SUN")
	if float(task["power"]) > 0.0:
		bits.append("%d POWER" % int(task["power"]))
	bits.append(("%d ENERGY" % int(e)) if e > 0.0 else ("WINS BACK %d ENERGY" % int(-e)) if e < 0.0 else "NO ENERGY")
	_prompt_cost.text = "COSTS   " + "   ".join(bits)
	var why := check_task(task)
	if _msg_t > 0.0:
		_prompt_status.text = _msg
		_prompt_status.add_theme_color_override("font_color", UiStyle.AMBER)
	elif why == "":
		_prompt_status.text = "READY. Press E."
		_prompt_status.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	else:
		_prompt_status.text = why
		_prompt_status.add_theme_color_override("font_color", UiStyle.CORAL)
