class_name FaultCard
extends Control
## A call from Mission Control, shown inside Mission Operations when the camera faults after the wide shot is taken and
## the close-up is still missing. The Flight Director chooses one of three responses; each says what the crew has to do
## aboard the ship and what it costs. The mission clock does not run while this is open (minutes only pass when the crew
## walks or works). All the numbers come from ShipInterior.fault_info(), which reads the same task rules that charge them.

signal chosen(route: String)

var info := {}
var _buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.09, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1560, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(22, 0.98))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	p.add_child(col)

	var head := HBoxContainer.new()
	var tag := UiStyle.mono_label("MISSION CONTROL   -   CALL FROM HOUSTON", 15, UiStyle.AMBER)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	head.add_child(UiStyle.mono_label("MISSION CLOCK PAUSED", 15, UiStyle.PHOSPHOR))
	col.add_child(head)
	var h := UiStyle.heading("CAMERA FAULT")
	h.add_theme_color_override("font_color", UiStyle.AMBER)
	col.add_child(h)
	col.add_child(_text("The camera dropped offline right after the wide shot. You have the wide image, which shows WHERE the basin is. The close-up would show WHAT THE SURFACE IS LIKE. Flight Director, what is your call?", 19, 1500.0))
	col.add_child(UiStyle.mono_label(String(info["now"]), 16, UiStyle.NEAR_WHITE))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	for r in info["routes"]:
		row.add_child(_route_panel(r))

	col.add_child(UiStyle.mono_label("YOUR CREW SAYS", 13, UiStyle.PHOSPHOR))
	var crew := HBoxContainer.new()
	crew.add_theme_constant_override("separation", 12)
	col.add_child(crew)
	for a in info["advice"]:
		crew.add_child(_advice(a))
	Sfx.play("error", -8.0, 0.8)


func _text(t: String, size: int, width: float) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _route_panel(r: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiStyle.panel(12, 0.92))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	var t := UiStyle.heading(String(r["title"]))
	t.add_theme_font_size_override("font_size", 24)
	v.add_child(t)
	v.add_child(_text(String(r["what"]), 16, 440.0))
	v.add_child(UiStyle.mono_label("%-26s %5s %5s %6s" % ["COSTS", "MIN", "POWER", "ENERGY"], 12, Color(UiStyle.NEAR_WHITE, 0.55)))
	for row in r["rows"]:
		var tag := String(row["label"])
		var line := UiStyle.mono_label("%-26s %5s %5s %6s" % [tag.substr(0, 26), _n(row["time"]), _n(row["power"]), _n(row["energy"])], 13, Color(UiStyle.NEAR_WHITE, 0.9) if not bool(row.get("later", false)) else Color(UiStyle.NEAR_WHITE, 0.6))
		v.add_child(line)
	var tot: Dictionary = r["total"]
	v.add_child(UiStyle.mono_label("%-26s %5s %5s %6s" % ["TOTAL", _n(tot["time"]), _n(tot["power"]), _n(tot["energy"])], 14, UiStyle.PHOSPHOR))
	var verdict := _text(String(r["verdict"]), 15, 440.0)
	verdict.add_theme_color_override("font_color", UiStyle.PHOSPHOR if bool(r["ok"]) else UiStyle.CORAL)
	v.add_child(verdict)
	var b := Button.new()
	b.text = "CHOOSE THIS" if bool(r["ok"]) else "NOT AVAILABLE"
	b.theme_type_variation = &"PrimaryButton" if bool(r["ok"]) else &"OutlineButton"
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(0, 62)
	b.disabled = not bool(r["ok"])
	b.focus_mode = Control.FOCUS_NONE
	var id := String(r["id"])
	b.pressed.connect(func(): chosen.emit(id))
	v.add_child(b)
	_buttons[id] = b
	return panel


func _n(x) -> String:
	var f := float(x)
	return "-" if f <= 0.0 else ("%d" % int(round(f)))


func _advice(a: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiStyle.panel(8, 0.9))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var pic := TextureRect.new()
	pic.texture = CrewData.portrait(String(a["char"]))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(64, 64)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiStyle.mono_label("%s   %s" % [String(a["name"]).to_upper(), a["role"]], 13, UiStyle.PHOSPHOR))
	v.add_child(_text(String(a["text"]), 15, 400.0))
	return panel


## Choose a route (public so a test can stand in for the click). Returns false if that route is not available.
func choose(route: String) -> bool:
	var b: Button = _buttons.get(route)
	if b == null or b.disabled:
		return false
	chosen.emit(route)
	return true
