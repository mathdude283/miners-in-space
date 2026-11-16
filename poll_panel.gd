class_name PollPanel
extends PanelContainer
## A go/no-go poll. Used twice: the Launch Director's final poll before the terminal count, and the
## flight team's calls on the way up. The player asks the room, hears each station answer, then makes
## the call. The ship's own problems come back as NO-GOs from the stations that care about them.

signal decided(choice: String)   # launch: "go" | "override" | "scrub"     ascent: "go" | "abort"

const GO_COLOR := Color("c8ff36")

var _mode := "launch"
var _rows: Array[Dictionary] = []
var _row_nodes: Array[Dictionary] = []     # {status, call}
var _title: Label
var _role: Label
var _ntd: Label
var _poll_btn: Button
var _primary: Button
var _secondary: Button
var _third: Label
var _polled := false
var _busy := false
var _can_abort := true
var did_hold := false


## mode "launch": final poll.  mode "ascent": a milestone poll in flight.
func setup(mode: String, title_text: String, role_text: String, rows: Array[Dictionary]) -> void:
	_mode = mode
	_rows = rows
	add_theme_stylebox_override("panel", UiStyle.panel(26, 0.94))
	custom_minimum_size = Vector2(1100 if mode == "launch" else 1000, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	col.add_child(UiStyle.mono_label(role_text, 15, UiStyle.PHOSPHOR))
	_title = UiStyle.heading(title_text)
	_title.add_theme_font_size_override("font_size", 34)
	col.add_child(_title)

	_role = Label.new()
	_role.add_theme_font_size_override("font_size", 19)
	_role.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.85))
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_role)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	col.add_child(grid)
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.custom_minimum_size = Vector2(0, 38)
		var name_l := UiStyle.mono_label(String(r["name"]), 17, UiStyle.NEAR_WHITE)
		name_l.custom_minimum_size = Vector2(150, 0)
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_l)
		var who := UiStyle.mono_label(String(r["who"]), 14, Color(UiStyle.NEAR_WHITE, 0.55))
		who.custom_minimum_size = Vector2(210, 0)
		who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(who)
		var status := UiStyle.mono_label("WAITING", 17, Color(UiStyle.NEAR_WHITE, 0.4))
		status.custom_minimum_size = Vector2(104, 0)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(status)
		var call := Label.new()
		call.add_theme_font_size_override("font_size", 17)
		call.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.92))
		call.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		call.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		call.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART        # long warnings wrap instead of being cut off
		call.custom_minimum_size = Vector2(420, 0)
		row.add_child(call)
		grid.add_child(row)
		_row_nodes.append({"status": status, "call": call})

	_ntd = UiStyle.mono_label("", 16, UiStyle.CHROME)
	_ntd.custom_minimum_size = Vector2(0, 40)
	col.add_child(_ntd)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	_third = UiStyle.mono_label("", 14, Color(UiStyle.NEAR_WHITE, 0.6))
	_third.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_third.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_third.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_third.custom_minimum_size = Vector2(0, 72)
	buttons.add_child(_third)
	_secondary = Button.new()
	_secondary.theme_type_variation = &"OutlineButton"
	_secondary.add_theme_font_size_override("font_size", 19)
	_secondary.custom_minimum_size = Vector2(0, 56)
	_secondary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_secondary.pressed.connect(_on_secondary)
	buttons.add_child(_secondary)
	_primary = Button.new()
	_primary.theme_type_variation = &"PrimaryButton"
	_primary.add_theme_font_size_override("font_size", 24)
	_primary.custom_minimum_size = Vector2(580, 96)
	_primary.pressed.connect(_on_primary)
	buttons.add_child(_primary)
	col.add_child(buttons)

	_role.text = "You are the Launch Director in the Launch Control Center. Ask each station for a go or no-go, then make the final call." if mode == "launch" else "Flight control polls the room. Decide: go, or call an abort."
	_primary.text = "POLL THE ROOM"
	_secondary.hide()
	_third.text = "Nobody answers until you ask."
	_primary.grab_focus()


func set_can_abort(on: bool) -> void:
	_can_abort = on


func _wait(sec: float) -> void:
	# Real time, even while the flight behind the panel is slowed down.
	await get_tree().create_timer(sec, true, false, true).timeout


func _on_primary() -> void:
	if _busy:
		return
	if not _polled:
		await _run_poll()
		return
	match _primary.get_meta("action", ""):
		"go":
			decided.emit("go")
		"abort":
			decided.emit("abort")
		"hold":
			await _run_hold()
		"scrub":
			decided.emit("scrub")


