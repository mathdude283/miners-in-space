extends SceneTree
## Records the 30-second video pitch with Godot's Movie Maker. The game plays itself through each screen, with a visible cursor and
## a caption that is exactly the sentence being said. The words and timing follow the Space Apps video brief:
##   0:00 introduce yourself and the team   0:02 lead in (the challenge, what inspired us)   0:05 name the project
##   0:10 describe the idea and the NASA data   0:20 look into the future
## godot --path . --write-movie build/pitch_silent.avi --fixed-fps 30 --script res://tools/demo_video.gd
## The voice is added afterwards with ffmpeg.

const FAR_SIDE: Texture2D = preload("res://assets/nasa/artemis2_farside_view.jpg")

# The sentences, and the frame (30 per second) where each caption appears. The voice starts at the same moments.
const LINES := [
	[0, "Hi! I'm Sarah, from Team Miners in Space!"],
	[114, "Artemis II flew around the Moon. What if everyone could fly it?"],
	[243, "Meet Moonbound: fly real missions and learn the science!"],
	[357, "Build your ship, photograph NASA's real Orientale Basin, and spot a flash. Every fact comes from NASA's open data."],
	[597, "Imagine students designing spacecraft for wildfires, lunar ice, even Neptune. That's how we inspire the next explorers!"],
]
# The screens, in order: start frame and what to show.
const SCREENS := [[0, "title"], [112, "farside"], [241, "title2"], [357, "build"], [417, "photo"], [525, "impact"], [570, "report"], [597, "design"], [705, "ending"]]
# Title cards that stay on screen: start frame, end frame, big text, small text, position, big text size, colour.
const CARDS := [
	[0, 112, "TEAM MINERS IN SPACE", "Presenter: Sarah Waldron   |   NASA Space Apps Challenge 2026", Vector2(70, 60), 46],
	[112, 241, "THE SPARK: NASA'S ARTEMIS II", "A real flight around the Moon. Could everyone try flying it?", Vector2(70, 60), 40],
	[241, 357, "MOONBOUND", "Fly real missions. Learn the science.", Vector2(960, 380), 100],
	[357, 597, "BUILT ON NASA'S OPEN DATA", "Artemis II images  |  LROC Sun angles  |  USGS crater names", Vector2(40, 20), 28],
	[597, 880, "THE FUTURE", "Wildfires. Lunar ice. Neptune.", Vector2(40, 20), 34],
]
const END_FRAME := 872

var _frames := 0
var _pd: Node
var _scene: Node
var _cursor: Control
var _cap: Label
var _cards: Array = []
var _cpos := Vector2(960, 700)
var _ripple := -1.0
var _screen := -1
var _zoom: TextureRect


func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_pd = root.get_node("PlayerData")
	_pd.autosave_enabled = false
	_pd.ai_notice_seen = true
	_make_overlay()


func _process(_delta: float) -> bool:
	_frames += 1
	var idx := 0
	for i in SCREENS.size():
		if _frames >= int(SCREENS[i][0]):
			idx = i
	if idx != _screen:
		_screen = idx
		_begin(String(SCREENS[idx][1]))
	var f := _frames - int(SCREENS[idx][0])
	_during(String(SCREENS[idx][1]), f)
	_overlay(String(SCREENS[idx][1]), f)
	for c in root.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == "SourcesPanel":
			c.queue_free()
	if _frames >= END_FRAME:
		quit()
	return false


# ---------------------------------------------------------------- the overlay: cursor, captions, intro card

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
	sb.bg_color = Color(0.02, 0.03, 0.1, 0.9)
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
	_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap.custom_minimum_size = Vector2(1500, 0)
	panel.add_child(_cap)
	layer.add_child(panel)
	# the title cards: introduction, the spark, the project name and tagline, NASA open data, the future
	for c in CARDS:
		var card := PanelContainer.new()
		var sb2 := sb.duplicate() as StyleBoxFlat
		sb2.set_content_margin_all(22)
		card.add_theme_stylebox_override("panel", sb2)
		card.position = c[4]
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		var t1 := Label.new()
		t1.text = String(c[2])
		t1.add_theme_font_size_override("font_size", int(c[5]))
		t1.add_theme_color_override("font_color", Color("c8ff36"))
		var t2 := Label.new()
		t2.text = String(c[3])
		t2.add_theme_font_size_override("font_size", 32 if int(c[5]) > 60 else (20 if int(c[5]) < 36 else 26))
		t2.add_theme_color_override("font_color", Color("f2f5ff"))
		v.add_child(t1)
		v.add_child(t2)
		card.add_child(v)
		layer.add_child(card)
		_cards.append(card)


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


