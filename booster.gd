class_name Booster
extends Control
## A solid rocket booster strapped to the side of the rocket, drawn in code (the Drive kit has no booster art).
## While `burning` it has a flickering flame. The flight scene pushes it away at separation.

const W := 90.0
const H := 500.0
const CX := 45.0
const BODY := 30.0

var burning := false


func _ready() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	pivot_offset = Vector2(CX, 200.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if burning:
		queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var white := Color(0.93, 0.95, 1.0)
	# Flame first, so the booster sits over it
	if burning:
		var flick := 1.0 + sin(t * 41.0) * 0.12 + sin(t * 23.0) * 0.08
		for k in 3:
			var flame_len := (150.0 - k * 38.0) * flick
			var fw := 20.0 - k * 5.0
			var col: Color = [Color(1.0, 0.45, 0.1, 0.8), Color(1.0, 0.75, 0.25, 0.9), Color(1.0, 0.97, 0.85, 0.95)][k]
			draw_colored_polygon(PackedVector2Array([Vector2(CX - fw, 378.0), Vector2(CX + fw, 378.0), Vector2(CX, 378.0 + flame_len)]), col)
	# Nozzle
	draw_colored_polygon(PackedVector2Array([Vector2(CX - 10.0, 352.0), Vector2(CX + 10.0, 352.0), Vector2(CX + 16.0, 380.0), Vector2(CX - 16.0, 380.0)]), Color(0.25, 0.27, 0.34))
	# Body
	draw_rect(Rect2(CX - BODY * 0.5, 58.0, BODY, 296.0), white)
	draw_rect(Rect2(CX - BODY * 0.5, 58.0, 8.0, 296.0), Color(0.72, 0.77, 0.9))
	draw_rect(Rect2(CX + BODY * 0.5 - 6.0, 58.0, 6.0, 296.0), Color(0.62, 0.68, 0.85))
	for y in [120.0, 200.0, 300.0]:
		draw_rect(Rect2(CX - BODY * 0.5, y, BODY, 10.0), Color(0.09, 0.2, 0.8))
		draw_rect(Rect2(CX - BODY * 0.5, y + 10.0, BODY, 2.0), UiStyle.PHOSPHOR)
	# Nose cone
	draw_colored_polygon(PackedVector2Array([Vector2(CX - BODY * 0.5, 58.0), Vector2(CX, 2.0), Vector2(CX + BODY * 0.5, 58.0)]), Color(0.22, 0.27, 0.5))
	draw_polyline(PackedVector2Array([Vector2(CX - BODY * 0.5, 58.0), Vector2(CX, 2.0), Vector2(CX + BODY * 0.5, 58.0), Vector2(CX - BODY * 0.5, 58.0)]), Color(UiStyle.CHROME, 0.9), 1.5, true)
	draw_rect(Rect2(CX - BODY * 0.5, 58.0, BODY, 296.0), Color(UiStyle.CHROME, 0.8), false, 1.5)
