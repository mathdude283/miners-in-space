class_name ReportScreen
extends Control
## Stage 04, Report: what the contract promised against what came back. Shows the photos that reached Earth with a
## confidence badge, the finding from the Science Lab, what happened on the way (events and who was hurt, and why),
## and what was left of time and power. A plain-text copy can be saved to a file.
## Confidence badges are a GAME score from how well the photo was framed, steadied and lit. They are not NASA measurements.

const HUD := preload("res://hud_frame.gd")
const TRACKER := preload("res://stage_tracker.gd")

@export_file("*.tscn") var next_scene: String = "res://mission_select.tscn"

var _status: Label
var _nasa_status: Label


func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Music.play("landing")
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/select/bg_earth_orbit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.027, 0.043, 0.133, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var hud: Control = HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.inset = 28.0
	hud.arm = 46.0
	hud.show_ruler = false
	add_child(hud)
	var layer := Decor.frame_layer(self)
	var tracker: HBoxContainer = TRACKER.new()
	tracker.active_index = 3
	tracker.position = Vector2(1320, 24)
	layer.add_child(tracker)
	_build(layer)


# ---------------------------------------------------------------- the screen

func _panel(pos: Vector2, size: Vector2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size
	p.size = size
	p.add_theme_stylebox_override("panel", UiStyle.panel(18, 0.92))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	_layer_ref.add_child(p)
	return v


var _layer_ref: Control


func _label(t: String, size := 17, color := Color(UiStyle.NEAR_WHITE, 0.92), width := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
	return l


func _build(layer: Control) -> void:
	_layer_ref = layer
	var run: MissionRun = PlayerData.run
	var m: Dictionary = Missions.get_mission(PlayerData.current_mission())
	# the team's Drive banner, centred at the top (artwork only: the words are drawn by the game)
	var ban := TextureRect.new()
	ban.texture = load("res://assets/ui/kit/banner_mission_report.png")
	ban.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ban.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ban.position = Vector2(700, 6)
	ban.size = Vector2(540, 180)
	ban.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ban.modulate = Color(1, 1, 1, 0.9)
	layer.add_child(ban)
	var head := UiStyle.heading("MISSION REPORT")
	head.position = Vector2(100, 40)
	head.size = Vector2(900, 50)
	layer.add_child(head)
	var sub := UiStyle.mono_label("%s   -   %s" % [String(m["tag"]), String(m["name"])], 16, UiStyle.PHOSPHOR)
	sub.position = Vector2(100, 96)
	layer.add_child(sub)

	# Left: promised against what came back
	var left := _panel(Vector2(100, 140), Vector2(640, 700))
	left.add_child(UiStyle.mono_label("WHAT THE CONTRACT PROMISED", 14, UiStyle.PHOSPHOR))
	left.add_child(_label(String(m["objective"]), 17, Color(UiStyle.NEAR_WHITE, 0.85), 600.0))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	for e in m["evidence"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.chip(UiStyle.CHROME))
		chip.add_child(UiStyle.mono_label(String(e), 13))
		chips.add_child(chip)
	left.add_child(chips)
	left.add_child(UiStyle.mono_label("WHAT CAME BACK", 14, UiStyle.PHOSPHOR))
	var any := run != null and not run.impact.is_empty()
	if any:
		for l in impact_lines(run):
			left.add_child(_label(String(l), 16, Color(UiStyle.NEAR_WHITE, 0.92), 600.0))
	for e in (run.evidence if run != null else []):
		if bool(e.get("needed", false)):
			any = true
			left.add_child(_row_card(e))
			continue
		if not bool(e.get("received", false)):
			continue
		any = true
		left.add_child(_evidence_card(e))
	if not any:
		left.add_child(_label("Nothing reached Earth.", 18, UiStyle.CORAL))

	_nasa_block(left, run)

	# Middle: the finding and what happened
	var mid := _panel(Vector2(770, 140), Vector2(560, 700))
	if PlayerData.campaign["done"].has(PlayerData.current_mission()) and run != null and not run.partial:
		var bd := TextureRect.new()
		bd.texture = load("res://assets/ui/kit/badge_trophy.png")
		bd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bd.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bd.custom_minimum_size = Vector2(0, 84)
		mid.add_child(bd)
		mid.add_child(UiStyle.mono_label("CONTRACT COMPLETE", 14, UiStyle.PHOSPHOR))
	if run != null:
		_grade_block(mid, run)
	mid.add_child(UiStyle.mono_label("THE FINDING", 14, UiStyle.PHOSPHOR))
	var lines := finding_lines(run)
	for l in lines:
		mid.add_child(_label(String(l), 17, Color(UiStyle.NEAR_WHITE, 0.92), 520.0))
	if run != null and not run.landing.is_empty():
		mid.add_child(UiStyle.mono_label("THE WAY HOME", 14, UiStyle.PHOSPHOR))
		for n in run.landing.get("notes", []):
			mid.add_child(_label(String(n), 16, Color(UiStyle.NEAR_WHITE, 0.9), 520.0))
	mid.add_child(UiStyle.mono_label("WHAT HAPPENED ON THE WAY", 14, UiStyle.PHOSPHOR))
	var evs: Array = run.events if run != null else []
	if evs.is_empty():
		mid.add_child(_label("Nothing unexpected.", 17, Color(UiStyle.NEAR_WHITE, 0.7), 520.0))
	for ev in evs:
		var t := String(ev["text"])
		if String(ev.get("choice", "")) != "":
			t += "   ->   " + String(ev["choice"])
		mid.add_child(_label(t, 16, UiStyle.AMBER if not t.contains("died") else UiStyle.CORAL, 520.0))
	if run != null:
		for d in run.damage_log:
			if not bool(d.get("died", false)):
				mid.add_child(_label("%s was hurt: %s" % [d["name"], d["reason"]], 15, Color(UiStyle.CORAL, 0.9), 520.0))
		mid.add_child(UiStyle.mono_label("LEFT AT THE END   TIME %d MIN   POWER %d" % [int(run.left("time")), int(run.left("power"))], 14, Color(UiStyle.NEAR_WHITE, 0.75)))
	mid.add_child(UiStyle.mono_label("Confidence is a GAME score, not a NASA measurement.", 12, Color(UiStyle.NEAR_WHITE, 0.5)))

	# Right: the crew
	var right := _panel(Vector2(1360, 140), Vector2(440, 700))
	right.add_child(UiStyle.mono_label("YOUR CREW", 14, UiStyle.PHOSPHOR))
	if run != null:
		for i in run.crew.size():
			right.add_child(_crew_row(run, i))

	# Buttons
	var save := Button.new()
	save.text = "SAVE A COPY OF THIS REPORT"
	save.theme_type_variation = &"OutlineButton"
	save.add_theme_font_size_override("font_size", 20)
	save.custom_minimum_size = Vector2(420, 64)
	save.position = Vector2(100, 870)
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(_on_save)
	layer.add_child(save)
	_status = UiStyle.mono_label("", 13, Color(UiStyle.NEAR_WHITE, 0.7))
	_status.position = Vector2(100, 944)
	_status.size = Vector2(1100, 60)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_status)
	var go := Button.new()
	go.text = "CONTINUE"
	go.theme_type_variation = &"PrimaryButton"
	go.add_theme_font_size_override("font_size", 30)
	go.custom_minimum_size = Vector2(420, 100)
	go.position = Vector2(1380, 880)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://ending_screen.tscn" if bool(PlayerData.campaign["over"]) else next_scene))
	layer.add_child(go)


## A needed shot with its four separate outcomes: captured, tagged, received, meets the contract criteria.
## The grade for this flight: a big letter, the points, and each category against its maximum.
func _grade_block(parent: VBoxContainer, run: MissionRun) -> void:
	var sb := ScoreBoard.compute(run, PlayerData.current_mission(), int(PlayerData.campaign.get("difficulty", 1)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var letter := UiStyle.heading(String(sb["grade"]))
	letter.add_theme_font_size_override("font_size", 64)
	letter.add_theme_color_override("font_color", UiStyle.PHOSPHOR if String(sb["grade"]) in ["A", "B"] else (UiStyle.AMBER if String(sb["grade"]) in ["C", "D"] else UiStyle.CORAL))
	head.add_child(letter)
	var tv := VBoxContainer.new()
	tv.add_child(UiStyle.mono_label("MISSION GRADE   %d%%" % int(sb["percent"]), 15, UiStyle.NEAR_WHITE))
	tv.add_child(UiStyle.mono_label("%d POINTS   (%d x %.2f %s)" % [int(sb["points"]), int(sb["total"]), float(sb["mult"]), String(sb["difficulty"])], 14, UiStyle.AMBER))
	head.add_child(tv)
	parent.add_child(head)
	# the letter slams in, with a sound that matches the grade
	letter.pivot_offset = Vector2(24, 40)
	letter.scale = Vector2(3.2, 3.2)
	letter.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(letter, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.5)
	tw.tween_property(letter, "modulate:a", 1.0, 0.2).set_delay(0.5)
	get_tree().create_timer(0.7).timeout.connect(func(): Sfx.play("fanfare" if String(sb["grade"]) in ["A", "B"] else ("chime_ok" if String(sb["grade"]) in ["C", "D"] else "fail")))
	# a personal best, when this computer is keeping score
	if PlayerData.autosave_enabled and PlayerData.campaign["done"].has(PlayerData.current_mission()):
		var rb := ScoreBoard.record_best(PlayerData.current_mission(), int(sb["points"]))
		if bool(rb["new_best"]):
			tv.add_child(UiStyle.mono_label("NEW PERSONAL BEST!", 14, UiStyle.PHOSPHOR))
		elif not bool(rb["first"]):
			tv.add_child(UiStyle.mono_label("YOUR BEST  %d" % int(rb["best"]), 13, Color(UiStyle.NEAR_WHITE, 0.7)))
	var bl := ScoreBoard.badges(sb, run)
	if not bl.is_empty():
		var br := HBoxContainer.new()
		br.add_theme_constant_override("separation", 10)
		for bd in bl:
			var cell := VBoxContainer.new()
			var t := TextureRect.new()
			t.texture = load("res://assets/ui/kit/%s.png" % String(bd["file"]))
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(62, 52)
			t.tooltip_text = String(bd["why"])
			cell.add_child(t)
			var cap := UiStyle.mono_label(String(bd["name"]), 9, UiStyle.AMBER)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(cap)
			br.add_child(cell)
		parent.add_child(br)
	for r in sb["rows"]:
		var l := UiStyle.mono_label("%-11s %3d / %d" % [String(r["name"]), int(r["pts"]), int(r["max"])], 13, UiStyle.PHOSPHOR if float(r["pts"]) >= 0.8 * float(r["max"]) else Color(UiStyle.NEAR_WHITE, 0.8))
		parent.add_child(l)


## One real NASA observation beside the player's simulated evidence. Clearly labelled REAL and SIMULATED, with its credit and source.
func _nasa_block(parent: VBoxContainer, run: MissionRun) -> void:
	var cid := PlayerData.current_mission()
	if cid > 1:
		return
	parent.add_child(UiStyle.mono_label("REAL NASA VIEW   (your photos above are crops of it, scored by the game)" if cid == 0 else "REAL NASA VIEW   (your photos above are SIMULATED)", 13, UiStyle.AMBER))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	parent.add_child(h)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/nasa/orientale_crop.jpg" if cid == 0 else "res://assets/nasa/artemis2_farside_view.jpg")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(150, 150)
	pic.clip_contents = true
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	v.add_child(_label("NASA's annotated view of the Moon's far side from the Artemis II flyby%s. Credit: NASA." % (" (Orientale area)" if cid == 0 else " (Ohm is labelled)"), 14, Color(UiStyle.NEAR_WHITE, 0.9), 400.0))
	var lk := LinkButton.new()
	lk.text = "Source: NASA flight day 6 blog"
	lk.uri = NasaCompare.SOURCE_URL
	lk.add_theme_font_size_override("font_size", 13)
	v.add_child(lk)
	_nasa_status = _label("", 14, UiStyle.PHOSPHOR, 400.0)
	v.add_child(_nasa_status)
	_refresh_nasa_status(run)
	if cid == 0:
		var b := Button.new()
		b.text = "COMPARE: FIND THE BASIN"
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(0, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _open_compare(run))
		v.add_child(b)


func _refresh_nasa_status(run: MissionRun) -> void:
	if _nasa_status == null:
		return
	var c: Dictionary = run.nasa_compare if run != null else {}
	_nasa_status.text = "" if c.is_empty() else "You found the dark interior: %s.  Bright rings: %s." % ["yes" if c.get("interior", false) else "no", "yes" if c.get("rings", false) else "no"]


func _open_compare(run: MissionRun) -> void:
	var nc := NasaCompare.new()
	var wide := {}
	for e in run.evidence:
		if String(e.get("lens", "")) == "wide" and bool(e.get("captured", true)):
			wide = e
	nc.framing = float(wide.get("framing", -1.0)) if not wide.is_empty() else -1.0
	nc.steady = float(wide.get("sharp", 0.0))
	nc.light = float(wide.get("light", 0.0))
	add_child(nc)
	nc.finished.connect(func(r):
		run.nasa_compare = r
		_refresh_nasa_status(run))


func _row_card(e: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.panel(10, 0.9))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	var pic := TextureRect.new()
	pic.texture = e.get("tex")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(170, 100)
	pic.clip_contents = true
	if e.get("tex") == null:
		pic.modulate = Color(1, 1, 1, 0.0)
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	var meets := bool(e["meets"])
	v.add_child(UiStyle.mono_label("%s   %s   %s" % [String(e["label"]), ("PHOTO: NASA VIEW, GAME SCORES" if PlayerData.current_mission() == 0 else "SIMULATED PHOTO"), ("*".repeat(int(e["stars"])) if int(e["stars"]) > 0 else "")], 14, UiStyle.NEAR_WHITE))
	var st := EvidenceCheck.stage_text(e)
	for kv in [["CAPTURED", st["captured"], bool(e["captured"])], ["TAGGED", st["tagged"], bool(e["tag_ok"])], ["RECEIVED", st["received"], bool(e["received"])], ["MEETS CRITERIA", st["meets"], meets]]:
		var line := UiStyle.mono_label("%-15s %s" % [kv[0], kv[1]], 14, UiStyle.PHOSPHOR if kv[2] else UiStyle.CORAL)
		v.add_child(line)
	if bool(e["captured"]):
		v.add_child(UiStyle.mono_label("FRAMED %d%%   STEADY %d%%   LIGHT %d%%" % [int(float(e["framing"]) * 100.0), int(float(e["sharp"]) * 100.0), int(float(e["light"]) * 100.0)], 12, Color(UiStyle.NEAR_WHITE, 0.7)))
	for pr in e["problems"]:
		v.add_child(_label(String(pr), 14, UiStyle.AMBER, 360.0))
	return card


func _evidence_card(e: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.panel(10, 0.9))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	var pic := TextureRect.new()
	pic.texture = e.get("tex")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(190, 110)
	pic.clip_contents = true
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	v.add_child(UiStyle.mono_label(evidence_title(e), 15, UiStyle.NEAR_WHITE))
	var conf := String(e["confidence"])
	var col := UiStyle.PHOSPHOR if conf == "STRONG" else (UiStyle.AMBER if conf == "MODERATE" else UiStyle.CORAL)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyle.chip(col))
	badge.add_child(UiStyle.mono_label("%s   %s" % [conf, "*".repeat(int(e["stars"]))], 14, col))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(badge)
	v.add_child(UiStyle.mono_label("Reached Earth", 13, Color(UiStyle.NEAR_WHITE, 0.7)))
	return card


func _crew_row(run: MissionRun, i: int) -> Control:
	var c: Dictionary = run.crew[i]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var pic := TextureRect.new()
	pic.texture = CrewData.portrait(String(c["char"]))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(80, 80)
	if run.is_dead(i):
		pic.modulate = Color(0.45, 0.45, 0.5)
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	v.add_child(UiStyle.mono_label("%s   %s" % [String(c["name"]).to_upper(), c["role"]], 14, UiStyle.NEAR_WHITE))
	var he := Control.new()
	he.custom_minimum_size = Vector2(0, 22)
	he.draw.connect(func(): CrewHearts.draw_row(he, Vector2.ZERO, 19.0, run.hearts(i), UiStyle.CORAL, Color(UiStyle.CORAL, 0.18)))
	v.add_child(he)
	var st := _label(("Lost: " + String(c.get("cause", ""))) if run.is_dead(i) else run.status_line(i), 14, UiStyle.CORAL if run.is_dead(i) else Color(UiStyle.NEAR_WHITE, 0.8), 290.0)
	v.add_child(st)
	return h


# ---------------------------------------------------------------- the words (also used for the saved copy)

static func evidence_title(e: Dictionary) -> String:
	if String(e.get("crater", "")) != "":
		var nm := String(CraterScience.CRATERS[e["crater"]]["name"]).to_upper()
		var pa := String(CraterScience.pass_by_id(String(e.get("pass", "")))["text"])
		return "%s   %s" % [nm, pa.to_upper()]
	return "WIDE PHOTO" if e["lens"] == "wide" else "CLOSE-UP PHOTO"


## Contract 03: what was sent, what Mission Control concluded, and whether each verdict was justified.
static func impact_lines(run: MissionRun) -> Array[String]:
	var out: Array[String] = []
	var im: Dictionary = run.impact
	out.append("%d of %d packets sent." % [int(im.get("sent_cost", 0)), int(im.get("budget", 0))])
	if not bool(im.get("sent", false)):
		out.append("Nothing reached Mission Control.")
		return out
	for r in im.get("eval", {}).get("results", []):
		out.append("%s: you said '%s'. %s (credit %d%%). %s" % [r["candidate"], String(ImpactReview.VERDICT_LABEL.get(r["verdict"], "nothing")), "Justified" if r["justified"] else "Not justified", int(r["credit"]), String(r["note"])])
	var lesson := String(im.get("reveal", {}).get("lesson", ""))
	if lesson != "":
		out.append("Lesson: " + lesson)
	return out


static func finding_lines(run: MissionRun) -> Array[String]:
	var out: Array[String] = []
	if run == null:
		return out
	if not run.impact.is_empty():
		out.append("Fictional simulation. The flashes, windows and packet costs are game data, and the rules are game rules, not NASA criteria.")
		out.append("Review %s." % ("complete: every verdict justified" if bool(run.impact.get("complete", false)) else "NOT complete"))
		return out
	var sci: Dictionary = run.science
	if bool(sci.get("crater", false)) and not sci.get("eval", {}).is_empty():
		var ev: Dictionary = sci["eval"]
		out.append("Comparison: %s confidence. %s" % [String(ev["confidence"]).capitalize(), "The pair held up." if ev["usable"] else String(ev["why"])])
		for l in ev["lines"]:
			out.append(String(l))
		return out
	var n := 0
	var meets := 0
	var total := 0
	for e in run.evidence:
		if bool(e.get("received", false)):
			n += 1
		if bool(e.get("needed", false)):
			total += 1
			if bool(e["meets"]):
				meets += 1
	out.append("%d photo%s reached Earth." % [n, "" if n == 1 else "s"])
	if total > 0:
		out.append("Contract criteria met for %d of %d needed shots. %s" % [meets, total, "The contract is complete." if meets == total else "The contract is NOT complete: see each shot."])
	for e in run.evidence:
		if bool(e.get("needed", false)):
			var st := EvidenceCheck.stage_text(e)
			out.append("%s: captured %s, tagged %s, %s, meets criteria %s." % [String(e["label"]), st["captured"].to_lower(), st["tagged"].to_lower(), st["received"].to_lower(), st["meets"].to_lower()])
		elif bool(e.get("received", false)):
			out.append("%s: %s, tagged %s." % [evidence_title(e).capitalize(), String(e["confidence"]).to_lower(), "correctly" if e.get("tag_ok", false) else "the wrong way round"])
	return out


## The whole report as plain text, for the saved copy.
static func build_text(run: MissionRun, m: Dictionary) -> String:
	var t := PackedStringArray()
	t.append("# Moonbound mission report")
	t.append("")
	t.append("**%s - %s**" % [m["tag"], m["name"]])
	t.append("")
	t.append("Promised: " + String(m["objective"]))
	t.append("Evidence asked for: " + ", ".join(m["evidence"]))
	t.append("")
	t.append("## What came back")
	var any := false
	if run != null and not run.impact.is_empty():
		any = true
		for l in impact_lines(run):
			t.append("- " + l)
	if run != null:
		for e in run.evidence:
			if bool(e.get("needed", false)):
				any = any or bool(e["received"])
				var st := EvidenceCheck.stage_text(e)
				t.append("- %s (%s): captured %s; tagged %s; %s; meets contract criteria %s. Framed %d%%, steady %d%%, light %d%%." % [String(e["label"]), "player photo cropped from NASA's real view" if int(m.get("id", 0)) == 0 else "simulated player photo", st["captured"].to_lower(), st["tagged"].to_lower(), st["received"].to_lower(), st["meets"].to_lower(), int(float(e["framing"]) * 100.0), int(float(e["sharp"]) * 100.0), int(float(e["light"]) * 100.0)])
				for pr in e["problems"]:
					t.append("    * " + String(pr))
			elif bool(e.get("received", false)):
				any = true
				t.append("- %s: %s confidence, %d stars. Reached Earth." % [evidence_title(e), String(e["confidence"]).to_lower(), int(e["stars"])])
	if not any:
		t.append("- Nothing reached Earth.")
	t.append("")
	t.append("## The finding")
	for l in finding_lines(run):
		t.append("- " + l)
	t.append("")
	t.append("## What happened on the way")
	if run == null or run.events.is_empty():
		t.append("- Nothing unexpected.")
	else:
		for ev in run.events:
			t.append("- %s%s" % [ev["text"], ("  ->  " + String(ev["choice"])) if String(ev.get("choice", "")) != "" else ""])
	if run != null:
		for d in run.damage_log:
			t.append("- %s lost health: %s" % [d["name"], d["reason"]])
		t.append("")
		t.append("## Crew")
		for i in run.crew.size():
			var c: Dictionary = run.crew[i]
			t.append("- %s (%s): %s" % [c["name"], c["role"], ("lost - " + String(c.get("cause", ""))) if run.is_dead(i) else run.status_line(i)])
		t.append("")
		t.append("Left at the end: %d minutes, %d power." % [int(run.left("time")), int(run.left("power"))])
	t.append("")
	t.append("## Real NASA reference")
	t.append("- Real image: NASA's annotated far-side view from the Artemis II lunar flyby (Orientale Basin and Ohm are labelled). Credit: NASA. Source: https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/")
	if run != null and not run.nasa_compare.is_empty():
		t.append("- Your comparison: dark basin interior found: %s; bright rings found: %s." % ["yes" if run.nasa_compare.get("interior", false) else "no", "yes" if run.nasa_compare.get("rings", false) else "no"])
	t.append("- Contract 01 photos are crops of NASA's real far-side view, framed and scored by the game. Other simulated views are not NASA imagery." if int(m.get("id", 0)) == 0 else "- The photos above are SIMULATED by the game. They are not NASA imagery.")
	t.append("")
	t.append("## Sources")
	t.append("- NASA Artemis II press kit (countdown, ascent, flyby, holds): https://www.nasa.gov/artemis-ii-press-kit/")
	t.append("- NASA flight day 6 lunar flyby updates (blackout about 40 minutes, Orientale, Glushko): https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/")
	t.append("- NASA flight day 10 re-entry updates (the way home): https://www.nasa.gov/blogs/missions/2026/04/10/artemis-ii-flight-day-10-re-entry-live-updates/")
	t.append("- USGS Gazetteer, Glushko: https://planetarynames.wr.usgs.gov/Feature/2195  and Ohm: https://planetarynames.wr.usgs.gov/Feature/4417")
	t.append("- LROC Sun Angles: https://lroc.im-ldi.com/images/790")
	t.append("")
	t.append("Moonbound is a fictional educational mission inspired by Artemis II. NASA does not endorse it.")
	t.append("Confidence, time, power and health are GAME scores and rules. They are not NASA measurements. Simulated views are not NASA imagery.")
	return "\n".join(t)


func _on_save() -> void:
	var dir := "user://reports"
	DirAccess.make_dir_recursive_absolute(dir)
	var m: Dictionary = Missions.get_mission(PlayerData.current_mission())
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/moonbound_report_%02d_%s.md" % [dir, PlayerData.current_mission() + 1, stamp]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_status.text = "Could not save the report."
		_status.add_theme_color_override("font_color", UiStyle.CORAL)
		return
	f.store_string(build_text(PlayerData.run, m))
	f.close()
	_status.text = "Saved: " + ProjectSettings.globalize_path(path)
	_status.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