func _overlay(screen: String, f: int) -> void:
	# caption: the sentence being said right now
	var text := ""
	for l in LINES:
		if _frames >= int(l[0]):
			text = String(l[1])
	_cap.text = text
	for i in CARDS.size():
		(_cards[i] as Control).visible = _frames >= int(CARDS[i][0]) and _frames < int(CARDS[i][1])
	var target := _cpos
	var click_now := false
	match screen:
		"title":
			target = _btn("START") if f > 40 else Vector2(1200, 760)
			click_now = f == 80
		"title2":
			target = Vector2(1500, 560)
		"farside":
			target = Vector2(1300, 420)
		"select":
			target = _scene.cards_row.get_child(0).get_global_rect().get_center() if f < 50 and _scene.get("cards_row") != null else _btn("ACCEPT")
			click_now = f == 40
		"build":
			target = _btn("Lunar evidence ship") if f < 30 else Vector2(1500, 300)
			click_now = f == 24
		"photo":
			if _scene != null and _scene.get("_aim") != null:
				target = _scene._aim * (Vector2(root.get_visible_rect().size) / Vector2(1920, 1080))
			click_now = f == 45 or f == 98
		"impact":
			if _scene != null and _scene.get("_view") != null and _scene._view != null:
				target = _scene._view.get_global_rect().position + Vector2(412, 236) if f > 12 else _btn("FLIGHT DECK")
			click_now = f == 36
		"report":
			target = Vector2(1090, 330)
		"design":
			target = _btn("CONTRACTS 04") if f < 50 else Vector2(560, 560)
			click_now = f == 20
		"ending":
			target = Vector2(960, 330)
	_cpos = _cpos.lerp(target, 0.16)
	if click_now:
		_ripple = 0.0
	if _ripple >= 0.0:
		_ripple += 0.07
		if _ripple > 1.0:
			_ripple = -1.0
	_cursor.queue_redraw()


# ---------------------------------------------------------------- the screens

func _swap(n: Node) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	if _zoom != null and is_instance_valid(_zoom):
		_zoom.queue_free()
		_zoom = null
	_scene = n
	root.add_child(n)
	current_scene = n


func _ship() -> BuildState:
	var b := BuildState.new()
	var rooms := ["flight-deck", "life-support", "observation", "communications", "science-lab", ""]
	for i in rooms.size():
		b.bays[i] = rooms[i]
	b.wide = true
	b.kit = true
	b.wings = 2
	return b


func _begin(screen: String) -> void:
	match screen:
		"title", "title2":
			_pd.new_campaign()
			_swap(load("res://title.tscn").instantiate())
		"farside":
			# NASA's real picture of the far side, slowly zooming in (credit: NASA)
			_swap(Control.new())
			_zoom = TextureRect.new()
			_zoom.texture = FAR_SIDE
			_zoom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_zoom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_zoom.size = Vector2(1080, 1080)
			_zoom.position = Vector2(420, 0)
			_zoom.pivot_offset = Vector2(540, 540)
			root.add_child(_zoom)
			var credit := Label.new()
			credit.text = "Real image: NASA, Artemis II lunar flyby"
			credit.add_theme_font_size_override("font_size", 20)
			credit.position = Vector2(40, 40)
			_zoom.add_child(credit)
		"select":
			_pd.new_campaign()
			_pd.campaign["briefed"] = true
			_swap(load("res://mission_select.tscn").instantiate())
		"build":
			_pd.new_campaign()
			_pd.scenario = 0
			var s = load("res://build_screen.tscn").instantiate()
			_swap(s)
			s._load_starter(1)
		"photo":
			var PG = load("res://photo_game.gd")
			PG._practiced = true
			var g = PG.new()
			g.theme = load("res://assets/themes/moonbound_theme.tres")
			g.has_lens = {"wide": true, "close": true}
			_swap(g)
			g._start_shoot()
		"impact":
			var w = load("res://impact_watch.gd").new()
			w.state = _ship()
			w.crew = _pd.crew
			_swap(w)
			w._start_watch()
			w.set_time(20.4, "V1")
		"report":
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
		"design":
			_pd.new_campaign()
			_pd.campaign["briefed"] = true
			_pd.campaign["done"] = [0]
			var ms = load("res://mission_select.tscn").instantiate()
			_swap(ms)
			ms.show_page.call_deferred(1)
		"ending":
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


func _during(screen: String, f: int) -> void:
	match screen:
		"farside":
			if _zoom != null and is_instance_valid(_zoom):
				var k := 1.0 + float(f) / 125.0 * 0.35
				_zoom.scale = Vector2(k, k)
		"photo":
			var g = _scene
			if g == null or not g.has_method("_set_hold"):
				return
			if f > 15 and f < 100:
				g._aim = g._target_at(g._t)
			if f == 45:
				g._set_hold(true)
			if f == 98:
				g._set_hold(false)
		"impact":
			var w = _scene
			if w != null and w.has_method("log_sighting") and f == 36:
				w.log_sighting(412.0, 236.0)
		"ending":
			if f == 20 and _scene.has_method("_show"):
				_scene._show(_scene.beat_count() - 1)
