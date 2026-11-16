extends Control
## The end of a campaign, told as a short story the player walks through one beat at a time.
##   WON:        HOMECOMING (crew, Mission Control welcomes them home) > YOUR MISSION (each contract, what you did) >
##               WHAT YOU DISCOVERED (the real NASA far side, the places you studied, what you learned) >
##               THE REAL MISSION (sourced Artemis II facts) > CERTIFICATE (a rating and a picture to keep)
##   CREW LOST:  IN MEMORY (who, and what happened) > WHAT TO TRY NEXT
##   STUCK:      THE SHIP CANNOT GO ON (what you finished, why, how to plan next time)
## Progress is already saved, so BACK TO TITLE keeps it. Everything here is fiction inspired by Artemis II, with REAL facts
## labelled and linked. The rating is a GAME score.

@export_file("*.tscn") var title_scene: String = "res://title.tscn"
@export_file("*.tscn") var select_scene: String = "res://mission_select.tscn"

const NASA_VIEW: Texture2D = preload("res://assets/nasa/artemis2_farside_view.jpg")
const PLACES := {"Orientale Basin": Vector2(715, 675), "Ohm": Vector2(565, 360)}      # where the places sit in NASA's picture (pixels)

var _kind := ""
var _beats: Array[Callable] = []
var _i := 0
var _stage: VBoxContainer
var _next: Button
var _pic: Control
var _pulse_t := 0.0
var _saved_label: Label


## Which ending this campaign has: "won", "crew_lost" or "stuck". Empty if the campaign is not over.
static func kind_of(campaign: Dictionary) -> String:
	if not bool(campaign.get("over", false)):
		return ""
	if bool(campaign.get("won", false)):
		return "won"
	if String(campaign.get("over_reason", "")).begins_with("The whole crew was lost"):
		return "crew_lost"
	return "stuck"


## The rating (a GAME score, 0 to 100) and its name, from the contract log. Each log entry carries its own 0 to 100 score.
static func rating(campaign: Dictionary, crew: Array) -> Dictionary:
	var log: Array = campaign.get("log", [])
	var total := 0.0
	for e in log:
		total += float(e.get("score", 60))
	var score := total / float(maxi(log.size(), 1))
	var healthy := 0
	for c in crew:
		if float(c.get("health", 100.0)) >= 99.0:
			healthy += 1
	if not crew.is_empty() and healthy == crew.size():
		score = minf(score + 5.0, 100.0)
	var name := "CADET"
	if score >= 90.0:
		name = "FLIGHT DIRECTOR"
	elif score >= 75.0:
		name = "MISSION COMMANDER"
	elif score >= 55.0:
		name = "MISSION SPECIALIST"
	return {"score": int(round(score)), "name": name}


func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_kind = kind_of(PlayerData.campaign)
	_build_background()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_right", 110)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)
	_stage = VBoxContainer.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.add_theme_constant_override("separation", 16)
	outer.add_child(_stage)
	_next = Button.new()
	_next.theme_type_variation = &"PrimaryButton"
	_next.add_theme_font_size_override("font_size", 26)
	_next.custom_minimum_size = Vector2(380, 90)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(next_beat)
	outer.add_child(_next)
	match _kind:
		"won":
			_beats = [_beat_home, _beat_mission, _beat_score, _beat_found, _beat_real, _beat_certificate]
			Music.play("landing")
		"crew_lost":
			_beats = [_beat_memorial, _beat_try_next]
			Music.play("design")
		_:
			_beats = [_beat_stuck]
			Music.play("design")
	_show(0)


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/select/bg_earth_orbit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.027, 0.043, 0.133, 0.62 if _kind == "won" else 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var ground := TextureRect.new()
	ground.texture = load("res://assets/ui/kit/layer_lunar_terrain_foreground.png")
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.modulate = Color(1, 1, 1, 0.5 if _kind == "won" else 0.25)
	add_child(ground)


# ---------------------------------------------------------------- moving through the beats

