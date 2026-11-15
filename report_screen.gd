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
	var any := false
	for e in (run.evidence if run != null else []):
		if not bool(e.get("received", false)):
			continue
		any = true
		left.add_child(_evidence_card(e))
	if not any:
		left.add_child(_label("Nothing reached Earth.", 18, UiStyle.CORAL))

	# Middle: the finding and what happened
	var mid := _panel(Vector2(770, 140), Vector2(560, 700))
	mid.add_child(UiStyle.mono_label("THE FINDING", 14, UiStyle.PHOSPHOR))
	var lines := finding_lines(run)
	for l in lines:
		mid.add_child(_label(String(l), 17, Color(UiStyle.NEAR_WHITE, 0.92), 520.0))
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
	go.pressed.connect(func(): get_tree().change_scene_to_file(next_scene))
	layer.add_child(go)


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


static func finding_lines(run: MissionRun) -> Array[String]:
	var out: Array[String] = []
	if run == null:
		return out
	var sci: Dictionary = run.science
	if bool(sci.get("crater", false)) and not sci.get("eval", {}).is_empty():
		var ev: Dictionary = sci["eval"]
		out.append("Comparison: %s confidence. %s" % [String(ev["confidence"]).capitalize(), "The pair held up." if ev["usable"] else String(ev["why"])])
		for l in ev["lines"]:
			out.append(String(l))
		return out
	var n := 0
	for e in run.evidence:
		if bool(e.get("received", false)):
			n += 1
	out.append("%d photo%s reached Earth." % [n, "" if n == 1 else "s"])
	for e in run.evidence:
		if bool(e.get("received", false)):
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
	if run != null:
		for e in run.evidence:
			if bool(e.get("received", false)):
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
