class_name PhotoGame
extends Control
## The Moon photo mini-game. The player takes the picture themselves.
##
## Aim the camera at the three-ring basin as it drifts across the observation window, hold to steady
## the camera, release to take the photo. A wide shot shows WHERE (best in high sun); a close-up shows
## WHAT THE SURFACE IS LIKE (best in low sun, when shadows show texture). Then tag the evidence.
##
## From the team's design brief (Drive): "show a wide lunar image next to a detail tile ... report which
## image supports location and which supports texture", and the evidence record keeps timestamp, target,
## view direction, source and confidence. The view is simulated terrain art, not NASA imagery, and the
## light model is a game rule.

signal finished(result: Dictionary)

const BG: Texture2D = preload("res://assets/ui/flight/bg_lunar_surface.png")
const CONFIRM: Texture2D = preload("res://assets/ui/play/overlay_camera_capture_confirmed.png")
const NASA_VIEW: Texture2D = preload("res://assets/nasa/artemis2_farside_view.jpg")   # REAL: NASA's annotated far side from the Artemis II flyby (credit NASA)
const BASIN_AT := Vector2(715.0, 675.0)       # Orientale in that image (pixels)
const NASA_SCALE := 3.2                       # how much the camera magnifies the NASA view
const WINDOW_SECONDS := 34.0
const FRAME := {"wide": Vector2(560, 340), "close": Vector2(250, 156)}
const LENS_NAME := {"wide": "WIDE", "close": "CLOSE-UP"}

var has_lens := {"wide": true, "close": true}
## What is being photographed (from the contract) and what the ship gives you (GAME rules).
var target := {"name": "Orientale", "desc": "dark Orientale basin", "noun": "basin"}
var perks := {"shake": 1.0, "tries": 2, "rows": []}
var met_at_start := 34
## Crater contracts (Contract 02): the Sun pass the crew planned at the Flight Deck. {elev, dir, text, id}. Fixed for the window.
var sun := {}
var crater_id := ""

var _phase := "brief"
var _t := 0.0
var _lens := "wide"
var _aim := Vector2(960, 540)
var _steady := 0.0
var _holding := false
var _flash := 0.0
var _taking := false
var _attempts := {"wide": 0, "close": 0}
var _best := {}                     # lens -> photo dictionary
var _photo_log: Array[Dictionary] = []

var sub: SubViewport
var world: Control
var bg: TextureRect
var _view: TextureRect
var _finder: Control
var _panel: Control
var _time_bar: Label
var _lens_btns := {}
var _hint: Label
var _done_btn: Button
var _sun_bar: Control
var _sun_label: Label
var _coach: Label
var _coach_panel: Control
var _howto: HowToCard
var _deco: Control
var _fb_t := 0.0                    # seconds left showing the result of the last shot
var _fb_text := ""
var _pinged := false
var _last_sec := -1
## The first time through there is a free practice shot with no clock. It is remembered for the session.
static var _practiced := false
var _practice := false
var _streak := 0
var _goal_panel: Control
var _goal: Label
var _tag_choice := {}               # lens -> "where" | "texture"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The scene lives in its own viewport, so a photo is a clean crop of it (no buttons in the picture).
	sub = SubViewport.new()
	sub.size = Vector2i(1920, 1080)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	bg = TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(2700, 1520)
	bg.position = Vector2(-300, -220)
	if not _is_crater():
		bg.texture = NASA_VIEW
		bg.size = NASA_VIEW.get_size() * NASA_SCALE
	sub.add_child(bg)
	world = Control.new()
	world.size = Vector2(1920, 1080)
	world.draw.connect(_draw_world)
	sub.add_child(world)

	_view = TextureRect.new()
	_view.texture = sub.get_texture()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	_finder = Control.new()
	_finder.size = Vector2(1920, 1080)      # drawn in the same 1920 by 1080 space as the scene, then scaled to fit
	_finder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finder.draw.connect(_draw_finder)
	add_child(_finder)
	resized.connect(_fit_finder)
	_fit_finder.call_deferred()

	_show_brief()


# ---------------------------------------------------------------- the simulated world

func _target_at(t: float) -> Vector2:
	return Vector2(1780.0 - t * 38.0, 470.0 + sin(t * 0.8) * 70.0)


func _is_crater() -> bool:
	return String(target.get("kind", "")) == "crater"


func _light() -> float:
	if _is_crater():
		return float(sun.get("elev", 0.5))           # the planned pass: it does not change during the window
	return 0.5 + 0.5 * sin(_t * 0.75 + 0.6)      # 0 = low sun, 1 = high sun


