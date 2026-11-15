extends Button
## One contract on the mission select board. The whole card is a toggle button, so a click, the
## keyboard (Enter / Space) or a controller can select it. Cards share a ButtonGroup, so only
## one can be selected at a time. Locked contracts cannot be selected.

signal chosen(mission_id: int)

const PHOSPHOR := Color("c8ff36")
const AMBER := Color("ffc45e")
const NEAR_WHITE := Color("f2f5ff")
const COBALT := Color("1736cc")
const MIDNIGHT := Color("070b22")

var mission: Dictionary = {}
var _available := true
var _done := false
var _lock_text := "NOT BUILT YET"

@onready var title_label: Label = $Title
@onready var tag_label: Label = $Tag
@onready var body_label: Label = $Body
@onready var evidence_box: HFlowContainer = $Evidence
@onready var diagram: ContractDiagram = $Diagram
@onready var badge: PanelContainer = $Badge
@onready var badge_label: Label = $Badge/Label


func _ready() -> void:
	# The card art has chamfered corners, so selection and focus are drawn to follow that shape
	# (the theme's rounded rectangles would not match it).
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(func():
		pivot_offset = size * 0.5
		queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_on): queue_redraw())
	resized.connect(queue_redraw)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	toggled.connect(_on_toggled)


## Call after the card is in the tree.
func setup(data: Dictionary, group: ButtonGroup) -> void:
	mission = data
	# The campaign decides whether a contract is open, finished, or locked and exactly why
	var st: Dictionary = data.get("status", {})
	_available = bool(st.get("open", data.get("available", false)))
	_done = bool(st.get("done", false))
	_lock_text = String(st.get("short", "NOT BUILT YET"))
	button_group = group
	title_label.text = data["name"]
	tag_label.text = data["tag"]
	body_label.text = data["objective"]
	diagram.kind = String(data.get("diagram", "orientale"))
	tooltip_text = "" if _available else String(st.get("reason", "Not built yet in this version."))
	for item in data["evidence"]:
		evidence_box.add_child(_make_chip(item))

	disabled = not _available
	modulate = Color.WHITE if _available else Color(1, 1, 1, 0.72)
	# The open contract is the one to pick, so it is the larger card.
	custom_minimum_size = Vector2(466, 551) if _available else Vector2(432, 510)
	_refresh_badge(false)


func _make_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COBALT, 0.35)
	style.set_border_width_all(1)
	style.border_color = Color(0.62, 0.70, 0.95, 0.55)
	style.set_corner_radius_all(6)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.theme_type_variation = &"MonoLabel"
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", NEAR_WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip


func _refresh_badge(selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	var text_color := PHOSPHOR
	if selected:
		badge_label.text = "SELECTED"
		style.bg_color = PHOSPHOR
		style.border_color = PHOSPHOR
		text_color = MIDNIGHT
	elif _available:
		badge_label.text = "OPEN"
		style.bg_color = Color(PHOSPHOR, 0.12)
		style.border_color = Color(PHOSPHOR, 0.9)
	elif _done:
		badge_label.text = "COMPLETE"
		style.bg_color = Color(PHOSPHOR, 0.2)
		style.border_color = PHOSPHOR
	else:
		badge_label.text = "LOCKED · " + _lock_text
		style.bg_color = Color(AMBER, 0.12)
		style.border_color = Color(AMBER, 0.85)
		text_color = AMBER
	badge.add_theme_stylebox_override("panel", style)
	badge_label.add_theme_color_override("font_color", text_color)


func _on_toggled(on: bool) -> void:
	_refresh_badge(on)
	if on:
		chosen.emit(int(mission["id"]))


func _hover(inside: bool) -> void:
	queue_redraw()
	if not _available:
		return
	var s := 1.02 if inside else 1.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(s, s), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------- selection / hover / focus outline that follows the card's chamfered shape ----------

# Art bounds inside the 518 x 612 frame image, and its corner cut.
const ART := Rect2(27, 17, 463, 578)
const CUT := 28.0


func _outline(expand: float) -> PackedVector2Array:
	var sx := size.x / 518.0
	var sy := size.y / 612.0
	var r := Rect2(ART.position.x * sx - expand, ART.position.y * sy - expand, ART.size.x * sx + expand * 2.0, ART.size.y * sy + expand * 2.0)
	var cx := CUT * sx + expand * 0.4
	var cy := CUT * sy + expand * 0.4
	return PackedVector2Array([
		Vector2(r.position.x + cx, r.position.y), Vector2(r.end.x - cx, r.position.y),
		Vector2(r.end.x, r.position.y + cy), Vector2(r.end.x, r.end.y - cy),
		Vector2(r.end.x - cx, r.end.y), Vector2(r.position.x + cx, r.end.y),
		Vector2(r.position.x, r.end.y - cy), Vector2(r.position.x, r.position.y + cy),
		Vector2(r.position.x + cx, r.position.y),
	])


func _draw() -> void:
	if not _available:
		return
	if button_pressed:
		var pts := _outline(7.0)
		draw_polyline(pts, Color(PHOSPHOR, 0.10), 16.0, true)
		draw_polyline(pts, Color(PHOSPHOR, 0.22), 9.0, true)
		draw_polyline(pts, PHOSPHOR, 3.0, true)
	elif is_hovered():
		draw_polyline(_outline(6.0), Color(NEAR_WHITE, 0.85), 2.0, true)
	if has_focus():
		draw_polyline(_outline(12.0), Color(NEAR_WHITE, 0.95), 2.0, true)
