class_name PartCard
extends Button
## One pickable part: a room tile in the drawer, or an equipment card (crew kit, solar wing, lens).
## It shows its own mass / power / budget cost, so the price is visible before the player decides.
## Hovering or focusing it tells the screen to preview the cost on the meters.

signal hovered(part: Dictionary)   # {} when the pointer leaves
signal chosen(part: Dictionary)      # one click: pick it to read about it
signal activated(part: Dictionary)   # double-click: add or take out straight away

var part: Dictionary = {}
var _art: TextureRect
var _name: Label
var _cost: Label
var _badge: Label
var _tall := true
var _on := false
var _locked_text := ""
var _picked := false


## part: {id, name, mass, power, cost, texture}. tall = drawer tile (art on top); wide = icon on the left.
static func make(data: Dictionary, tall: bool) -> PartCard:
	var c := PartCard.new()
	c.part = data
	c._tall = tall
	c.custom_minimum_size = Vector2(128, 124) if tall else Vector2(158, 80)
	c.theme_type_variation = &"TileButton"
	c.focus_mode = Control.FOCUS_ALL
	c.clip_contents = true
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL if tall else Control.SIZE_FILL
	return c


func _ready() -> void:
	var body: BoxContainer = VBoxContainer.new() if _tall else HBoxContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 2 if _tall else 8)
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8 if _tall else 8)
	add_child(pad)
	pad.add_child(body)

	_art = TextureRect.new()
	_art.texture = part.get("texture")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tall:
		_art.custom_minimum_size = Vector2(0, 64)
		_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		_art.custom_minimum_size = Vector2(58, 58)
		_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(_art)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 1)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(text_box)

	_name = UiStyle.mono_label(String(part.get("short", part["name"])).to_upper(), 14 if _tall else 14)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _tall:
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.clip_text = true
	text_box.add_child(_name)

	_cost = UiStyle.mono_label(_cost_text(), 14, Color(UiStyle.PHOSPHOR, 0.9))
	if _tall:
		_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(_cost)

	# "IN SHIP" / "ON" badge, shown over the art
	_badge = UiStyle.mono_label("", 13, UiStyle.MIDNIGHT)
	_badge.add_theme_stylebox_override("normal", UiStyle.chip(UiStyle.PHOSPHOR, true))
	_badge.visible = false
	add_child(_badge)
	_badge.position = Vector2(8, 8)

	pressed.connect(func(): chosen.emit(part))
	mouse_entered.connect(func(): hovered.emit(part))
	mouse_exited.connect(func(): hovered.emit({}))
	focus_entered.connect(func(): hovered.emit(part))
	focus_exited.connect(func(): hovered.emit({}))
	_refresh()


func _cost_text() -> String:
	return "M%d P%d $%d" % [int(part.get("mass", 0)), int(part.get("power", 0)), int(part.get("cost", 0))]


## on: this part is already in the ship. locked_text: why it cannot be used (empty = usable).
func set_state(on: bool, locked_text := "") -> void:
	_on = on
	_locked_text = locked_text
	_refresh()


func _refresh() -> void:
	if _art == null:
		return

	if part.get("kind", "room") == "room":
		disabled = false
		_art.modulate = Color(1, 1, 1, 0.45) if _on else Color.WHITE
		_badge.text = "IN SHIP"
		_badge.visible = _on
		tooltip_text = "In your ship. Click to take it out." if _on else ""
	else:
		# equipment: always readable; an unavailable one is only dimmed
		disabled = false
		_art.modulate = Color.WHITE if _locked_text == "" else Color(1, 1, 1, 0.4)
		_badge.text = "ON"
		_badge.visible = _on and _locked_text == ""
	_cost.text = _locked_text if _locked_text != "" else _cost_text()
	_cost.add_theme_color_override("font_color", Color(UiStyle.AMBER, 0.95) if _locked_text != "" else Color(UiStyle.PHOSPHOR, 0.9))
	add_theme_stylebox_override("normal", _style_for(_on))
	add_theme_stylebox_override("hover", _style_for(_on, true))
	add_theme_stylebox_override("pressed", _style_for(_on, true))
	add_theme_stylebox_override("disabled", _style_for(_on))


## Marks the part being read about in the inspector.
func set_picked(on: bool) -> void:
	_picked = on
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(part)
		accept_event()


func _style_for(on: bool, hot := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UiStyle.COBALT, 0.30 if hot else (0.20 if not on else 0.34))
	s.set_border_width_all(4 if _picked else 2)
	s.border_color = UiStyle.PHOSPHOR if (_picked or (on and part.get("kind", "room") != "room")) else (Color(UiStyle.CHROME, 0.9) if hot else Color(UiStyle.EDGE))
	s.set_corner_radius_all(12)
	return s
