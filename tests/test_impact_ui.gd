extends SceneTree
## Impact Watch end to end through the real screens: the flyer watches and logs sightings, chooses what to send within the budget,
## the case file goes out with no truth in it, Mission Control reviews only what arrived, and the review is judged on justification.
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
	var IW = load("res://impact_watch.gd")
	var full := _ship(["observation", "flight-deck", "science-lab", "communications"], true, true, 2)
	var minimal := _ship(["observation", "communications"], true, false, 0)
	# marks the player would log: right window, right time, near the flash
	var marks_all: Array = [
		{"vp": "V1", "t": 22.0, "x": 420.0, "y": 240.0}, {"vp": "V2", "t": 22.5, "x": 140.0, "y": 295.0},
		{"vp": "V3", "t": 51.0, "x": 255.0, "y": 405.0}, {"vp": "V1", "t": 70.5, "x": 310.0, "y": 185.0}]
	var av: Dictionary = IW.availability(full, marks_all, 8.0)
	check("a full ship can send everything it logged", av.values().all(func(w): return w == ""))
	var av_min: Dictionary = IW.availability(minimal, marks_all, 0.0)
	check("a minimal ship can send the Window 1 log", av_min["A1"] == "")
	check("but not a tight crop without the close lens", av_min["A2"] == "needs the close lens")
	check("and not a second window it does not have", av_min["A4"] == "needs a Flight Deck")
	check("the wide frame works with the wide lens", av_min["C3"] == "")
	check("a Science camera log needs a Science Lab", av_min["B1"] == "needs a Science Lab" and av_min["N1"] == "needs a Science Lab")
	check("a retelling needs a Flight Deck", av_min["B3"] == "needs a Flight Deck")
	var late: Array = [{"vp": "V1", "t": 40.0, "x": 412.0, "y": 236.0}]
	check("a click at the right place but the wrong time logs nothing", IW.availability(full, late, 8.0)["A1"] == "not logged")
	var far: Array = [{"vp": "V1", "t": 22.0, "x": 700.0, "y": 60.0}]
	check("a click in the right time but the wrong place logs nothing", IW.availability(full, far, 8.0)["A1"] == "not logged")
	var wrongwin: Array = [{"vp": "V2", "t": 22.0, "x": 412.0, "y": 236.0}]
	check("looking through the wrong window does not count", IW.availability(full, wrongwin, 8.0)["A1"] == "not logged")
	check("the silence log needs the camera to have been watched", IW.availability(full, marks_all, 2.0)["N1"] != "")
	check("packets grow with solar wings", IW.packets(full) == 12 + 8 and IW.packets(minimal) == 12)
	check("everything cannot be sent", ImpactScenario.total_cost() > IW.packets(full))
	# delivery
	var over: Dictionary = IW.deliver(minimal, ["A1", "A2", "A3", "C1", "C2", "C3", "B1", "B2", "B3", "N1", "A4", "A5"], "s")
	check("sending more than the budget is refused", not bool(over["ok"]) and String(over["error"]).contains("fit"))
	check("sending nothing is refused", not bool(IW.deliver(minimal, [], "s")["ok"]))
	var good: Dictionary = IW.deliver(full, ["A1", "A4", "B1", "C1", "C3"], "salt1")
	check("a sensible set is delivered", bool(good["ok"]) and good["sent_cost"] == 8)
	var txt := JSON.stringify(good["case"]).to_lower()
	check("the file holds no truth", not txt.contains("\"real\"") and not txt.contains("answer") and not txt.contains("truth") and not txt.contains("\"cand\""))
	check("and only the delivered records", good["case"]["records"].size() == 5)
	# the whole thing through the real screens
	var w = IW.new()
	w.state = full
	w.crew = [{"name": "Maya", "role": "Commander", "health": 100.0}, {"name": "Jo", "role": "Pilot", "health": 100.0}, {"name": "Rin", "role": "Scientist", "health": 100.0}]
	w.salt = "uitest"
	root.add_child(w)
	await create_timer(0.4).timeout
	await _snap("impact_brief")
	var got := {}
	w.finished.connect(func(r): got.merge(r, true))
	w._start_watch()
	await create_timer(0.3).timeout
	# the player looks through Window 1 and clicks on the flash at the right moment
	w.set_time(21.6, "V1")
	await process_frame
	w.log_sighting(415.0, 238.0)
	await _snap("impact_watch_flash")
	w.set_time(21.6, "V2")
	await process_frame
	w.log_sighting(135.0, 300.0)
	w.set_time(50.0, "V3")
	await process_frame
	w.log_sighting(262.0, 408.0)
	w.set_time(70.0, "V1")
	await process_frame
	w.log_sighting(305.0, 185.0)
	w._silence_watched = 8.0
	w.end_watch_now()
	await create_timer(0.4).timeout
	await _snap("impact_send")
	for id in ["A1", "A4", "B1", "C1", "C3"]:
		w.choose_product(id)
	w.choose_product("A3")
	w.choose_product("A5")
	w.choose_product("C2")
	await process_frame
	check("the budget stops a choice that does not fit", w._chosen.size() >= 5 and IW.cost_of(w._chosen.keys()) <= IW.packets(full))
	w._send()
	await process_frame
	check("sending delivers a validated case file", not got.is_empty() and bool(got["ok"]) and FileAccess.file_exists(String(got["path"])))
	var loaded: Dictionary = ImpactCase.load_case(String(got["path"]))
	check("the file loads back and validates", bool(loaded["ok"]))
	# Mission Control sees only the file
	var mc = load("res://impact_control.gd").new()
	mc.case = loaded["case"]
	mc.map = got["map"]
	mc.budget = got["budget"]
	mc.sent_cost = got["sent_cost"]
	root.add_child(mc)
	await create_timer(0.5).timeout
	await _snap("impact_control")
	var cands: Array = ImpactReview.candidates(loaded["case"])
	check("Mission Control finds the three candidates", cands.size() == 3)
	var done := {}
	mc.finished.connect(func(r): done.merge(r, true))
	check("the review cannot be locked before every candidate has a verdict", mc._lock_btn.disabled)
	for c in cands:
		var groups := {}
		var ids: Array = []
		for r in c["records"]:
			groups[String(r["source_group"])] = true
		var verdict := "supported" if groups.size() >= 2 else "possible"
		for r in c["records"]:
			if groups.size() >= 2 or ids.is_empty():
				ids.append(String(r["id"]))
			if String(r["finding"]) == "reflection_moves_with_window":
				verdict = "artifact"
		if verdict == "artifact":
			ids = c["records"].map(func(r): return String(r["id"]))
		mc.set_verdict(String(c["id"]), verdict)
		for id in ids:
			mc.cite(String(c["id"]), id, true)
	await process_frame
	check("with every verdict given the review can be locked", not mc._lock_btn.disabled)
	mc.lock()
	await create_timer(0.4).timeout
	await _snap("impact_locked")
	check("a well-justified review is complete", bool(mc._eval["complete"]))
	check("a review file was saved bound to the case", FileAccess.file_exists("user://impact_reviews/review_%s.json" % String(loaded["case"]["case_id"])))
	check("the reveal is available because the run record is aboard", not mc.map.is_empty())
	mc.queue_free()
	w.queue_free()
	# a reviewer who was careless: calls the reflection a real impact on the strength of a tight crop
	var careless: Dictionary = IW.deliver(full, ["C1", "C2", "A1", "A2"], "salt2")
	var cc: Array = careless["case"]["records"]
	var cands2: Array = ImpactReview.candidates(careless["case"])
	var verdicts: Array = []
	for c in cands2:
		verdicts.append({"candidate": c["id"], "verdict": "supported", "cites": c["records"].map(func(r): return String(r["id"]))})
	var ev: Dictionary = ImpactReview.evaluate(careless["case"], verdicts)
	check("calling everything supported on one witness each is not justified", not bool(ev["complete"]))
	check("the same scenario with two sends gives different files", JSON.stringify(good["case"]) != JSON.stringify(careless["case"]))
	# cleanup of this test's files
	for d in ["user://impact_cases", "user://impact_reviews", ImpactCase.RUNS_DIR]:
		var dir := DirAccess.open(d)
		if dir != null:
			for f in dir.get_files():
				dir.remove(f)
	print("FAILS: ", fails)
	quit(fails)
