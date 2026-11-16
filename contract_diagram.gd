class_name ContractDiagram
extends Control
## A small schematic of what a contract asks the player to produce. It is drawn in code, in the
## game's HUD style, so it stays crisp and editable. These are diagrams, not real imagery or data.

@export_enum("orientale", "glushko_ohm", "impact_watch") var kind: String = "orientale"

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 60)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Backing plate
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(UiStyle.COBALT, 0.14)
	plate.set_border_width_all(1)
	plate.border_color = Color(UiStyle.EDGE, 0.7)
	plate.set_corner_radius_all(6)
	draw_style_box(plate, Rect2(0, 0, w, h))
	# Faint grid
	var grid := Color(UiStyle.EDGE, 0.16)
	var gx := 24.0
	while gx < w:
		draw_line(Vector2(gx, 2), Vector2(gx, h - 2), grid, 1.0)
		gx += 24.0
	match kind:
		"orientale":
			_draw_orientale(w, h)
		"glushko_ohm":
			_draw_glushko_ohm(w, h)
		"impact_watch":
			_draw_impact_watch(w, h)
		"orbit":
			_draw_orbit(w, h)


# A planet and a tilted orbit with a small spacecraft going round it.
func _draw_orbit(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.5)
	draw_circle(c, h * 0.22, Color(0.2, 0.35, 0.8, 0.9))
	draw_arc(c, h * 0.22, 0, TAU, 28, Color(UiStyle.NEAR_WHITE, 0.6), 1.5, true)
	var rx := w * 0.34
	var ry := h * 0.4
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * float(i) / 48.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, Color(UiStyle.PHOSPHOR, 0.7), 1.5, true)
	var sa := _t * 0.8
	draw_circle(c + Vector2(cos(sa) * rx, sin(sa) * ry), 4.0, UiStyle.PHOSPHOR)


# Wide image with a ring basin (shows WHERE) linked to a close-up detail tile (shows what the surface is like).
func _draw_orientale(w: float, h: float) -> void:
	var wide := Rect2(8, 8, w * 0.58, h - 16)
	var tile := Rect2(w * 0.68, 8, h - 16, h - 16)
	_frame(wide)
	_frame(tile)
	var c := Vector2(wide.position.x + wide.size.x * 0.46, wide.get_center().y)
	for i in 3:
		draw_arc(c, wide.size.y * (0.16 + 0.12 * i), 0, TAU, 40, Color(UiStyle.NEAR_WHITE, 0.55 - 0.12 * i), 1.5, true)
	# Detail tile: crosshair that breathes
	var tc := tile.get_center()
	var r := tile.size.x * (0.26 + 0.03 * sin(_t * 2.4))
	draw_arc(tc, r, 0, TAU, 28, UiStyle.PHOSPHOR, 1.5, true)
	draw_line(tc + Vector2(-r - 5, 0), tc + Vector2(r + 5, 0), Color(UiStyle.PHOSPHOR, 0.8), 1.0)
	draw_line(tc + Vector2(0, -r - 5), tc + Vector2(0, r + 5), Color(UiStyle.PHOSPHOR, 0.8), 1.0)
	# Link from the pinned area to the tile
	var link := Color(UiStyle.PHOSPHOR, 0.45)
	draw_dashed_line(Vector2(wide.end.x, wide.position.y + 6), Vector2(tile.position.x, tile.position.y + 6), link, 1.0, 4.0)
	draw_dashed_line(Vector2(wide.end.x, wide.end.y - 6), Vector2(tile.position.x, tile.end.y - 6), link, 1.0, 4.0)


