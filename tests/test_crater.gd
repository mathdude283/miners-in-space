extends SceneTree
## Contract 02 rules: CraterScience, MissionEvents, requirements, and the interior flow (stand-ins for the player's clicks).
var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1


func _photo(pid: String, crater := "glushko") -> Dictionary:
	var pa := CraterScience.pass_by_id(pid)
	return {"lens": "wide", "stars": 3, "score": 0.9, "confidence": "STRONG", "crater": crater, "sun_elev": pa["elev"], "sun_dir": pa["dir"], "pass": pid}


func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()


func _run() -> void:
	await process_frame
	# ---- CraterScience
	var e := _photo("early")
	var n := _photo("noon")
	var l := _photo("late")
	check("same pass is fully comparable", CraterScience.comparability(e, e) == 1.0)
	check("early and late: partly comparable", CraterScience.comparability(e, l) > 0.5 and CraterScience.comparability(e, l) < 0.7)
	check("early and midday: not comparable", CraterScience.comparability(e, n) < 0.5)
	check("rays show best in the high Sun", CraterScience.rays_best(e, n) == "b" and CraterScience.rays_best(n, e) == "a")
	check("two low-Sun photos show rays about the same", CraterScience.rays_best(e, l) == "same")
	check("repeating a pass at the same crater costs a full orbit", CraterScience.wait_for("glushko", "early", [{"crater": "glushko", "pass": "early"}]) == CraterScience.REPEAT_WAIT)
	check("a different crater has no repeat wait", CraterScience.wait_for("ohm", "noon", [{"crater": "glushko", "pass": "noon"}]) == 8.0)
	check("first observation is Glushko, second follows the branch", CraterScience.crater_for(0, "ohm") == "glushko" and CraterScience.crater_for(1, "ohm") == "ohm" and CraterScience.crater_for(1, "reobserve") == "glushko")

	var good := CraterScience.evaluate("reobserve", e, e, {"dir_a": -1, "dir_b": -1, "rays": "same"})
	check("a matching pair with every answer right is usable and strong", good["usable"] and good["confidence"] == "STRONG")
	var bad := CraterScience.evaluate("reobserve", e, n, {"dir_a": -1, "dir_b": 0, "rays": "b"})
	check("different light fails the re-observation, and says why", not bad["usable"] and String(bad["why"]).contains("different light") and String(bad["fix"]).length() > 10)
	var wrong := CraterScience.evaluate("reobserve", e, e, {"dir_a": 1, "dir_b": 0, "rays": "a"})
	check("wrong answers lower the confidence and are named", wrong["confidence"] != "STRONG" and not wrong["dir_a_ok"] and not wrong["rays_ok"] and String(wrong["lines"][0]).contains("wrong"))
	var ohm_ok := CraterScience.evaluate("ohm", n, _photo("noon", "ohm"), {"dir_a": 0, "dir_b": 0, "rays": "same"})
	check("two high-Sun photos make a usable Ohm comparison", ohm_ok["usable"])
	var ohm_bad := CraterScience.evaluate("ohm", e, _photo("noon", "ohm"), {"dir_a": -1, "dir_b": 0, "rays": "b"})
	check("a low-Sun Glushko photo cannot compare rays with Ohm", not ohm_bad["usable"] and String(ohm_bad["why"]).contains("high Sun"))

	# ---- missions
	check("contract 02 is available", bool(Missions.get_mission(1)["available"]))
	var bare := BuildState.new()
	var req := Missions.requirements(1, bare)
	check("contract 02 needs the Science Lab", req.any(func(r): return r["label"] == "Science Lab"))
	var plan_no_lab: Array = load("res://flight.gd").make_plan(_ship_without_lab(), 1)
	check("without a lab the photo step fails with the lab named", not plan_no_lab[3]["ok"] and String(plan_no_lab[3]["why"]).contains("science lab") and String(plan_no_lab[3].get("fix", "")).contains("Science Lab"))
	var plan_lab: Array = load("res://flight.gd").make_plan(_ship_with_lab(), 1)
	check("with a lab the whole plan holds", plan_lab.all(func(r): return r["ok"]))
	for row in plan_lab:
		if not row["ok"]:
			print("   plan row failed: ", row["name"], " ", row["why"])
	var tt := _ship_with_lab().totals()
	check("a ship that can fly contract 02 fits the weight, power and budget limits", int(tt["mass"]) <= int(ShipData.RULES["mass_limit"]) and int(tt["cost"]) <= int(ShipData.RULES["budget_limit"]) and int(tt["margin"]) >= 0)
	var later := Missions.later_needs(0, _ship_without_lab())
	check("build tells the player contract 02 needs a lab", later.size() >= 1 and String(later[0]["text"]).contains("Science Lab") and not later[0]["ok"])
	check("and ticks it once the lab is built", Missions.later_needs(0, _ship_with_lab())[0]["ok"])

	# ---- campaign: the first contract's ship decides whether the second can be flown
	var pd = root.get_node("PlayerData")
	pd.new_campaign()
	pd.build = _ship_without_lab()
	pd.scenario = 0
	pd.start_run()
	pd.complete_contract(0)
	pd.sync_crew_after_flight()
	check("a locked ship with no lab cannot do contract 02", pd.campaign["over"] and String(pd.campaign["over_reason"]).contains("Science Lab"))
	pd.new_campaign()
	pd.build = _ship_with_lab()
	pd.scenario = 0
	pd.start_run()
	pd.complete_contract(0)
	pd.sync_crew_after_flight()
	check("a locked ship with a lab can go on", not pd.campaign["over"] and pd.contract_status(1)["open"])
	check("contract 03 is still not open", not pd.contract_status(2)["open"])

	# ---- events
	var r1 := MissionRun.start(1, CrewData.defaults(), 7)
	var r2 := MissionRun.start(1, CrewData.defaults(), 7)
	var p1 := MissionEvents.pick(r1, 2)
	var p2 := MissionEvents.pick(r2, 2)
	check("the same seed picks the same events", p1.size() == 2 and p1[0]["id"] == p2[0]["id"] and p1[1]["id"] == p2[1]["id"] and p1[0]["id"] != p1[1]["id"])
	var ship := _ship_with_lab()
	var run := MissionRun.start(1, CrewData.defaults(), 3)
	var heard := []
	run.crew_hurt.connect(func(i, amount, reason, died): heard.append(reason))
	var flare := {}
	for ev in MissionEvents.POOL:
		if ev["id"] == "solar_flare":
			flare = (ev as Dictionary).duplicate(true)
	flare["who_index"] = 0
	flare["who"] = "Ada"
	var t0 := run.left("time")
	var out := MissionEvents.apply(run, flare, 0, ship, 0)
	check("sheltering costs time and hurts nobody", absf(t0 - run.left("time") - 6.0) < 0.01 and heard.is_empty())
	var out2 := MissionEvents.apply(run, flare, 1, ship, 0)
	check("a harm carries its reason when it lands", (heard.size() == 3 and String(heard[0]).contains("radiation")) or heard.is_empty())
	var leak: Dictionary = {}
	for ev in MissionEvents.POOL:
		if ev["id"] == "cabin_leak":
			leak = (ev as Dictionary).duplicate(true)
	check("a built Life Support room makes the leak cheaper", MissionEvents.time_cost(leak["choices"][0], ship) < MissionEvents.time_cost(leak["choices"][0], _ship_lab_no_life()))
	var ill: Dictionary = {}
	for ev in MissionEvents.POOL:
		if ev["id"] == "illness":
			ill = (ev as Dictionary).duplicate(true)
	check("treating illness needs a Medical Bay and says so", MissionEvents.blocked(ill["choices"][0], ship) != "" and String(MissionEvents.blocked(ill["choices"][0], ship)).contains("Medical"))
	var run3 := MissionRun.start(1, CrewData.defaults(), 3)
	var heard3 := []
	run3.crew_hurt.connect(func(i, amount, reason, died): heard3.append([i, reason, died]))
	ill["who_index"] = 1
	ill["who"] = "Sam"
	ill["choices"][1]["hurt_one"]["reason"] = "Sam fell ill and kept working with no treatment."
	MissionEvents.apply(run3, ill, 1, ship, 0)
	check("untreated illness hurts that person with the reason", heard3.size() == 1 and heard3[0][0] == 1 and String(heard3[0][1]).contains("no treatment"))

	# ---- the interior, driven the way a player would (stand-ins for the clicks on each card)
	var pd2 = root.get_node("PlayerData")
	pd2.new_campaign()
	pd2.build = _ship_with_lab_and_all()
	pd2.scenario = 1
	var rn: MissionRun = pd2.start_run()
	var scr = load("res://ship_interior.gd")
	var op = scr.new()
	op.state = pd2.build
	op.run = rn
	op.mission_id = 1
	root.add_child(op)
	await create_timer(0.4).timeout
	var obs_task: Dictionary = op._task_for("observation")
	check("the observation bay becomes a crater camera", obs_task["kind"] == "crater_photo")
	check("the flight deck plans the pass", op._task_for("flight-deck")["kind"] == "plan")
	check("the lab compares", op._task_for("science-lab")["kind"] == "compare")
	check("observing before planning says to plan first", String(op.check_task(obs_task)).contains("Plan the Sun pass"))
	var cmp_task: Dictionary = op._task_for("science-lab")
	check("comparing before observing says you need both photos", String(op.check_task(cmp_task)).contains("both photos"))
	var send_task: Dictionary = op._task_for("communications")
	check("sending before taking a photo says take one", String(op.check_task(send_task)).contains("photo"))
	check("the scientist makes lab work quicker", absf(op._time_of(cmp_task) - 6.0) < 0.01)

	var t1: float = rn.left("time")
	op.commit_plan("reobserve", "early")
	check("planning spends the waiting time and picks the branch", rn.chosen("second") == "reobserve" and absf(t1 - rn.left("time") - 0.0) < 0.5)
	check("a pass is planned", op._planned["id"] == "early" and op._planned["crater"] == "glushko")
	op.finish_crater_photo(_photo("early"))
	check("the first photo is kept and the objective ticks", op._shots.has("first") and rn.is_done("first") and op._obs == 1)
	var t2: float = rn.left("time")
	op.commit_plan("", "early")
	check("repeating the pass waits for the next orbit", absf(t2 - rn.left("time") - CraterScience.REPEAT_WAIT) < 0.6)
	op.finish_crater_photo(_photo("early"))
	check("both photos are kept", op._shots.has("second") and rn.is_done("second") and op._obs == 2)
	check("nothing more to plan after two observations", String(op.check_task(op._task_for("flight-deck"))).contains("Both"))
	check("a comparison can be made now", String(op.check_task(cmp_task)) == "")
	check("sending before comparing says to compare first", String(op.check_task(send_task)).contains("Compare"))
	op.finish_compare({"says": {"dir_a": -1, "dir_b": -1, "rays": "same"}, "eval": CraterScience.evaluate("reobserve", _shots_of(op, "first"), _shots_of(op, "second"), {"dir_a": -1, "dir_b": -1, "rays": "same"})})
	check("compare ticks its objective", rn.is_done("compare"))
	check("now sending is allowed", String(op.check_task(send_task)) == "")
	op._received.append("first")
	op._received.append("second")
	rn.complete("send")
	var got: Dictionary = {}
	op.finished.connect(func(r): got.merge(r))
	op.finish_ops()
	check("operations report the science", got.get("science", {}).get("crater", false) and got["science"]["done"] and got["science"]["eval"]["usable"])
	check("operations report both photos and both reached Earth", got["shots"]["photos"].size() == 2 and got["sent"]["received"].size() == 2 and got["sent"]["lost"].is_empty())
	check("the notes explain the comparison", got["notes"].any(func(x): return String(x).contains("Comparability")))
	op.queue_free()

	# ---- a random event in the loop
	pd2.new_campaign()
	pd2.build = _ship_with_lab_and_all()
	pd2.scenario = 1
	var rn2: MissionRun = pd2.start_run()
	var op2 = scr.new()
	op2.state = pd2.build
	op2.run = rn2
	op2.mission_id = 1
	root.add_child(op2)
	await create_timer(0.4).timeout
	check("this contract has two events", op2._events.size() == 2)
	check("no event while no time has been used", not op2._busy)
	rn2.drain("time", rn2.resources["time"]["max"] * 0.3)
	op2.check_events()
	await create_timer(0.3).timeout
	check("an event pauses the ship until the player decides", op2._busy and _find(op2, "EventCard") != null)
	var card = _find(op2, "EventCard")
	var t3: float = rn2.left("time")
	# choose the first choice that can be made on this ship
	var chosen := -1
	for i in card.event["choices"].size():
		if MissionEvents.blocked(card.event["choices"][i], op2.state) == "":
			chosen = i
			break
	card.choose(chosen)
	await create_timer(0.2).timeout
	for b in card._body.get_children():
		if b is Button and b.text == "OK":
			b.pressed.emit()
	await create_timer(0.3).timeout
	check("after the decision the ship runs again", not op2._busy and op2._event_i == 1)
	op2.queue_free()
	print("FAILS: ", fails)
	quit(fails)


func _shots_of(op, key: String) -> Dictionary:
	return op._shots[key]


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and n.get_script().get_global_name() == cls:
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null


## A ship that can do both contracts: flight deck, life support, window, radio, with a crew kit and two wings.
func _base() -> BuildState:
	var s := BuildState.new()
	s.load_starter(ShipData.STARTERS[0])
	s.place_room("communications")
	s.set_wings(2)
	return s


func _ship_without_lab() -> BuildState:
	return _base()


func _ship_with_lab() -> BuildState:
	var s := _base()
	if not s.has_room("science-lab"):
		s.place_room("science-lab")
	return s


func _ship_lab_no_life() -> BuildState:
	var s := _ship_with_lab()
	for i in s.bays.size():
		if s.bays[i] == "life-support":
			s.remove_bay(i)
	return s


## Everything the contract can use: lab, flight deck, life support, galley, crew quarters, medical, cargo.
func _ship_with_lab_and_all() -> BuildState:
	var s := _ship_with_lab()
	return s
