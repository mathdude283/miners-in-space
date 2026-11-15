class_name Astronaut
extends Control
## A crew member walking the ship, using the team's character art (Drive: Crew members folder): a four-frame walk
## cycle and an idle pose, both facing right and flipped to face left. The feet are at the bottom-centre of the
## control. A name tag floats above the head, with a marker when this is the person the player is steering.

const W := 150.0
const H := 220.0
const DRAW_H := 176.0
const FPS := 9.0

var char_id := "ada"
var crew_name := ""
var role := "COMMANDER"
var selected := false
var facing := 1.0
var walking := false
var _t := 0.0
var _frames: Array[Texture2D] = []
var _idle: Texture2D          # side view: used when they stop after walking
var _idle_front: Texture2D    # facing us: used until they first move
var _has_walked := false


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2(W * 0.5, H)
	_frames = CrewData.walk_frames(char_id)
	_idle = CrewData.idle_right(char_id)
	_idle_front = CrewData.idle_front(char_id)


static var _sil_cache := {}


## The same picture as a flat white shape, so it can be tinted into an outline or glow.
static func _silhouette(tex: Texture2D) -> Texture2D:
	if _sil_cache.has(tex):
		return _sil_cache[tex]
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if c.a > 0.4 else 0.0))
	var out := ImageTexture.create_from_image(img)
	_sil_cache[tex] = out
	return out


func _process(delta: float) -> void:
	if walking:
		_t += delta
		_has_walked = true
	queue_redraw()


func _draw() -> void:
	# Facing us until they first move, then the side view whenever they stand still after walking
	var tex: Texture2D = _idle if _has_walked else _idle_front
	var front_view := not _has_walked and not walking
	if walking and not _frames.is_empty():
		tex = _frames[int(_t * FPS) % _frames.size()]
	if tex == null:
		tex = _idle
	var t := Time.get_ticks_msec() / 1000.0
	var bob := 0.0 if walking else sin(t * 2.0) * 1.2
	var feet := H - 4.0
	# A soft shadow where the feet meet the deck
	draw_set_transform(Vector2(W * 0.5, feet), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 40.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tex != null:
		var w := tex.get_width() * DRAW_H / tex.get_height()
		draw_set_transform(Vector2(W * 0.5, 0.0), 0.0, Vector2(1.0 if front_view else facing, 1.0))
		var rect := Rect2(-w * 0.5, feet - DRAW_H + bob, w, DRAW_H)
		# A glowing outline so the crew stand out from the busy ship behind them: a soft wide glow, then a crisp edge
		var sil := _silhouette(tex)
		var edge := UiStyle.PHOSPHOR if selected else Color(0.82, 0.92, 1.0)
		for k in 12:
			var a := float(k) * TAU / 12.0
			draw_texture_rect(sil, Rect2(rect.position + Vector2(cos(a), sin(a)) * 7.0, rect.size), false, Color(edge, 0.16))
		for k in 8:
			var a := float(k) * TAU / 8.0
			draw_texture_rect(sil, Rect2(rect.position + Vector2(cos(a), sin(a)) * 3.0, rect.size), false, Color(edge, 0.9))
		draw_texture_rect(tex, rect, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Name tag and the marker that shows who you are steering
	draw_rect(Rect2(W * 0.5 - 44.0, 1.0, 88.0, 22.0), Color(UiStyle.MIDNIGHT, 0.8))
	draw_string(UiStyle.MONO, Vector2(0.0, 17.0), crew_name, HORIZONTAL_ALIGNMENT_CENTER, W, 17, Color(UiStyle.NEAR_WHITE, 1.0 if selected else 0.7))
	if selected:
		var b := sin(t * 5.0) * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(W * 0.5 - 9.0, 27.0 + b), Vector2(W * 0.5 + 9.0, 27.0 + b), Vector2(W * 0.5, 39.0 + b)]), UiStyle.PHOSPHOR)
