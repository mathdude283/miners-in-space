extends Control
## Fly stage. The ship the player built is simulated through five checks: liftoff, climb, orbit,
## photo, radio. Any problem with the ship ends the flight at the stage it would break, with its own
## animation, and the mission data is lost. A ship with no problems makes it all the way.
##
## Nothing here asks the player to confirm anything: they chose to fly, so the flight just runs.
## The ship is kept, so they can go back, change it and try again.

const BG_PAD: Texture2D = preload("res://assets/ui/flight/bg_launch_pad.png")
const BG_ORBIT: Texture2D = preload("res://assets/ui/select/bg_earth_orbit.png")
const BG_MOON: Texture2D = preload("res://assets/ui/flight/bg_lunar_surface.png")
const TRACKER := preload("res://stage_tracker.gd")
const HUD := preload("res://hud_frame.gd")

@export_file("*.tscn") var back_scene: String = "res://build_screen.tscn"
@export_file("*.tscn") var title_scene: String = "res://title.tscn"

const PAD_Y := 800.0                 # where the ground is, on the 1920 x 1080 frame
const SHIP_HALF := 234.0             # half the ship's length once stood on end
const STAGES := ["LIFTOFF", "CLIMB", "ORBIT", "PHOTO", "RADIO"]

var state: BuildState
var plan: Array[Dictionary] = []

var world: Control
var bg_pad: TextureRect
var bg_orbit: TextureRect
var bg_moon: TextureRect
var ground: Control
var holder: Control
var ship: ShipView
var exhaust: CPUParticles2D
var smoke: CPUParticles2D
var boom: CPUParticles2D
var fx: Control
var flash: ColorRect
var dim: ColorRect
var debris: Control
var clock_label: Label
var banner: Label
var sub_banner: Label
var rows: Array[Label] = []
var skip_button: Button
var result_layer: Control

var _shake := 0.0
var _dot: GradientTexture2D
var _reticle := 0.0                  # 0..1 how closed the camera reticle is
var _reticle_bad := false
var _radio := -1.0                   # radio pulse progress, -1 = off
var _radio_bad := false
var _alarm := 0.0
var _ended := false
var poll_overlay: Control
var count_panel: CountPanel
var range_panel: RangePanel
var abort_button: Button
var role_label: Label
var _action := ""
var _can_abort := true
var mission_id := 0
var boosters: Array[Booster] = []
var crew_hearts: CrewHearts
var _notes: Array[String] = []


func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	state = PlayerData.get_build()
	# Money is the one hard stop: an over-budget ship cannot launch.
	if int(state.totals()["cost"]) > int(ShipData.RULES["budget_limit"]):
		get_tree().change_scene_to_file.call_deferred(back_scene)
		return
	mission_id = PlayerData.current_mission()
	if bool(PlayerData.campaign["locked"]):
		back_scene = "res://mission_select.tscn"      # the ship is locked, so there is nothing to rebuild
	PlayerData.start_run()
	Music.play("launch")
	plan = make_plan(state, mission_id)
	_build()
	_run.call_deferred()


func _exit_tree() -> void:
	Sfx.stop_all_loops()
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(back_scene)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 14.0)
		world.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif world.position != Vector2.ZERO:
		world.position = Vector2.ZERO
	if _alarm > 0.0:
		dim.color = Color(UiStyle.CORAL, 0.28 * absf(sin(Time.get_ticks_msec() / 160.0)) * _alarm)


# =====================================================================
# The plan: which stage the ship would break at, and why
# =====================================================================

## Public and static-free so it can be tested without playing the animation.
static func make_plan(s: BuildState, mission_id := 0) -> Array[Dictionary]:
	var t := s.totals()
	var R := ShipData.RULES
	var have: Dictionary = t["have"]
	var out: Array[Dictionary] = []

	# 1 LIFTOFF: weight
	var liftoff := {"name": "LIFTOFF", "ok": true, "kind": "", "why": ""}
	# (Over budget never gets this far: the Build screen will not launch an over-budget ship.)
	if int(t["mass"]) > int(R["mass_limit"]):
		liftoff = {"name": "LIFTOFF", "ok": false, "kind": "weight",
			"why": "Too heavy: %d against a limit of %d. The engines could not lift it." % [t["mass"], R["mass_limit"]]}
	out.append(liftoff)

	# 2 CLIMB: steering, then power
	var climb := {"name": "CLIMB", "ok": true, "kind": "", "why": ""}
	if not have.has("control"):
		climb = {"name": "CLIMB", "ok": false, "kind": "control",
			"why": "No flight deck. Nobody could steer, and the ship veered off course."}
	elif int(t["margin"]) < 0:
		climb = {"name": "CLIMB", "ok": false, "kind": "power",
			"why": "Not enough power: %d used and %d made. Systems shut down during the climb." % [t["draw"], t["gen"]]}
	out.append(climb)

	# 3 ORBIT: air, then the rest of what a crew needs
	var orbit := {"name": "ORBIT", "ok": true, "kind": "", "why": ""}
	var crew_msgs := {
		"food": "No food. The crew could not keep going.",
		"waste": "No waste handling. The cabin became unusable.",
		"sleep": "No place to sleep. The crew wore out.",
		"medical": "No medical care when a crew member fell ill.",
		"stowage": "Nothing was secured. Loose cargo broke free.",
	}
	if not have.has("air"):
		orbit = {"name": "ORBIT", "ok": false, "kind": "crew", "why": "No air and water system. The crew had to abort."}
	else:
		for f in ["food", "waste", "sleep", "medical", "stowage"]:
			if not have.has(f):
				orbit = {"name": "ORBIT", "ok": false, "kind": "crew", "why": crew_msgs[f]}
				break
	out.append(orbit)

	# 4 PHOTO: a window, then a lens
	var photo := {"name": "PHOTO", "ok": true, "kind": "", "why": ""}
	if not have.has("camera"):
		photo = {"name": "PHOTO", "ok": false, "kind": "photo", "why": "No window. There was no way to see the Moon."}
	elif not (s.wide or s.close):
		photo = {"name": "PHOTO", "ok": false, "kind": "photo", "why": "No lens. The camera could not frame a shot."}
	else:
		# Contract-specific needs (data in missions.gd)
		var needs: Dictionary = Missions.get_mission(mission_id).get("needs", {})
		if String(needs.get("lens", "any")) == "both" and not (s.wide and s.close):
			photo = {"name": "PHOTO", "ok": false, "kind": "photo", "why": "This contract needs both lenses, a wide one and a close-up."}
		elif bool(needs.get("lab", false)) and not s.has_room("science-lab"):
			photo = {"name": "PHOTO", "ok": false, "kind": "photo", "why": "No science lab. The two photos could not be compared."}
	out.append(photo)

	# 5 RADIO
	var radio := {"name": "RADIO", "ok": true, "kind": "", "why": ""}
	if not have.has("comms"):
		radio = {"name": "RADIO", "ok": false, "kind": "radio", "why": "No radio. The data could not be sent home."}
	if mission_id == 2:
		photo["name"] = "WATCH"
		radio["name"] = "SEND"
	out.append(radio)
	for row in out:
		if not row["ok"]:
			row["fix"] = _fix_for(row)
	return out


## What to change on the ship so this does not happen again.
static func _fix_for(row: Dictionary) -> String:
	var why := String(row.get("why", ""))
	match String(row.get("kind", "")):
		"weight":
			return "Take out a room, a lens or a wing until the ship is under the weight limit."
		"control":
			return "Add a Flight Deck: someone has to steer."
		"power":
			return "Add a solar wing, or take out a room that uses power."
		"crew":
			return "Add the crew kit, or the room that covers that need (Life Support, Galley, Crew Quarters, Hygiene Bay, Medical Bay or Cargo Bay)."
		"photo":
			if why.contains("window"):
				return "Add an Observation Bay: it is the window."
			if why.contains("both lenses"):
				return "Pack both the wide lens and the close-up lens."
			if why.contains("science lab"):
				return "Add a Science Lab."
			return "Pack a wide or a close-up lens."
		"radio":
			return "Add a Communications room."
	return ""


static func first_failure(p: Array[Dictionary]) -> int:
	for i in p.size():
		if not p[i]["ok"]:
			return i
	return -1


# =====================================================================
# Building the scene
# =====================================================================

