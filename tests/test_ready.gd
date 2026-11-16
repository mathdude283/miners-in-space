extends SceneTree
## The Lunar Evidence Ship preset against Orientale and Contract 02, the two readiness panels, the lock warning.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.ai_notice_seen = true
	pd.new_campaign()
	pd.scenario = 0
	var bs: BuildState = pd.get_build()
	bs.load_starter(ShipData.STARTERS[1])
	var t := bs.totals()
	print("   preset totals: ", t["draw"], " used / ", t["gen"], " made")
	var r0 := Missions.readiness(0, bs)
	var r1 := Missions.readiness(1, bs)
	check("the preset starts at 9 power used / 6 made", int(t["draw"]) == 9 and int(t["gen"]) == 6)
	check("so it is not ready for Orientale, and the power is named exactly", not r0["ready"] and r0["issues"].any(func(i): return String(i["text"]).contains("9 used / 6 made")))
	check("it is not ready for Contract 02 either, and the Science Lab is named", not r1["ready"] and r1["issues"].any(func(i): return String(i["text"]).contains("Science Lab")))
	check("each issue has a key for the inspect action", r1["issues"].all(func(i): return String(i["key"]) != ""))
	var scene: Node = load("res://build_screen.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.2).timeout
	check("two readiness panels are shown", scene._ready_panels.size() == 2)
	var texts: Array = []
	for rp in scene._ready_panels:
		texts.append(String(rp["title"].text))
	check("they say READY FOR ORIENTALE and READY FOR GLUSHKO AND OHM", String(texts[0]).contains("ORIENTALE") and String(texts[1]).contains("GLUSHKO"))
	check("the second panel warns the ship locks after Orientale", String(scene._ready_panels[1]["note"].text).contains("LOCKS"))
	await _snap("preset")
	# clicking an issue shows the part
	var shown := false
	for b in scene._ready_panels[1]["list"].get_children():
		if b is Button and String(b.text).contains("Science Lab"):
			b.pressed.emit()
			shown = true
	check("the Science Lab issue can be inspected", shown)
	# fix the power with a wing: still a lock warning because there is no lab, but the ship can fly Orientale
	bs.set_wings(1)
	scene._refresh()
	await create_timer(0.3).timeout
	var r0b := Missions.readiness(0, bs)
	check("with a solar wing the preset is ready for Orientale", r0b["ready"])
	check("the first panel says YES", String(scene._ready_panels[0]["title"].text).contains("YES"))
	# the lock dialog on Continue
	scene._on_continue()
	await create_timer(0.4).timeout
	var dlg_btns: Array = scene.find_children("*", "Button", true, false).filter(func(b): return b.text == "FLY THIS SHIP ANYWAY")
	check("Continue explains the lock before launching", dlg_btns.size() == 1)
	await _snap("lock_dialog")
	# add the lab: ready for both
	for b in scene.find_children("*", "Button", true, false):
		if b.text == "GO BACK AND FIX IT":
			b.pressed.emit()
	bs.place_room("science-lab")
	scene._refresh()
	await create_timer(0.3).timeout
	var both := Missions.readiness(1, bs)
	print("   with lab: ", both["issues"].map(func(i): return i["text"]))
	check("a one-lens window check still works", bs.wide)
	print("FAILS: ", fails)
	quit(fails)
