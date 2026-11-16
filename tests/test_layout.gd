extends SceneTree
## Layout check for every screen at the current window size: nothing spills off the screen, no button text is cut, nothing is
## squeezed below its minimum size. The runner runs this at several window sizes (small laptop, full HD, ultrawide, tall).
## Screenshots go to tests/out/layout_<size>_<screen>.png.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
var tag := ""
const SKIP_NAMES := ["Background", "Stars", "Shade", "Crt", "HudFrame", "Fade", "Dim", "LeftShade", "LogoGlow", "Banner"]

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _lint(scene: Node, vp: Rect2) -> Array[String]:
	var issues: Array[String] = []
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var ctl := n as Control
		# anything inside a scroll box is allowed to be longer than the screen
		var in_scroll := false
		var p: Node = ctl.get_parent()
		while p != null and p != scene:
			if p is ScrollContainer:
				in_scroll = true
			p = p.get_parent()
		var r := ctl.get_global_rect()
		var skip := ctl.name in SKIP_NAMES or (ctl.get_parent() != null and ctl.get_parent().name in SKIP_NAMES) or in_scroll or ctl is ColorRect or ctl is TextureRect or ctl is TextureButton
		if not skip and r.size.x > 0 and (r.position.x < vp.position.x - 1.0 or r.position.y < vp.position.y - 1.0 or r.end.x > vp.end.x + 1.0 or r.end.y > vp.end.y + 1.0):
			issues.append("OFFSCREEN  %s  %s" % [scene.get_path_to(ctl), r])
		if ctl is Button and (ctl as Button).text != "" and not skip:
			var b := ctl as Button
			var bfs := b.get_theme_font_size("font_size")
			var longest := 0.0
			for line in b.text.split("\n"):
				longest = maxf(longest, b.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x)
			if longest > r.size.x - 6.0 and not b.clip_text and b.autowrap_mode == TextServer.AUTOWRAP_OFF:
				issues.append("BTN TEXT TIGHT  %s '%s' needs %.0f has %.0f" % [scene.get_path_to(ctl), b.text.left(30), longest, r.size.x])
		if not skip and (ctl.size.x < ctl.get_combined_minimum_size().x - 1.0 or ctl.size.y < ctl.get_combined_minimum_size().y - 1.0):
			issues.append("SMALLER THAN MIN  %s  size %s min %s" % [scene.get_path_to(ctl), ctl.size, ctl.get_combined_minimum_size()])
	return issues

func _audit(name: String, scene: Node, wait := 1.4) -> void:
	root.add_child(scene)
	current_scene = scene
	await _wait(wait)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "layout_%s_%s.png" % [tag, name])
	var issues := _lint(scene, root.get_visible_rect())
	for i in issues:
		print("   ", i)
	check("%s fits at %s" % [name, tag], issues.is_empty())
	scene.queue_free()
	await process_frame