func _draw_world() -> void:
	var tp := _target_at(_t)
	if _is_crater():
		_draw_crater(tp)
		return
	if true:
		return                                   # Orientale is NASA's real picture: nothing is drawn over it
	# Two look-alike craters with a single ring
	for off in [Vector2(-640, 170), Vector2(-260, -190)]:
		var p: Vector2 = tp + off
		world.draw_arc(p, 54.0, 0, TAU, 40, Color(1, 1, 1, 0.32), 3.0, true)
	# The basin: three rings
	for r in [96.0, 62.0, 30.0]:
		world.draw_arc(tp, r, 0, TAU, 56, Color(1, 1, 1, 0.5), 4.0, true)
		world.draw_arc(tp, r + 5.0, 0, TAU, 56, Color(0, 0, 0, 0.2), 6.0, true)


## A crater as the camera sees it under the planned Sun. REAL rule (LROC Sun Angles): low Sun casts shadows that show
## relief; high Sun leaves no shadows, so bright rays stand out. How strong each looks here is a game picture.
func _draw_crater(tp: Vector2) -> void:
	var info: Dictionary = CraterScience.CRATERS.get(crater_id, CraterScience.CRATERS["glushko"])
	var r := 70.0 * float(info["size"])
	var elev := float(sun.get("elev", 0.5))
	var dir := int(sun.get("dir", 0))
	var ray_vis := clampf((elev - 0.3) / 0.6, 0.0, 1.0)
	var shadow_vis := clampf(1.0 - (elev - 0.3) / 0.4, 0.0, 1.0)
	# Rays: bright streaks thrown out from the crater
	for k in 18:
		var ang := float(k) * TAU / 18.0 + sin(float(k) * 1.7) * 0.12
		var len := r * (1.6 + float(info["ray_len"]) * (1.2 + 2.2 * fmod(float(k) * 0.618, 1.0)))
		var dirv := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dirv.y, dirv.x)
		var a := 0.10 + 0.62 * ray_vis
		world.draw_colored_polygon(PackedVector2Array([tp + dirv * r * 1.05 + side * 7.0, tp + dirv * r * 1.05 - side * 7.0, tp + dirv * len]), Color(1, 1, 1, a))
	# Bowl and rim
	world.draw_circle(tp, r, Color(0, 0, 0, 0.1))
	world.draw_arc(tp, r, 0, TAU, 56, Color(1, 1, 1, 0.55 + 0.25 * ray_vis), 5.0, true)
	world.draw_arc(tp, r + 6.0, 0, TAU, 56, Color(0, 0, 0, 0.18), 6.0, true)
	world.draw_circle(tp, 7.0, Color(1, 1, 1, 0.5))             # central peak
	# Shadow on the side facing the Sun: the near rim blocks the light. None when the Sun is high.
	if shadow_vis > 0.02 and dir != 0:
		var off := r * 0.9 * shadow_vis
		var m := 1.0 if dir == -1 else -1.0
		var pts := PackedVector2Array()
		var a_i := acos(clampf(off * 0.5 / r, -1.0, 1.0))
		for k in 17:
			var a := a_i + (TAU - 2.0 * a_i) * float(k) / 16.0
			pts.append(tp + Vector2(m * cos(a) * r, sin(a) * r))
		var b_i := acos(clampf(-off * 0.5 / r, -1.0, 1.0))
		for k in 17:
			var b := (TAU - b_i) - (TAU - 2.0 * b_i) * float(k) / 16.0
			pts.append(tp + Vector2(m * (off + cos(b) * r), sin(b) * r))
		world.draw_colored_polygon(pts, Color(0, 0, 0, 0.5 * shadow_vis))
	# Look-alike craters with no rays, to frame past
	for off2 in [Vector2(-640, 170), Vector2(-300, -200)]:
		world.draw_arc(tp + off2, 40.0, 0, TAU, 40, Color(1, 1, 1, 0.3), 3.0, true)


