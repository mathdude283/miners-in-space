extends SceneTree
## Music and sound settings, the sources panel, practice mode, the report screen, and the X on crew notices.
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
	var music = root.get_node("Music")
	pd.ai_notice_seen = true
	pd.new_campaign()
	# ---- music
	for t in ["design", "launch", "cruise", "orbit", "event", "landing"]:
		check("music track loads: " + t, load("res://assets/audio/music/classical_%s.mp3" % t) != null)
	music.play("launch")
	check("playing a track remembers it", music.current() == "launch")
	music.set_music(0.2)
	music.set_sfx(0.35)
	var cf := ConfigFile.new()
	check("volumes are saved", cf.load("user://settings.cfg") == OK and absf(float(cf.get_value("sound", "music")) - 0.2) < 0.01 and absf(float(cf.get_value("sound", "sfx")) - 0.35) < 0.01)
	check("a lower effects slider makes sounds quieter", root.get_node("Sfx").master_db < -5.0)
	music.set_music(0.5)
	music.set_sfx(0.7)
	check("the old loudness comes back at 70%", absf(root.get_node("Sfx").master_db + 5.0) < 0.01)
	# ---- the select screen with its new buttons
	var sel: Node = load("res://mission_select.tscn").instantiate()
	root.add_child(sel)
	current_scene = sel
	await create_timer(0.6).timeout
	var labels: Array = []
	for b in sel.find_children("*", "Button", true, false):
		labels.append(b.text)
	check("select has Sound and sources and Practice", labels.has("SOUND AND SOURCES") and labels.has("PRACTICE"))
	await _snap("select")
	var sp = load("res://sources_panel.gd").new()
	sel.add_child(sp)
	await create_timer(0.4).timeout
	await _snap("sources")
	var sl: HSlider = sp.find_children("*", "HSlider", true, false)[0]
	sl.value = 0.25
	check("the music slider changes the music volume", absf(music.music_volume - 0.25) < 0.01)
	music.set_music(0.5)
	sp._close()
	await process_frame
	# ---- practice
	var pm = load("res://practice_menu.gd").new()
	sel.add_child(pm)
	await create_timer(0.4).timeout
	await _snap("practice_menu")
	var before: Dictionary = pd.campaign.duplicate(true)
	for kind in ["basin", "crater_low", "crater_high", "radio"]:
		pm.start(kind)
		await create_timer(0.5).timeout
		var running = pm._game
		check("practice starts: " + kind, running != null and is_instance_valid(running))
		if kind == "crater_high":
			await _snap("practice_crater_high_brief")
		pm._on_game_finished({})
		await process_frame
		check("practice returns to the menu: " + kind, pm._game == null)
	check("practice changes nothing in the campaign", pd.campaign == before)
	pm._close()
	await process_frame
	# ---- the report screen after a Contract 02 run
	pd.new_campaign()
	var bs: BuildState = pd.get_build()
	bs.load_starter(ShipData.STARTERS[0])
	bs.place_room("communications")
	bs.place_room("science-lab")
	bs.set_wings(2)
	pd.scenario = 1
	var run: MissionRun = pd.start_run()
	var img := Image.create(300, 180, false, Image.FORMAT_RGB8)
	img.fill(Color(0.4, 0.45, 0.6))
	var tex := ImageTexture.create_from_image(img)
	var a := {"lens": "wide", "key": "first", "stars": 3, "confidence": "STRONG", "tag_ok": false, "received": true, "crater": "glushko", "pass": "early", "tex": tex}
	var b := {"lens": "wide", "key": "second", "stars": 2, "confidence": "MODERATE", "tag_ok": false, "received": true, "crater": "glushko", "pass": "early", "tex": tex}
	run.evidence = [a, b]
	var pa := {"sun_elev": 0.22, "sun_dir": -1}
	run.science = {"crater": true, "branch": "reobserve", "done": true, "observations": 2,
		"eval": CraterScience.evaluate("reobserve", pa, pa, {"dir_a": -1, "dir_b": -1, "rays": "same"})}
	run.log_event("CABIN LEAK", "Patch the leak")
	run.hurt(1, 20.0, "Sam is hurt: the boosters separated at the wrong moment.", "Rough separation")
	run.hurt(2, 500.0, "Noor ran out of air during the leak.")
	var txt: String = load("res://report_screen.gd").build_text(run, Missions.get_mission(1))
	check("the saved text names the contract and the evidence", txt.contains("GLUSHKO AND OHM") and txt.contains("GLUSHKO") and txt.contains("strong confidence"))
	check("the saved text carries the finding and who was hurt and why", txt.contains("Comparability") and txt.contains("Sam is hurt") and txt.contains("lost - Noor ran out of air"))
	check("the saved text says confidence is a game score", txt.contains("GAME scores"))
	var rs: Node = load("res://report_screen.tscn").instantiate()
	root.add_child(rs)
	current_scene = rs
	await create_timer(0.7).timeout
	await _snap("report")
	rs._on_save()
	var found := false
	for f in DirAccess.get_files_at("user://reports"):
		if f.begins_with("moonbound_report_02_"):
			found = true
	check("the report is saved to a file", found)
	check("the screen says where it saved it", rs._status.text.begins_with("Saved:"))
	rs.queue_free()
	await process_frame
	# ---- the X on crew notices
	var alerts = load("res://crew_alerts.gd").new()
	root.add_child(alerts)
	var run2: MissionRun = pd.start_run()
	alerts.setup(run2)
	await process_frame
	run2.hurt(0, 20.0, "Ada is starving: no food is left.", "Starving")
	await create_timer(0.3).timeout
	check("a heart-loss notice shows with an X", alerts._toasts.get_child_count() == 1)
	var x: Button = alerts._toasts.get_child(0).find_children("*", "Button", true, false)[0]
	x.pressed.emit()
	await process_frame
	await process_frame
	check("the X closes the notice", alerts._toasts.get_child_count() == 0)
	run2.hurt(1, 500.0, "Sam was lost.")
	await create_timer(0.5).timeout
	check("a death pop-up shows", alerts._showing)
	var xs: Array = alerts.find_children("*", "Button", true, false).filter(func(bt): return bt.text == "X")
	check("the pop-up has an X", xs.size() == 1)
	await _snap("death_popup_x")
	xs[0].pressed.emit()
	await process_frame
	check("the X on the pop-up closes it", not alerts._showing)
	print("FAILS: ", fails)
	quit(fails)
