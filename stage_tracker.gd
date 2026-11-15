@tool
extends HBoxContainer
## Contract / Build / Fly / Report progress chips. The active stage is bright with a green edge.

const STAGES := ["Contract", "Build", "Fly", "Report"]
const PHOSPHOR := Color("c8ff36")
const NEAR_WHITE := Color("f2f5ff")
const COBALT := Color("1736cc")

@export_range(0, 3) var active_index: int = 0:
	set(value):
		active_index = value
		if is_node_ready():
			_build()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	for i in STAGES.size():
		var active := i == active_index
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(COBALT, 0.55 if active else 0.2)
		style.set_border_width_all(2)
		style.border_color = PHOSPHOR if active else Color(0.62, 0.70, 0.95, 0.35)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 14
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		chip.add_theme_stylebox_override("panel", style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		chip.add_child(row)

		var num := Label.new()
		num.theme_type_variation = &"MonoLabel"
		num.text = "%02d" % (i + 1)
		num.add_theme_color_override("font_color", PHOSPHOR if active else Color(PHOSPHOR, 0.45))
		row.add_child(num)

		var label := Label.new()
		label.theme_type_variation = &"MonoLabel"
		label.text = String(STAGES[i]).to_upper()
		label.add_theme_color_override("font_color", NEAR_WHITE if active else Color(NEAR_WHITE, 0.5))
		row.add_child(label)

		add_child(chip)
