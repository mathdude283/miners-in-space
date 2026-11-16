extends SceneTree
## The Orientale camera fault: the three routes, the costs on the card, charging once, the evidence in the payload,
## the Medical Bay pointer and the return phase numbers. Stand-ins for clicks where a card or mini-game would open.
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _find(n: Node, cls: String) -> Node:
	for c in n.get_children():
		var s = c.get_script()
		if s != null and s.get_global_name() == cls:
			return c
		var r := _find(c, cls)
		if r != null:
			return r
	return null
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()

func _ship(close := true) -> BuildState:
	var s := BuildState.new()
	s.load_starter(ShipData.STARTERS[1])      # flight deck, life support, cargo, window, comms
	s.set_wings(1)
	if close:
		s.toggle_close()
	return s

func _make(bs: BuildState):
	var pd = root.get_node("PlayerData")
	pd.new_campaign()
	pd.build = bs
	pd.scenario = 0
	var run: MissionRun = pd.start_run()
	var op = load("res://ship_interior.gd").new()
	op.state = bs
	op.run = run
	op.mission_id = 0
	root.add_child(op)
	return op

func _photo(lens: String, tagged := true) -> Dictionary:
	var d := {"lens": lens, "stars": 3, "score": 0.9, "confidence": "STRONG"}
	if tagged:
		d["tag_ok"] = true
	return d

func _pad(op, room: String) -> Dictionary:
	for p in op._pads:
		if p["room"] == room:
			return p
	return {}