func _draw_finder() -> void:
	if _phase != "shoot":
		return
	var fr: Vector2 = FRAME[_lens]
	var c := _aim_with_shake()
	var col := UiStyle.PHOSPHOR
	var r := Rect2(c - fr * 0.5, fr)
	var arm := 34.0
	for sx in [0, 1]:
		for sy in [0, 1]:
			var corner := Vector2(r.position.x + sx * r.size.x, r.position.y + sy * r.size.y)
			var dx := 1.0 if sx == 0 else -1.0
			var dy := 1.0 if sy == 0 else -1.0
			_finder.draw_line(corner, corner + Vector2(dx * arm, 0), col, 4.0)
			_finder.draw_line(corner, corner + Vector2(0, dy * arm), col, 4.0)
	_finder.draw_line(c + Vector2(-18, 0), c + Vector2(18, 0), Color(col, 0.9), 2.0)
	_finder.draw_line(c + Vector2(0, -18), c + Vector2(0, 18), Color(col, 0.9), 2.0)
	_finder.draw_arc(c, 8.0, 0, TAU, 20, Color(col, 0.9), 2.0, true)
	# Steadiness ring: always there (faint) so you know to hold; it closes in as you hold, then flashes when perfect
	var pulse := Time.get_ticks_msec() / 1000.0
	if _holding:
		var closed := _steady >= 0.999
		_finder.draw_arc(c, 60.0 - 34.0 * _steady, 0, TAU, 40, Color(Color.WHITE if closed else col, 0.35 + 0.6 * _steady), 3.0 + (3.0 if closed else 0.0), true)
		if closed:
			_finder.draw_arc(c, 40.0 + 10.0 * sin(pulse * 12.0), 0, TAU, 40, Color(col, 0.55), 2.0, true)
	else:
		_finder.draw_arc(c, 60.0, 0, TAU, 40, Color(col, 0.16), 2.0, true)
	# Guides (drawn here, not in the world, so they never end up in the photo)
	var tp := _target_at(_t)
	if _lens_light() >= 0.7:
		_finder.draw_arc(tp, 118.0 + sin(pulse * 4.0) * 6.0, 0, TAU, 48, Color(col, 0.28), 3.0, true)
	if not _practice:
		for k in range(1, 8):
			_finder.draw_circle(_target_at(_t + k * 0.9), 3.5, Color(1, 1, 1, maxf(0.22 - k * 0.025, 0.03)))
	elif (tp - c).length() > fr.y * 0.6:
		var dir := (tp - c).normalized()
		var a0 := c + dir * 110.0
		var a1 := c + dir * 190.0
		_finder.draw_line(a0, a1, UiStyle.AMBER, 5.0)
		_finder.draw_line(a1, a1 - dir.rotated(0.5) * 24.0, UiStyle.AMBER, 5.0)
		_finder.draw_line(a1, a1 - dir.rotated(-0.5) * 24.0, UiStyle.AMBER, 5.0)
	if _flash > 0.0:
		_finder.draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(1, 1, 1, _flash))


func _max_shots() -> int:
	return int(perks.get("tries", 2))


func _lens_light() -> float:
	if _is_crater():
		return 1.0                                   # the light was chosen when the pass was planned
	return _light() if _lens == "wide" else 1.0 - _light()


func _draw_sun() -> void:
	var b := _sun_bar
	var w := b.size.x
	var h := 14.0
	for i in 40:
		var f := float(i) / 39.0
		b.draw_rect(Rect2(f * (w - w / 40.0), 4, w / 40.0 + 1.0, h), Color(0.12, 0.16, 0.4).lerp(Color(1.0, 0.92, 0.62), f))
	# The good zone for the lens now selected (the crater contract plans its Sun beforehand, so there is no zone)
	if not _is_crater():
		var z0 := 0.62 if _lens == "wide" else 0.0
		var z1 := 1.0 if _lens == "wide" else 0.38
		b.draw_rect(Rect2(z0 * w, 1, (z1 - z0) * w, h + 6), Color(UiStyle.PHOSPHOR, 0.9), false, 3.0)
	var x := _light() * w
	b.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, 28), Vector2(x + 8, 28), Vector2(x, 14)]), Color.WHITE)


func _coach_update() -> void:
	if _coach == null:
		return
	var good := _lens_light()
	if _is_crater():
		_sun_label.text = "PLANNED PASS: %s" % String(sun.get("text", "")).to_upper()
		_sun_label.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
	else:
		_sun_label.text = ("LIGHT IS GOOD FOR %s" % LENS_NAME[_lens]) if good >= 0.7 else ("LIGHT IS POOR FOR %s  -  WAIT" % LENS_NAME[_lens])
		_sun_label.add_theme_color_override("font_color", UiStyle.PHOSPHOR if good >= 0.7 else UiStyle.AMBER)
	_sun_bar.queue_redraw()
	if _fb_t > 0.0:
		_coach.text = _fb_text
		_coach.add_theme_color_override("font_color", UiStyle.NEAR_WHITE)
		(_coach_panel as CoachPanel).set_steps(["AIM", "HOLD", "RELEASE"], -1)
		return
	var fr: Vector2 = FRAME[_lens]
	var on_target := _aim.distance_to(_target_at(_t)) < fr.y * 0.5 * 0.7
	var msg := ""
	var col := UiStyle.PHOSPHOR
	if _holding:
		if not on_target:
			msg = "KEEP THE FRAME ON THE %s" % String(target["noun"]).to_upper()
			col = UiStyle.AMBER
		elif _steady < 0.85:
			msg = "STEADYING...  keep the frame on the %s" % target["noun"]
		else:
			msg = "3   RELEASE NOW to take the photo" if good >= 0.7 else "STEADY.  The light is poor. Release anyway, or wait."
	elif not on_target:
		msg = "1   MOVE THE MOUSE so the frame covers the %s" % target["desc"]
	elif good < 0.55:
		msg = "Basin framed, but the light is poor for %s. Wait for it, or switch lens (1 / 2)." % LENS_NAME[_lens]
		col = UiStyle.AMBER
	else:
		msg = "2   HOLD SPACE or the left button to steady the camera"
	_coach.text = ("PRACTICE   " + msg) if _practice else msg
	_coach.add_theme_color_override("font_color", col)
	var step := 0
	if on_target:
		step = 1
	if _holding and on_target and _steady >= 0.85:
		step = 2
	(_coach_panel as CoachPanel).set_steps(["AIM", "HOLD", "RELEASE"], step)


