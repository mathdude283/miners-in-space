extends Control
## Build stage. The player fits rooms and equipment into six bays. Every part costs weight, power
## and budget, so choosing one thing means giving up another. Hovering a part previews its cost on
## the meters before the player commits.

const STATUS_OK: Texture2D = preload("res://assets/ui/build/icons/status_check_ready.png")
const STATUS_BAD: Texture2D = preload("res://assets/ui/build/icons/status_check_blocked.png")
const ICON_KIT: Texture2D = preload("res://assets/ui/build/icons/equipment_cargo_crate.png")
const ICON_WING: Texture2D = preload("res://assets/ui/build/icons/equipment_solar_array.png")
const ICON_LENS: Texture2D = preload("res://assets/ui/build/icons/overlay_lunar_camera_reticle.png")

@export_file("*.tscn") var next_scene: String = "res://flight.tscn"
@export_file("*.tscn") var back_scene: String = "res://mission_select.tscn"

@onready var background: TextureRect = $Background
@onready var stars: CPUParticles2D = $Stars
@onready var header: Control = $Safe/Column/Header
@onready var top: Control = $Safe/Column/Top
@onready var mission_panel: PanelContainer = $Safe/Column/Top/MissionPanel
@onready var ship: ShipView = $Safe/Column/Top/ShipView
@onready var meters_panel: PanelContainer = $Safe/Column/Top/MetersPanel
@onready var detail_panel: PanelContainer = $Safe/Column/DetailPanel
@onready var message: RichTextLabel = $Safe/Column/Footer/Message
@onready var lower: Control = $Safe/Column/Lower
@onready var rooms_panel: PanelContainer = $Safe/Column/Lower/RoomsPanel
@onready var equip_panel: PanelContainer = $Safe/Column/Lower/EquipPanel
@onready var checks_panel: PanelContainer = $Safe/Column/Lower/ChecksPanel
@onready var footer: Control = $Safe/Column/Footer
@onready var back_button: BaseButton = $Safe/Column/Footer/BackButton
@onready var undo_button: Button = $Safe/Column/Footer/UndoButton
@onready var clear_button: Button = $Safe/Column/Footer/ClearButton
@onready var status_label: Label = $Safe/Column/Footer/Status/StatusLabel
@onready var note_label: Label = $Safe/Column/Footer/Status/NoteLabel
@onready var continue_button: Button = $Safe/Column/Footer/ContinueButton
@onready var fade: ColorRect = $Fade

var state: BuildState
var _room_cards: Dictionary = {}          # room id -> PartCard
var _equip_cards: Dictionary = {}         # "kit" / "wing1" / "wing2" / "wide" / "close" -> PartCard
var _meter_mass: SegmentMeter
var _meter_power: SegmentMeter
var _meter_budget: SegmentMeter
var _bays_label: Label
var _ahead_label: Label
var _check_rows: VBoxContainer
var _hover_part: Dictionary = {}
var _inspect: Dictionary = {}              # the part picked to read about
var inspector: PartInspector
var _hover_bay := -1
var _flash := ""
var _flash_token := 0
var _problem_keys: Array[String] = []
var _just_fixed: Array[String] = []
var _quiet := false                       # true while a whole plan is loaded, cleared or undone
var _leaving := false


var _was_over := false


func _ready() -> void:
	_keep_footer_visible()
	Music.play("design")
	state = PlayerData.get_build()
	_build_mission_panel()
	_build_meters_panel()
	_build_rooms_panel()
	_build_equipment_panel()
	_build_checks_panel()
	_build_inspector()

	ship.bind(state)
	ship.bay_picked.connect(_on_bay_picked)
	ship.bay_remove.connect(_on_bay_remove)
	ship.bay_hovered.connect(_on_bay_hovered)
	state.changed.connect(_refresh)

	undo_button.pressed.connect(func(): _undo())
	clear_button.pressed.connect(_on_clear)
	back_button.pressed.connect(func(): _leave(back_scene))
	continue_button.pressed.connect(func(): _leave(next_scene))
	continue_button.resized.connect(func(): continue_button.pivot_offset = continue_button.size * 0.5)

	_fit_to_size()
	resized.connect(_fit_to_size)
	# The Build page stays calm on purpose: only the corner ornaments (HudFrame) decorate it.
	_refresh()
	_calm_background()
	_play_intro()
	if PlayerData.scrub_note != "":
		_say(PlayerData.scrub_note, UiStyle.AMBER)
		PlayerData.scrub_note = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		_undo()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_leave(back_scene)
		get_viewport().set_input_as_handled()


