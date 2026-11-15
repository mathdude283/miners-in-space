class_name UiStyle
## Shared colors and small style helpers so every screen matches the Moonbound design brief:
## liquid chrome edges, smoked cobalt screens, midnight work areas, acid green for ready/selected.

const MIDNIGHT := Color("070b22")
const COBALT := Color("1736cc")
const PHOSPHOR := Color("c8ff36")
const AMBER := Color("ffc45e")
const NEAR_WHITE := Color("f2f5ff")
const CORAL := Color("ff6b7a")
const CHROME := Color(0.78, 0.83, 0.93, 1.0)
const EDGE := Color(0.62, 0.70, 0.95, 0.55)

const MONO: Font = preload("res://assets/fonts/IBMPlexMono-Medium.ttf")
const BODY: Font = preload("res://assets/fonts/InstrumentSans-Variable.ttf")
const DISPLAY: Font = preload("res://assets/fonts/ArchivoBlack-Regular.ttf")


## Smoked-glass panel with a chrome edge.
static func panel(margin := 18, alpha := 0.82) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(MIDNIGHT, alpha)
	s.set_border_width_all(2)
	s.border_color = Color(CHROME, 0.55)
	s.set_corner_radius_all(16)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin - 2
	s.content_margin_bottom = margin - 2
	s.shadow_color = Color(COBALT, 0.28)
	s.shadow_size = 14
	return s


## Small rounded label background.
static func chip(color: Color, filled := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color if filled else Color(color, 0.12)
	s.set_border_width_all(1 if not filled else 0)
	s.border_color = Color(color, 0.85)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


## A small outlined button with a fixed height, for use inside rows that must not change height.
static func compact_button(b: Button, font_size := 15, height := 26) -> void:
	b.theme_type_variation = &"OutlineButton"
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(62, height)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(COBALT, 0.4 if state == "hover" or state == "hover_pressed" else 0.16)
		s.set_border_width_all(2)
		s.border_color = Color(NEAR_WHITE, 0.95) if state == "hover" or state == "hover_pressed" else Color(EDGE, 0.8)
		s.set_corner_radius_all(8)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 0
		s.content_margin_bottom = 0
		b.add_theme_stylebox_override(state, s)


static func mono_label(text: String, size := 14, color := NEAR_WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", MONO)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DISPLAY)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", NEAR_WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
