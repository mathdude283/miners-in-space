extends SceneTree
## The "Did you know?" facts: plenty of them, each with a source, one for every spacecraft room and mission, and they show on the screens.
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
	var FD = load("res://fact_data.gd")
	check("there are at least 30 facts", FD.count() >= 30)
	var ok := true
	for tag in FD.FACTS:
		for f in FD.FACTS[tag]:
			if String(f[0]).length() < 40 or not (String(f[1]).begins_with("REAL") or String(f[1]).begins_with("GAME")):
				ok = false
	check("every fact is a real sentence with a REAL or GAME source", ok)
	var rooms_ok := true
	for room in FD.ROOM_TAG:
		if FD.for_room(room, 0).is_empty():
			rooms_ok = false
	check("every spacecraft room has a fact", rooms_ok)
	check("each design mission has facts that change", FD.for_mission(3, 0)["text"] != FD.for_mission(3, 1)["text"] and not FD.for_mission(5, 2).is_empty() and not FD.for_mission(4, 3).is_empty())
	check("facts say where they come from", FD.line(FD.for_room("POWER BAY", 0)).contains("DID YOU KNOW") and FD.line(FD.for_room("POWER BAY", 0)).contains("("))
	var pd = root.get_node("PlayerData")
	pd.autosave_enabled = false
	pd.new_campaign()
	pd.scenario = 5
	var sd = load("res://space_design.tscn").instantiate()
	root.add_child(sd)
	current_scene = sd
	await create_timer(0.6).timeout
	check("the design screen shows a fact", sd._fact.text.begins_with("DID YOU KNOW"))
	sd.queue_free()
	await process_frame
	pd.space_picks = {"hull": "standard", "power": "rtg4", "battery": "bat_m", "comms": "dish_l", "computer": "cpu_a", "thermal": "th_h", "propulsion": "ion", "tank": "tank_2", "gnc": "gnc_p", "storage": "st_m", "instruments": ["magnetometer", "probe"], "orbit": "cruise"}
	var so = load("res://space_ops.tscn").instantiate()
	root.add_child(so)
	current_scene = so
	await create_timer(0.5).timeout
	so.choose(0)
	await process_frame
	var found := false
	for l in so.find_children("*", "Label", true, false):
		if String(l.text).begins_with("DID YOU KNOW"):
			found = true
	check("each mission phase explains itself with a fact after you choose", found)
	print("FAILS: ", fails)
	quit(fails)