func _on_secondary() -> void:
	if _busy or not _polled:
		return
	match _secondary.get_meta("action", ""):
		"override":
			decided.emit("override")
		"go":
			decided.emit("go")
		"abort":
			decided.emit("abort")
		"scrub":
			decided.emit("scrub")


func _run_poll() -> void:
	_busy = true
	_primary.disabled = true
	_third.text = "Polling..."
	for i in _rows.size():
		var r := _rows[i]
		var st: Label = _row_nodes[i]["status"]
		var cl: Label = _row_nodes[i]["call"]
		st.text = "STAND BY"
		st.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.75))
		await _wait(0.42)
		_show_row(i)
		await _wait(0.2)
	_polled = true
	_busy = false
	_primary.disabled = false
	_after_poll()


func _show_row(i: int) -> void:
	var r := _rows[i]
	var st: Label = _row_nodes[i]["status"]
	var cl: Label = _row_nodes[i]["call"]
	if r["go"]:
		st.text = "GO"
		Sfx.play("beep", -7.0, 1.35)
		st.add_theme_color_override("font_color", GO_COLOR)
		cl.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.92))
	else:
		st.text = "NO-GO"
		Sfx.play("nogo", -5.0)
		st.add_theme_color_override("font_color", UiStyle.CORAL)
		cl.add_theme_color_override("font_color", UiStyle.CORAL)
	cl.text = String(r["call"])


func _after_poll() -> void:
	var bad := 0
	for r in _rows:
		if not r["go"]:
			bad += 1
	if _mode == "launch":
		_ntd.text = "NTD: " + GroundControl.ntd_line(_rows)
	else:
		_ntd.text = "Flight Director: all stations, report." if bad == 0 else "Flight Director: %d %s reporting no-go." % [bad, "station" if bad == 1 else "stations"]

	var blockers := GroundControl.blockers(_rows)
	var ship := GroundControl.ship_no_gos(_rows)
	_secondary.show()
	if _mode == "launch":
		if not blockers.is_empty():
			_primary.text = "HOLD THE COUNT"
			_primary.set_meta("action", "hold")
			_secondary.hide()
			_third.text = "The range cannot be overridden. Hold while the Eastern Range runs a test."
		elif ship.is_empty():
			_primary.text = "GO FOR TERMINAL COUNT"
			_primary.set_meta("action", "go")
			_secondary.text = "Scrub"
			_secondary.set_meta("action", "scrub")
			_third.text = "Every station is go. The final call is yours."
		else:
			_primary.text = "HOLD  -  FIX THE SHIP"
			_primary.set_meta("action", "scrub")
			_secondary.text = "LAUNCH ANYWAY"
			_secondary.set_meta("action", "override")
			_third.text = "These are no-goes on your ship. You can still launch. If the ship fails, the mission data is lost."
	else:
		if bad == 0:
			_primary.text = "GO"
			_primary.set_meta("action", "go")
			_secondary.text = "Call abort (game)"
			_secondary.set_meta("action", "abort")
			_secondary.visible = _can_abort
			_third.text = "All stations are go."
		else:
			_primary.text = "CALL ABORT" if _can_abort else "NO ABORT LEFT"
			_primary.set_meta("action", "abort")
			_primary.disabled = not _can_abort
			_secondary.text = "GO ANYWAY"
			_secondary.set_meta("action", "go")
			_third.text = "Abort pulls the crew module clear. The mission data is lost. Going anyway risks the ship."
	Sfx.play("go" if bad == 0 and blockers.is_empty() else "stage", -3.0)
	_primary.grab_focus()


## The Eastern Range finds a flight termination system issue and calls no-go until a confidence test
## passes (a real Artemis II launch-day event). The player holds; the test runs; the range goes green.
func _run_hold() -> void:
	did_hold = true
	Sfx.play("hold")
	_busy = true
	_primary.disabled = true
	_third.text = "HOLD. Engineers are running a confidence test on the flight termination system..."
	_ntd.text = "NTD: Launch Director, NTD. We are holding."
	await _wait(3.4)
	var fixed := GroundControl.stations(PlayerData.get_build(), false)
	for i in _rows.size():
		if String(_rows[i]["id"]) == "range":
			_rows[i] = fixed[i]
			_show_row(i)
	_busy = false
	_primary.disabled = false
	_after_poll()
	Sfx.play("go")
	_third.text = "Confidence test passed. The range is green. " + _third.text