func _amp() -> float:
	var base := (8.0 + _t * 0.55) * PlayerData.difficulty_factor("shake")
	return base * (1.0 if _lens == "wide" else 1.8) * float(perks.get("shake", 1.0))


func _effective_shake() -> float:
	return _amp() * lerpf(1.0, 0.12, ease(_steady, 0.6))


func _aim_with_shake() -> Vector2:
	var a := _effective_shake()
	var tt := Time.get_ticks_msec() / 1000.0
	return _aim + Vector2(sin(tt * 13.1) + sin(tt * 7.3) * 0.7, cos(tt * 11.7) + cos(tt * 5.9) * 0.7) * a * 0.55


# ---------------------------------------------------------------- phases

func _clear_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null


func _show_brief() -> void:
	_phase = "brief"
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = center
	# Y2K decoration pack from the team Drive, beside the panel (never over it, never clickable)
	_deco = Decor.frame_layer(self, center)
	pass
	pass
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(980, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(30, 0.94))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	col.add_child(UiStyle.mono_label("04  PHOTO", 15, UiStyle.PHOSPHOR))
	col.add_child(UiStyle.heading("OBSERVATION WINDOW"))
	if not _is_crater():
		var look := HBoxContainer.new()
		look.add_theme_constant_override("separation", 16)
		var pic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = NASA_VIEW
		at.region = Rect2(BASIN_AT - Vector2(110, 110), Vector2(220, 220))
		pic.texture = at
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(130, 130)
		look.add_child(pic)
		var lv := VBoxContainer.new()
		lv.add_child(UiStyle.mono_label("WHAT YOU ARE LOOKING FOR", 14, UiStyle.AMBER))
		var ll := Label.new()
		ll.text = "Orientale Basin: a dark, smooth centre with bright rings around it. Find it as the Moon drifts past."
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.add_theme_font_size_override("font_size", 19)
		ll.custom_minimum_size = Vector2(760, 0)
		lv.add_child(ll)
		look.add_child(lv)
		col.add_child(look)
	var goal := Label.new()
	goal.text = ("Photograph %s yourself. Three steps." % String(CraterScience.CRATERS.get(crater_id, {}).get("name", "the crater"))) if _is_crater() else "You take the photo yourself. Three steps."
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.add_theme_font_size_override("font_size", 21)
	col.add_child(goal)
	for line in [
		["1  AIM", "Move the mouse. Put the frame over the %s as it drifts across." % (target["desc"] if not _is_crater() else "crater")],
		["2  HOLD", "Hold SPACE or the left button. The ring tightens as the camera steadies."],
		["3  RELEASE", "Let go to take the photo. Do it while the light is right."],
		["LENS", "One lens does this job. You have %d tries and the best shot is kept." % _max_shots() if _is_crater() else "WIDE (key 1) shows WHERE the %s is. CLOSE-UP (key 2) shows WHAT THE SURFACE IS LIKE. %d tries each." % [target["noun"], _max_shots()]],
		["LIGHT", ("The Sun pass you planned is fixed: %s. Low Sun shows shadows and shape. High Sun shows bright rays." % String(sun.get("text", "")).to_lower()) if _is_crater() else "Watch the sun gauge. Wide wants high sun. Close-up wants low sun, when shadows show texture."],
		["YOUR SHIP", ShipData.perk_summary(perks, "photo")],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var tag := UiStyle.mono_label(line[0], 14, UiStyle.PHOSPHOR)
		tag.custom_minimum_size = Vector2(130, 0)
		row.add_child(tag)
		var l := Label.new()
		l.text = line[1]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.9))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		col.add_child(row)
	var note := UiStyle.mono_label("REAL: the view is NASA's far-side picture from the Artemis II flyby (credit NASA). Aim, steadiness and light scores are the game's." if not _is_crater() else "SIMULATED view, not NASA imagery. Low and high Sun follow the real Sun-angle rule; the look is a game picture.", 13, Color(UiStyle.NEAR_WHITE, 0.55))
	col.add_child(note)
	var go := Button.new()
	go.text = "OPEN THE WINDOW"
	go.theme_type_variation = &"PrimaryButton"
	go.add_theme_font_size_override("font_size", 28)
	go.custom_minimum_size = Vector2(430, 100)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.pressed.connect(_start_shoot)
	go.focus_mode = Control.FOCUS_NONE   # click only: SPACE is the hold key, so it must not dismiss the instructions
	col.add_child(go)


