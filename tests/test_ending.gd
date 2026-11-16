extends SceneTree
## The endings as a story: the winning ending walks through homecoming, your mission, what you discovered, the real mission and a
## certificate; the crew-lost ending is a memorial then what to try; the stuck ending says why. Also the campaign log that feeds
## them, the briefing and debrief from Mission Control, and saving the certificate picture.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _texts(n: Node) -> Array:
	var out: Array = []
	for l in n.find_children("*", "Label", true, false):
		out.append(String(l.text))
	return out
func _has(texts: Array, part: String) -> bool:
	return texts.any(func(t): return String(t).contains(part))
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
func _log() -> Array:
	return [
		{"id": 0, "tag": "CONTRACT 01", "name": "Orientale", "headline": "You photographed the Orientale Basin: 2 photos reached Earth.", "detail": "Your best shot scored 3 of 3 stars.", "score": 100, "grade": "A", "points": 1400},
		{"id": 1, "tag": "CONTRACT 02", "name": "Glushko And Ohm", "headline": "You compared two craters under different light and reached strong confidence.", "detail": "Comparability was 90%.", "score": 100},
		{"id": 2, "tag": "CONTRACT 03", "name": "Impact Watch", "headline": "Mission Control gave justified verdicts on 3 of 3 sightings.", "detail": "You sent 8 of 20 packets.", "score": 90}]
