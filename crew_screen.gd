extends Control
## Choose your crew. Three seats (commander, pilot, scientist) and seven people to put in them. The player picks
## each seat's look from the faces along the bottom and names the person anything they like. The crew is chosen
## once, at the start of a campaign, and then stays on screen with their health for the whole game.
## Roles, traits and the health numbers are GAME rules. Character art is from the team's Drive.

const HUD := preload("res://hud_frame.gd")
const TRACKER := preload("res://stage_tracker.gd")

@export_file("*.tscn") var next_scene: String = "res://build_screen.tscn"
@export_file("*.tscn") var back_scene: String = "res://mission_select.tscn"

var _slots: Array[Dictionary] = []          # {char, edited, field, portrait, panel, tag}
var _selected := 0
var _roster: Array[Dictionary] = []         # {id, panel, tag}
var _leaving := false


func _ready() -> void:
	Music.play("design")
	theme = load("res://assets/themes/moonbound_theme.tres")
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/select/bg_earth_orbit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.027, 0.043, 0.133, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var hud: Control = HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.inset = 28.0
	hud.arm = 46.0
	hud.show_ruler = false
	add_child(hud)
	var tracker: HBoxContainer = TRACKER.new()
	tracker.active_index = 0
	tracker.anchor_left = 1.0
	tracker.anchor_right = 1.0
	tracker.offset_top = 24.0
	tracker.offset_right = -120.0
	tracker.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(tracker)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	col.add_child(UiStyle.mono_label("01  CONTRACT", 15, UiStyle.PHOSPHOR))
	col.add_child(UiStyle.heading("CHOOSE YOUR CREW"))
	var sub := Label.new()
	sub.text = "Three seats, seven people. Pick a seat, click a face to put them in it, and give them any name you like."
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.9))
	col.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var crew := PlayerData.crew
	for i in CrewData.ROLES.size():
		var c: Dictionary = crew[i] if i < crew.size() else CrewData.defaults()[i]
		_slots.append({"char": String(c["char"]), "edited": String(c["name"]) != CrewData.char_name(String(c["char"])), "name": String(c["name"])})
		row.add_child(_seat_card(i))

	col.add_child(UiStyle.mono_label("PEOPLE YOU CAN PICK", 14, Color(UiStyle.NEAR_WHITE, 0.7)))
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 14)
	col.add_child(strip)
	for ch in CrewData.CHARACTERS:
		strip.add_child(_roster_card(String(ch["id"])))

	col.add_child(UiStyle.mono_label("Roles, traits and health are game rules. Character art is AI-generated and comes from the team's Drive.", 13, Color(UiStyle.NEAR_WHITE, 0.55)))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	var back := Button.new()
	back.text = "BACK"
	back.theme_type_variation = &"OutlineButton"
	back.custom_minimum_size = Vector2(150, 56)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): _leave(back_scene))
	foot.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	foot.add_child(_difficulty_picker())
	var go := Button.new()
	go.text = "CONTINUE TO BUILD"
	go.theme_type_variation = &"PrimaryButton"
	go.add_theme_font_size_override("font_size", 26)
	go.custom_minimum_size = Vector2(430, 90)
	go.pressed.connect(_on_continue)
	foot.add_child(go)
	_refresh()


func _seat_card(i: int) -> Control:
	var role: Dictionary = CrewData.ROLES[i]
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(430, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(150, 150)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(pic)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_theme_constant_override("separation", 6)
	top.add_child(side)
	side.add_child(UiStyle.mono_label("SEAT %d   %s" % [i + 1, role["role"]], 15, UiStyle.PHOSPHOR))
	var f := LineEdit.new()
	f.text = String(_slots[i]["name"])
	f.max_length = CrewData.MAX_NAME
	f.custom_minimum_size = Vector2(0, 48)
	f.add_theme_font_size_override("font_size", 24)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.03, 0.12, 0.95)
	normal.set_border_width_all(2)
	normal.border_color = Color(UiStyle.CHROME, 0.7)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = UiStyle.PHOSPHOR
	f.add_theme_stylebox_override("normal", normal)
	f.add_theme_stylebox_override("focus", focus)
	f.text_changed.connect(func(t): _slots[i]["edited"] = t != CrewData.char_name(String(_slots[i]["char"])); _slots[i]["name"] = t)
	f.focus_entered.connect(func(): _select(i))
	side.add_child(f)
	var trait_label := Label.new()
	trait_label.text = String(role["trait"])
	trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_label.custom_minimum_size = Vector2(0, 72)
	trait_label.add_theme_font_size_override("font_size", 20)
	trait_label.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.85))
	v.add_child(trait_label)
	# Clicking the portrait picks the seat (the name field picks it too when it gets focus)
	pic.mouse_filter = Control.MOUSE_FILTER_STOP
	pic.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_select(i))
	_slots[i]["field"] = f
	_slots[i]["portrait"] = pic
	_slots[i]["panel"] = p
	return p