func _run() -> void:
	await process_frame
	var pd = root.get_node("PlayerData")
	# ---- return phase numbers
	var RP = load("res://return_phase.gd")
	check("a clean entry peaks at the planned 3.9 g", absf(RP.peak_g(1.0) - 3.9) < 0.01)
	check("a bad angle makes the entry harder", RP.peak_g(0.0) > RP.peak_g(1.0) * 1.4)
	check("chutes on time give about 20 mph", absf(RP.splash_speed(22000.0, 6000.0) - 20.0) < 0.01)
	check("no main parachutes is a very hard landing", RP.splash_speed(22000.0, -1.0) > 60.0)
	check("a late main is harder than an on-time one", RP.splash_speed(22000.0, 3000.0) > RP.splash_speed(22000.0, 6000.0))
	check("a soft landing does no damage and a hard one does", RP.splash_damage(20.0) == 0.0 and RP.splash_damage(70.0) > 30.0)
	check("time over the g limit costs health", RP.entry_damage(0.0) == 0.0 and RP.entry_damage(2.0) > 0.0 and RP.entry_damage(100.0) <= 40.0)

	# ---- no fault with both shots, and none without the close-up lens
	var op0 = _make(_ship(true))
	await create_timer(0.4).timeout
	op0._shots["wide"] = _photo("wide")
	op0._shots["close"] = _photo("close")
	await op0._maybe_fault()
	check("both shots in the first session skips the fault", op0._fault_state == "" and not op0._fault_done)
	op0.queue_free()
	var op1 = _make(_ship(false))
	await create_timer(0.4).timeout
	op1._shots["wide"] = _photo("wide")
	await op1._maybe_fault()
	check("a ship with no close-up lens has no fault", op1._fault_state == "" and not op1._fault_done)
	op1.queue_free()

	# ---- the fault opens a card with the costs
	var op = _make(_ship(true))
	await create_timer(0.4).timeout
	op._shots["wide"] = _photo("wide")
	op.run.complete("photo")
	var photo_t: Dictionary = op.TASKS["observation"]
	var send_t: Dictionary = op.TASKS["communications"]
	op.teleport_to("observation")
	op.run.spend("time", float(photo_t["time"]))
	op.run.spend("power", float(photo_t["power"]))
	op._maybe_fault()
	await create_timer(0.5).timeout
	check("the camera fault card opens", _find(op, "FaultCard") != null and op._fault_state == "choice" and op._fault_done)
	var card = _find(op, "FaultCard")
	var info: Dictionary = card.info
	check("the card lists three routes", info["routes"].size() == 3)
	check("the card names the mission minutes, power and the crew member's energy", String(info["now"]).contains("TIME") and String(info["now"]).contains("POWER") and String(info["now"]).contains("ENERGY"))
	check("the solar wing benefit is counted once", String(info["now"]).contains("+3 from 1 solar wing"))
	var a_rows: Array = info["routes"][0]["rows"]
	var close_row: Dictionary = a_rows[2]
	check("the close-up cost on the card is read from the task rules", close_row["time"] == photo_t["time"] and close_row["power"] == photo_t["power"] and close_row["energy"] == photo_t["energy"])
	check("the send cost on the card includes the task cost", a_rows[3]["power"] == send_t["power"] and a_rows[3]["time"] >= send_t["time"])
	check("diagnose uses less power than divert", info["routes"][0]["total"]["power"] < info["routes"][1]["total"]["power"])
	check("divert saves the walk time", info["routes"][1]["total"]["time"] < info["routes"][0]["total"]["time"])
	check("the card shows walking in its estimates", a_rows[0]["time"] > 0.0 and a_rows[0]["energy"] > 0.0)
	var roles: Array = info["advice"].map(func(a): return a["role"])
	check("crew advice comes from each seat", roles.has("PILOT") and roles.has("SCIENTIST") and roles.has("COMMANDER"))
	var names: Array = pd.run.crew.map(func(c): return c["name"])
	check("advice uses the names the player chose", info["advice"].all(func(a): return names.has(a["name"])))
	var sci: Dictionary = info["advice"].filter(func(a): return a["role"] == "SCIENTIST")[0]
	check("the scientist explains what the close-up adds", String(sci["text"]).contains("WHAT THE SURFACE IS LIKE"))
	var cmd: Dictionary = info["advice"].filter(func(a): return a["role"] == "COMMANDER")[0]
	check("the commander gives the time and power left", String(cmd["text"]).contains("min") and String(cmd["text"]).contains("power"))
	var pil: Dictionary = info["advice"].filter(func(a): return a["role"] == "PILOT")[0]
	check("the pilot talks about steadiness", String(pil["text"]).contains("shake"))
	var t_before: float = op.run.left("time")
	await create_timer(1.0).timeout
	check("mission time is paused while the card is open", op.run.left("time") == t_before)
	var op_poor = _make(_ship(true))
	await create_timer(0.3).timeout
	op_poor._shots["wide"] = _photo("wide")
	op_poor.run.drain("power", 17.0)
	var poor: Dictionary = op_poor.fault_info()
	check("with little power left the divert route is unavailable and says why", not poor["routes"][1]["ok"] and String(poor["routes"][1]["why"]).contains("power"))
	check("unavailable routes carry their reason on the card", String(poor["routes"][1]["verdict"]).length() > 10)
	op_poor.queue_free()

	# ---- ROUTE A: diagnose
	card.choose("diagnose")
	await create_timer(0.3).timeout
	check("diagnose: the card closes and the Flight Deck is next", _find(op, "FaultCard") == null and op._fault_state == "diagnose" and op._next_room == "flight-deck")
	check("the next instruction is concrete", op._next_text == "Diagnose camera fault at Flight Deck")
	check("the camera cannot be used yet", String(op.check_task(op.TASKS["observation"])).contains("Diagnose"))
	var deck_task: Dictionary = op._task_of(_pad(op, "flight-deck"))
	check("the Flight Deck has a useful job now", deck_task["kind"] == "diagnose" and String(op.check_task(deck_task)) == "")
	var t0: float = op.run.left("time")
	var p0: float = op.run.left("power")
	var e0: float = float(op.run.crew[1]["energy"])
	op._select(1)
	op.teleport_to("flight-deck")
	await op._perform(deck_task)
	check("diagnosing charges time, power and energy once", absf(t0 - op.run.left("time") - 5.0) < 0.6 and absf(p0 - op.run.left("power") - 1.0) < 0.01 and e0 - float(op.run.crew[1]["energy"]) >= 6.0)
	check("then the camera is back and the Observation Bay is next", op._fault_state == "fixed" and op._next_room == "observation")
	check("the job cannot be repeated for a second charge", String(op.check_task(deck_task)) != "")
	var p1: float = op.run.left("power")
	op._select(0)
	check("switching crew does not charge again", op.run.left("power") == p1)
	check("the close-up is allowed after the fix", String(op.check_task(op.TASKS["observation"])) == "")
	op._shots["close"] = _photo("close")
	op._fault_state = "closed"
	op._fault["close_taken"] = true
	var sumA: Dictionary = op.fault_summary()
	check("the summary names the call and the cost", sumA["happened"] and sumA["route"] == "diagnose" and sumA["cost"]["time"] >= 5.0 and sumA["ledger"].size() == 1)
	op.queue_free()

	# ---- ROUTE B: divert power
	var opb = _make(_ship(true))
	await create_timer(0.4).timeout
	opb._shots["wide"] = _photo("wide")
	opb.choose_fault("divert")
	var obs_pad: Dictionary = _pad(opb, "observation")
	check("divert: the Observation Bay is next and offers RESTORE", opb._fault_state == "restore" and opb._next_room == "observation" and opb._task_of(obs_pad)["kind"] == "restore")
	var restore: Dictionary = opb._task_of(obs_pad)
	var tb: float = opb.run.left("time")
	var pb: float = opb.run.left("power")
	opb.teleport_to("observation")
	await opb._perform(restore)
	check("restoring costs the stated power and time", absf(pb - opb.run.left("power") - 4.0) < 0.01 and absf(tb - opb.run.left("time") - 2.0) < 0.3)
	check("then the close-up is next", opb._fault_state == "fixed" and opb._next_text.contains("close-up"))
	opb.queue_free()

	# ---- ROUTE C: send the wide shot first
	var opc = _make(_ship(true))
	await create_timer(0.4).timeout
	opc._shots["wide"] = _photo("wide")
	opc.choose_fault("send")
	check("send first: Communications is next", opc._fault_state == "send" and opc._next_room == "communications" and opc._next_text == "Send the wide shot from Communications")
	check("the camera cannot be used before sending", String(opc.check_task(opc.TASKS["observation"])).contains("send the wide shot"))
	opc._received.append("wide")
	opc._after_wide_sent()
	check("with enough left a close-up retry stays available", opc._fault_state == "restore" and opc._next_room == "observation")
	var opc2 = _make(_ship(true))
	await create_timer(0.4).timeout
	opc2._shots["wide"] = _photo("wide")
	opc2.choose_fault("send")
	opc2.run.drain("power", 15.0)
	opc2._received.append("wide")
	opc2._after_wide_sent()
	check("with too little power the retry is closed and says why", opc2._fault_state == "lost" and String(opc2._fault["lost_reason"]).contains("power"))
	check("the lost camera cannot take photos and says why", String(opc2.check_task(opc2.TASKS["observation"])).contains("cannot be recovered"))
	opc.queue_free()
	opc2.queue_free()

	# ---- Medical Bay pointer
	var bs_med := _ship(true)
	bs_med.place_room("medical")
	var opm = _make(bs_med)
	await create_timer(0.4).timeout
	check("nobody hurt: no medical hint", opm._hint_room == "")
	opm.run.hurt(1, 30.0, "Test injury.", "Rough separation")
	await create_timer(0.3).timeout
	check("someone hurt and a Medical Bay aboard: the pad is highlighted", opm._hint_room == "medical" and opm._hint_text.contains("Medical Bay"))
	var med_task: Dictionary = opm._task_of(_pad(opm, "medical"))
	opm._select(1)
	opm.teleport_to("medical")
	var h0: float = float(opm.run.crew[1]["health"])
	await opm._perform(med_task)
	check("treatment mends the hurt crew member", float(opm.run.crew[1]["health"]) > h0)
	var opn = _make(_ship(true))
	await create_timer(0.4).timeout
	opn.run.hurt(1, 30.0, "Test injury.", "Rough separation")
	await create_timer(0.3).timeout
	var stl: String = opn._chips[1]["status"].text
	check("without a Medical Bay the crew panel says so", stl.contains("No Medical Bay"))
	opm.queue_free()
	opn.queue_free()
	print("FAILS: ", fails)
	quit(fails)