func _start_shoot() -> void:
	_clear_panel()
	if _deco != null:
		_deco.queue_free()
		_deco = null
	_phase = "shoot"
	Sfx.play("stage")
	_lens = "wide" if has_lens["wide"] else "close"
	_practice = not PhotoGame._practiced and not _is_crater()
	# Practice: the basin stands still in good light, so the first try is only about learning the three steps
	_t = (1.0 if _lens == "wide" else 4.2) if _practice else 0.0
	_build_hud()


func _build_hud() -> void:
	var p := PanelContainer.new()
	p.position = Vector2(90, 110)
	p.custom_minimum_size = Vector2(420, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(16, 0.86))
	add_child(p)
	_panel = p
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	p.add_child(col)
	col.add_child(UiStyle.mono_label("OBSERVATION WINDOW", 15, UiStyle.PHOSPHOR))
	_time_bar = UiStyle.mono_label("", 18, UiStyle.NEAR_WHITE)
	col.add_child(_time_bar)
	col.add_child(UiStyle.mono_label("LENS", 13, Color(UiStyle.NEAR_WHITE, 0.6)))
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 10)
	for k in ["wide", "close"]:
		var b := Button.new()
		b.theme_type_variation = &"OutlineButton"
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 17)
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _pick_lens(k))
		lr.add_child(b)
		_lens_btns[k] = b
	col.add_child(lr)
	col.add_child(UiStyle.mono_label("SUN HEIGHT", 13, Color(UiStyle.NEAR_WHITE, 0.6)))
	_sun_bar = Control.new()
	_sun_bar.custom_minimum_size = Vector2(0, 30)
	_sun_bar.draw.connect(_draw_sun)
	col.add_child(_sun_bar)
	_sun_label = UiStyle.mono_label("", 14, UiStyle.NEAR_WHITE)
	col.add_child(_sun_label)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.8))
	_hint.custom_minimum_size = Vector2(0, 50)
	col.add_child(_hint)
	# Stop early: keep what you have and go on (for example to send a good wide shot now)
	_done_btn = Button.new()
	_done_btn.text = "DONE TAKING PHOTOS"
	_done_btn.theme_type_variation = &"OutlineButton"
	_done_btn.add_theme_font_size_override("font_size", 16)
	_done_btn.custom_minimum_size = Vector2(0, 44)
	_done_btn.focus_mode = Control.FOCUS_NONE
	_done_btn.disabled = true
	_done_btn.pressed.connect(func():
		if not _taking and not _best.is_empty():
			_end_shoot())
	col.add_child(_done_btn)
	_refresh_hud()
	# Live coaching line: always says what to do next
	var cp := CoachPanel.new(1000.0, 24)
	cp.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cp.offset_left = -500.0
	cp.offset_right = 500.0
	cp.offset_top = -190.0
	cp.offset_bottom = -40.0
	add_child(cp)
	_coach = cp.label
	_coach_panel = cp
	cp.set_steps(["AIM", "HOLD", "RELEASE"], 0)
	if not _is_crater():
		var credit := UiStyle.mono_label("REAL VIEW: NASA, Artemis II flyby. Scores are the game's.", 12, Color(UiStyle.NEAR_WHITE, 0.6))
		credit.position = Vector2(90, 1030)
		add_child(credit)
	# The how-to stays up until the player clicks GOT IT
	_howto = HowToCard.new()
	_howto.position = Vector2(90, 450)
	add_child(_howto)
	_howto.setup("HOW TO TAKE THE PHOTO", [
		["1  AIM", "Move the mouse. Put the frame over the %s." % target["desc"]],
		["2  HOLD", "Hold SPACE or the left button until the ring tightens."],
		["3  RELEASE", ("Let go to shoot." if _is_crater() else "Let go to shoot. Do it when the light is good.")],
		["LENS", ("One lens does this job." if _is_crater() else "Press 1 for WIDE or 2 for CLOSE-UP.")],
	])
	# Pinned goal strip: what you are trying to do, and how far along you are
	var gp := PanelContainer.new()
	gp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	gp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	gp.offset_left = -470.0
	gp.offset_right = 470.0
	gp.offset_top = 30.0
	gp.offset_bottom = 84.0
	gp.custom_minimum_size = Vector2(940, 54)
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gp.add_theme_stylebox_override("panel", UiStyle.panel(12, 0.86))
	add_child(gp)
	_goal = UiStyle.mono_label("", 17, UiStyle.NEAR_WHITE)
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gp.add_child(_goal)
	_goal_panel = gp
	_refresh_hud()


func _pick_lens(k: String) -> void:
	if _phase != "shoot" or not has_lens[k] or _attempts[k] >= _max_shots():
		return
	_lens = k
	_refresh_hud()


