extends SceneTree
## Looking after the crew: a Medical Bay fits on a legal ship that can still do every contract, one health event always comes
## up, hurt crew are pointed to the bay, and treatment mends them.
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
	var FL = load("res://flight.gd")
	var pd = root.get_node("PlayerData")
	pd.autosave_enabled = false
	# the ship that does all three contracts AND has a Medical Bay
	var b := BuildState.new()
	var rooms := ["flight-deck", "life-support", "observation", "communications", "science-lab", "medical"]
	for i in rooms.size():
		b.bays[i] = rooms[i]
	b.kit = true
	b.wings = 2
	b.wide = true
	var t: Dictionary = b.totals()
	check("the Medical Bay ship is within the budget and weight limits", int(t["cost"]) <= int(ShipData.RULES["budget_limit"]) and int(t["mass"]) <= int(ShipData.RULES["mass_limit"]))
	check("and makes enough power", int(t["margin"]) >= 0)
	var ok := true
	for m in [0, 1, 2]:
		for row in FL.make_plan(b, m):
			if not row["ok"]:
				ok = false
	check("and it can fly every contract", ok)
	check("the ship checklist has no problem", b.checks().all(func(c): return c["ok"]))
	# a health event always comes up when there are two or more events
	var always := true
	for seed in 60:
		var run := MissionRun.start(0, CrewData.defaults(), seed)
		var picks := MissionEvents.pick(run, 2)
		if not picks.any(func(e): return String(e["id"]) == "illness"):
			always = false
	check("one of two events is always a health event", always)
	var distinct := true
	var run2 := MissionRun.start(0, CrewData.defaults(), 5)
	var p3 := MissionEvents.pick(run2, 3)
	var ids := p3.map(func(e): return String(e["id"]))
	check("events stay different from each other", ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
	# (treatment itself, the pointer to the bay and the missing-bay message are checked in test_fault.gd)
	print("FAILS: ", fails)
	quit(fails)