func _build() -> void:
	_dot = GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_dot.gradient = g
	_dot.width = 64
	_dot.height = 64
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)

	world = Control.new()
	world.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)

	# Launch pad scene, enlarged and pushed left so the picture's own rocket is off screen
	bg_pad = _bg(BG_PAD)
	bg_pad.pivot_offset = Vector2(0, 1080)
	bg_pad.scale = Vector2(1.35, 1.35)
	bg_orbit = _bg(BG_ORBIT)
	bg_orbit.modulate.a = 0.0
	bg_moon = _bg(BG_MOON)
	bg_moon.modulate.a = 0.0

	ground = Control.new()
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.draw.connect(_draw_ground)
	world.add_child(ground)

	holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = Vector2(960, PAD_Y - SHIP_HALF)
	world.add_child(holder)

	smoke = _particles(false)
	holder.add_child(smoke)
	exhaust = _particles(true)
	holder.add_child(exhaust)

	# Two solid rocket boosters strapped to the sides, behind the ship. They separate on the way up.
	for side in [-1.0, 1.0]:
		var bst := Booster.new()
		bst.position = Vector2(side * 56.0 - Booster.W * 0.5, SHIP_HALF - 372.0)
		holder.add_child(bst)
		boosters.append(bst)

	ship = ShipView.new()
	ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship.custom_minimum_size = Vector2(1000, 336)
	holder.add_child(ship)
	ship.size = Vector2(1000, 336)
	ship.position = Vector2(-500, -168)
	ship.pivot_offset = Vector2(500, 168)
	ship.rotation = PI / 2.0           # nose up
	ship.scale = Vector2(0.5, 0.5)
	ship.bind(state)
	ship.set_flight_mode()
	exhaust.position = Vector2(0, SHIP_HALF + 2.0)
	smoke.position = Vector2(0, SHIP_HALF + 6.0)

	boom = CPUParticles2D.new()
	boom.texture = _dot
	boom.emitting = false
	boom.one_shot = true
	boom.amount = 180
	boom.lifetime = 1.3
	boom.explosiveness = 1.0
	boom.spread = 180.0
	boom.gravity = Vector2(0, 260)
	boom.initial_velocity_min = 220.0
	boom.initial_velocity_max = 760.0
	boom.scale_amount_min = 0.5
	boom.scale_amount_max = 1.3
	boom.color_ramp = _fire_ramp()
	boom.material = _additive()
	world.add_child(boom)

	debris = Control.new()
	debris.set_anchors_preset(Control.PRESET_FULL_RECT)
	debris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(debris)

	fx = Control.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx)
	world.add_child(fx)

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	_build_hud()


func _bg(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(t)
	return t


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _fire_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 0.98, 0.85, 1), Color(1, 0.75, 0.25, 0.95), Color(0.95, 0.3, 0.1, 0.6), Color(0.3, 0.05, 0.05, 0)])
	return g


func _particles(is_fire: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _dot
	p.emitting = false
	p.local_coords = false
	p.direction = Vector2(0, 1)
	p.gravity = Vector2.ZERO
	if is_fire:
		p.amount = 150
		p.lifetime = 0.75
		p.spread = 9.0
		p.initial_velocity_min = 420.0
		p.initial_velocity_max = 600.0
		p.scale_amount_min = 0.35
		p.scale_amount_max = 0.75
		p.color_ramp = _fire_ramp()
		p.material = _additive()
	else:
		p.amount = 70
		p.lifetime = 2.4
		p.spread = 26.0
		p.initial_velocity_min = 90.0
		p.initial_velocity_max = 220.0
		p.scale_amount_min = 0.9
		p.scale_amount_max = 1.8
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0.75, 0.78, 0.9, 0.38), Color(0.5, 0.52, 0.65, 0.0)])
		p.color_ramp = g
	return p


func _build_hud() -> void:
	var hud := Control.new()
	hud.set_script(HUD)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.set("inset", 28.0)
	hud.set("arm", 46.0)
	hud.set("show_ruler", false)
	add_child(hud)

	var tracker := HBoxContainer.new()
	tracker.set_script(TRACKER)
	tracker.set("active_index", 2)
	tracker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tracker.position = Vector2(-600, 44)
	add_child(tracker)

	# Flight checks: what has passed, what is running, what failed
	var panel := PanelContainer.new()
	panel.position = Vector2(90, 110)
	panel.add_theme_stylebox_override("panel", UiStyle.panel(18, 0.78))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	clock_label = UiStyle.mono_label("T-10:00", 22, UiStyle.PHOSPHOR)
	col.add_child(clock_label)
	role_label = UiStyle.mono_label("", 14, UiStyle.CHROME)
	col.add_child(role_label)
	col.add_child(UiStyle.mono_label("FLIGHT CHECKS", 14, Color(UiStyle.NEAR_WHITE, 0.65)))
	for i in STAGES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_l := UiStyle.mono_label("%02d  %s" % [i + 1, STAGES[i]], 17, UiStyle.NEAR_WHITE)
		name_l.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_l)
		var st := UiStyle.mono_label("WAITING", 16, Color(UiStyle.NEAR_WHITE, 0.45))
		st.custom_minimum_size = Vector2(96, 0)
		row.add_child(st)
		rows.append(st)
		col.add_child(row)

	banner = Label.new()
	banner.add_theme_font_override("font", UiStyle.DISPLAY)
	banner.add_theme_font_size_override("font_size", 56)
	banner.add_theme_color_override("font_color", UiStyle.NEAR_WHITE)
	banner.add_theme_color_override("font_outline_color", Color(UiStyle.MIDNIGHT, 0.9))
	banner.add_theme_constant_override("outline_size", 10)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.offset_top = -210
	banner.offset_bottom = -140
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	sub_banner = UiStyle.mono_label("", 20, Color(UiStyle.NEAR_WHITE, 0.9))
	sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub_banner.anchor_left = 0.0
	sub_banner.anchor_right = 1.0
	sub_banner.offset_top = -136
	sub_banner.offset_bottom = -100
	sub_banner.modulate.a = 0.0
	add_child(sub_banner)

	skip_button = Button.new()
	skip_button.text = "Skip ahead"
	skip_button.theme_type_variation = &"OutlineButton"
	skip_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.position = Vector2(-250, -110)
	skip_button.custom_minimum_size = Vector2(160, 50)
	skip_button.focus_mode = Control.FOCUS_NONE        # SPACE is a game key, so no button may take it
	skip_button.pressed.connect(func():
		Engine.time_scale = 8.0
		skip_button.disabled = true)
	skip_button.hide()
	add_child(skip_button)

	range_panel = RangePanel.new()
	range_panel.position = Vector2(90, 420)
	range_panel.terminate_pressed.connect(func(): _action = "terminate")
	range_panel.hide()
	add_child(range_panel)

	abort_button = Button.new()
	abort_button.text = "CALL ABORT (game)"
	abort_button.theme_type_variation = &"OutlineButton"
	abort_button.add_theme_font_size_override("font_size", 17)
	abort_button.position = Vector2(90, 850)
	abort_button.custom_minimum_size = Vector2(300, 48)
	abort_button.focus_mode = Control.FOCUS_NONE
	abort_button.pressed.connect(func(): _action = "abort")
	abort_button.hide()
	add_child(abort_button)

	# The crew's hearts stay on screen the whole flight
	crew_hearts = CrewHearts.new()
	crew_hearts.run = PlayerData.run
	crew_hearts.anchor_left = 1.0
	crew_hearts.anchor_top = 1.0
	crew_hearts.anchor_right = 1.0
	crew_hearts.anchor_bottom = 1.0
	crew_hearts.offset_left = -400.0
	crew_hearts.offset_right = -40.0
	crew_hearts.offset_top = -420.0
	crew_hearts.offset_bottom = -129.0
	add_child(crew_hearts)
	var alert_layer := CanvasLayer.new()          # above everything, so a pop-up about the crew can never be hidden
	alert_layer.layer = 20
	add_child(alert_layer)
	var alerts := CrewAlerts.new()
	alert_layer.add_child(alerts)
	alerts.setup(PlayerData.run)


# =====================================================================
# Drawing: pad, reticle, radio
# =====================================================================

