extends SceneTree
## Records a 30-second tour of Moonbound with Godot's Movie Maker (the game plays itself through each screen).
## godot --path . --write-movie build/demo.avi --fixed-fps 30 --resolution 1280x720 --script res://tools/demo_video.gd
var _frames := 0
var _cursor: Control
var _cap: Label
var _cpos := Vector2(960, 700)
var _ripple := -1.0
var _plan: Array = []
# The caption on each screen is exactly the sentence the voice says there (two screens can share one sentence).
const LINES := [
	"Moonbound: a free space game inspired by Artemis Two.",
	"Pick a contract.",
	"Choose your crew.",
	"Build your ship.",
	"Fly it, and photograph the real Orientale Basin.",
	"Spot a flash. One witness is not proof.",
	"Every flight is graded, then quizzed by Mission Control.",
	"Later: design spacecraft for Neptune, and more.",
	"Bring them home, and earn your certificate.",
]
const STEP_LINE := [0, 1, 2, 3, 4, 5, 6, 6, 7, 8]
var _scene: Node
var _pd: Node
var _step := -1
const FPS := 30

# (frame to start at, what to show)
const TIMELINE := [0, 115, 175, 235, 295, 425, 532, 622, 702, 815]

func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	_cursor = Control.new()
	_cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.draw.connect(_draw_cursor)
	layer.add_child(_cursor)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.1, 0.88)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.border_color = Color("c8ff36")
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -34.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap = Label.new()
	_cap.add_theme_font_size_override("font_size", 30)
	_cap.add_theme_color_override("font_color", Color("f2f5ff"))
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_cap)
	layer.add_child(panel)


func _draw_cursor() -> void:
	if _ripple >= 0.0:
		var r := 18.0 + _ripple * 70.0
		_cursor.draw_arc(_cpos, r, 0, TAU, 40, Color(0.78, 1.0, 0.21, 1.0 - _ripple), 5.0, true)
	var pts := PackedVector2Array([_cpos, _cpos + Vector2(0, 34), _cpos + Vector2(9, 26), _cpos + Vector2(16, 40), _cpos + Vector2(23, 37), _cpos + Vector2(16, 24), _cpos + Vector2(28, 24)])
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(3, 3))
	_cursor.draw_colored_polygon(shadow, Color(0, 0, 0, 0.5))
	_cursor.draw_colored_polygon(pts, Color.WHITE)
	_cursor.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.05, 0.05, 0.1), 2.0)


func _btn(part: String) -> Vector2:
	if _scene != null and is_instance_valid(_scene):
		for b in _scene.find_children("*", "BaseButton", true, false):
			if b is Button and String(b.text).to_upper().contains(part.to_upper()) and b.is_visible_in_tree():
				return b.get_global_rect().get_center()
	return Vector2(960, 540)


func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_pd = root.get_node("PlayerData")
	_pd.autosave_enabled = false
	_pd.ai_notice_seen = true
	_make_overlay()

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
	_move_cursor(idx, _frames - TIMELINE[idx])
	if _frames >= 898:
		quit()
	return false

## Where the cursor goes in each step: [frame, target position (or a Callable), click?]. The cursor glides to each target.
func _move_cursor(i: int, f: int) -> void:
	_cap.text = LINES[STEP_LINE[i]]
	var target := _cpos
	var click_now := false
	match i:
		0:
			target = _btn("START") if f > 15 else Vector2(900, 800)
			click_now = f == 70
		1:
			if f < 35:
				target = _btn("ORIENTALE") if _scene.has_method("show_page") and false else (_scene.cards_row.get_child(0).get_global_rect().get_center() if _scene.get("cards_row") != null else target)
				click_now = f == 28
			else:
				target = _btn("ACCEPT")
				click_now = f == 62
		2:
			if f < 30:
				target = _btn("PILOT")
				click_now = f == 24
			else:
				target = _btn("CONTINUE TO BUILD")
				click_now = f == 52
		3:
			if f < 30:
				target = _btn("Lunar evidence ship")
				click_now = f == 24
			else:
				target = _btn("FLY") 
				click_now = f == 66
		4:
			var g = _scene
			if g != null and g.get("_aim") != null:
				target = g._aim * (Vector2(root.get_visible_rect().size) / Vector2(1920, 1080))
			click_now = f == 45 or f == 98
		5:
			var w = _scene
			if w != null and w.get("_view") != null and w._view != null:
				target = w._view.get_global_rect().position + Vector2(412, 236) if f > 20 else _btn("FLIGHT DECK")
			click_now = f == 52
		6:
			target = Vector2(1090, 330)
			click_now = false
		7:
			var qc = _scene
			if qc != null and qc.get("_order") != null and qc.get("questions") != null:
				var kk := 0
				for k in qc._order.size():
					if qc._order[k] == int(qc.questions[0]["answer"]):
						kk = k
				if f > 5 and qc._opts.get_child_count() > kk:
					target = (qc._opts.get_child(kk) as Control).get_global_rect().get_center()
			click_now = f == 32
		8:
			target = _btn("CONTRACTS 04") if f < 45 else Vector2(560, 560)
			click_now = f == 20
		9:
			target = _btn("NEW CAMPAIGN") if f > 90 else Vector2(960, 330)
	_cpos = _cpos.lerp(target, 0.16)
	if click_now:
		_ripple = 0.0
	if _ripple >= 0.0:
		_ripple += 0.07
		if _ripple > 1.0:
			_ripple = -1.0
	_cursor.queue_redraw()


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
			if f > 15 and f < 100:
				g._aim = g._target_at(g._t)
			if f == 45:
				g._set_hold(true)
			if f == 98:
				g._set_hold(false)
		5:
			var w = _scene
			if w == null or not w.has_method("log_sighting"):
				return
			if f == 50:
				w.log_sighting(412.0, 236.0)
		7:
			var qc = _scene
			if qc != null and qc.has_method("answer") and f == 34:
				for k in qc._order.size():
					if qc._order[k] == int(qc.questions[0]["answer"]):
						qc.answer(k)
		9:
			if f == 50 and _scene.has_method("_show"):
				_scene._show(_scene.beat_count() - 1)