## Back, Undo, Clear and Continue must always be on screen. The footer is pulled out of the tall column and pinned under it,
## and the column (ship, parts, checklist) scrolls inside the space that is left when the window is too short.
func _keep_footer_visible() -> void:
	var safe: MarginContainer = $Safe
	var column: VBoxContainer = $Safe/Column
	var footer: Control = $Safe/Column/Footer
	column.remove_child(footer)
	safe.remove_child(column)
	var outer := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.get_node("Top").custom_minimum_size.y = 316.0
	outer.add_theme_constant_override("separation", 6)
	safe.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	outer.add_child(footer)


## Designed on a 1920x1080 frame; on a wider or taller window the frame stays centered.
const FRAME := Vector2(1920, 1080)

func _fit_to_size() -> void:
	var extra := (size - FRAME).max(Vector2.ZERO) * 0.5
	var safe: MarginContainer = $Safe
	safe.add_theme_constant_override("margin_left", 90 + int(extra.x))
	safe.add_theme_constant_override("margin_right", 90 + int(extra.x))
	safe.add_theme_constant_override("margin_top", 14 + int(extra.y))
	safe.add_theme_constant_override("margin_bottom", 12 + int(extra.y))
	background.pivot_offset = size * 0.5
	stars.position = size * 0.5
	stars.emission_rect_extents = size * 0.5


# =====================================================================
# Panels
# =====================================================================

func _style_panel(p: PanelContainer, margin := 18) -> void:
	p.add_theme_stylebox_override("panel", UiStyle.panel(margin))


func _build_mission_panel() -> void:
	_style_panel(mission_panel, 20)
	var idx := 0
	if PlayerData.scenario != null:
		idx = clampi(int(PlayerData.scenario), 0, Missions.LIST.size() - 1)
	var m: Dictionary = Missions.LIST[idx]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	mission_panel.add_child(box)
	box.add_child(UiStyle.mono_label(String(m["tag"]), 14, UiStyle.PHOSPHOR))
	var name_label := UiStyle.heading(String(m["name"]))
	name_label.add_theme_font_size_override("font_size", 28)
	box.add_child(name_label)
	var obj := Label.new()
	obj.text = m["objective"]
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj.add_theme_font_size_override("font_size", 18)
	obj.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.92))
	box.add_child(obj)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for e in m["evidence"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.chip(UiStyle.CHROME))
		chip.add_child(UiStyle.mono_label(String(e), 14))
		flow.add_child(chip)
	box.add_child(flow)
	# The ship is locked after the first contract, so say now what later contracts will need
	if idx == 0 and not Missions.later_needs(0, null).is_empty():
		_ahead_label = Label.new()
		_ahead_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ahead_label.add_theme_font_size_override("font_size", 16)
		box.add_child(_ahead_label)


func _build_meters_panel() -> void:
	_style_panel(meters_panel, 20)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	meters_panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_child(UiStyle.heading("SHIP LIMITS"))
	box.add_child(head)
	_meter_mass = _make_meter("WEIGHT", 1)
	_meter_power = _make_meter("POWER USED / MADE", 1)
	_meter_budget = _make_meter("BUDGET", 3)
	_meter_mass.fix_pressed.connect(_on_fix.bind("mass"))
	_meter_power.fix_pressed.connect(_on_fix.bind("power"))
	_meter_budget.fix_pressed.connect(_on_fix.bind("cost"))
	box.add_child(_meter_mass)
	box.add_child(_meter_power)
	box.add_child(_meter_budget)
	_bays_label = UiStyle.mono_label("", 16, Color(UiStyle.NEAR_WHITE, 0.9))
	box.add_child(_bays_label)


func _make_meter(title: String, seg_units: int) -> SegmentMeter:
	var m := SegmentMeter.new()
	m.title = title
	m.segment_units = seg_units
	m.custom_minimum_size = Vector2(0, 76)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return m


