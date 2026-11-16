class_name PartInspector
extends PanelContainer
## Reads out what a part is: its name and costs, WHY you would want it, WHAT you do in it, and a
## NASA fact (or a GAME note where NASA does not say). It has a fixed height so the page never jumps
## when the text changes, and it holds the one button that adds or takes out the part.

signal action_pressed

var _thumb: TextureRect
var _name: Label
var _chips: Label
var _source: Label
var _why: Label
var _do: Label
var _fact_tag: Label
var _fact: Label
var _flight_tag: Label
var _flight: Label
var _real: Label
var _real_tag: Label
var _real_row: Control
var _action: Button


func _ready() -> void:
	custom_minimum_size = Vector2(0, 190)
	add_theme_stylebox_override("panel", UiStyle.panel(12))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(96, 96)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_thumb)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	_name = UiStyle.heading("")
	title_row.add_child(_name)
	_chips = UiStyle.mono_label("", 16, UiStyle.PHOSPHOR)
	_chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_chips)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	_source = UiStyle.mono_label("", 13, Color(UiStyle.NEAR_WHITE, 0.55))
	_source.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_source)
	col.add_child(title_row)

	var why_pair := _line("WHY", UiStyle.PHOSPHOR)
	_why = why_pair[1]
	col.add_child(why_pair[0])
	var do_pair := _line("DO", UiStyle.PHOSPHOR)
	_do = do_pair[1]
	col.add_child(do_pair[0])
	var fact_pair := _line("NASA", UiStyle.CHROME)
	_fact_tag = fact_pair[2]
	_fact = fact_pair[1]
	col.add_child(fact_pair[0])
	var flight_pair := _line("FLIGHT", UiStyle.AMBER)
	_flight = flight_pair[1]
	_flight_tag = flight_pair[2]
	col.add_child(flight_pair[0])
	# REAL spacecraft numbers from the team's spacecraft sheet (kg, W, $M). Game units on the Build screen are different.
	var real_pair := _line("REAL", UiStyle.PHOSPHOR)
	_real = real_pair[1]
	_real.clip_text = false
	_real.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_real.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_real.add_theme_font_size_override("font_size", 14)
	_real.add_theme_color_override("font_color", Color(UiStyle.PHOSPHOR, 0.85))
	_real_tag = real_pair[2]
	_real_row = real_pair[0]
	col.add_child(_real_row)

	_action = Button.new()
	_action.theme_type_variation = &"OutlineButton"
	_action.add_theme_font_size_override("font_size", 20)
	_action.custom_minimum_size = Vector2(210, 56)
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action.pressed.connect(func(): action_pressed.emit())
	row.add_child(_action)
	show_empty("Click any room or equipment to read what it is, then press the button to add it.")


## Returns [row, text label, tag label].
func _line(tag: String, tag_color: Color) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var t := UiStyle.mono_label(tag, 14, tag_color)
	t.custom_minimum_size = Vector2(52, 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.93))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	return [h, l, t]


func show_empty(text: String) -> void:
	_thumb.texture = null
	_name.text = "PICK A PART"
	_chips.text = ""
	_source.text = ""
	_why.text = text
	_do.text = ""
	_fact.text = ""
	_fact_tag.text = ""
	_flight.text = ""
	_flight_tag.text = ""
	_real.text = ""
	_real_tag.text = ""
	_action.visible = false


## part: {name, mass, power, cost, texture, kind}. info: ShipData.info(...) with why / do / nasa / game / source.
func show_part(part: Dictionary, info: Dictionary, action_text: String, action_enabled: bool) -> void:
	_thumb.texture = part.get("texture")
	_name.text = String(part["name"]).to_upper()
	var gen := int(part.get("gen", 0))
	_chips.text = "WEIGHT %d   POWER %d%s   COST %d" % [int(part.get("mass", 0)), int(part.get("power", 0)),
		("  MAKES +%d" % gen) if gen > 0 else "", int(part.get("cost", 0))]
	_why.text = String(info.get("why", ""))
	_do.text = String(info.get("do", ""))
	if info.has("nasa") and String(info["nasa"]) != "":
		_fact_tag.text = "NASA"
		_fact_tag.add_theme_color_override("font_color", UiStyle.CHROME)
		_fact.text = String(info["nasa"])
		_source.text = String(info.get("source", ""))
	else:
		_fact_tag.text = "GAME"
		_fact_tag.add_theme_color_override("font_color", UiStyle.AMBER)
		_fact.text = String(info.get("game", ""))
		_source.text = ""
	_real.text = String(info.get("real", "")).trim_prefix("REAL: ")
	_real_tag.text = "REAL" if _real.text != "" else ""
	var fl := String(info.get("flight", ""))
	_flight_tag.text = "FLIGHT" if fl != "" else ""
	_flight.text = fl
	_action.visible = action_text != ""
	_action.text = action_text
	_action.disabled = not action_enabled
