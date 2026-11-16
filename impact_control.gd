class_name ImpactControl
extends Control
## Contract 03, Mission Control's side. It sees ONLY the delivered case file: records with times, places, observers and source
## groups. No truth, no unsent records. The reviewer groups records into candidate sightings, cites the records that back each
## verdict, locks the review, and only then is the reveal shown (if the flyer's run record is on this computer).
## All rules are GAME rules inspired by the scientific process. They are not NASA's formal criteria. The mission is fictional.

signal finished(result: Dictionary)

var case: Dictionary = {}
var map: Dictionary = {}                 # opaque record id -> product id (flyer's run record); empty when reviewing someone else's case
var budget := 0
var sent_cost := 0
var standalone := false                  # opened from a file by a second person
var given_verdicts: Array = []           # a review file that came back: shown already judged, with the reveal

var _cands: Array[Dictionary] = []
var _sel := 0
var _verdicts := {}                      # candidate id -> {"verdict": String, "cites": Array}
var _locked := false
var _eval := {}
var _timeline: Control
var _grid: Control
var _right: VBoxContainer
var _left: VBoxContainer
var _status: Label
var _lock_btn: Button
var _group_colors := {}
const PALETTE := [Color("c8ff36"), Color("ffc45e"), Color("6fb4ff"), Color("ff8fd0"), Color("9be7c4"), Color("c9a0ff")]


func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cands = ImpactReview.candidates(case)
	var gi := 0
	var gs := {}
	for r in case["records"]:
		gs[String(r["source_group"])] = true
	var keys := gs.keys()
	keys.sort()
	for g in keys:
		_group_colors[g] = PALETTE[gi % PALETTE.size()]
		gi += 1
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.98)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(UiStyle.mono_label("MISSION CONTROL   -   %s   -   FICTIONAL SIMULATION, GAME RULES, NOT NASA CRITERIA" % String(case["case_id"]), 14, UiStyle.AMBER))
	root.add_child(UiStyle.heading("WHAT CAN WE RESPONSIBLY CONCLUDE?"))
	root.add_child(_label("You see only what arrived (%d records). You do not know what stayed aboard or what is real. Group records by SOURCE: records from one window, or a retelling of someone else's log, are ONE witness. Cite the records that back each verdict." % case["records"].size(), 18, Color(UiStyle.NEAR_WHITE, 0.9), 1780))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	_left = VBoxContainer.new()
	_left.custom_minimum_size = Vector2(820, 0)
	_left.add_theme_constant_override("separation", 8)
	row.add_child(_left)
	_timeline = Control.new()
	_timeline.custom_minimum_size = Vector2(820, 130)
	_timeline.draw.connect(_draw_timeline)
	_left.add_child(UiStyle.mono_label("TIMELINE (0 to 1:30)   colour = source group", 13, UiStyle.CHROME))
	_left.add_child(_timeline)
	_grid = Control.new()
	_grid.custom_minimum_size = Vector2(820, 300)
	_grid.draw.connect(_draw_grid)
	_left.add_child(UiStyle.mono_label("FAR SIDE (approximate)   boxes = what each observer could see   dots = reported places", 13, UiStyle.CHROME))
	_left.add_child(_grid)
	_status = _label("", 18, UiStyle.PHOSPHOR, 820)
	_left.add_child(_status)
	_lock_btn = Button.new()
	_lock_btn.text = "LOCK MY REVIEW"
	_lock_btn.theme_type_variation = &"PrimaryButton"
	_lock_btn.add_theme_font_size_override("font_size", 26)
	_lock_btn.custom_minimum_size = Vector2(420, 80)
	_lock_btn.focus_mode = Control.FOCUS_NONE
	_lock_btn.pressed.connect(_lock)
	_left.add_child(_lock_btn)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 10)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_right)
	_rebuild_right()
	_update_status()
	if not given_verdicts.is_empty():
		for v in given_verdicts:
			_verdicts[String(v.get("candidate", ""))] = {"verdict": String(v.get("verdict", "")), "cites": (v.get("cites", []) as Array).duplicate()}
		_lock(false)