func _draw_ground() -> void:
	# A plain launch pad: concrete slab, support legs, warm lights.
	var cx := holder.position.x if holder != null else 960.0
	var slab := Rect2(cx - 300, PAD_Y, 600, 34)
	ground.draw_rect(slab, Color(0.16, 0.18, 0.26, 1))
	ground.draw_rect(Rect2(slab.position.x, slab.position.y, slab.size.x, 4), Color(0.45, 0.5, 0.65, 1))
	for i in 7:
		var lx := slab.position.x + 40 + i * 86
		ground.draw_circle(Vector2(lx, PAD_Y + 18), 5.0, Color(1.0, 0.78, 0.4, 1))
		ground.draw_circle(Vector2(lx, PAD_Y + 18), 14.0, Color(1.0, 0.78, 0.4, 0.14))
	for sx in [-250.0, -150.0, 150.0, 250.0]:
		ground.draw_rect(Rect2(cx + sx - 14, PAD_Y + 34, 28, 300), Color(0.1, 0.12, 0.2, 1))
	ground.draw_rect(Rect2(0, PAD_Y + 34, 1920, 400), Color(0.03, 0.04, 0.1, 0.0))


func _draw_fx() -> void:
	# Camera reticle closing in on the Moon
	if _reticle > 0.0:
		var c := Vector2(960, 470)
		var col := UiStyle.CORAL if _reticle_bad else UiStyle.PHOSPHOR
		var r := lerpf(380.0, 120.0, _reticle)
		fx.draw_arc(c, r, 0, TAU, 64, Color(col, 0.9), 3.0, true)
		fx.draw_arc(c, r * 0.55, 0, TAU, 48, Color(col, 0.5), 2.0, true)
		for k in 4:
			var d := Vector2.RIGHT.rotated(k * PI / 2.0)
			fx.draw_line(c + d * (r + 12), c + d * (r + 52), Color(col, 0.9), 3.0)
		var b := lerpf(520.0, 220.0, _reticle)
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var corner := c + Vector2(sx * b, sy * b * 0.62)
				fx.draw_line(corner, corner + Vector2(-sx * 46, 0), Color(col, 0.9), 4.0)
				fx.draw_line(corner, corner + Vector2(0, -sy * 46), Color(col, 0.9), 4.0)
		if _reticle_bad:
			fx.draw_line(c + Vector2(-60, -60), c + Vector2(60, 60), UiStyle.CORAL, 6.0)
			fx.draw_line(c + Vector2(60, -60), c + Vector2(-60, 60), UiStyle.CORAL, 6.0)
	# Radio pulses leaving the ship
	if _radio >= 0.0:
		var origin := Vector2(900, 560)
		var col2 := UiStyle.CORAL if _radio_bad else UiStyle.PHOSPHOR
		for i in 4:
			var t := fposmod(_radio * 1.6 - i * 0.25, 1.0)
			var rad := 80.0 + t * 900.0
			var a := (1.0 - t) * (0.25 if _radio_bad and t > 0.35 else 0.85)
			fx.draw_arc(origin, rad, -0.7, 0.7, 48, Color(col2, a), 5.0, true)
		if _radio_bad:
			fx.draw_line(origin + Vector2(360, -50), origin + Vector2(460, 50), UiStyle.CORAL, 8.0)
			fx.draw_line(origin + Vector2(460, -50), origin + Vector2(360, 50), UiStyle.CORAL, 8.0)


# =====================================================================
# The flight
# =====================================================================

func _run() -> void:
	await _wait(0.5)
	role_label.text = "YOU: LAUNCH DIRECTOR"
	_say("LAUNCH CONTROL CENTER", "Firing Room 1", UiStyle.NEAR_WHITE)
	var choice := await _final_poll()
	if choice == "scrub":
		PlayerData.scrub_note = "Count stopped before launch. The ship is safe and nothing was lost. Fix the no-goes and try again."
		_leave_to(back_scene)
		return
	var cr := await _terminal_count()
	if cr == "scrub":
		PlayerData.scrub_note = "The count was scrubbed. Nothing was lost."
		_leave_to(back_scene)
		return
	await _handoff()
	var out := await _ascent()
	if out.is_empty():
		var shots: Dictionary = {}
		var sent: Dictionary = {}
		var ops: Dictionary = {}
		for i in range(2, plan.size()):
			_set_row(i, "RUNNING")
			match i:
				2:
					skip_button.show()
					await _orbit(plan[i])
					skip_button.hide()
				3:
					if plan[i]["ok"]:
						await _phase_transitions()
						# The player walks the ship and does the photo and the send themselves
						if mission_id == 2:
							ops = await _impact_phase()
						else:
							ops = await _ops_phase()
						shots = ops.get("shots", {})
					else:
						skip_button.show()
						await _photo(plan[i])
						skip_button.hide()
				4:
					if plan[i]["ok"]:
						sent = ops.get("sent", {})
					else:
						await _radio_stage(plan[i])
			if not plan[i]["ok"]:
				_set_row(i, "FAILED")
				await _finish({"kind": "failed", "stage": plan[i]["name"], "why": plan[i]["why"], "fix": plan[i].get("fix", "")})
				return
			if i == 3 and PlayerData.run.alive_count() == 0:
				_set_row(i, "FAILED")
				_note("The whole crew was lost.")
				await _finish({"kind": "failed", "stage": "CREW", "why": "The whole crew was lost during operations. See below for how each person died.", "fix": "Watch the crew list: rest and feed people before their energy runs out."})
				return
			if i == 3 and bool(ops.get("science", {}).get("crater", false)):
				var why3 := _crater_failure(ops)
				if not why3.is_empty():
					_set_row(i, "FAILED")
					_note(String(why3["why"]))
					await _finish({"kind": "failed", "stage": "SCIENCE", "why": why3["why"], "fix": why3["fix"]})
					return
			if i == 3 and mission_id != 2 and shots.get("photos", []).is_empty():
				_set_row(i, "FAILED")
				_note("The window closed before you took a photo.")
				await _finish({"kind": "failed", "stage": "PHOTO", "why": "No photo was taken" + (" because operations ran out of time." if ops.get("time_out", false) else " before operations ended."), "fix": "Go to the Observation Bay early and take the photo: aim, hold SPACE, release. Walking and jobs use up the minutes."})
				return
			if i == 4 and bool(ops.get("science", {}).get("crater", false)) and sent.get("received", []).size() < shots.get("photos", []).size():
				_set_row(i, "FAILED")
				_note("Not every photo reached Earth.")
				await _finish({"kind": "failed", "stage": "RADIO", "why": "Only %d of %d photos reached Earth%s. A comparison needs both photos, so the finding was lost." % [sent.get("received", []).size(), shots.get("photos", []).size(), " because operations ran out of time" if ops.get("time_out", false) else ": the downlink window closed first"], "fix": "Leave enough minutes to send both photos, and keep the beam on Earth until each bar fills."})
				return
			if i == 4 and mission_id != 2 and sent.get("received", []).is_empty():
				_set_row(i, "FAILED")
				_note("No photo finished sending before the downlink window closed.")
				await _finish({"kind": "failed", "stage": "RADIO", "why": "No photo reached Earth" + (" because operations ran out of time." if ops.get("time_out", false) else ": the downlink was not finished.") + " Mission data is lost if it never gets home.", "fix": "Send the photos from the Communications room, and keep the beam on Earth until each bar fills."})
				return
			_set_row(i, "OK")
		out = {"kind": "success", "evidence": _evidence_text(shots, sent)}
		PlayerData.evidence = _evidence_list(shots, sent)
		PlayerData.run.evidence = PlayerData.evidence.duplicate()
		PlayerData.run.science = ops.get("science", {})
		PlayerData.run.fault = ops.get("fault", {})
		if mission_id == 2:
			out = _impact_outcome(ops)
		elif not bool(ops.get("science", {}).get("crater", false)):
			# Four separate outcomes per shot (captured, tagged, received, meets criteria); the contract needs every needed shot to meet them
			var rows := EvidenceCheck.rows(shots.get("photos", []), sent.get("received", []), state.wide, state.close)
			PlayerData.evidence = rows
			PlayerData.run.evidence = rows.duplicate(true)
			var sm := EvidenceCheck.summary(rows)
			out["evidence"] = _evidence_text(shots, sent)
			if not bool(sm["complete"]):
				var why := String(sm["why"])
				if bool(ops.get("fault", {}).get("happened", false)):
					why += " The camera fault cost you the close-up%s." % ((": " + String(ops["fault"].get("lost_reason", ""))) if String(ops["fault"].get("lost_reason", "")) != "" else "")
				out = {"kind": "partial", "evidence": out["evidence"], "why": why, "fix": sm["fix"], "missing": []}
				PlayerData.run.partial = true
		# The way home: separation, entry angle, re-entry, parachutes, splashdown
		var ret := await _return_phase()
		PlayerData.run.landing = ret
		if not bool(ret.get("landed", true)):
			out = {"kind": "failed", "stage": "LANDING", "why": "Everyone aboard was lost on the way home. See below for how each person died.", "fix": "Set the entry angle in the green, hold to keep the load under the limit, and open the parachutes inside their bands. Treat injured crew in a Medical Bay before the return."}
	await _finish(out)