func _build_rooms_panel() -> void:
	_style_panel(rooms_panel, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	rooms_panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UiStyle.heading("ROOMS"))
	var hint := UiStyle.mono_label("USE EACH ONCE  -  6 BAYS", 14, Color(UiStyle.NEAR_WHITE, 0.7))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var start := UiStyle.mono_label("START FROM", 14, Color(UiStyle.NEAR_WHITE, 0.7))
	start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(start)
	for i in ShipData.STARTERS.size():
		var b := Button.new()
		b.text = String(ShipData.STARTERS[i]["name"])
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(_load_starter.bind(i))
		head.add_child(b)
	box.add_child(head)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for r in ShipData.ROOMS:
		var data: Dictionary = r.duplicate()
		data["texture"] = ShipData.room_texture(r["id"])
		data["kind"] = "room"
		data["uid"] = "r:" + String(r["id"])
		var card := PartCard.make(data, true)
		card.chosen.connect(_on_part_picked)
		card.activated.connect(_activate)
		card.hovered.connect(_on_part_hovered)
		grid.add_child(card)
		_room_cards[r["id"]] = card


func _build_equipment_panel() -> void:
	_style_panel(equip_panel, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	equip_panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UiStyle.heading("EQUIPMENT"))
	box.add_child(head)

	var R := ShipData.RULES
	var defs := [
		["kit", {"name": ShipData.KIT["name"], "mass": ShipData.KIT["mass"], "power": ShipData.KIT["power"], "cost": ShipData.KIT["cost"], "texture": ICON_KIT, "kind": "kit", "key": "kit", "uid": "e:kit"}],
		["wing1", {"name": "Solar wing 1", "mass": R["wing_mass"], "power": 0, "cost": R["wing_cost"], "texture": ICON_WING, "kind": "wing", "gen": R["wing_power"], "key": "wing1", "uid": "e:wing1"}],
		["wing2", {"name": "Solar wing 2", "mass": R["wing_mass"], "power": 0, "cost": R["wing_cost"], "texture": ICON_WING, "kind": "wing", "gen": R["wing_power"], "key": "wing2", "uid": "e:wing2"}],
		["wide", {"name": "Wide lens", "mass": R["lens_mass"], "power": 0, "cost": R["lens_cost"], "texture": ICON_LENS, "kind": "lens", "key": "wide", "uid": "e:wide"}],
		["close", {"name": "Close-up lens", "mass": R["lens_mass"], "power": 0, "cost": R["lens_cost"], "texture": ICON_LENS, "kind": "lens", "key": "close", "uid": "e:close"}],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for d in defs:
		var card := PartCard.make(d[1], false)
		card.chosen.connect(_on_part_picked)
		card.activated.connect(_activate)
		card.hovered.connect(_on_part_hovered)
		grid.add_child(card)
		_equip_cards[d[0]] = card


func _build_inspector() -> void:
	# The panel node stays; the inspector fills it.
	detail_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	inspector = PartInspector.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(inspector)
	inspector.action_pressed.connect(func(): _activate(_shown_part()))


func _build_checks_panel() -> void:
	_style_panel(checks_panel, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	checks_panel.add_child(box)
	box.add_child(UiStyle.heading("CHECKLIST"))
	_check_rows = VBoxContainer.new()
	_check_rows.add_theme_constant_override("separation", 1)
	box.add_child(_check_rows)


# =====================================================================
# Actions
# =====================================================================

## One click picks a part to read about. Nothing is added until the player presses the button
## (or double-clicks), so they can read first.
func _on_part_picked(part: Dictionary) -> void:
	_inspect = part
	_sync_picked()
	_refresh_detail()


func _sync_picked() -> void:
	var uid := String(_inspect.get("uid", ""))
	for id in _room_cards:
		_room_cards[id].set_picked(uid == "r:" + String(id))
	for k in _equip_cards:
		_equip_cards[k].set_picked(uid == "e:" + String(k))


## Add the part, or take it out if it is already in the ship.
func _activate(part: Dictionary) -> void:
	if part.is_empty():
		return
	if String(part.get("kind", "room")) == "room":
		_on_room_chosen(part)
	else:
		_on_equipment_chosen(part, String(part["key"]))


func _on_room_chosen(part: Dictionary) -> void:
	# A room that is already in the ship comes out when its tile is clicked again.
	if state.has_room(String(part["id"])):
		state.remove_bay(state.bays.find(String(part["id"])))
		Sfx.play("remove")
		_say("%s is out. Undo brings it back." % part["name"])
		return
	var want := ship.selected_bay()
	var at := state.place_room(String(part["id"]), want)
	ship.clear_selection()
	if at < 0:
		Sfx.play("error")
		_say("No free bay. Take a room out first.", UiStyle.CORAL)
	else:
		Sfx.play("add")
		var left := ShipData.RULES["bays"] - state.used_bays()
		_say("%s is in bay %d. %d %s free." % [part["name"], at + 1, left, "bay" if left == 1 else "bays"])


func _on_equipment_chosen(_part: Dictionary, key: String) -> void:
	if key == "wing2" and state.wings < 1:
		Sfx.play("error")
		_say("Add solar wing 1 first.", UiStyle.AMBER)
		return
	match key:
		"kit":
			state.toggle_kit()
		"wing1":
			state.set_wings(0 if state.wings == 1 else 1)
		"wing2":
			state.set_wings(1 if state.wings == 2 else 2)
		"wide":
			state.toggle_wide()
		"close":
			state.toggle_close()
	var now_on := false
	match key:
		"kit":
			now_on = state.kit
		"wing1":
			now_on = state.wings >= 1
		"wing2":
			now_on = state.wings >= 2
		"wide":
			now_on = state.wide
		"close":
			now_on = state.close
	Sfx.play("add" if now_on else "remove")


func _on_bay_picked(index: int) -> void:
	if state.bays[index] == "":
		_say("Bay %d is next. Pick a room." % (index + 1))
	else:
		_inspect = _room_part(state.bays[index])
		_sync_picked()
		_refresh_detail()


func _on_bay_remove(index: int) -> void:
	var id := state.bays[index]
	if id == "":
		return
	state.remove_bay(index)
	Sfx.play("remove")
	_say("%s is out. Undo brings it back." % ShipData.room(id)["name"])


func _undo() -> void:
	if state.can_undo():
		_quiet = true
		state.undo()
		_quiet = false
		Sfx.play("back")
		_say("Undone.")


func _on_clear() -> void:
	if state.is_empty():
		return
	_quiet = true
	state.clear()
	_quiet = false
	_say("Ship cleared. Undo brings it back.")


func _load_starter(i: int) -> void:
	var s: Dictionary = ShipData.STARTERS[i]
	_quiet = true
	state.load_starter(s)
	_quiet = false
	_say("%s loaded. %s" % [s["name"], s["note"]])


## A hint, not an automatic fix: it says what would help and lights up where to find it,
## so the player still makes the change.
func _on_fix(key: String) -> void:
	var msg := ""
	var target: Control = null
	if key.begins_with("fn:"):
		var def: Dictionary = ShipData.FUNCTIONS[key.substr(3)]
		var room_name: String = ShipData.room(def["room"])["name"]
		if def["kit"]:
			msg = "%s is missing. The crew kit covers it, or you can add the %s." % [def["label"], room_name]
			target = _equip_cards["kit"]
		else:
			msg = "%s is missing. Try adding the %s." % [def["label"], room_name]
			target = _room_cards[def["room"]]
	elif key == "camera":
		msg = "No window. The Observation Bay is the window."
		target = _room_cards["observation"]
	elif key == "lens":
		msg = "No lens. Pack the wide lens, the close-up lens, or both."
		target = _equip_cards["wide"]
	elif key == "mass" or key == "cost":
		var e := state.extras(false)
		if not e.is_empty():
			msg = "The %s repeats a job another part already does. Taking it out saves weight and budget." % ShipData.room(e[0]["id"])["name"]
			target = ship.bay_slot(int(e[0]["i"]))
		elif state.close and state.wide:
			msg = "Two lenses cost weight and budget. One may be enough."
			target = _equip_cards["close"]
		else:
			msg = "Every part is doing a job. Swap something for a lighter or cheaper part."
	elif key == "power":
		if state.wings < int(ShipData.RULES["wings_max"]):
			msg = "Not enough power. Solar wings make more."
			target = _equip_cards["wing1" if state.wings < 1 else "wing2"]
		else:
			var pe := state.extras(true)
			if not pe.is_empty():
				msg = "The %s repeats a job and uses power. Taking it out frees some." % ShipData.room(pe[0]["id"])["name"]
				target = ship.bay_slot(int(pe[0]["i"]))
			else:
				msg = "Every part uses power. Swap a power-hungry room for a lighter one."
	Sfx.play("steady")
	_say(msg, UiStyle.AMBER)
	if target != null:
		_pulse(target)


func _pulse(c: Control) -> void:
	var tw := create_tween()
	for i in 2:
		tw.tween_property(c, "modulate", Color(1.9, 1.9, 1.9, 1.0), 0.16)
		tw.tween_property(c, "modulate", Color.WHITE, 0.22)


## If a change fixed something and no other message took the news, say it on its own.
func _flush_fixed() -> void:
	if _just_fixed.is_empty():
		return
	var names := ", ".join(_just_fixed)
	_just_fixed.clear()
	Sfx.play("go", -3.0)
	_flash = "[color=#c8ff36][b]Fixed: %s.[/b][/color]" % names
	_flash_token += 1
	var token := _flash_token
	_refresh_detail()
	get_tree().create_timer(3.2).timeout.connect(func():
		if token == _flash_token:
			_flash = ""
			_refresh_detail())


func _on_part_hovered(part: Dictionary) -> void:
	_hover_part = part
	_refresh_preview()
	_refresh_detail()


func _on_bay_hovered(index: int) -> void:
	_hover_bay = index
	_refresh_preview()
	_refresh_detail()


func _say(text: String, color: Color = UiStyle.PHOSPHOR) -> void:
	_flash = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	if not _just_fixed.is_empty():
		_flash += "  [color=#c8ff36][b]Fixed: %s.[/b][/color]" % ", ".join(_just_fixed)
		_just_fixed.clear()
	_flash_token += 1
	var token := _flash_token
	_refresh_detail()
	get_tree().create_timer(3.2).timeout.connect(func():
		if token == _flash_token:
			_flash = ""
			_refresh_detail())


# =====================================================================
# Refresh
# =====================================================================

func _refresh() -> void:
	var t := state.totals()
	var R := ShipData.RULES

	for id in _room_cards:
		_room_cards[id].set_state(state.has_room(id))
	_equip_cards["kit"].set_state(state.kit)
	_equip_cards["wing1"].set_state(state.wings >= 1)
	_equip_cards["wing2"].set_state(state.wings >= 2, "" if state.wings >= 1 else "ADD WING 1")
	_equip_cards["wide"].set_state(state.wide)
	_equip_cards["close"].set_state(state.close)

	_bays_label.text = "BAYS  %d / %d USED" % [state.used_bays(), R["bays"]]
	if _ahead_label != null:
		var bits: Array[String] = []
		var all_ok := true
		for n in Missions.later_needs(0, state):
			bits.append(("[X] " if n["ok"] else "[  ] ") + String(n["text"]))
			all_ok = all_ok and bool(n["ok"])
		_ahead_label.text = "PLAN AHEAD: this ship is locked for the whole game once this contract is done.\n" + "\n".join(bits)
		_ahead_label.add_theme_color_override("font_color", UiStyle.PHOSPHOR if all_ok else UiStyle.AMBER)
	_refresh_preview()
	_refresh_checks()

	undo_button.disabled = not state.can_undo()
	clear_button.disabled = state.is_empty()
	var problems := state.problems()
	# Say so when a problem has been solved. The player did the fixing; the page just notices.
	var keys: Array[String] = []
	for p in problems:
		keys.append(String(p["key"]))
	var solved: Array[String] = []
	for c in state.checks():
		if _problem_keys.has(String(c["key"])) and not keys.has(String(c["key"])):
			solved.append(String(c["label"]))
	var first_refresh := _problem_keys.is_empty() and _flash == "" and state.is_empty()
	_problem_keys = keys
	if not solved.is_empty() and not first_refresh and not _quiet:
		_just_fixed = solved
		_flush_fixed.call_deferred()
	# Only money stops a launch. Every other problem can fly, and fails in flight.
	var over_budget := int(t["cost"]) > int(R["budget_limit"])
	continue_button.disabled = over_budget
	if over_budget and not _was_over:
		Sfx.play("error")
	_was_over = over_budget
	if over_budget:
		status_label.text = "OVER BUDGET"
		status_label.add_theme_color_override("font_color", UiStyle.CORAL)
		note_label.text = "Take something out to launch."
		continue_button.text = "OVER BUDGET"
		continue_button.modulate = Color.WHITE
	elif problems.is_empty():
		status_label.text = "READY TO FLY"
		status_label.add_theme_color_override("font_color", UiStyle.PHOSPHOR)
		note_label.text = ""
		continue_button.text = "CONTINUE"
		continue_button.modulate = Color.WHITE
	else:
		status_label.text = "%d %s" % [problems.size(), "PROBLEM" if problems.size() == 1 else "PROBLEMS"]
		status_label.add_theme_color_override("font_color", UiStyle.AMBER)
		note_label.text = "It can still fly. A failed flight loses the mission data."
		continue_button.text = "FLY ANYWAY"
		continue_button.modulate = Color(1.0, 0.84, 0.55)
	_refresh_detail()


## Shows what the part under the pointer would do to each meter.
func _refresh_preview() -> void:
	var t := state.totals()
	var R := ShipData.RULES
	var d := _delta_for(_hover_part, _hover_bay)
	_meter_mass.set_values(int(t["mass"]), int(R["mass_limit"]), int(d["mass"]))
	_meter_power.set_values(int(t["draw"]), int(t["gen"]), int(d["draw"]), int(d["gen"]))
	_meter_budget.set_values(int(t["cost"]), int(R["budget_limit"]), int(d["cost"]))


## Change a hovered part (or a hovered bay's room, if it were taken out) would make.
func _delta_for(part: Dictionary, bay: int) -> Dictionary:
	var out := {"mass": 0, "draw": 0, "cost": 0, "gen": 0}
	var R := ShipData.RULES
	if not part.is_empty():
		match String(part.get("kind", "room")):
			"room":
				var sg := -1 if state.has_room(String(part["id"])) else 1
				out["mass"] = sg * int(part["mass"])
				out["draw"] = sg * int(part["power"])
				out["cost"] = sg * int(part["cost"])
			"kit":
				var sign := -1 if state.kit else 1
				out["mass"] = sign * int(ShipData.KIT["mass"])
				out["draw"] = sign * int(ShipData.KIT["power"])
				out["cost"] = sign * int(ShipData.KIT["cost"])
			"wing":
				var is_wing2 := String(part["name"]).ends_with("2")
				var adding := (state.wings < 2) if is_wing2 else (state.wings < 1)
				if is_wing2 and state.wings < 1:
					return out
				var sg := 1 if adding else -1
				out["mass"] = sg * int(R["wing_mass"])
				out["cost"] = sg * int(R["wing_cost"])
				out["gen"] = sg * int(R["wing_power"])
			"lens":
				var on := state.wide if String(part["name"]).begins_with("Wide") else state.close
				var s2 := -1 if on else 1
				out["mass"] = s2 * int(R["lens_mass"])
				out["cost"] = s2 * int(R["lens_cost"])
	elif bay >= 0 and state.bays[bay] != "":
		var r := ShipData.room(state.bays[bay])
		out["mass"] = -int(r["mass"])
		out["draw"] = -int(r["power"])
		out["cost"] = -int(r["cost"])
	# a negative capacity change is not drawn as a ghost; the words still say it
	out["gen"] = maxi(int(out["gen"]), 0)
	return out


func _refresh_checks() -> void:
	for c in _check_rows.get_children():
		c.queue_free()
	var rows: Array[Dictionary] = []
	for c in state.checks():
		if c["group"] != "limits":
			rows.append(c)
	for c in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 26)
		var icon := TextureRect.new()
		icon.texture = STATUS_OK if c["ok"] else STATUS_BAD
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(22, 22)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var label := UiStyle.mono_label(String(c["label"]).to_upper(), 15, UiStyle.NEAR_WHITE if c["ok"] else UiStyle.AMBER)
		label.custom_minimum_size = Vector2(176, 0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		var why := UiStyle.mono_label(String(c["why"]), 15, Color(UiStyle.NEAR_WHITE, 0.78) if c["ok"] else UiStyle.CORAL)
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		why.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		why.clip_text = true
		row.add_child(why)
		if not c["ok"]:
			var fix := Button.new()
			fix.text = "Hint"
			fix.tooltip_text = String(c["fix"])
			UiStyle.compact_button(fix, 15, 26)
			fix.pressed.connect(_on_fix.bind(String(c["key"])))
			row.add_child(fix)
		_check_rows.add_child(row)


## The part the inspector shows: what is under the pointer, else what was picked.
func _shown_part() -> Dictionary:
	if not _hover_part.is_empty():
		return _hover_part
	if _hover_bay >= 0 and state.bays[_hover_bay] != "":
		return _room_part(state.bays[_hover_bay])
	return _inspect


func _refresh_detail() -> void:
	var part := _shown_part()
	if part.is_empty():
		inspector.show_empty("Click any room or equipment to read what it is, then press the button to add it.")
	else:
		var kind := String(part.get("kind", "room"))
		var info_key := String(part["id"]) if kind == "room" else (String(part["kind"]) if kind in ["wing", "kit"] else String(part["key"]))
		var action := ""
		var enabled := true
		match kind:
			"room":
				if state.has_room(String(part["id"])):
					action = "TAKE OUT"
				else:
					var at := ship.selected_bay()
					var free := state.first_empty()
					if free < 0:
						action = "NO FREE BAY"
						enabled = false
					else:
						action = "ADD TO BAY %d" % ((at if (at >= 0 and state.bays[at] == "") else free) + 1)
			"kit":
				action = "TAKE OUT" if state.kit else "ADD TO SHIP"
			"wing":
				var is2 := String(part["key"]) == "wing2"
				if is2 and state.wings < 1:
					action = "ADD WING 1 FIRST"
					enabled = false
				else:
					action = "TAKE OUT" if state.wings >= (2 if is2 else 1) else "ADD TO SHIP"
			"lens":
				var on := state.wide if String(part["key"]) == "wide" else state.close
				action = "TAKE OUT" if on else "ADD TO SHIP"
		inspector.show_part(part, ShipData.info(info_key), action, enabled)
	message.text = _flash if _flash != "" else _coach()




func _room_part(id: String) -> Dictionary:
	var p := ShipData.room(id).duplicate()
	p["kind"] = "room"
	return p


## One line of advice: the first problem, or what is spare when the ship is ready.
func _coach() -> String:
	var problems := state.problems()
	if state.is_empty():
		return "[color=#c8ff36]Design your own ship.[/color] Six bays, three limits. Every part costs something, so choose what matters."
	if problems.is_empty():
		var t := state.totals()
		return "[color=#c8ff36]Ready to fly.[/color] Spare: %d weight, %d power, %d budget, %d bays." % [
			int(t["mass_left"]), int(t["margin"]), int(t["budget_left"]), ShipData.RULES["bays"] - state.used_bays()]
	var p: Dictionary = problems[0]
	var more := "" if problems.size() == 1 else "   (+%d more)" % (problems.size() - 1)
	return "[color=#ffc45e]%s: %s.[/color] Try: %s.%s" % [p["label"], String(p["why"]).to_lower(), String(p["fix"]).to_lower(), more]


# =====================================================================
# Motion and flow
# =====================================================================

func _leave(scene_path: String) -> void:
	if _leaving:
		return
	_leaving = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween().set_parallel()
	tw.tween_property(fade, "color:a", 1.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(background, "scale", background.scale * 1.05, 0.45).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(scene_path)


func _play_intro() -> void:
	fade.color.a = 1.0
	var parts: Array[Control] = [header, top, detail_panel, lower, footer]
	for p in parts:
		p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	var t := 0.15
	for p in parts:
		tw.parallel().tween_property(p, "modulate:a", 1.0, 0.45).set_delay(t)
		t += 0.1


## This page is dense and interactive, so the background holds still: no drift, no parallax,
## no scan band, no moving stars. Nothing moves unless the player does something.
func _calm_background() -> void:
	background.scale = Vector2.ONE
	stars.emitting = false
	stars.hide()
	var crt := $Crt as ColorRect
	if crt.material is ShaderMaterial:
		(crt.material as ShaderMaterial).set_shader_parameter("sweep_strength", 0.0)