func _show(i: int) -> void:
	_i = i
	for c in _stage.get_children():
		c.queue_free()
	_pic = null
	_beats[i].call()
	_next.visible = i < _beats.size() - 1
	_next.text = "NEXT" if i < _beats.size() - 2 else ("SEE THE CERTIFICATE" if _kind == "won" else "WHAT TO TRY NEXT")
	# each beat fades in, piece by piece
	var d := 0.0
	for c in _stage.get_children():
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(c, "modulate:a", 1.0, 0.55).set_delay(d)
		d += 0.28


## Go to the next beat. Public so a test can stand in for the click.
func next_beat() -> void:
	if _i < _beats.size() - 1:
		Sfx.play("stage", -4.0)
		_show(_i + 1)


func beat_count() -> int:
	return _beats.size()


func _process(delta: float) -> void:
	_pulse_t += delta
	if _pic != null:
		_pic.queue_redraw()


# ---------------------------------------------------------------- small builders

func _label(t: String, size := 22, color := UiStyle.NEAR_WHITE, minw := 1400.0) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(minw, 0)
	return l


func _panel(inner: Control, alpha := 0.86, margin := 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(margin, alpha))
	p.add_child(inner)
	return p


func _names() -> String:
	var names: Array[String] = []
	for c in PlayerData.crew:
		names.append(String(c["name"]))
	if names.is_empty():
		return "the crew"
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