func _run() -> void:
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.autosave_enabled = false
	pd.ai_notice_seen = true
	var ES = load("res://ending_screen.gd")
	check("no ending while the campaign is open", ES.kind_of({"over": false}) == "")
	check("won", ES.kind_of({"over": true, "won": true}) == "won")
	check("crew lost", ES.kind_of({"over": true, "won": false, "over_reason": "The whole crew was lost. Ada: x"}) == "crew_lost")
	check("a ship that cannot go on", ES.kind_of({"over": true, "won": false, "over_reason": "Your ship does not have a Science Lab."}) == "stuck")
	# the rating
	var r_hi: Dictionary = ES.rating({"log": _log()}, [{"health": 100.0}])
	check("a strong record is rated highly", int(r_hi["score"]) >= 90 and String(r_hi["name"]) == "FLIGHT DIRECTOR")
	var r_lo: Dictionary = ES.rating({"log": [{"score": 40}, {"score": 50}]}, [{"health": 60.0}])
	check("a weak record is rated lower", String(r_lo["name"]) == "CADET")
	# the campaign log is written when a contract completes
	pd.new_campaign()
	pd.scenario = 0
	var bs: BuildState = pd.get_build()
	for i in ["flight-deck", "life-support", "observation", "communications", "science-lab"].size():
		bs.bays[i] = ["flight-deck", "life-support", "observation", "communications", "science-lab"][i]
	bs.wide = true
	bs.kit = true
	bs.wings = 2
	var run: MissionRun = pd.start_run()
	run.evidence = [{"needed": true, "received": true, "stars": 3, "lens": "wide"}]
	run.nasa_compare = {"interior": true, "rings": true, "done": true}
	pd.complete_contract(0)
	var lg: Array = pd.campaign["log"]
	check("finishing a contract adds a line to the story", lg.size() == 1 and String(lg[0]["headline"]).contains("Orientale") and int(lg[0]["score"]) > 0 and String(lg[0]["grade"]) != "")
	check("and records the real place you studied", pd.campaign["studied"].has("Orientale Basin"))
	check("and queues Mission Control's debrief", int(pd.campaign["debrief"]) == 0)
	pd.complete_contract(0)
	check("finishing the same contract twice does not duplicate the story", pd.campaign["log"].size() == 1)
	# Mission Control speaks
	var br: Array = load("res://story_card.gd").briefing()
	check("the briefing says it is fictional and that the ship is locked after the first contract", br.size() == 3 and String(br[0]).contains("FICTIONAL") and String(br[1]).contains("locked"))
	var db: Array = load("res://story_card.gd").debrief(0, lg)
	check("the debrief says what you did and what is next", db.size() == 2 and String(db[0]).contains("Orientale") and String(db[1]).contains("Glushko"))
	# a winning ending
	pd.new_campaign()
	pd.campaign["crew_chosen"] = true
	pd.campaign["log"] = _log()
	pd.campaign["studied"] = ["Orientale Basin", "Ohm"]
	pd.campaign["done"] = [0, 1, 2]
	pd.campaign["over"] = true
	pd.campaign["won"] = true
	pd.campaign["over_reason"] = "You finished every contract in this version."
	var s1: Node = load("res://ending_screen.tscn").instantiate()
	root.add_child(s1)
	current_scene = s1
	await create_timer(1.6).timeout
	check("the winning ending has six beats", s1.beat_count() == 6)
	var t1 := _texts(s1)
	check("beat 1: you brought them home, Mission Control welcomes the crew", _has(t1, "YOU BROUGHT THEM HOME") and _has(t1, "Welcome home"))
	await _snap("ending_1_home")
	s1.next_beat()
	await create_timer(1.8).timeout
	t1 = _texts(s1)
	check("beat 2: each contract with what you did", _has(t1, "Orientale") and _has(t1, "Glushko") and _has(t1, "justified verdicts"))
	await _snap("ending_2_mission")
	s1.next_beat()
	await create_timer(1.8).timeout
	t1 = _texts(s1)
	check("beat 3: the score, with the leaderboard", _has(t1, "POINTS") and _has(t1, "LEADERBOARD"))
	await _snap("ending_3_score")
	s1.next_beat()
	await create_timer(1.8).timeout
	t1 = _texts(s1)
	check("beat 4: what you discovered, with the NASA credit", _has(t1, "WHAT IT TAUGHT YOU") and _has(t1, "Credit: NASA") and _has(t1, "ONE WITNESS"))
	await _snap("ending_3_found")
	s1.next_beat()
	await create_timer(1.8).timeout
	t1 = _texts(s1)
	check("beat 5: the real mission, each fact linked to NASA", _has(t1, "REAL MISSION") or _has(t1, "REALLY DID"))
	var links: Array = s1.find_children("*", "LinkButton", true, false)
	check("every real fact has a link to its source", links.size() >= 4 and links.all(func(l): return String(l.uri).begins_with("https://www.nasa.gov/")))
	await _snap("ending_4_real")
	s1.next_beat()
	await create_timer(1.8).timeout
	t1 = _texts(s1)
	check("beat 6: a certificate with a rating and the fiction label", _has(t1, "MISSION CERTIFICATE") and _has(t1, "RATING") and _has(t1, "NASA does not endorse"))
	await _snap("ending_5_certificate")
	var path: String = await s1.save_certificate()
	check("the certificate can be saved as a picture", path != "" and FileAccess.file_exists(path))
	if path != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	s1.queue_free()
	await process_frame
	# crew lost
	pd.new_campaign()
	pd.campaign["log"] = _log().slice(0, 1)
	pd.campaign["done"] = [0]
	pd.campaign["over"] = true
	pd.campaign["won"] = false
	pd.campaign["over_reason"] = "The whole crew was lost. Ada: lost during re-entry.  Sam: the capsule hit the water too hard."
	pd.campaign["memorial"] = [{"name": "Ada", "role": "COMMANDER", "char": "ada", "cause": "Lost during re-entry."}, {"name": "Sam", "role": "PILOT", "char": "sam", "cause": "The capsule hit the water too hard."}]
	pd.crew = [] as Array[Dictionary]
	var s2: Node = load("res://ending_screen.tscn").instantiate()
	root.add_child(s2)
	current_scene = s2
	await create_timer(1.6).timeout
	check("the crew-lost ending has two beats", s2.beat_count() == 2)
	var t2 := _texts(s2)
	check("it is gentle and names who was lost and why", _has(t2, "I am sorry") and _has(t2, "ADA") or _has(t2, "Ada"))
	check("and what they had finished before", _has(t2, "BEFORE THEY WERE LOST"))
	check("it does not claim anyone is home", not _has(t2, "BROUGHT THEM HOME") and not _has(t2, "home safe"))
	await _snap("ending_lost_1")
	s2.next_beat()
	await create_timer(1.8).timeout
	var t2b := _texts(s2)
	check("then practical advice, including the Medical Bay", _has(t2b, "TREAT THE HURT") and _has(t2b, "Medical Bay"))
	await _snap("ending_lost_2")
	s2.queue_free()
	await process_frame
	# stuck
	pd.new_campaign()
	pd.campaign["log"] = _log().slice(0, 1)
	pd.campaign["done"] = [0]
	pd.campaign["over"] = true
	pd.campaign["won"] = false
	pd.campaign["over_reason"] = "Your ship does not have a Science Lab. It was locked when you finished the first contract, so it cannot do this contract."
	var s3: Node = load("res://ending_screen.tscn").instantiate()
	root.add_child(s3)
	current_scene = s3
	await create_timer(1.6).timeout
	var t3 := _texts(s3)
	check("the stuck ending explains the locked ship", _has(t3, "THIS SHIP CANNOT GO ON") and _has(t3, "Science Lab"))
	check("and lists what you finished", _has(t3, "WHAT YOU FINISHED") and _has(t3, "Orientale"))
	await _snap("ending_stuck")
	s3.new_campaign()
	await create_timer(1.0).timeout
	check("New Campaign wipes the progress", pd.campaign["done"].is_empty() and not bool(pd.campaign["over"]) and pd.campaign["log"].is_empty())
	print("FAILS: ", fails)
	quit(fails)