func _tex() -> ImageTexture:
	var img := Image.create(64, 40, false, Image.FORMAT_RGB8)
	img.fill(Color(0.4, 0.4, 0.5))
	return ImageTexture.create_from_image(img)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and String(args[0]).contains("x"):
		var wh := String(args[0]).split("x")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await _wait(0.3)
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		DisplayServer.window_set_position(Vector2i(6000, 3000))
		await _wait(0.6)
	await process_frame
	var ws := DisplayServer.window_get_size()
	tag = "%dx%d" % [ws.x, ws.y]
	var pd = root.get_node("PlayerData")
	pd.autosave_enabled = false
	pd.ai_notice_seen = true
	pd.new_campaign()
	pd.scenario = 0
	var theme: Theme = load("res://assets/themes/moonbound_theme.tres")
	await _audit("title", load("res://title.tscn").instantiate(), 2.4)
	var tc: Node = load("res://title.tscn").instantiate()
	root.add_child(tc)
	current_scene = tc
	await _wait(1.8)
	tc._open_credits()
	await _wait(1.0)
	var ci := _lint(tc, root.get_visible_rect())
	for i in ci:
		print("   ", i)
	check("credits box fits at %s" % tag, ci.is_empty())
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "layout_%s_credits.png" % tag)
	tc.queue_free()
	await process_frame
	pd.campaign["briefed"] = true
	await _audit("select", load("res://mission_select.tscn").instantiate(), 2.4)
	# crew with the longest names the field allows
	pd.crew = CrewData.defaults()
	for c in pd.crew:
		c["name"] = "W".repeat(CrewData.MAX_NAME)
	await _audit("crew_longest_names", load("res://crew_screen.tscn").instantiate(), 1.6)
	pd.new_campaign()
	pd.scenario = 0
	var bs: BuildState = pd.get_build()
	bs.load_starter(ShipData.STARTERS[1])
	bs.set_wings(1)
	await _audit("build", load("res://build_screen.tscn").instantiate(), 2.0)
	var ops = load("res://ship_interior.gd").new()
	ops.state = bs
	ops.run = pd.start_run()
	ops.mission_id = 0
	await _audit("ops", ops, 2.0)
	var pg = load("res://photo_game.gd").new()
	pg.theme = theme
	pg.has_lens = {"wide": true, "close": true}
	await _audit("photo_brief", pg, 1.2)
	var dg = load("res://downlink_game.gd").new()
	dg.theme = theme
	var photos: Array[Dictionary] = [{"lens": "wide", "stars": 3, "confidence": "STRONG", "tex": _tex()}, {"lens": "close", "stars": 2, "confidence": "MODERATE", "tex": _tex()}]
	dg.photos = photos
	await _audit("downlink_brief", dg, 1.2)
	var pp = load("res://poll_panel.gd").new()
	pp.theme = theme
	var rows: Array[Dictionary] = []
	for i in 4:
		rows.append({"id": "x%d" % i, "name": "RANGE SAFETY", "who": "Eastern Range", "go": i == 0, "block": i != 0, "call": "Flight termination system comms issue. No assurance it works means no-go until a confidence test passes and the range manager reports green."})
	var ph := Control.new()
	ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ph.theme = theme
	ph.add_child(pp)
	root.add_child(ph)
	pp.setup("launch", "FINAL POLL", "", rows)
	await _wait(1.2)
	var pi := _lint(ph, root.get_visible_rect())
	for i in pi:
		print("   ", i)
	check("poll fits at %s" % tag, pi.is_empty())
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "layout_%s_poll.png" % tag)
	ph.queue_free()
	await process_frame
	# the report: a success and a failure
	pd.new_campaign()
	pd.scenario = 0
	var bs2: BuildState = pd.get_build()
	bs2.load_starter(ShipData.STARTERS[1])
	var run: MissionRun = pd.start_run()
	run.evidence = [{"needed": true, "lens": "wide", "key": "wide", "label": "WIDE IMAGE", "captured": true, "tagged": true, "tag_ok": true, "received": true, "stars": 3, "confidence": "STRONG",
		"framing": 0.8, "sharp": 0.7, "light": 0.9, "tex": null, "problems": [], "meets": true, "crater": "", "pass": ""}]
	await _audit("report_success", load("res://report_screen.tscn").instantiate(), 1.4)
	run.evidence = []
	run.landing = {"landed": false, "notes": ["Entry angle: too steep.", "Everyone aboard was lost on the way home."]}
	for i in run.crew.size():
		run.crew[i]["health"] = 0.0
		run.crew[i]["cause"] = "Lost during re-entry."
	await _audit("report_failed", load("res://report_screen.tscn").instantiate(), 1.4)
	# Impact Watch
	var full := BuildState.new()
	for i in ["flight-deck", "life-support", "observation", "communications", "science-lab"].size():
		full.bays[i] = ["flight-deck", "life-support", "observation", "communications", "science-lab"][i]
	full.wide = true
	full.wings = 2
	var iw = load("res://impact_watch.gd").new()
	iw.state = full
	iw.crew = pd.crew
	await _audit("impact_brief", iw, 0.8)
	var iw2 = load("res://impact_watch.gd").new()
	iw2.state = full
	iw2.crew = pd.crew
	root.add_child(iw2)
	current_scene = iw2
	await _wait(0.3)
	iw2._start_watch()
	await _wait(0.5)
	iw2.set_time(21.8, "V1")
	await _wait(0.3)
	var wi := _lint(iw2, root.get_visible_rect())
	for i in wi:
		print("   ", i)
	check("impact watch window fits at %s" % tag, wi.is_empty())
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "layout_%s_impact_watch.png" % tag)
	iw2.log_sighting(412.0, 236.0)
	iw2.end_watch_now()
	await _wait(0.5)
	var si := _lint(iw2, root.get_visible_rect())
	for i in si:
		print("   ", i)
	check("impact send screen fits at %s" % tag, si.is_empty())
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "layout_%s_impact_send.png" % tag)
	iw2.queue_free()
	await process_frame
	var r: Dictionary = load("res://impact_watch.gd").deliver(full, ["A1", "A4", "B1", "C1", "C3"], "layout")
	var mc = load("res://impact_control.gd").new()
	mc.case = r["case"]
	mc.map = r["map"]
	mc.budget = r["budget"]
	mc.sent_cost = r["sent_cost"]
	await _audit("impact_control", mc, 0.8)
	pd.new_campaign()
	pd.campaign["done"] = [0, 1, 2]
	pd.campaign["over"] = true
	pd.campaign["won"] = true
	await _audit("ending_won", load("res://ending_screen.tscn").instantiate(), 1.0)
	print("FAILS: ", fails)
	quit(fails)