func _portrait(id: String, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/ui/crew/%s_portrait.png" % id) as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = Vector2(size, size)
	return t


func _crew_row(memorial := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var list: Array = PlayerData.campaign.get("memorial", []) if memorial else PlayerData.crew
	for c in list:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		var pic := _portrait(String(c["char"]), 150.0)
		if memorial:
			pic.modulate = Color(0.55, 0.58, 0.68, 1.0)
		v.add_child(pic)
		var n := UiStyle.mono_label(String(c["name"]).to_upper(), 18, UiStyle.NEAR_WHITE)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var r := UiStyle.mono_label(String(c["role"]), 13, UiStyle.CHROME)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(r)
		if memorial:
			var cause := _label(String(c.get("cause", "")), 15, Color(UiStyle.NEAR_WHITE, 0.8), 230.0)
			cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(cause)
		else:
			var h := UiStyle.mono_label("HEALTH %d%%" % int(float(c.get("health", 100.0))), 13, UiStyle.PHOSPHOR)
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(h)
		row.add_child(v)
	return row


func _mc(text: String, width := 1500.0, size := 26) -> CoachPanel:
	var cp := CoachPanel.new(width, size)
	cp.say(text)
	return cp


# ---------------------------------------------------------------- the winning ending

func _beat_home() -> void:
	Sfx.play("fanfare")
	_confetti()
	_stage.add_child(UiStyle.mono_label("MOONBOUND   -   MISSION COMPLETE", 15, UiStyle.AMBER))
	var h := UiStyle.heading("YOU BROUGHT THEM HOME")
	h.add_theme_font_size_override("font_size", 56)
	h.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	_stage.add_child(h)
	var done: Array = PlayerData.campaign.get("log", [])
	_stage.add_child(_mc("Welcome home, %s. %d contracts, one ship you built once and never got to change, and everyone is on the ground. Flight Director, that is the whole job. Well done." % [_names(), done.size()]))
	_stage.add_child(_panel(_crew_row(), 0.8, 18))
	var badges := HBoxContainer.new()
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 24)
	for n in ["badge_gold_wings", "badge_trophy", "badge_rocket"]:
		var t := TextureRect.new()
		t.texture = load("res://assets/ui/kit/%s.png" % n)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(130, 120)
		badges.add_child(t)
	_stage.add_child(badges)


func _beat_mission() -> void:
	_stage.add_child(UiStyle.mono_label("YOUR MISSION", 15, UiStyle.AMBER))
	_stage.add_child(UiStyle.heading("WHAT YOU DID"))
	_stage.add_child(_mc("Here is the record. Three different jobs: seeing a place, comparing two places, and deciding what you can honestly conclude."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	for e in PlayerData.campaign.get("log", []):
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.custom_minimum_size = Vector2(540, 0)
		v.add_child(UiStyle.mono_label("%s   %s" % [String(e.get("tag", "")), String(e.get("name", ""))], 16, UiStyle.PHOSPHOR))
		v.add_child(_label(String(e.get("headline", "")), 22, UiStyle.NEAR_WHITE, 520.0))
		v.add_child(_label(String(e.get("detail", "")), 17, Color(UiStyle.NEAR_WHITE, 0.82), 520.0))
		v.add_child(UiStyle.mono_label("GRADE %s   %d POINTS" % [String(e.get("grade", "-")), int(e.get("points", 0))], 16, UiStyle.AMBER))
		row.add_child(_panel(v, 0.86, 18))
	_stage.add_child(row)


## Total points, the difficulty, and where this run sits on this computer's leaderboard.
func _beat_score() -> void:
	var pts := int(PlayerData.campaign.get("points", 0))
	var diff := ScoreBoard.difficulty(int(PlayerData.campaign.get("difficulty", 1)))
	_stage.add_child(UiStyle.mono_label("YOUR SCORE", 15, UiStyle.AMBER))
	var h := UiStyle.heading("%d POINTS" % pts)
	h.add_theme_font_size_override("font_size", 64)
	h.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	_stage.add_child(h)
	var r := rating(PlayerData.campaign, PlayerData.crew)
	_stage.add_child(_mc("%s difficulty, rated %s. Points are earned from DATA, SCIENCE, FLIGHT, CREW, EFFICIENCY and DECISIONS on every flight, and harder settings multiply them. Can you beat this on %s?" % [String(diff["name"]).capitalize(), String(r["name"]), "DIRECTOR" if int(PlayerData.campaign.get("difficulty", 1)) < 2 else "your own record"]))
	var entry := {"name": String(PlayerData.crew[0]["name"]) if not PlayerData.crew.is_empty() else "Flight Director", "points": pts, "grade": String(r["name"]), "difficulty": String(diff["name"]), "date": Time.get_date_string_from_system()}
	var rank := 0
	if PlayerData.autosave_enabled and not bool(PlayerData.campaign.get("score_saved", false)):
		rank = ScoreBoard.submit(entry)
		PlayerData.campaign["score_saved"] = true
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", 4)
	board.add_child(UiStyle.mono_label("LEADERBOARD   (this computer)", 14, UiStyle.PHOSPHOR))
	var scores := ScoreBoard.load_scores() if PlayerData.autosave_enabled else [entry]
	var shown := 0
	for s in scores:
		if shown >= 5:
			break
		shown += 1
		var mine: bool = int(s.get("points", 0)) == pts and String(s.get("date", "")) == String(entry["date"]) and String(s.get("name", "")) == String(entry["name"])
		board.add_child(UiStyle.mono_label("%d.  %-12s %6d   %-10s %s" % [shown, String(s.get("name", "")), int(s.get("points", 0)), String(s.get("difficulty", "")), "<  YOU" if mine else ""], 17, UiStyle.PHOSPHOR if mine else UiStyle.NEAR_WHITE))
	if rank == 1:
		board.add_child(UiStyle.mono_label("NEW HIGH SCORE!", 18, UiStyle.AMBER))
	_stage.add_child(_panel(board, 0.86, 18))


func _beat_found() -> void:
	_stage.add_child(UiStyle.mono_label("WHAT YOU DISCOVERED", 15, UiStyle.AMBER))
	_stage.add_child(UiStyle.heading("THE FAR SIDE, AND WHAT IT TAUGHT YOU"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_stage.add_child(row)
	# NASA's real far-side picture with the places you studied pulsing on it
	var left := VBoxContainer.new()
	row.add_child(left)
	_pic = Control.new()
	_pic.custom_minimum_size = Vector2(620, 620)
	_pic.draw.connect(_draw_pic)
	left.add_child(_pic)
	left.add_child(UiStyle.mono_label("REAL: NASA's annotated far side from the Artemis II flyby. Credit: NASA.", 12, Color(UiStyle.NEAR_WHITE, 0.7)))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	var lessons := [
		["LIGHT CHANGES WHAT YOU SEE", "Low Sun throws shadows that show a crater's shape. High Sun has no shadows, so bright rays stand out. Two photos in different light are not a fair comparison. (REAL rule: LROC Sun Angles.)"],
		["ONE WITNESS IS NOT TWO", "Records from one window, or a retelling of someone else's log, count as ONE source. A real event can honestly be called 'possible' when only one source saw it. (GAME rule inspired by how scientists confirm things.)"],
		["THE MOON BLOCKS RADIO", "Behind the Moon there is no contact. NASA planned about 40 minutes of blackout on the real flyby. You planned which data to send first. (REAL: NASA flight day 6.)"],
	]
	for l in lessons:
		var v := VBoxContainer.new()
		v.add_child(UiStyle.mono_label(String(l[0]), 15, UiStyle.PHOSPHOR))
		v.add_child(_label(String(l[1]), 19, UiStyle.NEAR_WHITE, 760.0))
		right.add_child(_panel(v, 0.86, 14))


func _draw_pic() -> void:
	if _pic == null:
		return
	_pic.draw_texture_rect(NASA_VIEW, Rect2(Vector2.ZERO, Vector2(620, 620)), false)
	var k := 620.0 / 1024.0
	var p := 0.5 + 0.5 * sin(_pulse_t * 3.0)
	var studied: Array = PlayerData.campaign.get("studied", ["Orientale Basin", "Ohm"])
	for name in PLACES:
		if not studied.has(name):
			continue
		var at: Vector2 = PLACES[name] * k
		_pic.draw_arc(at, 22.0 + 6.0 * p, 0, TAU, 40, Color(UiStyle.PHOSPHOR, 0.95), 3.0, true)
		_pic.draw_arc(at, 34.0 + 10.0 * p, 0, TAU, 40, Color(UiStyle.PHOSPHOR, 0.45), 2.0, true)
		_pic.draw_string(UiStyle.MONO, at + Vector2(-60, -46), "YOU STUDIED " + String(name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 240, 13, UiStyle.PHOSPHOR)


func _beat_real() -> void:
	_stage.add_child(UiStyle.mono_label("THE REAL MISSION", 15, UiStyle.AMBER))
	_stage.add_child(UiStyle.heading("WHAT NASA'S ARTEMIS II REALLY DID"))
	_stage.add_child(_mc("Everything you flew was fiction, but it stands on a real flight. These are the real facts behind your mission, each with its NASA source."))
	var facts := [
		["THE FLYBY", "Artemis II's crew flew around the Moon in April 2026. On flight day 6 they passed the far side and photographed basins such as Orientale.", "https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/"],
		["THE BLACKOUT", "Behind the Moon the crew lost radio contact for about 40 minutes (planned 6:44 to 7:25 p.m. EDT). Your blackout was shorter: that is a GAME rule.", "https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/"],
		["THE WAY HOME", "Orion hit the atmosphere at about 400,000 ft with up to 3.9 g, then parachutes brought it down at about 20 mph off San Diego. You flew the same steps.", "https://www.nasa.gov/blogs/missions/2026/04/10/artemis-ii-flight-day-10-re-entry-live-updates/"],
		["THE COUNTDOWN", "The flight termination system is armed at T-4:30 and a hold after T-1:30 recycles the count. Your launch day used those rules.", "https://www.nasa.gov/artemis-ii-press-kit/"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	for f in facts:
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(740, 0)
		v.add_child(UiStyle.mono_label(String(f[0]), 15, UiStyle.PHOSPHOR))
		v.add_child(_label(String(f[1]), 19, UiStyle.NEAR_WHITE, 720.0))
		var lk := LinkButton.new()
		lk.text = "Source: " + String(f[2])
		lk.uri = String(f[2])
		lk.add_theme_font_size_override("font_size", 12)
		v.add_child(lk)
		grid.add_child(_panel(v, 0.86, 14))
	_stage.add_child(grid)


func _beat_certificate() -> void:
	var r := rating(PlayerData.campaign, PlayerData.crew)
	_stage.add_child(UiStyle.mono_label("MOONBOUND   -   CERTIFICATE", 15, UiStyle.AMBER))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(1300, 0)
	var t := UiStyle.heading("MISSION CERTIFICATE")
	t.add_theme_font_size_override("font_size", 46)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label("This certifies that the crew of %s, under their Flight Director, completed every contract of the Moonbound mission and came home." % _names(), 22, UiStyle.NEAR_WHITE, 1240.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var rk := UiStyle.heading("RATING:  %s" % String(r["name"]))
	rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rk.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	rk.add_theme_font_size_override("font_size", 40)
	v.add_child(rk)
	var sc := UiStyle.mono_label("GAME SCORE  %d / 100   -   %s" % [int(r["score"]), Time.get_date_string_from_system()], 16, UiStyle.AMBER)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sc)
	v.add_child(_crew_row())
	var fine := _label("Moonbound is a fictional educational mission inspired by Artemis II. NASA does not endorse it. The rating and every number are game values, not NASA data.", 14, Color(UiStyle.NEAR_WHITE, 0.6), 1240.0)
	fine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(fine)
	var pnl := _panel(v, 0.9, 26)
	pnl.name = "Certificate"
	_stage.add_child(pnl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var save := _button("SAVE THIS CERTIFICATE (PICTURE)", false, 20, 64)
	save.pressed.connect(save_certificate)
	row.add_child(save)
	var again := _button("NEW CAMPAIGN", true, 24, 64)
	again.pressed.connect(new_campaign)
	row.add_child(again)
	var title := _button("BACK TO TITLE", false, 20, 64)
	title.pressed.connect(func(): get_tree().change_scene_to_file(title_scene))
	row.add_child(title)
	_stage.add_child(row)
	_saved_label = _label("", 15, UiStyle.PHOSPHOR, 1300.0)
	_stage.add_child(_saved_label)


func _button(text: String, primary: bool, size: int, h: int) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"PrimaryButton" if primary else &"OutlineButton"
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(420 if primary else 360, h)
	b.focus_mode = Control.FOCUS_NONE
	return b


## Save a picture of the certificate screen to the player's own folder. Returns the file path ("" if it failed).
func save_certificate() -> String:
	await RenderingServer.frame_post_draw
	var dir := "user://certificates"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/moonbound_certificate_%s.png" % [dir, Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")]
	var err := get_viewport().get_texture().get_image().save_png(path)
	if err != OK:
		if _saved_label != null:
			_saved_label.text = "Could not save the picture."
		return ""
	var real := ProjectSettings.globalize_path(path)
	if _saved_label != null:
		_saved_label.text = "Saved: " + real
	return path


# ---------------------------------------------------------------- the crew-lost ending

func _beat_memorial() -> void:
	_stage.add_child(UiStyle.mono_label("MOONBOUND   -   IN MEMORY", 15, UiStyle.AMBER))
	var h := UiStyle.heading("THE CREW WAS LOST")
	h.add_theme_color_override("font_color", UiStyle.CORAL)
	h.add_theme_font_size_override("font_size", 48)
	_stage.add_child(h)
	_stage.add_child(_mc("Flight Director, I am sorry. We lost the crew. Every contract carries risk, and crew safety comes before every result. Take a moment. Then we will go through what happened."))
	if not PlayerData.campaign.get("memorial", []).is_empty():
		_stage.add_child(_panel(_crew_row(true), 0.8, 18))
	_stage.add_child(_label(String(PlayerData.campaign.get("over_reason", "")), 20, Color(UiStyle.NEAR_WHITE, 0.9)))
	var done: Array = PlayerData.campaign.get("log", [])
	if not done.is_empty():
		_stage.add_child(UiStyle.mono_label("BEFORE THEY WERE LOST THEY COMPLETED", 14, UiStyle.PHOSPHOR))
		for e in done:
			_stage.add_child(_label("%s   %s:   %s" % [String(e.get("tag", "")), String(e.get("name", "")), String(e.get("headline", ""))], 18))


func _beat_try_next() -> void:
	_stage.add_child(UiStyle.mono_label("WHAT TO TRY NEXT", 15, UiStyle.AMBER))
	_stage.add_child(UiStyle.heading("HOW TO BRING THEM HOME"))
	_stage.add_child(_mc("Failing is how a flight director learns. Here is what usually saves a crew, in order."))
	var tips := [
		["TREAT THE HURT", "Fit a Medical Bay. In flight, steer a hurt crew member there and press E. Hurt crew are shown in coral. Untreated injuries add up."],
		["FEED AND REST", "Energy at zero starts costing health. Walk the crew to the Galley and Crew Quarters before they run dry."],
		["THE WAY HOME IS A SKILL", "In Practice you can fly the entry angle, the g-load hold and the parachutes as often as you like. The same steps are on the real Orion."],
		["PLAN THE SHIP", "The ship is locked after the first contract. The Build screen shows what later contracts need, so build for all three."],
	]
	for t in tips:
		var v := VBoxContainer.new()
		v.add_child(UiStyle.mono_label(String(t[0]), 14, UiStyle.PHOSPHOR))
		v.add_child(_label(String(t[1]), 19, UiStyle.NEAR_WHITE, 1300.0))
		_stage.add_child(_panel(v, 0.84, 12))
	_final_buttons()


func _final_buttons() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var again := _button("NEW CAMPAIGN", true, 26, 80)
	again.pressed.connect(new_campaign)
	row.add_child(again)
	var title := _button("BACK TO TITLE", false, 20, 80)
	title.pressed.connect(func(): get_tree().change_scene_to_file(title_scene))
	row.add_child(title)
	_stage.add_child(row)


# ---------------------------------------------------------------- the stuck ending

func _beat_stuck() -> void:
	_stage.add_child(UiStyle.mono_label("MOONBOUND   -   END OF CAMPAIGN", 15, UiStyle.AMBER))
	var h := UiStyle.heading("THIS SHIP CANNOT GO ON")
	h.add_theme_color_override("font_color", UiStyle.CORAL)
	h.add_theme_font_size_override("font_size", 48)
	_stage.add_child(h)
	_stage.add_child(_mc("Your crew is safe, and you finished what this ship could do. But the next contract needs something the ship does not have, and a ship cannot be rebuilt once it is locked."))
	_stage.add_child(_label(String(PlayerData.campaign.get("over_reason", "")), 21))
	var log: Array = PlayerData.campaign.get("log", [])
	_stage.add_child(UiStyle.mono_label("WHAT YOU FINISHED", 14, UiStyle.PHOSPHOR))
	if log.is_empty():
		_stage.add_child(_label("No contract was finished.", 19))
	for e in log:
		_stage.add_child(_label("%s   %s:   %s" % [String(e.get("tag", "")), String(e.get("name", "")), String(e.get("headline", ""))], 19))
	_stage.add_child(_crew_row())
	_stage.add_child(_label("Next time: the Build screen lists what later contracts need. Plan the one ship for all of them, and keep a bay for a Medical Bay if you can.", 19, Color(UiStyle.NEAR_WHITE, 0.9)))
	_final_buttons()


## Forget this campaign (and its save) and start again from Mission Select. Public so a test can stand in for the click.
func new_campaign() -> void:
	PlayerData.start_over()
	get_tree().change_scene_to_file(select_scene)


func _confetti() -> void:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.34, 0.67, 1.0])
	ramp.colors = PackedColorArray([UiStyle.PHOSPHOR, UiStyle.CHROME, UiStyle.AMBER, Color(0.35, 0.5, 1.0)])
	for side in [0.12, 0.88]:
		var p := CPUParticles2D.new()
		p.position = Vector2(1920.0 * side, 1111.0)
		p.amount = 90
		p.one_shot = true
		p.explosiveness = 0.95
		p.lifetime = 3.2
		p.direction = Vector2(-0.35 if side > 0.5 else 0.35, -1.0)
		p.spread = 30.0
		p.initial_velocity_min = 900.0
		p.initial_velocity_max = 1500.0
		p.gravity = Vector2(0.0, 1100.0)
		p.angular_velocity_min = -420.0
		p.angular_velocity_max = 420.0
		p.scale_amount_min = 5.0
		p.scale_amount_max = 11.0
		p.color_initial_ramp = ramp
		add_child(p)
		p.emitting = true
		get_tree().create_timer(4.5).timeout.connect(p.queue_free)