func _label(t: String, size := 18, color := UiStyle.NEAR_WHITE, minw := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if minw > 0.0:
		l.custom_minimum_size = Vector2(minw, 0)
	return l


func _chip_text(g: String) -> String:
	return g


# ---------------------------------------------------------------- the right side: candidates, records, verdict

func _rebuild_right() -> void:
	for c in _right.get_children():
		c.queue_free()
	if _cands.is_empty():
		_right.add_child(_label("Nothing positive arrived: no candidate sightings. A review with nothing to review is complete.", 22, UiStyle.AMBER, 860))
		return
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	_right.add_child(tabs)
	for i in _cands.size():
		var c := _cands[i]
		var b := Button.new()
		var done: bool = _verdicts.has(c["id"])
		b.text = "%s  %s%s" % [c["id"], _span(c["t"]), "  (done)" if done else ""]
		b.theme_type_variation = &"PrimaryButton" if i == _sel else &"OutlineButton"
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(0, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			_sel = i
			_rebuild_right()
			_timeline.queue_redraw()
			_grid.queue_redraw())
		tabs.add_child(b)
	var c := _cands[_sel]
	_right.add_child(_label("CANDIDATE %s: something reported at about %s, near lat %.0f, lon %.0f.   Independent sources: you decide." % [c["id"], _span(c["t"]), float(c["pos"]["lat"]), float(c["pos"]["lon"])], 20, UiStyle.NEAR_WHITE, 860))
	for r in c["records"]:
		_right.add_child(_record_row(r, c, true))
	for r in c["silent_inside"]:
		_right.add_child(_record_row(r, c, false, "SAW NOTHING (could see this place)"))
	for r in c["silent_outside"]:
		_right.add_child(_record_row(r, c, false, "SAW NOTHING (was looking elsewhere: weak)"))
	_right.add_child(_label("YOUR VERDICT", 16, UiStyle.AMBER))
	var vb := HBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_right.add_child(vb)
	var cur: Dictionary = _verdicts.get(c["id"], {})
	for v in ImpactReview.VERDICTS:
		var b := Button.new()
		b.text = String(ImpactReview.VERDICT_LABEL[v]).to_upper()
		b.toggle_mode = true
		b.button_pressed = String(cur.get("verdict", "")) == v
		b.disabled = _locked
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): set_verdict(String(c["id"]), v))
		vb.add_child(b)
	if _locked and not _eval.is_empty():
		for res in _eval["results"]:
			if res["candidate"] == c["id"]:
				var ok: bool = res["justified"]
				_right.add_child(_label("%s  %s  Credit %d%%.  %s  %s" % ["JUSTIFIED" if ok else "NOT JUSTIFIED", "", int(res["credit"]), String(res["note"]), "The evidence could justify: " + String(ImpactReview.VERDICT_LABEL[res["support"]["best"]]) + ". " + String(res["support"]["why"])], 18, UiStyle.PHOSPHOR if ok else UiStyle.CORAL, 860))


func _span(t: Array) -> String:
	return "%d:%02d" % [int(float(t[0])) / 60, int(float(t[0])) % 60] if absf(float(t[1]) - float(t[0])) < 1.5 else "%d:%02d to %d:%02d" % [int(float(t[0])) / 60, int(float(t[0])) % 60, int(float(t[1])) / 60, int(float(t[1])) % 60]


func _record_row(r: Dictionary, c: Dictionary, can_cite: bool, tag := "") -> Control:
	var p := PanelContainer.new()
	var sb := UiStyle.panel(10, 0.7)
	sb.border_color = _group_colors.get(String(r["source_group"]), UiStyle.EDGE)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	if can_cite:
		var cb := CheckBox.new()
		cb.text = "CITE"
		cb.disabled = _locked
		cb.focus_mode = Control.FOCUS_NONE
		var v: Dictionary = _verdicts.get(String(c["id"]), {})
		cb.button_pressed = (v.get("cites", []) as Array).has(String(r["id"]))
		cb.toggled.connect(func(on): cite(String(c["id"]), String(r["id"]), on))
		h.add_child(cb)
	var v2 := VBoxContainer.new()
	v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v2)
	var kind: String = {"crew_log": "LOG", "tight_crop": "TIGHT CROP", "wide_context": "WIDE FRAME"}.get(String(r["type"]), String(r["type"]))
	v2.add_child(_label("%s   %s   %s   SOURCE %s%s" % [r["id"], kind, r["observer"], r["source_group"], ("   (derived from " + String(r["derived_from"]) + ")") if String(r["derived_from"]) != "" else ""], 15, _group_colors.get(String(r["source_group"]), UiStyle.CHROME), 640))
	v2.add_child(_label("%s%s   (reporter's confidence %d%%)" % [(tag + ":  ") if tag != "" else "", r["text"], int(float(r["confidence"]) * 100.0)], 17, UiStyle.NEAR_WHITE, 640))
	return p