func _refresh_hud() -> void:
	if _done_btn != null:
		_done_btn.disabled = _best.is_empty()
	for k in _lens_btns:
		var b: Button = _lens_btns[k]
		var left: int = _max_shots() - int(_attempts[k])
		var stars := ""
		if _best.has(k):
			stars = "   " + "*".repeat(int(_best[k]["stars"]))
		b.text = ("%s  x%d%s" % [LENS_NAME[k], left, stars]) if has_lens[k] else ("%s  not fitted" % LENS_NAME[k])
		b.disabled = not has_lens[k] or left <= 0
		b.modulate = Color(1, 1, 1, 1.0) if _lens == k else Color(1, 1, 1, 0.6)
	if _is_crater():
		_hint.text = "Low Sun: shadows show the crater's shape. High Sun: bright rays stand out."
	else:
		_hint.text = "Wide wants HIGH sun: shows where." if _lens == "wide" else "Close-up wants LOW sun: shadows show texture."
	if _goal != null:
		var bits: Array[String] = []
		for k in ["wide", "close"]:
			if has_lens[k]:
				bits.append("%s %s" % [LENS_NAME[k], ("*".repeat(int(_best[k]["stars"]))) if _best.has(k) else "--"])
		if _is_crater():
			_goal.text = "GOAL: a 3-star shot of %s     %s" % [String(CraterScience.CRATERS.get(crater_id, {}).get("name", "the crater")), "    ".join(bits)]
		else:
			_goal.text = "GOAL: a 3-star shot with each lens     " + "    ".join(bits)


func _fit_finder() -> void:
	if _finder != null and size.x > 1.0 and size.y > 1.0:
		_finder.scale = size / Vector2(1920.0, 1080.0)


## The scene is drawn 1920 by 1080 and stretched to this control, so the mouse is turned back into that space.
func _world_point(p: Vector2) -> Vector2:
	if size.x < 1.0 or size.y < 1.0:
		return p
	return p * Vector2(1920.0, 1080.0) / size