## Contract 03: the flyer watches and logs, chooses what to send within the packet budget, then plays Mission Control on what arrived.
func _impact_phase() -> Dictionary:
	Music.play("orbit")
	banner.modulate.a = 0.0
	sub_banner.modulate.a = 0.0
	Engine.time_scale = 1.0
	var w := ImpactWatch.new()
	w.state = state
	w.crew = PlayerData.run.crew
	add_child(w)
	var sent: Dictionary = await w.finished
	w.queue_free()
	var im := {"sent": false, "complete": false, "budget": int(sent.get("budget", ImpactWatch.packets(state))), "sent_cost": int(sent.get("sent_cost", 0))}
	if not bool(sent.get("ok", false)):
		_note("Nothing was sent to Mission Control.")
		return {"impact": im}
	im["sent"] = true
	im["delivered"] = sent["delivered"]
	im["case_id"] = String(sent["case"]["case_id"])
	var mc := ImpactControl.new()
	mc.case = sent["case"]
	mc.map = sent["map"]
	mc.budget = int(sent["budget"])
	mc.sent_cost = int(sent["sent_cost"])
	add_child(mc)
	var rv: Dictionary = await mc.finished
	mc.queue_free()
	im["complete"] = bool(rv.get("complete", false))
	im["eval"] = rv.get("eval", {})
	im["reveal"] = rv.get("reveal", {})
	im["verdicts"] = rv.get("verdicts", {})
	return {"impact": im}


func _impact_outcome(ops: Dictionary) -> Dictionary:
	var im: Dictionary = ops.get("impact", {})
	PlayerData.run.impact = im
	PlayerData.evidence = []
	PlayerData.run.evidence = []
	var text := "%d of %d packets sent." % [int(im.get("sent_cost", 0)), int(im.get("budget", 0))]
	if bool(im.get("complete", false)):
		return {"kind": "success", "evidence": text + " Every verdict was justified by what arrived."}
	PlayerData.run.partial = true
	var why := "Nothing reached Mission Control, so there was nothing to review." if not bool(im.get("sent", false)) else "Mission Control could not justify every verdict from what arrived. %d verdict%s not justified." % [int(im.get("eval", {}).get("unjustified", 0)), "" if int(im.get("eval", {}).get("unjustified", 0)) == 1 else "s"]
	var fix := "Log what you see in more than one window, and send the wide frame for any spot that might be a reflection." if not bool(im.get("sent", false)) else String(im.get("reveal", {}).get("lesson", ""))
	return {"kind": "partial", "evidence": text, "why": why, "fix": fix, "missing": []}


func _leave_to(path: String) -> void:
	Engine.time_scale = 1.0
	var tw := create_tween()
	tw.tween_property(dim, "color", Color(0.01, 0.02, 0.07, 1.0), 0.5)
	await tw.finished
	get_tree().change_scene_to_file(path)


func _note(text: String) -> void:
	_notes.append(text)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _set_row(i: int, status: String) -> void:
	var l := rows[i]
	l.text = status
	match status:
		"RUNNING":
			l.add_theme_color_override("font_color", UiStyle.NEAR_WHITE)
		"OK":
			l.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
		"FAILED":
			l.add_theme_color_override("font_color", UiStyle.CORAL)
		"ABORTED", "TERMINATED":
			l.add_theme_color_override("font_color", UiStyle.AMBER)


func _say(text: String, sub := "", color: Color = UiStyle.NEAR_WHITE) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	sub_banner.text = sub
	var tw := create_tween().set_parallel()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_property(sub_banner, "modulate:a", 1.0 if sub != "" else 0.0, 0.25)


func _start_burn() -> void:
	exhaust.emitting = true
	smoke.emitting = true
	_shake = 5.0
	Sfx.loop_start("rumble", -2.0)


func _stop_burn() -> void:
	exhaust.emitting = false
	smoke.emitting = false
	Sfx.loop_stop("rumble", 1.2)


func _tick_clock(from_t: float, to_t: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): clock_label.text = "T+%02d" % int(v), from_t, to_t, dur)


# ---------------- launch control: the final poll and the terminal count ----------------
func _final_poll() -> String:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	dim.color = Color(0.01, 0.02, 0.07, 0.45)
	var panel := PollPanel.new()
	center.add_child(panel)
	panel.setup("launch", "FINAL POLL", "LAUNCH CONTROL CENTER  -  FIRING ROOM 1", GroundControl.stations(state, true))
	var choice: String = await panel.decided
	var rows_now: Array[Dictionary] = panel._rows
	var bad := GroundControl.ship_no_gos(rows_now)
	if panel.did_hold:
		_note("The Eastern Range held the count for a flight termination system test. A range no-go cannot be overridden, and you held.")
	if choice == "override":
		var names: Array[String] = []
		for r in bad:
			names.append(String(r["name"]).capitalize())
		_note("You launched with %d no-go%s on the ship (%s)." % [bad.size(), "" if bad.size() == 1 else "s", ", ".join(names)])
	elif choice == "go":
		_note("The final poll was all go, and you made the call.")
	else:
		_note("You scrubbed the count.")
	layer.queue_free()
	dim.color = Color(0, 0, 0, 0)
	return choice


func _terminal_count() -> String:
	count_panel = CountPanel.new()
	count_panel.position = Vector2(1250, 110)
	add_child(count_panel)
	count_panel.milestone.connect(_on_count_milestone)
	count_panel.clock_changed.connect(func(t): clock_label.text = t)      # one countdown, shown in both places
	var r: String = await count_panel.run()
	count_panel.queue_free()
	return r


func _on_count_milestone(i: int) -> void:
	Sfx.play("beep_hi" if i == GroundControl.COUNT.size() - 1 else "beep")
	if i == 10:
		_start_burn()          # the main engines start about 6 seconds before liftoff


func _handoff() -> void:
	clock_label.text = "MET +0:00"
	role_label.text = "YOU: FLIGHT DIRECTOR (HOUSTON)"
	_say("LIFTOFF", "Control passes from Launch Control to Mission Control in Houston", UiStyle.PHOSPHOR)
	_note("Liftoff. Control passed to the flight team in Houston, as it does after the boosters ignite.")
	range_panel.show()
	abort_button.show()
	_start_burn()
	for bst in boosters:
		bst.burning = true
	Sfx.play("whoosh")
	Sfx.loop_level("rumble", 3.0, 1.0)
	await _wait(1.8)


# ---------------- ascent: the flight team watches, polls and decides ----------------
func _met_text(met: float) -> String:
	return "MET +%d:%02d" % [int(met) / 60, int(met) % 60]


func _update_range(met: float, kind: String) -> void:
	var dev := sin(met * 0.4) * 0.05
	var status := "IN CORRIDOR"
	if kind == "control" and met > 40.0:
		dev = clampf((met - 40.0) / 60.0, 0.0, 1.4)
		if dev > 0.476:
			status = "OUTSIDE CORRIDOR"
		elif dev > 0.2:
			status = "ERRATIC"
	elif kind == "power" and met > 60.0:
		status = "NO DATA"
	range_panel.set_state(status, dev, pow(met / 498.0, 0.6))


