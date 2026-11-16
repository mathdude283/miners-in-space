extends SceneTree
## Grades and points: a perfect flight earns an A, a sloppy one does not, harder difficulty multiplies points and tightens
## time and power, the leaderboard keeps the best, and text never goes outside a button.
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
	var pd = root.get_node("PlayerData")
	pd.autosave_enabled = false
	pd.new_campaign()
	pd.scenario = 0
	var bs: BuildState = pd.get_build()
	for i in ["flight-deck", "life-support", "observation", "communications", "science-lab"].size():
		bs.bays[i] = ["flight-deck", "life-support", "observation", "communications", "science-lab"][i]
	bs.wide = true
	bs.kit = true
	bs.wings = 2
	# a perfect flight
	var run: MissionRun = pd.start_run()
	run.evidence = [{"needed": true, "captured": true, "stars": 3, "tag_ok": true, "received": true}]
	run.nasa_compare = {"interior": true, "rings": true, "done": true}
	run.landing = {"landed": true, "speed_mph": 18.0, "angle": 1.0, "over_seconds": 0.0}
	var good: Dictionary = ScoreBoard.compute(run, 0, 1)
	check("a near-perfect flight earns an A", String(good["grade"]) == "A" and float(good["percent"]) >= 92.0)
	check("points are the total times the difficulty multiplier", int(good["points"]) == int(round(int(good["total"]) * 1.25)))
	var ptsd: Dictionary = ScoreBoard.compute(run, 0, 2)
	var ptsc: Dictionary = ScoreBoard.compute(run, 0, 0)
	check("harder difficulty gives more points for the same flight", int(ptsd["points"]) > int(good["points"]) and int(good["points"]) > int(ptsc["points"]))
	var bl: Array = ScoreBoard.badges(good, run)
	check("a great flight earns badges", bl.size() >= 3 and bl.any(func(x): return x["name"] == "PERFECT SHOT"))
	var bp := "user://test_best.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bp))
	var r1: Dictionary = ScoreBoard.record_best(0, 1000, bp)
	var r2: Dictionary = ScoreBoard.record_best(0, 1200, bp)
	var r3: Dictionary = ScoreBoard.record_best(0, 900, bp)
	check("personal bests: first, then a new best, then not", bool(r1["first"]) and bool(r2["new_best"]) and not bool(r3["new_best"]) and int(r3["best"]) == 1200)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bp))
	# a sloppy flight
	var run2: MissionRun = pd.start_run()
	run2.evidence = [{"needed": true, "captured": true, "stars": 1, "tag_ok": false, "received": true}]
	run2.landing = {"landed": true, "speed_mph": 34.0, "angle": 0.3, "over_seconds": 3.0}
	run2.drain("time", 30.0)
	run2.hurt(1, 30.0, "Test", "t")
	var bad: Dictionary = ScoreBoard.compute(run2, 0, 1)
	check("a sloppy flight does not get an A or B", String(bad["grade"]) in ["C", "D", "F"])
	check("and scores far fewer points", int(bad["points"]) < int(good["points"]) / 2)
	check("grade boundaries", ScoreBoard.grade_for(92.0) == "A" and ScoreBoard.grade_for(91.9) == "B" and ScoreBoard.grade_for(70.0) == "C" and ScoreBoard.grade_for(55.0) == "D" and ScoreBoard.grade_for(10.0) == "F")
	# difficulty tightens the run
	pd.campaign["difficulty"] = 0
	var easy: MissionRun = pd.start_run()
	pd.campaign["difficulty"] = 2
	var hard: MissionRun = pd.start_run()
	check("Director has less time and power than Cadet", float(hard.resources["time"]["max"]) < float(easy.resources["time"]["max"]) * 0.75 and float(hard.resources["power"]["max"]) < float(easy.resources["power"]["max"]))
	check("and a shakier camera and shorter windows", pd.difficulty_factor("shake") > 1.4 and pd.difficulty_factor("window") < 0.75)
	# a finished contract carries its grade
	pd.campaign["difficulty"] = 1
	var run3: MissionRun = pd.start_run()
	run3.evidence = run.evidence
	run3.nasa_compare = run.nasa_compare
	run3.landing = run.landing
	pd.complete_contract(0)
	var e: Dictionary = pd.campaign["log"][0]
	check("the story line has a grade and points", String(e["grade"]) != "" and int(e["points"]) > 0 and int(pd.campaign["points"]) == int(e["points"]))
	# the leaderboard
	var path := "user://test_scores.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ScoreBoard.submit({"name": "A", "points": 500}, path)
	ScoreBoard.submit({"name": "B", "points": 900}, path)
	var rank := ScoreBoard.submit({"name": "C", "points": 700}, path)
	var list := ScoreBoard.load_scores(path)
	check("the leaderboard is sorted best first and ranks new scores", list[0]["name"] == "B" and list[1]["name"] == "C" and rank == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# text never goes outside a button
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = load("res://assets/themes/moonbound_theme.tres")
	root.add_child(host)
	var cases := [["A VERY LONG BUTTON LABEL THAT CANNOT POSSIBLY FIT IN THIS SMALL SPACE", Vector2(160, 40), 22], ["SHORT", Vector2(60, 30), 30], ["ONEHUGEWORDTHATISWIDERTHANTHEBUTTONITSELF", Vector2(120, 44), 24], ["Two\nlines of text with more words than fit", Vector2(140, 50), 20], ["", Vector2(100, 40), 20]]
	var btns: Array[Button] = []
	for c in cases:
		var b := Button.new()
		b.text = c[0]
		b.size = c[1]
		b.custom_minimum_size = c[1]
		b.add_theme_font_size_override("font_size", c[2])
		host.add_child(b)
		btns.append(b)
	await create_timer(0.3).timeout
	for i in btns.size():
		btns[i].size = cases[i][1]
	await create_timer(0.8).timeout
	var BF = load("res://button_fit.gd")
	var all_fit := true
	for b in btns:
		var ok: bool = BF.fits(b, b.get_theme_font_size("font_size"))
		if not ok:
			all_fit = false
			var sbx: StyleBox = b.get_theme_stylebox("normal")
			var fnt: Font = b.get_theme_font("font")
			var fs: int = b.get_theme_font_size("font_size")
			var avx: float = b.size.x - sbx.get_minimum_size().x - 6.0
			print("   does not fit: '", b.text.left(30), "' size ", b.size, " font ", fs, " pad ", sbx.get_minimum_size(), " ml ", fnt.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, avx, fs, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY), " avail_x ", avx)
	check("long, tiny and one-word button text all fit inside their buttons", all_fit)
	check("a label that already fits keeps its full size", btns[1].get_theme_font_size("font_size") >= 16)
	btns[0].text = "SHORT NOW"
	await create_timer(0.8).timeout
	check("when the text gets shorter the font grows back", btns[0].get_theme_font_size("font_size") > 14)
	print("FAILS: ", fails)
	quit(fails)