## Mouse: aim with movement, shoot with the left button. This control stops mouse events, so they arrive here and not
## in _unhandled_input. Clicks on the HUD panels and buttons are taken by those and never reach this.
func _gui_input(event: InputEvent) -> void:
	if _phase != "shoot":
		return
	if event is InputEventMouseMotion:
		_aim = _world_point(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_aim = _world_point(event.position)
		_set_hold(event.pressed)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != "shoot":
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		_set_hold(event.pressed)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_pick_lens("wide")
		elif event.keycode == KEY_2:
			_pick_lens("close")


func _set_hold(on: bool) -> void:
	if _taking:
		return
	if on and not _holding:
		_holding = true
		_pinged = false
		Sfx.play("tick", -2.0, 0.7)
		_steady = 0.0
	elif not on and _holding:
		_holding = false
		_fire()


func _process(delta: float) -> void:
	if _phase != "shoot":
		return
	if not _practice:
		_t += delta
	if _holding:
		_steady = minf(_steady + delta * 1.25, 1.0)
	else:
		_steady = maxf(_steady - delta * 2.0, 0.0)
	_flash = maxf(0.0, _flash - delta * 3.0)
	if _is_crater():
		bg.position = Vector2(-300 - _t * 14.0, -220)
	else:
		bg.position = _target_at(_t) - BASIN_AT * NASA_SCALE     # the Moon drifts past: the real basin follows the target path
	world.queue_redraw()
	_finder.queue_redraw()
	var left := maxf(WINDOW_SECONDS * PlayerData.difficulty_factor("window") - _t, 0.0)
	if _practice:
		left = WINDOW_SECONDS * PlayerData.difficulty_factor("window")
		_time_bar.text = "PRACTICE SHOT  -  NO CLOCK"
	else:
		_time_bar.text = "WINDOW CLOSES IN  %d s" % int(ceil(left))
	_time_bar.add_theme_color_override("font_color", UiStyle.CORAL if left < 8.0 else UiStyle.NEAR_WHITE)
	_fb_t = maxf(_fb_t - delta, 0.0)
	if _holding and _steady >= 0.999 and not _pinged:
		_pinged = true
		Sfx.play("steady")
	var sec := int(ceil(left))
	if left < 6.0 and sec != _last_sec:
		Sfx.play("tick", -2.0, 1.0 + (6.0 - left) * 0.08)
	_last_sec = sec
	_coach_update()
	if left <= 0.0 and not _taking:
		_end_shoot()


# ---------------------------------------------------------------- taking the photo

func _fire() -> void:
	if _taking or not has_lens[_lens] or _attempts[_lens] >= _max_shots():
		return
	_taking = true
	Sfx.play("shutter")
	var fr: Vector2 = FRAME[_lens]
	var center := _aim_with_shake()
	var tp := _target_at(_t)
	var half := fr.y * 0.5
	var framing := clampf(1.0 - center.distance_to(tp) / (half * 1.1), 0.0, 1.0)
	var sharp := clampf(1.0 - _effective_shake() / _amp(), 0.0, 1.0)
	var light := _lens_light()
	var score := 0.4 * framing + 0.35 * sharp + 0.25 * light
	var stars := 3 if score >= 0.72 else (2 if score >= 0.5 else 1)
	_flash = 0.8
	if _practice:
		_practice_result(framing, sharp, light)
		return
	# A clean crop of exactly what the lens saw
	await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	var rect := Rect2i(Vector2i(center - fr * 0.5), Vector2i(fr)).intersection(Rect2i(0, 0, 1920, 1080))
	var crop := img.get_region(rect) if rect.size.x > 8 and rect.size.y > 8 else img
	var photo := {
		"lens": _lens, "framing": framing, "sharp": sharp, "light": light, "score": score, "stars": stars,
		"met": met_at_start + int(_t), "tex": ImageTexture.create_from_image(crop),
		"confidence": "STRONG" if score >= 0.72 else ("MODERATE" if score >= 0.5 else "TENTATIVE"),
	}
	if _is_crater():
		photo["sun_elev"] = float(sun.get("elev", 0.5))
		photo["sun_dir"] = int(sun.get("dir", 0))
		photo["pass"] = String(sun.get("id", ""))
		photo["crater"] = crater_id
	_attempts[_lens] += 1
	var tip := "Center the dark basin next time."
	var low := framing
	if sharp < low:
		low = sharp
		tip = "Hold longer before you release. The ring tightens."
	if light < low:
		low = light
		tip = "Wide wants high sun. Close-up wants low sun."
	_streak = _streak + 1 if stars == 3 else 0
	var verdict := "Good shot." if score >= 0.72 else tip
	if _streak >= 2:
		verdict += "   STREAK x%d" % _streak
	_fb_text = "%s SHOT  %s    FRAMED %d%% %s   STEADY %d%% %s   LIGHT %d%% %s
%s" % [LENS_NAME[_lens], "*".repeat(stars),
		int(framing * 100.0), "OK" if framing >= 0.8 else "--", int(sharp * 100.0), "OK" if sharp >= 0.8 else "--",
		int(light * 100.0), "OK" if light >= 0.8 else "--", verdict]
	if _is_crater():
		# The Sun was planned beforehand, so there is no light score to show
		_fb_text = _fb_text.replace("   LIGHT %d%% %s" % [int(light * 100.0), "OK" if light >= 0.8 else "--"], "")
	_fb_t = 4.0
	Sfx.play("chime_good" if stars == 3 else ("chime_ok" if stars == 2 else "chime_poor"), -2.0, 1.0 + 0.06 * float(mini(_streak, 4)) if stars == 3 else 1.0)
	_pop_confirm(center, stars)
	if not _best.has(_lens) or float(_best[_lens]["score"]) < score:
		_best[_lens] = photo
	_photo_log.append(photo)
	_taking = false
	# Next lens if this one is used up
	if _attempts[_lens] >= _max_shots():
		var other := "close" if _lens == "wide" else "wide"
		if has_lens[other] and _attempts[other] < _max_shots():
			_lens = other
	_refresh_hud()
	var all_done := true
	for k in ["wide", "close"]:
		if has_lens[k] and _attempts[k] < _max_shots():
			all_done = false
	if all_done:
		_end_shoot()


## The practice shot does not count. It shows the result, then the real window opens.
func _practice_result(framing: float, sharp: float, light: float) -> void:
	_fb_text = "PRACTICE SHOT   FRAMED %d%%   STEADY %d%%   LIGHT %d%%
Now the real window opens. It has a clock, and the target drifts." % [int(framing * 100.0), int(sharp * 100.0), int(light * 100.0)]
	_fb_t = 4.5
	Sfx.play("chime_ok")
	_taking = false
	await get_tree().create_timer(4.2).timeout
	if _phase != "shoot":
		return
	_practice = false
	PhotoGame._practiced = true
	_t = 0.0
	_steady = 0.0
	_fb_t = 0.0
	Sfx.play("stage")


## The "photo taken" mark pops at the frame; a three-star shot also throws sparks.
func _pop_confirm(at: Vector2, stars: int) -> void:
	var t := TextureRect.new()
	t.texture = CONFIRM
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(280, 280)
	t.position = at - t.size * 0.5
	t.pivot_offset = t.size * 0.5
	t.scale = Vector2(0.5, 0.5)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stars < 3:
		t.modulate = Color(1, 1, 1, 0.8) if stars == 2 else Color(1.0, 0.8, 0.5, 0.7)
	add_child(t)
	var tw := create_tween().set_parallel()
	tw.tween_property(t, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 0.0, 0.5).set_delay(0.55)
	tw.chain().tween_callback(t.queue_free)
	if stars == 3:
		var p := CPUParticles2D.new()
		p.position = at
		p.amount = 36
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 0.9
		p.spread = 180.0
		p.initial_velocity_min = 220.0
		p.initial_velocity_max = 520.0
		p.gravity = Vector2.ZERO
		p.damping_min = 160.0
		p.damping_max = 220.0
		p.scale_amount_min = 3.0
		p.scale_amount_max = 6.0
		p.color = UiStyle.PHOSPHOR
		add_child(p)
		p.emitting = true
		get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _end_shoot() -> void:
	if _phase != "shoot":
		return
	_phase = "tag"
	Sfx.play("stage")
	_holding = false
	_finder.queue_redraw()
	_clear_panel()
	if _coach_panel != null:
		_coach_panel.queue_free()
		_coach_panel = null
	if _howto != null:
		_howto.queue_free()
		_howto = null
	if _goal_panel != null:
		_goal_panel.queue_free()
		_goal_panel = null
		_goal = null
	if _best.is_empty():
		finished.emit({"photos": [], "tags_ok": 0})
		return
	if _is_crater():
		var one: Array[Dictionary] = []
		for k in _best:
			one.append(_best[k])
		finished.emit({"photos": one, "tags_ok": 0})
		return
	_show_tag()