## Give a verdict to a candidate. Public so a test can stand in for the click.
func set_verdict(cid: String, verdict: String) -> void:
	if _locked or not ImpactReview.VERDICTS.has(verdict):
		return
	var cur: Dictionary = _verdicts.get(cid, {"verdict": "", "cites": []})
	cur["verdict"] = verdict
	_verdicts[cid] = cur
	_rebuild_right()
	_update_status()


## Cite (or un-cite) a record for a candidate's verdict. Public so a test can stand in for the click.
func cite(cid: String, rid: String, on := true) -> void:
	if _locked:
		return
	var cur: Dictionary = _verdicts.get(cid, {"verdict": "", "cites": []})
	var cites: Array = cur["cites"]
	if on and not cites.has(rid):
		cites.append(rid)
	elif not on:
		cites.erase(rid)
	cur["cites"] = cites
	_verdicts[cid] = cur
	_update_status()


func _update_status() -> void:
	if _lock_btn == null:
		return
	var missing := 0
	for c in _cands:
		if String(_verdicts.get(c["id"], {}).get("verdict", "")) == "":
			missing += 1
	_lock_btn.disabled = _locked or missing > 0
	if _locked:
		return
	_status.text = "%d of %d candidates have a verdict.%s" % [_cands.size() - missing, _cands.size(), "" if missing == 0 else "  Pick a verdict for each, with records cited."]
	_status.add_theme_color_override("font_color", UiStyle.PHOSPHOR if missing == 0 else UiStyle.AMBER)


## Lock the review and judge it. Public so a test can stand in for the click.
func lock() -> void:
	_lock()


func _lock(save_file := true) -> void:
	if _locked:
		return
	var list: Array = []
	for cid in _verdicts:
		list.append({"candidate": cid, "verdict": _verdicts[cid]["verdict"], "cites": _verdicts[cid]["cites"]})
	if _cands.size() > 0 and list.size() < _cands.size():
		return
	_locked = true
	_eval = ImpactReview.evaluate(case, list)
	var vf := ImpactCase.build_verdict_file(case, list)
	DirAccess.make_dir_recursive_absolute("user://impact_reviews")
	var path := "user://impact_reviews/review_%s.json" % String(case["case_id"])
	if save_file:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(vf, "  ", true))
			f.close()
	_rebuild_right()
	_lock_btn.disabled = true
	_status.text = "REVIEW LOCKED.  %s  Mean credit %d%%.%s" % ["Every verdict is justified by what arrived." if bool(_eval["complete"]) else "%d verdict%s not justified by the evidence." % [_eval["unjustified"], "" if int(_eval["unjustified"]) == 1 else "s"], int(_eval["mean_credit"]), ("  Saved to " + ProjectSettings.globalize_path(path) + "  Send this file back to the flyer.") if save_file else ""]
	_status.add_theme_color_override("font_color", UiStyle.PHOSPHOR if bool(_eval["complete"]) else UiStyle.CORAL)
	_lock_btn.hide()
	_show_reveal()


func _show_reveal() -> void:
	var run_known := not map.is_empty()
	var rev := {}
	if run_known:
		rev = ImpactReview.reveal(case, map, _eval, budget, sent_cost)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_left.add_child(box)
	if run_known:
		var show := Button.new()
		show.text = "REVEAL WHAT REALLY HAPPENED"
		show.theme_type_variation = &"OutlineButton"
		show.add_theme_font_size_override("font_size", 22)
		show.custom_minimum_size = Vector2(0, 64)
		show.focus_mode = Control.FOCUS_NONE
		show.pressed.connect(func():
			show.hide()
			_reveal_text(box, rev))
		box.add_child(show)
	else:
		box.add_child(_label("The reveal needs the flyer's run record, which stays on the flyer's computer. Send your review file back to the flyer.", 18, UiStyle.AMBER, 820))
	var done := Button.new()
	done.text = "DONE"
	done.theme_type_variation = &"PrimaryButton"
	done.add_theme_font_size_override("font_size", 26)
	done.custom_minimum_size = Vector2(0, 70)
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(func(): finished.emit({"complete": bool(_eval["complete"]), "eval": _eval, "reveal": rev, "verdicts": _verdicts.duplicate(true)}))
	box.add_child(done)


