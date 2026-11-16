extends Control
## Contracts 04 to 06, step 2: run the mission. Each phase is a room of the spacecraft with something happening. You choose what to
## do, and whether it works depends on the design you built. At the end: a grade, points, and what each choice did.

@export_file("*.tscn") var back_scene: String = "res://mission_select.tscn"

var mission_id := 3
var picks := {}
var choices: Array = []

var _m: Dictionary
var _i := 0
var _stage: VBoxContainer
var _answered := false
var _result := {}


func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mission_id = PlayerData.current_mission()
	picks = PlayerData.space_picks
	_m = SpaceData.mission(mission_id)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/select/bg_earth_orbit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.027, 0.043, 0.133, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 150)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	_stage = VBoxContainer.new()
	_stage.add_theme_constant_override("separation", 14)
	margin.add_child(_stage)
	Music.play("orbit")
	_show_phase()


func _clear() -> void:
	for c in _stage.get_children():
		c.queue_free()


func _label(t: String, size := 22, color := UiStyle.NEAR_WHITE, minw := 1500.0) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(minw, 0)
	return l


func _show_phase() -> void:
	_clear()
	_answered = false
	var phases: Array = _m["phases"]
	if _i >= phases.size():
		_show_result()
		return
	var ph: Dictionary = phases[_i]
	_stage.add_child(UiStyle.mono_label("%s   -   PHASE %d OF %d   -   ROOM: %s" % [String(_m["name"]), _i + 1, phases.size(), String(ph["room"])], 14, UiStyle.PHOSPHOR))
	var h := UiStyle.heading(String(ph["title"]))
	h.add_theme_font_size_override("font_size", 44)
	_stage.add_child(h)
	var coach := CoachPanel.new(1500.0, 23)
	coach.say(String(ph["text"]))
	_stage.add_child(coach)
	_stage.add_child(UiStyle.mono_label("WHAT DO YOU DO?", 14, UiStyle.AMBER))
	var opts: Array = ph["options"]
	for k in opts.size():
		var b := Button.new()
		b.text = String(opts[k]["label"])
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(1500, 80)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): choose(k))
		_stage.add_child(b)


## Pick option k for this phase. Public so a test can stand in for the click.
func choose(k: int) -> void:
	if _answered:
		return
	var ph: Dictionary = (_m["phases"] as Array)[_i]
	var opts: Array = ph["options"]
	if k < 0 or k >= opts.size():
		return
	_answered = true
	choices.append(k)
	var d := SpaceData.derive(mission_id, picks)
	var o: Dictionary = opts[k]
	var good := SpaceData.passes(mission_id, d, String(o["test"]))
	Sfx.play("chime_good" if good else "chime_poor")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_label(("IT WORKED.  " if good else "IT DID NOT WORK.  ") + (String(o["good"]) if good else String(o["bad"])), 24, UiStyle.PHOSPHOR if good else UiStyle.CORAL))
	if not good:
		box.add_child(_label("The design decides this. Look at the part that was needed and try it next time.", 17, Color(UiStyle.NEAR_WHITE, 0.75)))
	var fact := FactData.for_room(String(ph["room"]), _i + mission_id)
	if not fact.is_empty():
		box.add_child(_label(FactData.line(fact), 17, UiStyle.AMBER))
	_stage.add_child(box)
	var nx := Button.new()
	nx.text = "NEXT" if _i < (_m["phases"] as Array).size() - 1 else "SEE THE RESULT"
	nx.theme_type_variation = &"PrimaryButton"
	nx.add_theme_font_size_override("font_size", 26)
	nx.custom_minimum_size = Vector2(380, 84)
	nx.size_flags_horizontal = Control.SIZE_SHRINK_END
	nx.focus_mode = Control.FOCUS_NONE
	nx.pressed.connect(func():
		_i += 1
		_show_phase())
	_stage.add_child(nx)


## After the result Mission Control asks three questions about this mission, worth points.
func _after_result() -> void:
	var qs: Array = []
	for q in QuizData.planner():
		if String(q["mission"]) == String(_m["name"]):
			qs.append(q)
	if qs.is_empty():
		get_tree().change_scene_to_file(back_scene)
		return
	var qc := QuizCard.new()
	qc.questions = qs
	qc.title_text = "MISSION CONTROL QUIZ"
	add_child(qc)
	qc.finished.connect(func(res: Dictionary):
		PlayerData.campaign["points"] = int(PlayerData.campaign.get("points", 0)) + int(res["points"])
		PlayerData.autosave()
		get_tree().change_scene_to_file(back_scene))


func _show_result() -> void:
	_clear()
	_result = SpaceData.score(mission_id, picks, choices, int(PlayerData.campaign.get("difficulty", 1)))
	PlayerData.complete_spacecraft(mission_id, _result)
	Sfx.play("fanfare" if String(_result["grade"]) in ["A", "B"] else "chime_ok")
	_stage.add_child(UiStyle.mono_label("%s   -   MISSION RESULT" % String(_m["name"]), 14, UiStyle.PHOSPHOR))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var letter := UiStyle.heading(String(_result["grade"]))
	letter.add_theme_font_size_override("font_size", 120)
	letter.add_theme_color_override("font_color", UiStyle.PHOSPHOR if String(_result["grade"]) in ["A", "B"] else (UiStyle.AMBER if String(_result["grade"]) in ["C", "D"] else UiStyle.CORAL))
	row.add_child(letter)
	var tv := VBoxContainer.new()
	tv.add_child(UiStyle.heading("%d POINTS" % int(_result["points"])))
	tv.add_child(UiStyle.mono_label("%d%%   (%d of %d, x%.2f %s)" % [int(_result["percent"]), int(_result["total"]), int(_result["max"]), float(_result["mult"]), String(_result["difficulty"])], 16, UiStyle.AMBER))
	for r in _result["rows"]:
		tv.add_child(UiStyle.mono_label("%-11s %3d / %d   %s" % [String(r["name"]), int(r["pts"]), int(r["max"]), String(r["why"])], 13, UiStyle.PHOSPHOR if float(r["pts"]) >= 0.8 * float(r["max"]) else Color(UiStyle.NEAR_WHITE, 0.8)))
	row.add_child(tv)
	_stage.add_child(row)
	_stage.add_child(UiStyle.mono_label("WHAT HAPPENED", 14, UiStyle.AMBER))
	for r in _result["results"]:
		_stage.add_child(_label("%s (%s):  %s   %s" % [String(r["title"]), String(r["room"]), "worked" if bool(r["good"]) else "did not work", String(r["text"])], 16, UiStyle.NEAR_WHITE if bool(r["good"]) else Color(UiStyle.CORAL, 0.95), 1500.0))
	var go := Button.new()
	go.text = "CONTINUE"
	go.theme_type_variation = &"PrimaryButton"
	go.add_theme_font_size_override("font_size", 28)
	go.custom_minimum_size = Vector2(420, 84)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_after_result)
	_stage.add_child(go)
