extends SceneTree
## Contract 03 wiring: it opens after Contract 02, every legal ship has a way to complete it honestly, the flight plan names the
## stages for this contract, the report carries the review, and the second person can open the case and the review files.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
func _ship(rooms: Array, wide: bool, close: bool, wings: int) -> BuildState:
	var b := BuildState.new()
	for i in rooms.size():
		b.bays[i] = String(rooms[i])
	b.wide = wide
	b.close = close
	b.wings = wings
	return b
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var pd = root.get_node("PlayerData")
	var IW = load("res://impact_watch.gd")
	var FL = load("res://flight.gd")
	var RS = load("res://report_screen.gd")
	check("Contract 03 is playable", bool(Missions.get_mission(2)["available"]))
	# the campaign order
	pd.new_campaign()
	pd.campaign["crew_chosen"] = true
	var ship: BuildState = pd.get_build()
	for i in ["flight-deck", "life-support", "observation", "communications", "science-lab", "crew-quarters"].size():
		ship.bays[i] = ["flight-deck", "life-support", "observation", "communications", "science-lab", "crew-quarters"][i]
	ship.wide = true
	ship.close = true
	ship.wings = 1
	check("Contract 03 waits for Contract 02", not pd.contract_status(2)["open"])
	pd.complete_contract(0)
	pd.complete_contract(1)
	check("after Contract 02 the next contract is 03 and it is open", pd.contract_status(2)["open"] and not bool(pd.campaign["over"]))
	pd.complete_contract(2)
	check("finishing all three ends the campaign as a win", bool(pd.campaign["over"]) and bool(pd.campaign["won"]))
	# every legal ship (the minimum the contract asks for) has the stages it needs
	var minimal := _ship(["flight-deck", "life-support", "observation", "communications", "", ""], true, false, 0)
	var plan: Array = FL.make_plan(minimal, 2)
	check("the stages are WATCH and SEND for this contract", plan[3]["name"] == "WATCH" and plan[4]["name"] == "SEND")
	check("a ship with only the minimum can start the watch and the send", plan[3]["ok"] and plan[4]["ok"])
	var only_close := _ship(["flight-deck", "life-support", "observation", "communications", "", ""], false, true, 0)
	check("a ship with only the close lens can too", FL.make_plan(only_close, 2)[3]["ok"])
	var no_lens := _ship(["flight-deck", "life-support", "observation", "communications", "", ""], false, false, 0)
	check("no lens still cannot watch", not FL.make_plan(no_lens, 2)[3]["ok"])
	check("Contract 01 stage names are unchanged", FL.make_plan(minimal, 0)[3]["name"] == "PHOTO")
	# an honest path exists for the minimal ship: log A and C in Window 1, send the log, the crop-free wide frame, and the reflection log
	var marks: Array = [{"vp": "V1", "t": 22.0, "x": 412.0, "y": 236.0}, {"vp": "V1", "t": 70.5, "x": 300.0, "y": 180.0}]
	var av: Dictionary = IW.availability(minimal, marks, 0.0)
	var picks := ["A1", "C1", "C3"]
	check("the minimal ship can send the honest set", picks.all(func(id): return av[id] == ""))
	var r: Dictionary = IW.deliver(minimal, picks, "minimal")
	check("and it fits in the base packets", bool(r["ok"]))
	var cands: Array = ImpactReview.candidates(r["case"])
	var verdicts: Array = []
	for c in cands:
		var recs: Array = c["records"]
		var refl: Array = recs.filter(func(x): return String(x["finding"]) == "reflection_moves_with_window")
		if not refl.is_empty():
			verdicts.append({"candidate": c["id"], "verdict": "artifact", "cites": [refl[0]["id"]]})
		else:
			verdicts.append({"candidate": c["id"], "verdict": "possible", "cites": [recs[0]["id"]]})
	var ev: Dictionary = ImpactReview.evaluate(r["case"], verdicts)
	check("an honest reviewer of the minimal ship's case completes the contract", bool(ev["complete"]))
	var close_only := _ship(["flight-deck", "life-support", "observation", "communications", "", ""], false, true, 0)
	var av2: Dictionary = IW.availability(close_only, marks, 0.0)
	var r2: Dictionary = IW.deliver(close_only, ["A1", "C1", "C2"], "closeonly")
	var cands2: Array = ImpactReview.candidates(r2["case"])
	var v2: Array = []
	for c in cands2:
		v2.append({"candidate": c["id"], "verdict": "possible", "cites": [c["records"][0]["id"]]})
	check("the close-lens ship can send crops but not the wide frame", av2["C2"] == "" and av2["C3"] == "needs the wide lens")
	check("and a careful 'possible' on each still completes the contract", bool(ImpactReview.evaluate(r2["case"], v2)["complete"]))
	# the report carries the review
	pd.new_campaign()
	pd.scenario = 2
	var bs: BuildState = pd.get_build()
	bs.load_starter(ShipData.STARTERS[1])
	var run: MissionRun = pd.start_run()
	run.impact = {"sent": true, "complete": true, "budget": 12, "sent_cost": 6, "eval": ev, "reveal": ImpactReview.reveal(r["case"], r["map"], ev, 12, 6)}
	var txt: String = RS.build_text(run, Missions.get_mission(2))
	check("the saved report lists the packets and each verdict", txt.contains("6 of 12 packets sent") and txt.contains("Justified"))
	check("and says it is fictional and a game rule", txt.contains("fictional") and txt.contains("GAME"))
	var rs: Node = load("res://report_screen.tscn").instantiate()
	root.add_child(rs)
	current_scene = rs
	await create_timer(0.8).timeout
	await _snap("report_contract3")
	var labels: Array = []
	for l in rs.find_children("*", "Label", true, false):
		labels.append(String(l.text))
	check("the report screen shows the review", labels.any(func(t): return t.contains("packets sent")) and not labels.any(func(t): return t == "Nothing reached Earth."))
	check("and does not show the Orientale NASA block", not labels.any(func(t): return t.contains("NASA'S ANNOTATED") or t.contains("REAL NASA VIEW")))
	rs.queue_free()
	await process_frame
	# the not-sent report
	run.impact = {"sent": false, "complete": false, "budget": 12, "sent_cost": 0}
	check("sending nothing is reported plainly", RS.impact_lines(run).any(func(t): return t.contains("Nothing reached Mission Control")))
	# files: the second person opens the case, the flyer opens the review
	for d in ["user://impact_cases", "user://impact_reviews", ImpactCase.RUNS_DIR]:
		DirAccess.make_dir_recursive_absolute(d)
	var path := "user://impact_cases/test_case_c3.json"
	check("the case file saves", ImpactCase.save_case(r["case"], path) == "")
	ImpactCase.save_run(r["case"], r["map"], 6, 12)
	var ms: Node = load("res://mission_select.tscn").instantiate()
	root.add_child(ms)
	current_scene = ms
	await create_timer(0.8).timeout
	await _snap("select_contract3")
	var msg: String = ms.open_case_file("user://impact_cases/does_not_exist.json")
	check("a missing file gives a readable message", msg != "")
	var junk := FileAccess.open("user://impact_cases/test_junk.json", FileAccess.WRITE)
	junk.store_string("{\"hello\": 1}")
	junk.close()
	check("a file that is not a case gives a readable message", ms.open_case_file("user://impact_cases/test_junk.json") != "")
	var tampered: Dictionary = JSON.parse_string(JSON.stringify(r["case"]))
	tampered["records"][0]["truth"] = "real"
	var tf := FileAccess.open("user://impact_cases/test_tampered.json", FileAccess.WRITE)
	tf.store_string(JSON.stringify(tampered))
	tf.close()
	check("a case with a hidden truth field is refused", ms.open_case_file("user://impact_cases/test_tampered.json") != "")
	check("a good case opens for review", ms.open_case_file(path) == "")
	await create_timer(0.5).timeout
	var mc = ms.find_children("*", "Control", true, false).filter(func(n): return n.get_script() != null and n.get_script().get_global_name() == "ImpactControl")
	check("the review board is on screen", mc.size() == 1)
	if mc.size() == 1:
		check("and the run record on this computer lets it reveal afterwards", not mc[0].map.is_empty())
		mc[0].queue_free()
	await process_frame
	# a review file coming back is judged against the case on this computer
	var rv := ImpactCase.build_verdict_file(r["case"], verdicts)
	var rvp := "user://impact_reviews/test_review_c3.json"
	var rf := FileAccess.open(rvp, FileAccess.WRITE)
	rf.store_string(JSON.stringify(rv))
	rf.close()
	check("a review file opens and is shown already judged", ms.open_case_file(rvp) == "")
	await create_timer(0.6).timeout
	await _snap("review_received")
	var mc2 = ms.find_children("*", "Control", true, false).filter(func(n): return n.get_script() != null and n.get_script().get_global_name() == "ImpactControl")
	check("the judged review is locked and complete", mc2.size() == 1 and mc2[0]._locked and bool(mc2[0]._eval["complete"]))
	var rv_bad := ImpactCase.build_verdict_file(r["case"], verdicts)
	rv_bad["case_hash"] = "0000"
	var bf := FileAccess.open("user://impact_reviews/test_review_bad.json", FileAccess.WRITE)
	bf.store_string(JSON.stringify(rv_bad))
	bf.close()
	if mc2.size() == 1:
		mc2[0].queue_free()
	check("a review that does not match the case is refused", ms.open_case_file("user://impact_reviews/test_review_bad.json") != "")
	for d in ["user://impact_cases", "user://impact_reviews", ImpactCase.RUNS_DIR]:
		var dir := DirAccess.open(d)
		if dir != null:
			for f in dir.get_files():
				dir.remove(f)
	print("FAILS: ", fails)
	quit(fails)