# Two craters side by side, one with rays, and a light-direction arrow.
func _draw_glushko_ohm(w: float, h: float) -> void:
	var a := Rect2(8, 8, w * 0.44, h - 16)
	var b := Rect2(w * 0.52, 8, w * 0.44, h - 16)
	_frame(a)
	_frame(b)
	var ca := a.get_center()
	var cb := b.get_center()
	var r := h * 0.2
	draw_arc(ca, r, 0, TAU, 32, Color(UiStyle.NEAR_WHITE, 0.7), 1.5, true)
	draw_arc(cb, r * 0.85, 0, TAU, 32, Color(UiStyle.NEAR_WHITE, 0.7), 1.5, true)
	for i in 10:
		var ang := TAU * i / 10.0 + 0.3
		draw_line(cb + Vector2.RIGHT.rotated(ang) * (r * 0.85 + 3), cb + Vector2.RIGHT.rotated(ang) * (r * 0.85 + 12 + (i % 3) * 3), Color(UiStyle.NEAR_WHITE, 0.4), 1.0)
	# Light direction arrows (amber), one per panel, pointing differently
	_arrow(a.position + Vector2(10, 12), Vector2(14, 6), UiStyle.AMBER)
	_arrow(b.position + Vector2(10, 12), Vector2(14, -2) if sin(_t) > -2 else Vector2(14, 6), UiStyle.AMBER)
	# Splitter handle between them
	var mx := w * 0.5
	draw_line(Vector2(mx, 4), Vector2(mx, h - 4), Color(UiStyle.PHOSPHOR, 0.85), 2.0)
	draw_circle(Vector2(mx, h * 0.5), 5.0, UiStyle.PHOSPHOR)


# Two observer logs on a shared time axis; a matching blip is corroborated, a lone one is tentative.
func _draw_impact_watch(w: float, h: float) -> void:
	var left := 12.0
	var right := w - 12.0
	var y1 := h * 0.32
	var y2 := h * 0.68
	draw_line(Vector2(left, y1), Vector2(right, y1), Color(UiStyle.EDGE, 0.8), 1.0)
	draw_line(Vector2(left, y2), Vector2(right, y2), Color(UiStyle.EDGE, 0.8), 1.0)
	var x := left
	while x <= right:
		draw_line(Vector2(x, y1 - 3), Vector2(x, y1 + 3), Color(UiStyle.EDGE, 0.5), 1.0)
		draw_line(Vector2(x, y2 - 3), Vector2(x, y2 + 3), Color(UiStyle.EDGE, 0.5), 1.0)
		x += 20.0
	# Matched pair (corroborated), and a lone blip (tentative)
	var xm := left + (right - left) * 0.38
	var xl := left + (right - left) * 0.74
	draw_dashed_line(Vector2(xm, y1), Vector2(xm, y2), Color(UiStyle.PHOSPHOR, 0.7), 1.0, 3.0)
	draw_circle(Vector2(xm, y1), 5.0, UiStyle.PHOSPHOR)
	draw_circle(Vector2(xm, y2), 5.0, UiStyle.PHOSPHOR)
	draw_arc(Vector2(xl, y1), 5.0, 0, TAU, 16, UiStyle.AMBER, 1.5, true)
	# Playhead sweeping across the axis
	var px := left + fposmod(_t * 36.0, right - left)
	draw_line(Vector2(px, 4), Vector2(px, h - 4), Color(UiStyle.NEAR_WHITE, 0.55), 1.0)


func _frame(r: Rect2) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UiStyle.MIDNIGHT, 0.55)
	s.set_border_width_all(2)
	s.border_color = Color(UiStyle.CHROME, 0.55)
	s.set_corner_radius_all(4)
	draw_style_box(s, r)


func _pin(p: Vector2) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)])
	draw_colored_polygon(pts, UiStyle.PHOSPHOR)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(UiStyle.MIDNIGHT, 0.9), 1.0)


func _arrow(from: Vector2, delta: Vector2, color: Color) -> void:
	var to := from + delta
	draw_line(from, to, color, 2.0)
	var d := delta.normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([to + d * 4, to - d * 3 + n * 4, to - d * 3 - n * 4]), color)