## One stretch of the climb. Returns "" when it ran to the end, or the player's action.
func _segment(met_from: float, met_to: float, dur: float, y_to: float, kind: String, extra: Callable) -> String:
	_action = ""
	var tw := create_tween().set_parallel()
	tw.tween_property(holder, "position:y", y_to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if extra.is_valid():
		extra.call(tw, dur)
	var elapsed := 0.0
	var fired := {}
	while elapsed < dur:
		await get_tree().process_frame
		if _action != "":
			tw.kill()
			return _action
		elapsed += get_process_delta_time()
		var met := lerpf(met_from, met_to, minf(elapsed / dur, 1.0))
		clock_label.text = _met_text(met)
		_update_range(met, kind)
		for m in GroundControl.ASCENT:
			if not m["poll"] and float(m["met"]) > met_from and float(m["met"]) <= met and not fired.has(m["label"]):
				fired[m["label"]] = true
				_say(String(m["name"]), String(m["text"]), UiStyle.NEAR_WHITE)
				if String(m["label"]) == "+0:09":
					_set_row(0, "OK")
					_set_row(1, "RUNNING")
	return ""


func _ascent() -> Dictionary:
	_set_row(0, "RUNNING")
	if not plan[0]["ok"]:
		await _liftoff_weight()
		_set_row(0, "FAILED")
		return {"kind": "failed", "stage": "LIFTOFF", "why": plan[0]["why"], "fix": plan[0].get("fix", "")}

	var kind: String = "" if plan[1]["ok"] else String(plan[1]["kind"])
	_shake = 7.0

	# Liftoff to maximum dynamic pressure
	var act: String = await _segment(0.0, 70.0, 6.0, 380.0, kind, func(tw: Tween, dur: float):
		tw.tween_property(ground, "position:y", 420.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(bg_pad, "position:y", 140.0, dur))
	if act != "":
		return await _handle_action(act)
	_set_row(0, "OK")
	_set_row(1, "RUNNING")

	# Your first control in the air: ease the throttle through maximum dynamic pressure
	var mq := await _ascent_control("maxq")
	_stress_crew(float(mq["quality"]), "Max Q", String(mq["text"]) + " " + String(mq.get("advice", "")), "The ship shook through Max Q: the air pressure stayed above the limit too long.", "Shaken by Max Q")
	if _action != "":
		return await _handle_action(_action)
	var c1 := await _ascent_poll(0)
	if c1 == "abort":
		_note("Max Q poll: you called an abort.")
		return await _do_abort()
	_note("Max Q poll: you called go%s." % (" with a no-go reported" if kind != "" else ""))
	if kind != "":
		return await _climb_failure(kind)

	# Max Q to booster separation
	act = await _segment(70.0, 128.0, 3.4, 340.0, kind, func(tw: Tween, dur: float):
		tw.tween_property(bg_pad, "modulate:a", 0.0, dur)
		tw.tween_property(bg_orbit, "modulate:a", 1.0, dur).set_delay(dur * 0.2)
		tw.tween_property(ground, "position:y", 900.0, dur))
	if act != "":
		return await _handle_action(act)
	# Your second control: separate the boosters as their thrust runs out, and watch them fall away
	var sp := await _ascent_control("sep")
	await _separate_boosters(float(sp["quality"]))
	_stress_crew(float(sp["quality"]), "Booster separation", String(sp["text"]) + " " + String(sp.get("advice", "")), "The boosters separated at the wrong moment and the jolt hurt the crew.", "Rough separation")
	if _action != "":
		return await _handle_action(_action)
	var c2 := await _ascent_poll(1)
	if c2 == "abort":
		_note("Booster separation poll: you called an abort.")
		return await _do_abort()

	# Booster separation to launch abort system jettison
	act = await _segment(128.0, 198.0, 3.0, 310.0, kind, Callable())
	if act != "":
		return await _handle_action(act)
	var c3 := await _ascent_poll(2)
	_shake = 6.0
	Sfx.play("stage")
	if c3 == "abort":
		_note("Abort system jettison poll: you called an abort.")
		return await _do_abort()
	# Jettisoned: from here the launch abort system is gone, and so is this abort call.
	_can_abort = false
	abort_button.text = "ABORT: LAS JETTISONED"
	abort_button.disabled = true

	# To orbit: core stage engine cutoff and separation
	act = await _segment(198.0, 498.0, 4.0, 360.0, kind, Callable())
	if act != "":
		return await _handle_action(act)
	_set_row(1, "OK")
	range_panel.hide()
	abort_button.hide()
	_note("The ascent went to plan. You made every call.")
	Sfx.play("stage")
	Sfx.loop_stop("rumble", 2.5)
	return {}


## A control the player runs in the air. Real time, so the skip button does not rush it.
func _ascent_control(mode: String) -> Dictionary:
	Engine.time_scale = 1.0
	skip_button.hide()
	var c := AscentControl.new()
	c.mode = mode
	c.preview = not AscentControl._seen.get(mode, false)       # the first live attempt starts with a preview and a READY step
	c.level.connect(func(v: float): _shake = maxf(_shake, 3.0 + v * 9.0))
	add_child(c)
	var r: Dictionary = await c.done
	c.queue_free()
	return r


## A rough control hurts the crew a little. Up to 24 health, which is about a heart.
func _stress_crew(quality: float, what: String, text: String, reason: String, short: String) -> void:
	var dmg := roundi((1.0 - quality) * 24.0)
	if dmg <= 0:
		_note("%s: clean. %s" % [what, text])
		return
	var lost := PlayerData.run.hurt_all(float(dmg), reason, short)
	_note("%s: %s The crew took some damage." % [what, text])
	for n in lost:
		_note("%s was lost." % n)


## The two boosters push away from the rocket and fall back, with a puff of smoke from each.
func _separate_boosters(quality: float) -> void:
	_say("BOOSTER SEPARATION", "", UiStyle.NEAR_WHITE)
	var rough := 1.0 - quality
	_shake = 12.0 + rough * 10.0
	Sfx.play("thud")
	flash.color.a = 0.45
	create_tween().tween_property(flash, "color:a", 0.0, 0.5)
	for i in boosters.size():
		var bst: Booster = boosters[i]
		var dir := -1.0 if i == 0 else 1.0
		bst.burning = false
		var puff := CPUParticles2D.new()
		puff.texture = _dot
		puff.position = bst.position + Vector2(Booster.CX, 150.0)
		puff.one_shot = true
		puff.emitting = true
		puff.amount = 44
		puff.lifetime = 1.4
		puff.explosiveness = 0.9
		puff.spread = 180.0
		puff.initial_velocity_min = 60.0
		puff.initial_velocity_max = 220.0
		puff.gravity = Vector2.ZERO
		puff.scale_amount_min = 0.8
		puff.scale_amount_max = 1.8
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1.0, 0.95, 0.85, 0.7), Color(0.6, 0.62, 0.75, 0.0)])
		puff.color_ramp = g
		holder.add_child(puff)
		get_tree().create_timer(2.0).timeout.connect(puff.queue_free)
		var tw := create_tween().set_parallel()
		tw.tween_property(bst, "position", bst.position + Vector2(dir * (170.0 + 130.0 * rough), 700.0), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(bst, "rotation", dir * (0.3 + 0.5 * rough), 2.0)
		tw.tween_property(bst, "modulate:a", 0.0, 0.7).set_delay(1.3)
	if rough > 0.3:
		var wob := create_tween()
		wob.tween_property(holder, "rotation", 0.12 * rough * 3.0, 0.25)
		wob.tween_property(holder, "rotation", 0.0, 0.5)
	await _wait(2.1)
	for bst in boosters:
		if is_instance_valid(bst):
			bst.queue_free()
	boosters.clear()


func _ascent_poll(idx: int) -> String:
	var mile: Dictionary = GroundControl.ASCENT[[2, 3, 4][idx]]
	Sfx.play("stage")
	_say(String(mile["name"]), String(mile["text"]), UiStyle.NEAR_WHITE)
	Engine.time_scale = 0.06
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var panel := PollPanel.new()
	panel.position = Vector2(820, 100)
	layer.add_child(panel)
	panel.setup("ascent", "%s  %s" % [mile["label"], mile["name"]], "MISSION CONTROL  -  HOUSTON", GroundControl.ascent_stations(state, idx))
	panel.set_can_abort(_can_abort)
	var choice: String = await panel.decided
	Engine.time_scale = 1.0
	layer.queue_free()
	_action = ""
	return choice


func _race(tw: Tween, dur: float) -> String:
	_action = ""
	var elapsed := 0.0
	while elapsed < dur:
		await get_tree().process_frame
		if _action != "":
			tw.kill()
			return _action
		elapsed += get_process_delta_time()
	return ""


func _climb_failure(kind: String) -> Dictionary:
	var act := ""
	if kind == "control":
		_say("OFF COURSE", "Nothing is steering", UiStyle.CORAL)
		var drift := create_tween().set_parallel()
		drift.tween_property(holder, "rotation", 0.95, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drift.tween_property(holder, "position:x", 1250.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var el := 0.0
		while el < 3.0 and act == "":
			act = await _race_step()
			el += get_process_delta_time()
			var met := 70.0 + el * 14.0
			_update_range(met, "control")
		if act != "":
			drift.kill()
			return await _handle_action(act)
		await _explode(false, true, "Nothing was steering the rocket because the ship has no Flight Deck. It veered off course and was destroyed with the crew aboard.")
	else:
		_say("POWER LOST", "Systems going dark. No data.", UiStyle.CORAL)
		_stop_burn()
		create_tween().tween_property(ship, "modulate", Color(0.28, 0.3, 0.4, 1), 0.5)
		_alarm = 1.0
		var tumble := create_tween().set_parallel()
		tumble.tween_property(holder, "rotation", 3.4, 3.0).set_trans(Tween.TRANS_SINE)
		tumble.tween_property(holder, "position:y", 640.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var el2 := 0.0
		while el2 < 3.0 and act == "":
			act = await _race_step()
			el2 += get_process_delta_time()
			_update_range(75.0, "power")
		_alarm = 0.0
		if act != "":
			tumble.kill()
			return await _handle_action(act)
		await _explode(false, true, "The ship ran out of power during the climb. Its systems shut down, it tumbled, and it was destroyed with the crew aboard.")
	_set_row(1, "FAILED")
	_note("You did not terminate and did not abort. The ship was lost.")
	return {"kind": "failed", "stage": "CLIMB", "why": plan[1]["why"], "fix": plan[1].get("fix", "")}


func _race_step() -> String:
	_action = _action
	await get_tree().process_frame
	return _action


func _handle_action(act: String) -> Dictionary:
	if act == "terminate":
		return await _do_terminate()
	return await _do_abort()


func _do_abort() -> Dictionary:
	_stop_burn()
	_can_abort = false
	abort_button.disabled = true
	range_panel.set_enabled(false)
	_say("ABORT", "The launch abort system pulls the crew module clear", UiStyle.CORAL)
	var cap := TextureRect.new()
	cap.texture = ShipData.room_texture("flight-deck")
	cap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cap.size = Vector2(96, 96)
	cap.pivot_offset = cap.size * 0.5
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.position = holder.global_position - cap.size * 0.5 + Vector2(0, -150)
	debris.add_child(cap)
	var tw := create_tween().set_parallel()
	tw.tween_property(cap, "position", Vector2(420, 110), 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cap, "rotation", -0.7, 1.8)
	await _explode(false, false)
	_set_row(1, "ABORTED")
	_note("You called an abort. The crew module got clear. In this game an abort ends the mission.")
	return {"kind": "aborted", "stage": "CLIMB"}


func _do_terminate() -> Dictionary:
	var valid := range_panel.is_threat()
	var why := range_panel.status
	_stop_burn()
	_say("FLIGHT TERMINATED", "Range safety ended the flight" if valid else "The path was still inside the corridor", UiStyle.CORAL)
	await _explode(false, true, ("Range safety destroyed the rocket because it left its safe path, and the crew was still aboard. Calling an abort first would have saved them." if valid else "You terminated a rocket that was still on its safe path, and the crew was still aboard."))
	_set_row(1, "TERMINATED")
	if valid:
		_note("Range safety terminated the flight while the display read %s." % why.to_lower())
	else:
		_note("You terminated while the path was still inside the safe corridor.")
	return {"kind": "terminated" if valid else "early_terminated", "stage": "CLIMB", "status": why}


func _liftoff_weight() -> void:
	var y0 := PAD_Y - SHIP_HALF
	_say("LIFTOFF", "", UiStyle.NEAR_WHITE)
	var tw := create_tween()
	tw.tween_property(holder, "position:y", y0 - 46.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shake = 9.0
	await tw.finished
	exhaust.emitting = false          # the engines give out
	smoke.emitting = false
	_say("TOO HEAVY", "The engines cannot lift it", UiStyle.CORAL)
	var fall := create_tween()
	fall.tween_property(holder, "position:y", y0 + 6.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	await _explode(true, true, "The ship was too heavy to lift. It fell back onto the pad and was destroyed with the crew aboard.")
	_note("The ship was too heavy and never left the pad.")


# ---------------- Mission Operations: the player walks the ship ----------------
func _ops_phase() -> Dictionary:
	Music.play("orbit")
	banner.modulate.a = 0.0
	sub_banner.modulate.a = 0.0
	Engine.time_scale = 1.0
	var op := ShipInterior.new()
	op.state = state
	op.run = PlayerData.run
	op.mission_id = mission_id
	add_child(op)
	var r: Dictionary = await op.finished
	op.queue_free()
	for n in r.get("notes", []):
		_note(String(n))
	return r


# ---------------- the photo and the radio are games the player plays ----------------
func _photo_game() -> Dictionary:
	banner.modulate.a = 0.0
	sub_banner.modulate.a = 0.0
	Engine.time_scale = 1.0
	var g := PhotoGame.new()
	g.has_lens = {"wide": state.wide, "close": state.close}
	g.met_at_start = 34
	g.target = Missions.get_mission(mission_id)["target"]
	g.perks = ShipData.flight_perks(state, PlayerData.run.crew)
	add_child(g)
	var r: Dictionary = await g.finished
	g.queue_free()
	var photos: Array = r.get("photos", [])
	if not photos.is_empty():
		PlayerData.run.complete("photo")
		PlayerData.run.complete("tag")
	for ph in photos:
		_note("%s photo: %s, %s." % [("Wide" if ph["lens"] == "wide" else "Close-up"), String(ph["confidence"]).to_lower(), "tagged correctly" if ph.get("tag_ok", false) else "tagged the wrong way round"])
	return r


func _downlink_game(shots: Dictionary) -> Dictionary:
	Engine.time_scale = 1.0
	var g := DownlinkGame.new()
	var list: Array[Dictionary] = []
	for ph in shots.get("photos", []):
		list.append(ph)
	g.photos = list
	g.perks = ShipData.flight_perks(state, PlayerData.run.crew)
	add_child(g)
	var r: Dictionary = await g.finished
	if not r.get("received", []).is_empty():
		PlayerData.run.complete("send")
	g.queue_free()
	for lens in r.get("received", []):
		_note("%s photo reached Earth." % ("Wide" if lens == "wide" else "Close-up"))
	for lens in r.get("lost", []):
		_note("%s photo was lost: it did not finish sending." % ("Wide" if lens == "wide" else "Close-up"))
	return r


## Why a crater contract ended badly after operations, or an empty dictionary if the science holds up.
## Returns {why, fix}. Every reason is specific, as the game promises.
static func _crater_failure(ops: Dictionary) -> Dictionary:
	var sci: Dictionary = ops.get("science", {})
	var n := int(ops.get("shots", {}).get("photos", []).size())
	var tail := " Operations ran out of time." if ops.get("time_out", false) else ""
	if n < 2:
		return {"why": "Only %d of the 2 observations produced a photo, so there was nothing to compare.%s" % [n, tail],
			"fix": "Plan a pass at the Flight Deck, then observe, for both photos. Waiting for the Sun costs minutes, so plan your time."}
	if not bool(sci.get("done", false)):
		return {"why": "The two photos were never compared in the Science Lab, so there was no finding to send.%s" % tail,
			"fix": "After both observations, walk to the Science Lab and compare the photos before you send."}
	var ev: Dictionary = sci.get("eval", {})
	if not bool(ev.get("usable", false)):
		return {"why": String(ev.get("why", "The comparison did not hold up.")), "fix": String(ev.get("fix", ""))}
	return {}


## Earth orbit, translunar injection and the lunar flyby are different phases of the real mission. A short banner for each,
## so the player is not told the Moon flyby happens in Earth orbit. The timing is compressed for the game.
func _phase_transitions() -> void:
	Engine.time_scale = 1.0
	banner.modulate.a = 1.0
	sub_banner.modulate.a = 1.0
	_say("EARTH ORBIT", "Systems checkout. REAL: Orion spent about a day in high Earth orbit first. (Game: skipped ahead.)", UiStyle.NEAR_WHITE)
	clock_label.text = "EARTH ORBIT"
	await _wait(2.0)
	_say("TRANSLUNAR INJECTION", "REAL: the burn that sends Orion toward the Moon (about +1 day 1.6 hours). A different phase from orbit.", UiStyle.AMBER)
	clock_label.text = "TRANSLUNAR BURN"
	await _wait(2.0)
	_say("LUNAR FLYBY", "REAL: Orion passes the Moon about 4,000 to 6,000 miles up. Mission Operations start now. Minutes below are GAME minutes.", UiStyle.PHOSPHOR)
	clock_label.text = "LUNAR FLYBY"
	await _wait(2.2)


## The way home. Returns {landed, speed_mph, notes, ...}. Injuries and deaths carry their reasons through the crew alerts.
func _return_phase() -> Dictionary:
	banner.modulate.a = 0.0
	sub_banner.modulate.a = 0.0
	Engine.time_scale = 1.0
	Music.play("landing")
	var rp := ReturnPhase.new()
	rp.run = PlayerData.run
	add_child(rp)
	# keep the crew panel and the damage notices above the return screen
	for c in get_children():
		if c is CrewAlerts or c is CrewHearts:
			move_child(c, -1)
	var r: Dictionary = await rp.finished
	rp.queue_free()
	for n in r.get("notes", []):
		_note(String(n))
	return r


func _evidence_list(shots: Dictionary, sent: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ph in shots.get("photos", []):
		var key := String(ph.get("key", ph["lens"]))
		out.append({"lens": ph["lens"], "key": key, "stars": ph["stars"], "confidence": ph["confidence"], "tag_ok": ph.get("tag_ok", false),
			"received": sent.get("received", []).has(key), "crater": ph.get("crater", ""), "pass": ph.get("pass", ""), "tex": ph.get("tex")})
	return out


func _evidence_text(shots: Dictionary, sent: Dictionary) -> String:
	var parts: Array[String] = []
	for e in (_evidence_list(shots, sent) if bool(shots.get("crater", false)) else _evidence_list(shots, sent)):
		if e["received"]:
			if String(e.get("crater", "")) != "":
				parts.append("%s %s" % [String(CraterScience.CRATERS[e["crater"]]["name"]), String(e["confidence"]).to_lower()])
			else:
				parts.append("%s %s" % [("wide" if e["lens"] == "wide" else "close-up"), String(e["confidence"]).to_lower()])
	return ", ".join(parts)


# ---------------- 3 ORBIT ----------------
func _orbit(st: Dictionary) -> void:
	_stop_burn()
	_say("ORBIT", "", UiStyle.NEAR_WHITE)
	_tick_clock(24, 34, 2.8)
	var tw := create_tween().set_parallel()
	tw.tween_property(holder, "rotation", -PI / 2.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(holder, "position", Vector2(960, 520), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(holder, "scale", Vector2(1.45, 1.45), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if st["ok"]:
		await _wait(0.9)
		return
	_say("CREW ALARM", "The crew had to stop the flight", UiStyle.CORAL)
	_alarm = 1.0
	await _wait(1.0)
	create_tween().tween_property(ship, "modulate", Color(0.4, 0.4, 0.5, 1), 1.2)
	await _wait(1.8)
	_alarm = 0.0


# ---------------- 4 PHOTO ----------------
func _photo(st: Dictionary) -> void:
	_say("MOON IN VIEW", "", UiStyle.NEAR_WHITE)
	_tick_clock(34, 46, 3.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(bg_moon, "modulate:a", 1.0, 1.4)
	tw.tween_property(bg_orbit, "modulate:a", 0.0, 1.4)
	tw.tween_property(holder, "modulate:a", 0.0, 1.0)
	await tw.finished
	_reticle_bad = not st["ok"]
	var close := create_tween()
	close.tween_method(func(v: float): _reticle = v; fx.queue_redraw(), 0.0, 1.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await close.finished
	if st["ok"]:
		flash.color.a = 0.9
		create_tween().tween_property(flash, "color:a", 0.0, 0.5)
		_say("SHOT TAKEN", "Evidence recorded", UiStyle.PHOSPHOR)
		await _wait(1.3)
	else:
		_say("NO SHOT", "", UiStyle.CORAL)
		_alarm = 0.6
		await _wait(1.8)
		_alarm = 0.0
	_reticle = 0.0
	fx.queue_redraw()


# ---------------- 5 RADIO ----------------
func _radio_stage(st: Dictionary) -> void:
	_say("SENDING DATA", "", UiStyle.NEAR_WHITE)
	_tick_clock(46, 58, 3.0)
	holder.modulate.a = 1.0
	_radio_bad = not st["ok"]
	var tw := create_tween()
	tw.tween_method(func(v: float): _radio = v; fx.queue_redraw(), 0.0, 2.6, 2.6)
	await tw.finished
	if st["ok"]:
		_say("DATA SENT", "It reached home", UiStyle.PHOSPHOR)
	else:
		_say("NO RADIO", "The data could not be sent", UiStyle.CORAL)
		_alarm = 0.6
	await _wait(1.4)
	_alarm = 0.0
	_radio = -1.0
	fx.queue_redraw()


# ---------------- failure effects ----------------
func _explode(on_pad: bool, crew_lost := true, reason := "The ship was destroyed with the crew aboard.") -> void:
	Sfx.play("boom")
	for bst in boosters:
		if is_instance_valid(bst):
			bst.visible = false
	if crew_lost:
		var gone := PlayerData.run.kill_all(reason)
		if not gone.is_empty():
			_note("The ship was lost with the crew aboard.")
	_stop_burn()
	_shake = 22.0
	boom.global_position = holder.global_position
	boom.emitting = true
	flash.color.a = 0.95
	create_tween().tween_property(flash, "color:a", 0.0, 0.7)
	ship.visible = false
	# The player's own rooms fly apart
	for id in state.bays:
		if id == "":
			continue
		var d := TextureRect.new()
		d.texture = ShipData.room_texture(id)
		d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		d.size = Vector2(84, 84)
		d.pivot_offset = d.size * 0.5
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.position = holder.global_position - d.size * 0.5 + Vector2(randf_range(-30, 30), randf_range(-90, 90))
		debris.add_child(d)
		var away := Vector2(randf_range(-520, 520), randf_range(-420 if not on_pad else -520, 260 if not on_pad else 60))
		var tw := create_tween().set_parallel()
		tw.tween_property(d, "position", d.position + away, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "rotation", randf_range(-6.0, 6.0), 1.6)
		tw.tween_property(d, "modulate:a", 0.0, 1.6).set_delay(0.5)
	_say("SHIP LOST", "", UiStyle.CORAL)
	await _wait(1.6)


# =====================================================================
# The result
# =====================================================================

func _finish(out: Dictionary) -> void:
	if _ended:
		return
	_ended = true
	Engine.time_scale = 1.0
	Sfx.loop_stop("rumble", 1.0)
	skip_button.hide()
	range_panel.hide()
	abort_button.hide()
	var kind := String(out.get("kind", "failed"))
	var success := kind == "success"
	var partial := kind == "partial"
	PlayerData.flight_result = {"success": success, "kind": kind, "stage": out.get("stage", ""), "reason": out.get("why", ""), "partial": partial}
	PlayerData.mission_data_lost = not (success or partial)
	if success:
		PlayerData.complete_contract(mission_id)
	PlayerData.sync_crew_after_flight()
	await _wait(0.6)
	var fade := create_tween()
	fade.tween_property(dim, "color", Color(0.01, 0.02, 0.07, 0.86), 0.6)
	await fade.finished
	_show_result(out)


## Confetti from both bottom corners when the flight succeeds
func _confetti() -> void:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.34, 0.67, 1.0])
	ramp.colors = PackedColorArray([UiStyle.PHOSPHOR, UiStyle.CHROME, UiStyle.AMBER, Color(0.35, 0.5, 1.0)])
	for side in [0.16, 0.84]:
		var p := CPUParticles2D.new()
		p.position = Vector2(size.x * side, size.y + 20.0)
		p.amount = 80
		p.one_shot = true
		p.explosiveness = 0.95
		p.lifetime = 3.0
		p.direction = Vector2(-0.35 if side > 0.5 else 0.35, -1.0)
		p.spread = 28.0
		p.initial_velocity_min = 800.0
		p.initial_velocity_max = 1400.0
		p.gravity = Vector2(0.0, 1100.0)
		p.angular_velocity_min = -420.0
		p.angular_velocity_max = 420.0
		p.scale_amount_min = 5.0
		p.scale_amount_max = 11.0
		p.color_initial_ramp = ramp
		add_child(p)
		p.emitting = true
		get_tree().create_timer(4.0).timeout.connect(p.queue_free)


func _show_result(out: Dictionary) -> void:
	banner.modulate.a = 0.0
	sub_banner.modulate.a = 0.0
	var kind := String(out.get("kind", "failed"))
	var success := kind == "success"
	var partial := kind == "partial"
	if success:
		Sfx.play("fanfare")
		_confetti()
		# Sparkles from the Y2K decoration pack flank the result panel
		var deco := Decor.frame_layer(self)
		pass
		pass
	else:
		Sfx.play("fail")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1000, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.panel(30))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var accent: Color = UiStyle.PHOSPHOR if success else (UiStyle.AMBER if kind in ["aborted", "terminated", "partial"] else UiStyle.CORAL)
	col.add_child(UiStyle.mono_label("FLIGHT RESULT", 15, Color(UiStyle.NEAR_WHITE, 0.65)))
	var heads := {"success": "FLIGHT SUCCESSFUL", "partial": "PARTIAL EVIDENCE", "failed": "MISSION FAILED", "aborted": "ABORTED", "terminated": "FLIGHT TERMINATED", "early_terminated": "TERMINATED TOO EARLY"}
	var head := UiStyle.heading(String(heads.get(kind, "MISSION FAILED")))
	head.add_theme_font_size_override("font_size", 40)
	head.add_theme_color_override("font_color", accent)
	col.add_child(head)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.add_theme_font_size_override("normal_font_size", 21)
	text.add_theme_font_size_override("bold_font_size", 21)
	var lost := "\n\n[color=#ffc45e][b]All mission data is lost.[/b][/color]  Your ship is kept, so you can change it and fly again."
	match kind:
		"success":
			text.text = "Every system held. You took the photos and sent them home.\n\n[color=#c8ff36][b]Evidence on Earth:[/b][/color]  %s.\n[color=#c8ff36][b]Contract complete.[/b][/color]  Your ship is now locked for the rest of the game. The report is next." % String(out.get("evidence", "none"))
		"partial":
			text.text = "[color=#ffc45e][b]Part of the evidence reached Earth.[/b][/color]\n\n[color=#c8ff36][b]On Earth:[/b][/color]  %s.\n[color=#ffc45e][b]This does not complete Orientale.[/b][/color]  Your ship is not locked. Change it if you like and fly again. The data that arrived is kept." % String(out.get("evidence", "none"))
		"aborted":
			text.text = "[color=#ffc45e][b]You called an abort.[/b][/color]  The launch abort system pulled the crew module clear of the rocket. The crew is safe, but an abort ends the mission." + lost
		"terminated":
			text.text = "[color=#ffc45e][b]Range safety ended the flight.[/b][/color]  The display read [b]%s[/b], so the rocket was destroyed to protect people on the ground." % String(out.get("status", "")).to_lower() + lost
		"early_terminated":
			text.text = "[color=#ff6b7a][b]The rocket was still inside its safe corridor.[/b][/color]  Range safety terminates for three reasons: the path crosses a destruct line, the flight is erratic, or the data goes dark. None of them was true yet." + lost
		_:
			text.text = "[color=#ff6b7a][b]%s failed.[/b][/color]  Why it failed is explained below." % String(out.get("stage", "")).capitalize() + lost
	col.add_child(text)
	var run := PlayerData.run
	var crew_ok := run.alive_count() == run.crew.size()
	col.add_child(UiStyle.mono_label("CREW   " + run.crew_summary(), 15, UiStyle.PHOSPHOR if crew_ok else UiStyle.CORAL))
	for d in run.deaths():
		var dl := Label.new()
		dl.text = "%s died: %s" % [d["name"], d["cause"]]
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", 16)
		dl.add_theme_color_override("font_color", UiStyle.CORAL)
		col.add_child(dl)
	if not run.landing.is_empty():
		var ll := Label.new()
		ll.text = "Splashdown at %d mph (NASA reported about 20 mph on Artemis II).  Crew alive after landing: %d of %d." % [int(round(float(run.landing.get("speed_mph", 0.0)))), int(run.landing.get("alive", 0)), run.crew.size()]
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.add_theme_font_size_override("font_size", 16)
		col.add_child(ll)
	if run.fault.get("happened", false):
		col.add_child(UiStyle.mono_label("THE CALL YOU MADE", 14, UiStyle.AMBER))
		var fl_ := Label.new()
		var fc: Dictionary = run.fault["cost"]
		fl_.text = "%s.  It cost %d min, %d power and %d energy (walking included).  Close-up: %s." % [String(run.fault["label"]), int(round(float(fc["time"]))), int(round(float(fc["power"]))), int(round(float(fc["energy"]))), "taken" if bool(run.fault["close_taken"]) else "not taken"]
		fl_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl_.add_theme_font_size_override("font_size", 16)
		col.add_child(fl_)
	if not success:
		# Say exactly why it failed (or is not complete), and what would change it
		col.add_child(UiStyle.mono_label("WHY IT IS NOT COMPLETE" if partial else "WHY IT FAILED", 14, UiStyle.AMBER if partial else UiStyle.CORAL))
		var why_text := String(out.get("why", ""))
		if why_text == "":
			match kind:
				"aborted":
					why_text = "You called an abort, so the mission ended. In this game an abort ends the mission."
				"terminated":
					why_text = "Range safety ended the flight because the display read %s." % String(out.get("status", "")).to_lower()
				"early_terminated":
					why_text = "You terminated the flight while the rocket was still inside its safe corridor."
		var wl := Label.new()
		wl.text = why_text
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.add_theme_font_size_override("font_size", 18)
		col.add_child(wl)
		var fix := String(out.get("fix", ""))
		if fix != "":
			var fl := Label.new()
			fl.text = ("TO FIX:  " + fix) if not bool(PlayerData.campaign["locked"]) else "Your ship is locked for the rest of the game. " + fix
			fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fl.add_theme_font_size_override("font_size", 17)
			fl.add_theme_color_override("font_color", UiStyle.PHOSPHOR if not bool(PlayerData.campaign["locked"]) else UiStyle.AMBER)
			col.add_child(fl)
	if bool(PlayerData.campaign["over"]):
		var ol := Label.new()
		ol.text = "CAMPAIGN OVER.  " + String(PlayerData.campaign["over_reason"])
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ol.add_theme_font_size_override("font_size", 17)
		ol.add_theme_color_override("font_color", UiStyle.CORAL)
		col.add_child(ol)

	# What the ground team did, in order
	col.add_child(UiStyle.mono_label("YOUR CALLS", 14, Color(UiStyle.NEAR_WHITE, 0.6)))
	for n in _notes.slice(0, 5 if success else 3):
		var l := Label.new()
		l.text = "-  " + String(n)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.88))
		col.add_child(l)

	# What is real and what is game design
	col.add_child(UiStyle.mono_label("REAL OR GAME", 14, Color(UiStyle.NEAR_WHITE, 0.6)))
	for line in [
		["REAL", "The Launch Director polls the room for go or no-go before the terminal count."],
		["REAL", "After the boosters ignite, control passes from Launch Control to the flight team in Houston."],
		["REAL", "Range safety can destroy a rocket that leaves its safe path, to protect people on the ground."],
		["GAME", "Your ship's problems, the ascent polls and the abort call from the ground team are game design."],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var tag := UiStyle.mono_label(line[0], 13, UiStyle.CHROME if line[0] == "REAL" else UiStyle.AMBER)
		tag.custom_minimum_size = Vector2(52, 0)
		row.add_child(tag)
		var l2 := Label.new()
		l2.text = line[1]
		l2.add_theme_font_size_override("font_size", 15)
		l2.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.78))
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l2)
		col.add_child(row)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var title_btn := Button.new()
	title_btn.text = "Title screen"
	title_btn.theme_type_variation = &"OutlineButton"
	title_btn.custom_minimum_size = Vector2(0, 52)
	title_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_btn.pressed.connect(func(): get_tree().change_scene_to_file(title_scene))
	buttons.add_child(title_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var back := Button.new()
	var over := bool(PlayerData.campaign["over"])
	var locked := bool(PlayerData.campaign["locked"])
	back.text = "SEE THE REPORT" if (success or partial) else ("SEE THE ENDING" if over else ("BUILD AGAIN" if not locked else "BACK TO CONTRACTS"))
	back.theme_type_variation = &"PrimaryButton"
	back.add_theme_font_size_override("font_size", 28)
	back.custom_minimum_size = Vector2(380, 100)
	back.pressed.connect(func():
		if success or partial:
			get_tree().change_scene_to_file("res://report_screen.tscn")
		elif over:
			get_tree().change_scene_to_file("res://ending_screen.tscn")
		elif locked:
			get_tree().change_scene_to_file("res://mission_select.tscn")
		else:
			get_tree().change_scene_to_file(back_scene))
	buttons.add_child(back)
	col.add_child(buttons)
	# Ignore clicks for a moment: a click meant for the animation must not hit these buttons.
	title_btn.disabled = true
	back.disabled = true
	get_tree().create_timer(0.8).timeout.connect(func():
		title_btn.disabled = false
		back.disabled = false
		back.grab_focus())
	center.modulate.a = 0.0
	create_tween().tween_property(center, "modulate:a", 1.0, 0.35)
