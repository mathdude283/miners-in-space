class_name CrewHearts
extends Control
## The crew, always on screen: portrait, name, role, five hearts (20 health each, like Oregon Trail), and one short
## line on how they are doing ("Rested and ready.", "Starving: no food left."). When the last heart goes the
## person is lost and the row says so. A heart that was just lost flashes.
## Reads the live MissionRun every frame, so nothing has to tell it to update.

const ROW_H := 86.0
const W := 380.0

var run: MissionRun
var _last: Array[float] = []
var _flash: Array[float] = []


## Draws a row of five hearts. hearts can be fractional (2.5 = two and a half).
static func draw_row(c: CanvasItem, pos: Vector2, size: float, hearts: float, col: Color, dim: Color) -> void:
	for i in 5:
		var center := pos + Vector2(i * (size + 6.0) + size * 0.5, size * 0.5)
		var poly := _heart(center, size)
		c.draw_colored_polygon(poly, dim)
		var fill := clampf(hearts - i, 0.0, 1.0)
		if fill > 0.0:
			var cut := PackedVector2Array([Vector2(center.x - size, center.y - size), Vector2(center.x - size + 2.0 * size * fill, center.y - size),
				Vector2(center.x - size + 2.0 * size * fill, center.y + size), Vector2(center.x - size, center.y + size)])
			for piece in Geometry2D.intersect_polygons(poly, cut):
				c.draw_colored_polygon(piece, col)
		c.draw_polyline(poly + PackedVector2Array([poly[0]]), Color(col, 0.9), 1.5, true)


static func _heart(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var k := size / 34.0
	for i in 28:
		var t := TAU * i / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(center + Vector2(x, y + 1.5) * k)
	return pts


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if run == null:
		run = PlayerData.run
	var n := run.crew.size() if run != null else 3
	custom_minimum_size = Vector2(W, 30.0 + ROW_H * n)
	size = custom_minimum_size


func _process(delta: float) -> void:
	if run == null:
		return
	while _last.size() < run.crew.size():
		_last.append(float(run.crew[_last.size()]["health"]))
		_flash.append(0.0)
	for i in run.crew.size():
		var h := float(run.crew[i]["health"])
		if h < _last[i] - 0.01:
			_flash[i] = 0.9
		_last[i] = h
		_flash[i] = maxf(_flash[i] - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	draw_style_box(UiStyle.panel(14, 0.9), Rect2(Vector2.ZERO, Vector2(W, 30.0 + ROW_H * run.crew.size())))
	draw_string(UiStyle.MONO, Vector2(16.0, 24.0), "YOUR CREW", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.PHOSPHOR)
	for i in run.crew.size():
		var c: Dictionary = run.crew[i]
		var y := 30.0 + ROW_H * i
		var dead := run.is_dead(i)
		var pic := CrewData.portrait(String(c["char"]))
		if pic != null:
			draw_texture_rect(pic, Rect2(14.0, y + 6.0, 64.0, 64.0), false, Color(0.35, 0.35, 0.4, 0.8) if dead else Color.WHITE)
		var f: float = _flash[i] if i < _flash.size() else 0.0
		if f > 0.0:
			draw_rect(Rect2(8.0, y + 2.0, W - 16.0, ROW_H - 4.0), Color(UiStyle.CORAL, 0.35 * f))
		draw_string(UiStyle.MONO, Vector2(90.0, y + 22.0), String(c["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 170.0, 16, Color(UiStyle.NEAR_WHITE, 0.5 if dead else 1.0))
		draw_string(UiStyle.MONO, Vector2(W - 124.0, y + 22.0), "LOST" if dead else String(c["role"]), HORIZONTAL_ALIGNMENT_RIGHT, 110.0, 12, UiStyle.CORAL if dead else Color(UiStyle.NEAR_WHITE, 0.6))
		CrewHearts.draw_row(self, Vector2(90.0, y + 30.0), 22.0, run.hearts(i), UiStyle.CORAL, Color(UiStyle.CORAL, 0.18))
		var hurt := float(c["health"]) < 100.0
		draw_string(UiStyle.MONO, Vector2(90.0, y + 74.0), run.status_line(i), HORIZONTAL_ALIGNMENT_LEFT, W - 100.0, 13, UiStyle.CORAL if (hurt or dead) else Color(UiStyle.NEAR_WHITE, 0.75))
