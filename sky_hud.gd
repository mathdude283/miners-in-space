@tool
extends Control
## HUD marks that sit on the moon plate: a reticle on Earth and a thin orbit line around the Moon
## with a small marker travelling along it. Child of the background TextureRect, so it follows its
## zoom and drift. Positions are fractions of the picture, mapped with the same "cover" math the
## background uses, so they stay on target at any window shape.

@export var color: Color = Color(0.78, 1.0, 0.21, 1.0)
@export var earth_at: Vector2 = Vector2(0.5703, 0.4426)
@export var moon_at: Vector2 = Vector2(0.8447, 0.4833)
## Orbit radii as fractions of the picture width, and tilt in degrees.
@export var orbit_radius: Vector2 = Vector2(0.27, 0.10)
@export var orbit_tilt_deg: float = -20.0
@export var orbit_speed: float = 0.14

var _mono: Font = preload("res://assets/fonts/IBMPlexMono-Medium.ttf")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()


# Picture fraction -> local pixels, plus the pixels-per-picture-pixel scale.
func _map() -> Dictionary:
	var parent_tex := get_parent() as TextureRect
	if parent_tex == null or parent_tex.texture == null:
		return {}
	var tex := parent_tex.texture.get_size()
	var s := maxf(size.x / tex.x, size.y / tex.y)
	return {"tex": tex, "s": s, "off": (size - tex * s) * 0.5}


func _point(m: Dictionary, frac: Vector2) -> Vector2:
	return m.off + m.tex * frac * m.s


func _draw() -> void:
	var m := _map()
	if m.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	_draw_orbit(m, t)
	_draw_earth_reticle(m, t)


func _draw_orbit(m: Dictionary, t: float) -> void:
	var c := _point(m, moon_at)
	var rx: float = orbit_radius.x * m.tex.x * m.s
	var ry: float = orbit_radius.y * m.tex.x * m.s
	var tilt := deg_to_rad(orbit_tilt_deg)

	var seg := 160
	var prev := _ellipse(c, rx, ry, tilt, 0.0)
	for i in range(1, seg + 1):
		var cur := _ellipse(c, rx, ry, tilt, TAU * i / seg)
		if i % 2 == 0:
			draw_line(prev, cur, Color(color, 0.26), 1.5, true)
		prev = cur

	# Travelling marker with a fading trail
	var a := t * orbit_speed * TAU
	for k in range(16, 0, -1):
		var p := _ellipse(c, rx, ry, tilt, a - k * 0.022)
		draw_circle(p, 2.6 * (1.0 - k / 17.0) + 0.6, Color(color, 0.5 * (1.0 - k / 16.0)))
	var head := _ellipse(c, rx, ry, tilt, a)
	draw_circle(head, 13.0, Color(color, 0.14))
	draw_circle(head, 6.0, Color(color, 0.9))
	draw_circle(head, 2.6, Color(1, 1, 1, 1))


func _ellipse(c: Vector2, rx: float, ry: float, tilt: float, ang: float) -> Vector2:
	return c + Vector2(cos(ang) * rx, sin(ang) * ry).rotated(tilt)


func _draw_earth_reticle(m: Dictionary, t: float) -> void:
	var c := _point(m, earth_at)
	var r: float = 30.0 * maxf(m.s, 0.6)
	var spin := t * 0.5
	var col := Color(color, 0.9)
	for i in 4:
		var start := spin + i * TAU / 4.0 + 0.25
		draw_arc(c, r, start, start + TAU / 4.0 - 0.5, 18, col, 2.0, true)
	# Fixed tick marks
	for i in 4:
		var d := Vector2.RIGHT.rotated(i * TAU / 4.0 + PI / 4.0)
		draw_line(c + d * (r + 6.0), c + d * (r + 14.0), Color(color, 0.6), 1.5)

	# Leader line and label
	var knee := c + Vector2(r * 0.72, -r * 0.72)
	var elbow := knee + Vector2(46, -40)
	var tail := elbow + Vector2(74, 0)
	draw_polyline(PackedVector2Array([knee, elbow, tail]), Color(color, 0.7), 1.5, true)
	draw_string(_mono, elbow + Vector2(8, -8), "EARTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.949, 0.961, 1, 0.9))
