class_name CoachPanel
extends PanelContainer
## A Mission Control coach that talks the player through what to do, right now. The portrait is the team's Drive art
## (panel_mission_control, left part only: its baked-in sentence is an example, so the words here are drawn live).
## Steps ("1 AIM", "2 HOLD", ...) light up as the player reaches them, so the order is always visible.

const SHEET: Texture2D = preload("res://assets/ui/kit/panel_mission_control.png")

var label: Label                       # the live words (read by tests)
var _steps_row: HBoxContainer
var _chips: Array[Label] = []
var _portrait: TextureRect
var _last := ""


func _init(width := 900.0, font_size := 22) -> void:
	custom_minimum_size = Vector2(width, 0)
	add_theme_stylebox_override("panel", UiStyle.panel(10, 0.9))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_portrait = TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = SHEET
	at.region = Rect2(0, 0, 196, 180)
	_portrait.texture = at
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(110, 100)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UiStyle.mono_label("MISSION CONTROL", 12, UiStyle.CHROME))
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.custom_minimum_size = Vector2(width - 170.0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(label)
	_steps_row = HBoxContainer.new()
	_steps_row.add_theme_constant_override("separation", 8)
	_steps_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_steps_row)


## The words to show now. Colour tells urgency (amber = fix something). Does nothing if unchanged.
func say(text: String, color: Color = UiStyle.NEAR_WHITE) -> void:
	if text == _last and label.get_theme_color("font_color") == color:
		return
	_last = text
	label.text = text
	label.add_theme_color_override("font_color", color)


## Set the steps shown under the words, and which one is the current one (-1 for none).
func set_steps(names: Array, active: int) -> void:
	if _chips.size() != names.size():
		for c in _chips:
			c.queue_free()
		_chips.clear()
		for n in names:
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 14)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_steps_row.add_child(l)
			_chips.append(l)
	for i in names.size():
		var l: Label = _chips[i]
		l.text = "%d  %s" % [i + 1, String(names[i])]
		var on := i == active
		var done := active > i
		l.add_theme_color_override("font_color", UiStyle.MIDNIGHT if on else (Color(UiStyle.NEAR_WHITE, 0.55) if not done else Color(UiStyle.PHOSPHOR, 0.55)))
		l.add_theme_stylebox_override("normal", UiStyle.chip(UiStyle.PHOSPHOR, on) if on else UiStyle.chip(UiStyle.EDGE))
