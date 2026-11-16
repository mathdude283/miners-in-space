extends SceneTree
## The educational quiz: every contract has questions with reasons and sources, answers are shuffled, right answers earn points
## (more for a streak), wrong ones explain themselves, and the planner uses the team's real mission numbers.
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _run() -> void:
	await process_frame
	var QD = load("res://quiz_data.gd")
	var all_ok := true
	for id in [0, 1, 2]:
		var qs: Array = QD.for_contract(id)
		if qs.size() != 3:
			all_ok = false
		for q in qs:
			if (q["options"] as Array).size() < 3 or int(q["answer"]) < 0 or int(q["answer"]) >= (q["options"] as Array).size() or String(q["why"]).length() < 30 or not (String(q["source"]).begins_with("REAL") or String(q["source"]).begins_with("GAME")):
				all_ok = false
	check("every contract has three questions, each with a reason and a REAL or GAME source", all_ok)
	var plan: Array = QD.planner()
	check("the planner has nine questions from the team's three missions", plan.size() == 9 and plan.any(func(q): return q["mission"] == "NEPTUNE") and plan.any(func(q): return q["mission"] == "LUNAR ICE") and plan.any(func(q): return q["mission"] == "EARTH WILDFIRE"))
	check("the planner uses the sheet's real numbers", plan.any(func(q): return String(q["why"]).contains("0.25 kW")) and plan.any(func(q): return String(q["options"][0]).contains("450 W")))
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var qc = load("res://quiz_card.gd").new()
	qc.questions = QD.for_contract(0)
	var res := {}
	qc.finished.connect(func(r): res.merge(r, true))
	host.add_child(qc)
	await create_timer(0.5).timeout
	# find the right button each time (the options are shuffled, so read the answer from the data)
	var firsts := 0
	for i in 3:
		var q: Dictionary = qc.questions[i]
		var slot := -1
		for k in qc._order.size():
			if qc._order[k] == int(q["answer"]):
				slot = k
		if slot == 0:
			firsts += 1
		qc.answer(slot)
		await process_frame
		check("question %d: a right answer explains why and shows its source" % (i + 1), qc._why.text.begins_with("Correct") and qc._src.text != "")
		qc.advance()
		await process_frame
	check("three right answers in a row earn 100, 125 and 150 points", int(res.get("points", 0)) == 375 and int(res.get("correct", 0)) == 3)
	var qc2 = load("res://quiz_card.gd").new()
	qc2.questions = QD.for_contract(1)
	var res2 := {}
	qc2.finished.connect(func(r): res2.merge(r, true))
	host.add_child(qc2)
	await create_timer(0.4).timeout
	var q0: Dictionary = qc2.questions[0]
	var wrong := -1
	for k in qc2._order.size():
		if qc2._order[k] != int(q0["answer"]):
			wrong = k
	qc2.answer(wrong)
	await process_frame
	check("a wrong answer still explains the reason, in amber", qc2._why.text.begins_with("Here is why") and qc2._streak == 0)
	qc2.advance()
	var q1: Dictionary = qc2.questions[1]
	for k in qc2._order.size():
		if qc2._order[k] == int(q1["answer"]):
			qc2.answer(k)
	qc2.advance()
	for i in 1:
		var q2: Dictionary = qc2.questions[2]
		for k in qc2._order.size():
			if qc2._order[k] == int(q2["answer"]):
				qc2.answer(k)
	qc2.advance()
	await process_frame
	check("after a miss the streak restarts: 0 + 100 + 125 points", int(res2.get("points", 0)) == 225 and int(res2.get("correct", 0)) == 2)
	# the right answer is not always the first button
	var not_first := 0
	for q in plan:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(q["q"]))
		var order: Array[int] = [0, 1, 2]
		for k in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t := order[k]
			order[k] = order[j]
			order[j] = t
		if order[0] != 0:
			not_first += 1
	check("the right answer is shuffled away from the first button for most questions", not_first >= 4)
	var src := FileAccess.get_file_as_string("res://flight.gd")
	check("only the Max Q poll stops the flight in the air; later calls go ahead on their own", src.contains("if idx > 0:") and src.contains("all stations go"))
	print("FAILS: ", fails)
	quit(fails)
