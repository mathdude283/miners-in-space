extends Control
## Contracts 04 to 06, step 1: design the spacecraft. One part per subsystem, up to the template's instrument mounts, and an orbit.
## Live meters show mass, cost, power and mounts against the limits. The numbers on the parts are REAL (the team's spacecraft sheet);
## the limits and the way they are scored are GAME rules. LAUNCH stays off until the design is legal.

@export_file("*.tscn") var ops_scene: String = "res://space_ops.tscn"
@export_file("*.tscn") var back_scene: String = "res://mission_select.tscn"

var mission_id := 3
var picks := {"instruments": [], "orbit": ""}

var _m: Dictionary
var _meters: VBoxContainer
var _problems: Label
var _note: Label
var _launch: Button
var _sub_groups := {}
var _inst_btns := {}
var _orbit_btns := {}


func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mission_id = PlayerData.current_mission() if SpaceData.is_space(PlayerData.current_mission()) else mission_id
	_m = SpaceData.mission(mission_id)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/select/bg_earth_orbit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.027, 0.043, 0.133, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	root.add_child(UiStyle.mono_label("%s   -   DESIGN YOUR SPACECRAFT" % String(_m["tag"]), 14, UiStyle.PHOSPHOR))
	root.add_child(UiStyle.heading(String(_m["name"])))
	var coach := CoachPanel.new(1780.0, 19)
	coach.say("%s Pick one part for each subsystem, up to %d instruments, and an orbit. Part numbers are REAL (kg, W, $M from your team's sheet). The limits and the scoring are GAME rules. Watch the meters on the right." % [String(_m["goal"]), int(_m["mount"])])
	root.add_child(coach)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.custom_minimum_size = Vector2(1060, 0)
	cols.add_child(left)
	for sub in SpaceData.SUBSYSTEMS:
		left.add_child(_subsystem_row(sub))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(660, 0)
	cols.add_child(right)
	right.add_child(UiStyle.mono_label("ORBIT", 13, UiStyle.AMBER))
	var og := ButtonGroup.new()
	for o in _m["orbits"]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = og
		b.text = String(o["name"])
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 38)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var oid := String(o["id"])
		var note := String(o["note"])
		b.pressed.connect(func():
			picks["orbit"] = oid
			_note.text = note
			_refresh())
		right.add_child(b)
		_orbit_btns[oid] = b
	right.add_child(UiStyle.mono_label("INSTRUMENTS   (up to %d mounts)" % int(_m["mount"]), 13, UiStyle.AMBER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	for ins in SpaceData.INSTRUMENTS:
		if String(ins["id"]) == "probe" and mission_id != 5:
			continue
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s\n%d kg  %d W  $%dM" % [ins["name"], int(ins["kg"]), int(ins["w"]), int(ins["m"])]
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(320, 46)
		b.focus_mode = Control.FOCUS_NONE
		var iid := String(ins["id"])
		var inote := String(ins["note"])
		b.toggled.connect(func(on):
			var list: Array = picks["instruments"]
			if on and not list.has(iid):
				list.append(iid)
			elif not on:
				list.erase(iid)
			_note.text = inote
			_refresh())
		grid.add_child(b)
		_inst_btns[iid] = b
	_meters = VBoxContainer.new()
	_meters.add_theme_constant_override("separation", 2)
	right.add_child(_meters)
	_problems = Label.new()
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems.add_theme_font_size_override("font_size", 14)
	_problems.add_theme_color_override("font_color", UiStyle.CORAL)
	_problems.custom_minimum_size = Vector2(640, 0)
	right.add_child(_problems)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 14)
	_note.add_theme_color_override("font_color", Color(UiStyle.PHOSPHOR, 0.9))
	_note.custom_minimum_size = Vector2(640, 40)
	right.add_child(_note)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	root.add_child(foot)
	var back := Button.new()
	back.text = "BACK"
	back.theme_type_variation = &"OutlineButton"
	back.add_theme_font_size_override("font_size", 20)
	back.custom_minimum_size = Vector2(160, 60)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_tree().change_scene_to_file(back_scene))
	foot.add_child(back)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	_launch = Button.new()
	_launch.text = "LAUNCH"
	_launch.theme_type_variation = &"PrimaryButton"
	_launch.add_theme_font_size_override("font_size", 28)
	_launch.custom_minimum_size = Vector2(420, 84)
	_launch.focus_mode = Control.FOCUS_NONE
	_launch.pressed.connect(launch)
	foot.add_child(_launch)
	Music.play("design")
	_refresh()


func _subsystem_row(sub: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := UiStyle.mono_label("%s  (%s)" % [SpaceData.SUB_LABEL[sub], SpaceData.SUB_ROOM[sub]], 11, Color(UiStyle.NEAR_WHITE, 0.8))
	lab.custom_minimum_size = Vector2(250, 0)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	var group := ButtonGroup.new()
	for p in SpaceData.parts_for(mission_id, sub):
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = "%s\n%s kg  %s  $%dM" % [p["name"], _num(int(p["kg"])), (str(int(p.get("w", 0))) + " W") if int(p.get("w", 0)) > 0 else ((str(int(p["gen"])) + " W made") if p.has("gen") else "0 W"), int(p["m"])]
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(266, 44)
		b.focus_mode = Control.FOCUS_NONE
		var pid := String(p["id"])
		var pnote := String(p.get("note", ""))
		b.pressed.connect(func():
			picks[sub] = pid
			_note.text = pnote
			_refresh())
		row.add_child(b)
	return row


func _num(n: int) -> String:
	return "%d,%03d" % [n / 1000, n % 1000] if n >= 1000 else str(n)


func _refresh() -> void:
	var d := SpaceData.derive(mission_id, picks)
	for c in _meters.get_children():
		c.queue_free()
	var lines := [
		["MASS", "%s / %s kg" % [_num(int(d["kg"])), _num(int(_m["mass_cap"]))], float(d["kg"]) <= float(_m["mass_cap"])],
		["COST", "$%s / $%sM" % [_num(int(d["cost"])), _num(int(_m["cost_cap"]))], float(d["cost"]) <= float(_m["cost_cap"])],
		["POWER", "%.1f W made / %.1f W used" % [float(d["gen"]), float(d["draw"])], float(d["margin"]) >= 0.0],
		["MOUNTS", "%d / %d instruments" % [(d["instruments"] as Array).size(), int(_m["mount"])], (d["instruments"] as Array).size() <= int(_m["mount"])],
		["BURNS", "%.1f burn units (GAME)" % float(d["burns"]), true],
		["SCIENCE", "%d of 100 for this mission" % SpaceData.science_value(mission_id, d), true],
	]
	for l in lines:
		_meters.add_child(UiStyle.mono_label("%-8s %s" % [l[0], l[1]], 14, UiStyle.PHOSPHOR if bool(l[2]) else UiStyle.CORAL))
	_problems.text = "\n".join(d["problems"] as Array)
	_launch.disabled = not bool(d["ok"])


## Start the mission with this design. Public so a test can stand in for the button.
func launch() -> void:
	var d := SpaceData.derive(mission_id, picks)
	if not bool(d["ok"]):
		return
	PlayerData.space_picks = picks.duplicate(true)
	get_tree().change_scene_to_file(ops_scene)
