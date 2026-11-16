extends SceneTree
## Press-kit countdown, hold rules, the radio blackout decision, the NASA comparison, report credits and links, poll wrapping.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
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
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.ai_notice_seen = true
	# ---- the countdown against the press kit
	var GC = load("res://ground_control.gd")
	var labels: Array = GC.COUNT.map(func(m): return m["label"])
	check("the flight termination system is armed at T-4:30 (press kit), not T-5:00", labels.has("T-4:30") and not labels.has("T-5:00"))
	var fts: Dictionary = GC.COUNT.filter(func(m): return m["label"] == "T-4:30")[0]
	check("and it asks for the Launch Director's call", String(fts.get("prompt", "")).contains("Flight termination"))
	check("the T-2:02 ICPS and T-2:00 booster battery entries are there", labels.has("T-2:02") and labels.has("T-2:00"))
	var times: Array = GC.COUNT.map(func(m): return m["t"])
	var ordered := true
	for i in range(1, times.size()):
		if float(times[i]) <= float(times[i - 1]):
			ordered = false
	check("the count is in time order", ordered)
	check("the sequencer lockout is still T-0:33", GC.sequencer_t() == -33.0)
	check("a stop after T-1:30 is described as a recycle", GC.hold_guidance("late").contains("recycles the count to T-10:00"))
	var cp = load("res://count_panel.gd").new()
	cp.theme = load("res://assets/themes/moonbound_theme.tres")
	root.add_child(cp)
	var done := {"r": ""}
	var co := func(): done["r"] = await cp.run()
	co.call()
	var late_hold := false
	var recycled_late := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000 and not recycled_late and done["r"] == "":
		await process_frame
		if cp._go_btn.visible:
			cp._go_pressed = true
		if not late_hold and cp._zone() == "late" and not cp._locked and cp._t > -89.0:
			late_hold = true
			check("in the late zone the guidance is the recycle rule", cp._rule.text == GC.hold_guidance("late"))
			cp._on_hold()
		if late_hold and cp._t <= -599.0:
			recycled_late = true
	check("holding after T-1:30 recycles the count to T-10:00", recycled_late)
	cp.queue_free()
	await process_frame

	# ---- the NASA comparison
	var nc = load("res://nasa_compare.gd").new()
	root.add_child(nc)
	await create_timer(0.4).timeout
	await _snap("nasa_compare")
	nc.choose(nc.INTERIOR_C)
	check("clicking the dark interior is correct", nc._interior_ok)
	nc.choose(nc.RING_C + Vector2(0, -190))
	check("clicking a bright ring is correct", nc._rings_ok)
	var nc2 = load("res://nasa_compare.gd").new()
	root.add_child(nc2)
	await create_timer(0.2).timeout
	nc2.choose(Vector2(30, 30))
	nc2.choose(nc2.INTERIOR_C)
	check("wrong clicks are marked wrong (interior missed, rings missed at the centre)", not nc2._interior_ok and not nc2._rings_ok)
	nc.queue_free()
	nc2.queue_free()

	# ---- the report: real NASA view, credit, link, four outcomes
	pd.new_campaign()
	pd.scenario = 0
	var bs: BuildState = pd.get_build()
	bs.load_starter(ShipData.STARTERS[1])
	bs.set_wings(1)
	var run: MissionRun = pd.start_run()
	run.evidence = [{"needed": true, "lens": "wide", "key": "wide", "label": "WIDE IMAGE", "captured": true, "tagged": true, "tag_ok": true, "received": true, "stars": 3, "confidence": "STRONG",
		"framing": 0.8, "sharp": 0.7, "light": 0.9, "tex": null, "problems": [], "meets": true, "crater": "", "pass": ""}]
	var rs: Node = load("res://report_screen.tscn").instantiate()
	root.add_child(rs)
	current_scene = rs
	await create_timer(0.8).timeout
	await _snap("report_nasa")
	var texts: Array = []
	for l in rs.find_children("*", "Label", true, false):
		texts.append(l.text)
	check("the report labels the real NASA view and says the photos are crops of it", texts.any(func(t): return String(t).contains("REAL NASA VIEW") and String(t).contains("crops of it")))
	check("the report credits NASA beside the real image", texts.any(func(t): return String(t).contains("Credit: NASA")))
	var links: Array = rs.find_children("*", "LinkButton", true, false)
	check("the report links to the NASA source record", links.any(func(l): return String(l.uri).contains("flight-day-6-lunar-flyby")))
	var txt: String = load("res://report_screen.gd").build_text(run, Missions.get_mission(0))
	check("the saved report credits NASA and lists the source links", txt.contains("Credit: NASA") and txt.contains("artemis-ii-press-kit") and txt.contains("planetarynames.wr.usgs.gov/Feature/2195") and txt.contains("crops of NASA"))
	check("the saved report says it is a fictional mission inspired by Artemis II", txt.contains("fictional educational mission inspired by Artemis II"))
	rs.queue_free()
	await process_frame

	# ---- sources panel: direct links
	var sp = load("res://sources_panel.gd").new()
	root.add_child(sp)
	await create_timer(0.4).timeout
	var slinks: Array = sp.find_children("*", "LinkButton", true, false)
	check("the sources panel has direct links", slinks.size() >= 8 and slinks.all(func(l): return String(l.uri).begins_with("https://")))
	await _snap("sources_links")
	sp.queue_free()
	await process_frame

	# ---- the radio blackout is a forecast and a decision
	var dg = load("res://downlink_game.gd").new()
	var img := Image.create(64, 40, false, Image.FORMAT_RGB8)
	img.fill(Color(0.4, 0.4, 0.5))
	var tex := ImageTexture.create_from_image(img)
	var photos: Array[Dictionary] = [{"lens": "wide", "stars": 3, "confidence": "STRONG", "tex": tex}, {"lens": "close", "stars": 2, "confidence": "MODERATE", "tex": tex}]
	dg.photos = photos
	root.add_child(dg)
	await create_timer(0.4).timeout
	dg._start()
	await create_timer(0.5).timeout
	var fc_found := false
	for l in dg.find_children("*", "Label", true, false):
		if String(l.text).begins_with("BLACKOUT FORECAST") and String(l.text).contains("Contact returns at"):
			fc_found = true
	check("the blackout is forecast with the time contact returns", fc_found)
	check("there is exactly one blackout window", dg.LOS_WINDOWS.size() == 1)
	var btns: Array = dg.find_children("*", "Button", true, false).filter(func(b): return String(b.text).contains("SEND FIRST"))
	check("the reorder button exists but is disabled before the blackout", btns.size() == 1 and btns[0].disabled)
	dg._t = dg.LOS_WINDOWS[0][0] + 0.5
	await create_timer(0.3).timeout
	check("the Moon is blocking contact", dg._los)
	btns = dg.find_children("*", "Button", true, false).filter(func(b): return String(b.text).contains("SEND FIRST"))
	check("during the blackout the queue can be reordered", btns.size() == 1 and not btns[0].disabled)
	check("the coach says when contact returns", String(dg._coach.text).contains("Contact returns in"))
	var first_before: String = dg._order[0]
	btns[0].pressed.emit()
	await create_timer(0.2).timeout
	check("pressing SEND FIRST changes the order", dg._order[0] != first_before)
	await _snap("blackout")
	dg.queue_free()
	await process_frame

	# ---- the poll: a long NO-GO response wraps instead of being cut off
	var pp = load("res://poll_panel.gd").new()
	pp.theme = load("res://assets/themes/moonbound_theme.tres")
	var rows: Array[Dictionary] = []
	for i in 3:
		rows.append({"id": "x%d" % i, "name": "RANGE", "who": "Eastern Range", "go": false, "block": true, "call": "Flight termination system comms issue. No assurance it works means no-go until a confidence test passes and the range manager reports green."})
	root.add_child(pp)
	pp.setup("launch", "FINAL POLL", "", rows)
	await create_timer(0.4).timeout
	var calls: Array = pp._row_nodes.map(func(r): return r["call"])
	calls[0].text = String(rows[0]["call"])
	await create_timer(0.3).timeout
	check("a long response wraps to more than one line", calls[0].get_line_count() >= 2)
	check("and is not clipped or cut with an ellipsis", not calls[0].clip_text and calls[0].text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS)
	await _snap("poll_long")
	pp.queue_free()
	print("FAILS: ", fails)
	quit(fails)
