@tool
extends Control
## Thin HUD frame for screens: corner brackets and a tick ruler along the left edge.
## Purely decorative, so it ignores the mouse.

@export var color: Color = Color(0.78, 1.0, 0.21, 0.85):
	set(value):
		color = value
		queue_redraw()
@export var inset: float = 40.0:
	set(value):
		inset = value
		queue_redraw()
@export var arm: float = 56.0:
	set(value):
		arm = value
		queue_redraw()
@export var line_width: float = 3.0
@export var show_ruler: bool = true
## Use the chrome corner ornament from the Y2K decoration pack instead of the plain lime brackets.
@export var ornaments: bool = true
@export var ornament_size: float = 88.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var l := inset
	var t := inset
	var r := size.x - inset
	var b := size.y - inset

	# Corners
	if ornaments:
		_ornament(Vector2(l, t), Vector2(1, 1))
		_ornament(Vector2(r, t), Vector2(-1, 1))
		_ornament(Vector2(l, b), Vector2(1, -1))
		_ornament(Vector2(r, b), Vector2(-1, -1))
	else:
		_bracket(Vector2(l, t), Vector2(1, 1))
		_bracket(Vector2(r, t), Vector2(-1, 1))
		_bracket(Vector2(l, b), Vector2(1, -1))
		_bracket(Vector2(r, b), Vector2(-1, -1))

	if show_ruler:
		# Tick ruler on the left edge, between the two left brackets
		var faint := Color(color, 0.35)
		var y := t + arm + 18.0
		var i := 0
		while y < b - arm - 18.0:
			var len := 14.0 if i % 5 == 0 else 7.0
			draw_line(Vector2(l, y), Vector2(l + len, y), faint, 1.5)
			y += 14.0
			i += 1


## The art is a top-left corner with a transparent margin, so its outer corner sits about 15% in.
## Flipping the drawing sets it into the other three corners.
func _ornament(corner: Vector2, dir: Vector2) -> void:
	var tex := Decor.tex("decor_corner_chrome_lime")
	if tex == null:
		return
	draw_set_transform(corner, 0.0, dir)
	draw_texture_rect(tex, Rect2(Vector2(-0.15, -0.15) * ornament_size, Vector2(ornament_size, ornament_size)), false, Color(1, 1, 1, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _bracket(corner: Vector2, dir: Vector2) -> void:
	var pts := PackedVector2Array([
		corner + Vector2(dir.x * arm, 0.0),
		corner,
		corner + Vector2(0.0, dir.y * arm),
	])
	draw_polyline(pts, color, line_width, true)
	# Small square node on the corner
	draw_rect(Rect2(corner - Vector2(3, 3), Vector2(6, 6)), color)