# ---------------------------------------------------------------- tagging the evidence

func _show_tag() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	# Sparkles from the Y2K decoration pack flank the evidence panel (beside it, never over it)
	var spark := Decor.frame_layer(_panel)
	pass
	pass
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(28, 0.96))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	col.add_child(UiStyle.mono_label("EVIDENCE", 15, UiStyle.PHOSPHOR))
	col.add_child(UiStyle.heading("TAG YOUR PHOTOS"))
	var q := Label.new()
	q.text = "Which picture shows WHERE the %s is, and which shows WHAT THE SURFACE IS LIKE?" % target["noun"]
	q.add_theme_font_size_override("font_size", 20)
	col.add_child(q)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_tag_choice.clear()
	var tag_btns := {}
	var cont := Button.new()          # made first: the tag buttons below switch it on, and they capture it when they are made
	cont.text = "SEND TO RADIO"
	cont.theme_type_variation = &"PrimaryButton"
	cont.add_theme_font_size_override("font_size", 26)
	cont.custom_minimum_size = Vector2(400, 92)
	cont.disabled = true
	cont.pressed.connect(_finish_tags)
	for k in ["wide", "close"]:
		if not _best.has(k):
			continue
		var ph: Dictionary = _best[k]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiStyle.panel(14, 0.9))
		row.add_child(card)
		var cc := VBoxContainer.new()
		cc.add_theme_constant_override("separation", 6)
		card.add_child(cc)
		var thumb := TextureRect.new()
		thumb.texture = ph["tex"]
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(430, 262)
		cc.add_child(thumb)
		cc.add_child(UiStyle.mono_label("%s   %s" % [LENS_NAME[k], "*".repeat(int(ph["stars"]))], 16, UiStyle.PHOSPHOR))
		for kv in [["GAME CLOCK", "%d min into operations (GAME)" % maxi(int(ph["met"]) - 34, 0)], ["TARGET", ("%s (simulated)" if _is_crater() else "%s (NASA's real view)") % target["name"]], ["VIEW", "From the observation window"], ["SOURCE", "Your ship's camera (game)" if _is_crater() else "A crop of NASA's view, framed by you (game scores)"], ["CONFIDENCE", String(ph["confidence"])]]:
			cc.add_child(UiStyle.mono_label("%-10s %s" % [kv[0], kv[1]], 13, Color(UiStyle.NEAR_WHITE, 0.8)))
		var br := HBoxContainer.new()
		br.add_theme_constant_override("separation", 8)
		for choice in [["where", "SHOWS WHERE"], ["texture", "SHOWS WHAT IT IS LIKE"]]:
			var b := Button.new()
			b.text = choice[1]
			b.theme_type_variation = &"OutlineButton"
			b.add_theme_font_size_override("font_size", 15)
			b.custom_minimum_size = Vector2(0, 44)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.toggle_mode = true
			b.pressed.connect(func():
				_tag_choice[k] = choice[0]
				for other in tag_btns[k]:
					other.button_pressed = (other == b)
				cont.disabled = _tag_choice.size() < _best.size())
			br.add_child(b)
			if not tag_btns.has(k):
				tag_btns[k] = []
			tag_btns[k].append(b)
		cc.add_child(br)

	var foot := HBoxContainer.new()
	var hint := Label.new()
	hint.text = "A wide picture shows where. A close-up shows what the surface is like."
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.7))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	foot.add_child(cont)
	col.add_child(foot)


func _finish_tags() -> void:
	var ok := 0
	var photos: Array[Dictionary] = []
	for k in _best:
		var right := "where" if k == "wide" else "texture"
		var correct: bool = _tag_choice.get(k, "") == right
		if correct:
			ok += 1
		var ph: Dictionary = _best[k].duplicate()
		ph["tag_ok"] = correct
		photos.append(ph)
	_clear_panel()
	finished.emit({"photos": photos, "tags_ok": ok})