func _reveal_text(box: VBoxContainer, rev: Dictionary) -> void:
	box.add_child(_label("WHAT HAPPENED (aboard only)", 15, UiStyle.AMBER, 820))
	for t in rev["what_happened"]:
		box.add_child(_label(String(t), 16, UiStyle.NEAR_WHITE, 820))
	box.add_child(_label("WHAT REACHED EARTH", 15, UiStyle.AMBER, 820))
	box.add_child(_label("%d records. %s" % [case["records"].size(), String(rev["reached"][rev["reached"].size() - 1])], 16, UiStyle.NEAR_WHITE, 820))
	box.add_child(_label("WHAT THE REVIEW COULD SUPPORT", 15, UiStyle.AMBER, 820))
	for t in rev["could_support"]:
		box.add_child(_label(String(t), 16, UiStyle.NEAR_WHITE, 820))
	box.add_child(_label("LESSON FOR THE FLYER:  " + String(rev["lesson"]), 17, UiStyle.PHOSPHOR, 820))
	var parent: Node = box.get_parent()
	if parent != null:
		box.move_child(box.get_child(box.get_child_count() - 1), box.get_child_count() - 1)


# ---------------------------------------------------------------- drawings

func _draw_timeline() -> void:
	var w := _timeline.size.x
	_timeline.draw_rect(Rect2(0, 0, w, 130), Color(0.03, 0.05, 0.12))
	_timeline.draw_line(Vector2(10, 100), Vector2(w - 10, 100), UiStyle.EDGE, 2.0)
	for s in range(0, 91, 15):
		var x := 10.0 + (w - 20.0) * float(s) / 90.0
		_timeline.draw_line(Vector2(x, 96), Vector2(x, 106), UiStyle.EDGE, 2.0)
		_timeline.draw_string(ThemeDB.fallback_font, Vector2(x - 12, 124), "%d:%02d" % [s / 60, s % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.CHROME)
	var sel_ids := {}
	if not _cands.is_empty():
		for r in _cands[_sel]["records"]:
			sel_ids[String(r["id"])] = true
	var lane := {}
	var n := 0
	for r in case["records"]:
		var g := String(r["source_group"])
		if not lane.has(g):
			lane[g] = n
			n += 1
		var x0 := 10.0 + (w - 20.0) * float(r["time"][0]) / 90.0
		var x1 := maxf(10.0 + (w - 20.0) * float(r["time"][1]) / 90.0, x0 + 6.0)
		var y := 12.0 + float(lane[g]) * 20.0
		var col: Color = _group_colors.get(g, UiStyle.CHROME)
		_timeline.draw_rect(Rect2(x0, y, x1 - x0, 14), Color(col, 1.0 if sel_ids.has(String(r["id"])) else 0.45))
		if sel_ids.has(String(r["id"])):
			_timeline.draw_rect(Rect2(x0 - 2, y - 2, x1 - x0 + 4, 18), UiStyle.NEAR_WHITE, false, 2.0)


func _draw_grid() -> void:
	var sz := _grid.size
	_grid.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.05, 0.12))
	# longitude -180..180 across, latitude 60..-60 down
	var f := func(lon: float, lat: float) -> Vector2: return Vector2((lon + 180.0) / 360.0 * sz.x, (60.0 - lat) / 120.0 * sz.y)
	for lon in range(-180, 181, 60):
		_grid.draw_line(f.call(lon, 60), f.call(lon, -60), Color(UiStyle.EDGE, 0.35), 1.0)
	for lat in range(-60, 61, 30):
		_grid.draw_line(f.call(-180, lat), f.call(180, lat), Color(UiStyle.EDGE, 0.35), 1.0)
	var seen := {}
	for r in case["records"]:
		var cov: Dictionary = r["coverage"]
		var key := "%s%s" % [cov["lat"], cov["lon"]]
		if seen.has(key):
			continue
		seen[key] = true
		var a: Vector2 = f.call(float(cov["lon"][0]), float(cov["lat"][1]))
		var b: Vector2 = f.call(float(cov["lon"][1]), float(cov["lat"][0]))
		_grid.draw_rect(Rect2(a, b - a), Color(_group_colors.get(String(r["source_group"]), UiStyle.CHROME), 0.8), false, 2.0)
	var sel_ids := {}
	if not _cands.is_empty():
		for r in _cands[_sel]["records"]:
			sel_ids[String(r["id"])] = true
	for r in case["records"]:
		if r["position"] == null:
			continue
		var p: Vector2 = f.call(float(r["position"]["lon"]), float(r["position"]["lat"]))
		var col: Color = _group_colors.get(String(r["source_group"]), UiStyle.CHROME)
		_grid.draw_arc(p, float(r["position"]["err"]) / 360.0 * sz.x, 0, TAU, 24, Color(col, 0.6), 1.5)
		_grid.draw_circle(p, 7.0 if sel_ids.has(String(r["id"])) else 4.0, col)
