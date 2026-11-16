extends SceneTree
## Records a 30-second tour of Moonbound with Godot's Movie Maker (the game plays itself through each screen).
## godot --path . --write-movie build/demo.avi --fixed-fps 30 --resolution 1280x720 --script res://tools/demo_video.gd
var _frames := 0
var _scene: Node
var _pd: Node
var _step := -1
const FPS := 30

# (frame to start at, what to show)
const TIMELINE := [0, 60, 125, 190, 255, 385, 465, 545, 625, 700]

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_pd = root.get_node("PlayerData")
	_pd.autosave_enabled = false
	_pd.ai_notice_seen = true

func _process(_delta: float) -> bool:
	_frames += 1
	var idx := -1
	for i in TIMELINE.size():
		if _frames >= TIMELINE[i]:
			idx = i
	if idx != _step:
		_step = idx
		print("DEMO step ", idx, " frame ", _frames)
		_begin(idx)
	# the recording shows the real screens only: close any stray credits panel
	for c in root.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == "SourcesPanel":
			c.queue_free()
	if _scene != null and is_instance_valid(_scene):
		for c in _scene.get_children():
			if c.get_script() != null and c.get_script().get_global_name() == "SourcesPanel":
				c.queue_free()
	_during(idx, _frames - TIMELINE[idx])
	if _frames >= 905:
		quit()
	return false

func _swap(n: Node) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	_scene = n
	root.add_child(n)
	current_scene = n

func _ship(full := true) -> BuildState:
	var b := BuildState.new()
	var rooms := ["flight-deck", "life-support", "observation", "communications", "science-lab", ""]
	for i in rooms.size():
		b.bays[i] = rooms[i]
	b.wide = true
	b.kit = true
	b.wings = 2
	return b

func _begin(i: int) -> void:
	match i:
		0:   # title
			_pd.new_campaign()
			_swap(load("res://title.tscn").instantiate())
		1:   # mission select, page 1
			_pd.new_campaign()
			_pd.campaign["briefed"] = true
			_swap(load("res://mission_select.tscn").instantiate())
		2:   # crew
			_swap(load("res://crew_screen.tscn").instantiate())
		3:   # build
			_pd.new_campaign()
			_pd.scenario = 0
			var s = load("res://build_screen.tscn").instantiate()
			_swap(s)
			s._load_starter(1)
		4:   # the Moon photo with NASA's real view
			var PG = load("res://photo_game.gd")
			PG._practiced = true
			var g = PG.new()
			g.theme = load("res://assets/themes/moonbound_theme.tres")
			g.has_lens = {"wide": true, "close": true}
			_swap(g)
			g._start_shoot()
		5:   # Impact Watch
			var w = load("res://impact_watch.gd").new()
			w.state = _ship()
			w.crew = _pd.crew
			_swap(w)
			w._start_watch()
			w.set_time(19.0, "V1")
		6:   # the report with a grade
			_pd.new_campaign()
			_pd.scenario = 0
			var bs: BuildState = _pd.get_build()
			var b := _ship()
			for k in b.bays.size():
				bs.bays[k] = b.bays[k]
			bs.wide = true
			bs.kit = true
			bs.wings = 2
			var run: MissionRun = _pd.start_run()
			run.evidence = [{"needed": true, "lens": "wide", "key": "wide", "label": "WIDE IMAGE", "captured": true, "tagged": true, "tag_ok": true, "received": true, "stars": 3, "confidence": "STRONG", "framing": 0.9, "sharp": 0.9, "light": 0.95, "tex": null, "problems": [], "meets": true, "crater": "", "pass": ""}]
			run.nasa_compare = {"interior": true, "rings": true, "done": true}
			run.landing = {"landed": true, "speed_mph": 19.0, "angle": 1.0, "over_seconds": 0.0, "notes": ["Entry angle: clean.", "Splashdown at 19 mph: soft."]}
			_pd.campaign["done"].append(0)
			_swap(load("res://report_screen.tscn").instantiate())
		7:   # a quiz question
			var qc = load("res://quiz_card.gd").new()
			qc.questions = QuizData.for_contract(0)
			_swap(qc)
		8:   # the spacecraft design contracts
			_pd.new_campaign()
			_pd.campaign["briefed"] = true
			_pd.campaign["done"] = [0]
			var ms = load("res://mission_select.tscn").instantiate()
			_swap(ms)
			ms.show_page.call_deferred(1)
		9:   # the ending
			_pd.new_campaign()
			_pd.campaign["crew_chosen"] = true
			_pd.campaign["done"] = [0, 1, 2]
			_pd.campaign["over"] = true
			_pd.campaign["won"] = true
			_pd.campaign["studied"] = ["Orientale Basin", "Ohm"]
			_pd.campaign["points"] = 4120
			_pd.campaign["log"] = [
				{"id": 0, "tag": "CONTRACT 01", "name": "Orientale", "headline": "You photographed the Orientale Basin: 2 photos reached Earth.", "detail": "Your best shot scored 3 of 3 stars.", "score": 96, "grade": "A", "points": 1380},
				{"id": 1, "tag": "CONTRACT 02", "name": "Glushko And Ohm", "headline": "You compared two craters under different light and reached strong confidence.", "detail": "Comparability was 92%.", "score": 91, "grade": "B", "points": 1290},
				{"id": 2, "tag": "CONTRACT 03", "name": "Impact Watch", "headline": "Mission Control gave justified verdicts on 3 of 3 sightings.", "detail": "You sent 8 of 20 packets.", "score": 93, "grade": "A", "points": 1450}]
			_swap(load("res://ending_screen.tscn").instantiate())

func _during(i: int, f: int) -> void:
	match i:
		1:
			if f == 45 and _scene.has_method("show_page"):
				_scene.show_page(0)
		4:
			var g = _scene
			if g == null or not g.has_method("_set_hold"):
				return
			g._t = 1.0 if f < 5 else g._t
			if f > 30 and f < 105:
				g._aim = g._target_at(g._t)
			if f == 60:
				g._set_hold(true)
			if f == 110:
				g._set_hold(false)
		5:
			var w = _scene
			if w == null or not w.has_method("log_sighting"):
				return
			if f == 50:
				w.log_sighting(412.0, 236.0)
		7:
			var qc = _scene
			if qc != null and qc.has_method("answer") and f == 40:
				for k in qc._order.size():
					if qc._order[k] == int(qc.questions[0]["answer"]):
						qc.answer(k)
		9:
			if f == 75 and _scene.has_method("_show"):
				_scene._show(_scene.beat_count() - 1)