func _roster_card(id: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(190, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var pic := TextureRect.new()
	pic.texture = CrewData.portrait(id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(0, 118)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	var l := UiStyle.mono_label(CrewData.char_name(id).to_upper(), 17, UiStyle.NEAR_WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var tag := UiStyle.mono_label("", 15, UiStyle.PHOSPHOR)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func(): _assign(id))
	p.add_child(b)
	_roster.append({"id": id, "panel": p, "tag": tag, "pic": pic})
	return p


func _select(i: int) -> void:
	_selected = i
	_refresh()


## Put this person in the selected seat. If they were already in another seat the two swap.
func _assign(id: String) -> void:
	var other := -1
	for k in _slots.size():
		if _slots[k]["char"] == id:
			other = k
	var mine: String = _slots[_selected]["char"]
	if other == _selected:
		return
	if other >= 0:
		_set_char(other, mine)
	_set_char(_selected, id)
	Sfx.play("add", -4.0)
	_refresh()


func _set_char(i: int, id: String) -> void:
	_slots[i]["char"] = id
	if not bool(_slots[i]["edited"]):
		_slots[i]["name"] = CrewData.char_name(id)
		(_slots[i]["field"] as LineEdit).text = CrewData.char_name(id)


func _refresh() -> void:
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		(s["portrait"] as TextureRect).texture = CrewData.portrait(String(s["char"]))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UiStyle.COBALT, 0.4 if i == _selected else 0.18)
		sb.set_border_width_all(3 if i == _selected else 2)
		sb.border_color = UiStyle.PHOSPHOR if i == _selected else Color(UiStyle.CHROME, 0.5)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		(s["panel"] as PanelContainer).add_theme_stylebox_override("panel", sb)
	for r in _roster:
		var in_seat := -1
		for k in _slots.size():
			if _slots[k]["char"] == r["id"]:
				in_seat = k
		(r["tag"] as Label).text = ("IN SEAT %d" % (in_seat + 1)) if in_seat >= 0 else "AVAILABLE"
		(r["tag"] as Label).add_theme_color_override("font_color", UiStyle.PHOSPHOR if in_seat == _selected else Color(UiStyle.NEAR_WHITE, 0.55))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UiStyle.COBALT, 0.45 if in_seat == _selected else 0.18)
		sb.set_border_width_all(3 if in_seat == _selected else 2)
		sb.border_color = UiStyle.PHOSPHOR if in_seat == _selected else Color(UiStyle.CHROME, 0.4)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 8
		sb.content_margin_bottom = 6
		(r["panel"] as PanelContainer).add_theme_stylebox_override("panel", sb)
		(r["pic"] as TextureRect).modulate = Color(1, 1, 1, 1.0 if in_seat < 0 or in_seat == _selected else 0.6)


## Three buttons: how hard the campaign is, and the points multiplier that comes with it.
func _difficulty_picker() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UiStyle.mono_label("DIFFICULTY   (harder = more points)", 13, UiStyle.AMBER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var blurb := UiStyle.mono_label("", 12, Color(UiStyle.NEAR_WHITE, 0.75))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(520, 0)
	var group := ButtonGroup.new()
	for lvl in ScoreBoard.DIFFICULTY.size():
		var d: Dictionary = ScoreBoard.DIFFICULTY[lvl]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = "%s  x%.2f" % [d["name"], float(d["mult"])]
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(170, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = int(PlayerData.campaign.get("difficulty", 1)) == lvl
		b.pressed.connect(func():
			PlayerData.campaign["difficulty"] = lvl
			blurb.text = String(d["blurb"]))
		row.add_child(b)
		if b.button_pressed:
			blurb.text = String(d["blurb"])
	v.add_child(blurb)
	return v


func _on_continue() -> void:
	var crew: Array[Dictionary] = []
	for i in _slots.size():
		var role := String(CrewData.ROLES[i]["role"])
		var nm := CrewData.clean_name((_slots[i]["field"] as LineEdit).text, CrewData.char_name(String(_slots[i]["char"])))
		crew.append(CrewData.make(String(_slots[i]["char"]), nm, role))
	PlayerData.crew = crew
	PlayerData.campaign["crew_chosen"] = true
	PlayerData.autosave()
	_leave(next_scene)


func _leave(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave(back_scene)
		get_viewport().set_input_as_handled()
