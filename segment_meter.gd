class_name SegmentMeter
extends Control
## A live limit meter drawn from data: a chrome track, lit segments for what is used, and a
## ghost for what a hovered choice WOULD add. Red segments mean over the limit and a word says so
## (color is never the only signal). When the ship is over the limit a Fix button appears.

signal fix_pressed

@export var title: String = "WEIGHT"
## How many units one segment stands for (use 3 for a long meter like the budget).
@export var segment_units: int = 1
@export var left_word: String = "left"

var value: int = 0
var limit: int = 1
var preview: int = 0          # extra units a hovered choice would add (may be negative)
var limit_delta: int = 0      # extra capacity a hovered choice would add (solar wings)

const TRACK_H := 30.0
const SEG_GAP := 3.0

var _fix: Button


func _ready() -> void:
	custom_minimum_size.y = 80
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fix = Button.new()
	_fix.text = "Hint"
	UiStyle.compact_button(_fix, 15, 28)
	_fix.size = Vector2(62, 28)
	_fix.visible = false
	_fix.pressed.connect(func(): fix_pressed.emit())
	add_child(_fix)
	resized.connect(_place_fix)
	_place_fix()


func _place_fix() -> void:
	if _fix:
		# Sits just after the title text so it never covers it
		_fix.position = Vector2(UiStyle.MONO.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0, -3.0)


func set_values(new_value: int, new_limit: int, new_preview: int = 0, new_limit_delta: int = 0) -> void:
	value = new_value
	limit = maxi(new_limit, 1)
	preview = new_preview
	limit_delta = new_limit_delta
	if _fix:
		_fix.visible = value > limit
	queue_redraw()


func _draw() -> void:
	var mono := UiStyle.MONO
	var after := value + preview
	var over := value > limit
	var limit_after := limit + limit_delta
	var will_over := after > limit_after

	# Title and numbers
	draw_string(mono, Vector2(0, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiStyle.NEAR_WHITE, 0.9))
	var num := "%d / %d" % [value, limit]
	draw_string(mono, Vector2(0, 16), num, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 18, UiStyle.CORAL if over else UiStyle.NEAR_WHITE)

	# Track
	var track := Rect2(0, 26, size.x, TRACK_H)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.12, 0.95)
	bg.set_border_width_all(2)
	bg.border_color = Color(UiStyle.CHROME, 0.7)
	bg.set_corner_radius_all(8)
	draw_style_box(bg, track)

	# Segments
	var segs_limit := int(ceil(float(limit) / segment_units))
	var segs_cap := int(ceil(float(limit_after) / segment_units))
	var segs_max := maxi(maxi(segs_limit, segs_cap), int(ceil(float(maxi(value, after)) / segment_units)))
	segs_max = mini(segs_max, int(segs_limit * 1.5) + 1)
	var inner := track.grow(-5)
	var seg_w := (inner.size.x - SEG_GAP * (segs_max - 1)) / segs_max
	for i in segs_max:
		var r := Rect2(inner.position.x + i * (seg_w + SEG_GAP), inner.position.y, seg_w, inner.size.y)
		var unit_start := i * segment_units
		var lit := unit_start < value
		var ghost := preview > 0 and unit_start >= value and unit_start < after
		var freed := preview < 0 and unit_start >= after and unit_start < value
		var beyond := i >= segs_cap
		var new_capacity := limit_delta > 0 and unit_start >= limit and unit_start < limit_after
		var col := Color(UiStyle.COBALT, 0.28)
		if lit:
			col = UiStyle.CORAL if beyond else (UiStyle.AMBER if float(value) / limit >= 0.9 else UiStyle.PHOSPHOR)
		draw_rect(r, col)
		if new_capacity and not ghost:
			draw_rect(r, Color(UiStyle.PHOSPHOR, 0.9), false, 2.0)
		if ghost:
			var gcol := UiStyle.CORAL if (beyond or will_over) else UiStyle.NEAR_WHITE
			draw_rect(r, Color(gcol, 0.35))
			draw_rect(r, Color(gcol, 0.95), false, 2.0)
		elif freed:
			draw_rect(r, Color(UiStyle.NEAR_WHITE, 0.9), false, 2.0)
		if i == segs_limit - 1 and segs_max > segs_limit:
			var x := r.end.x + SEG_GAP * 0.5
			draw_line(Vector2(x, track.position.y - 2), Vector2(x, track.end.y + 2), Color(UiStyle.NEAR_WHITE, 0.9), 2.0)

	# Words under the bar: how much is spare on the left, what a hovered choice does on the right
	var y := track.end.y + 19
	var spare := limit - value
	var msg := ""
	var msg_col := Color(UiStyle.NEAR_WHITE, 0.8)
	if over:
		msg = "Over by %d" % (value - limit)
		msg_col = UiStyle.CORAL
	elif spare == 0:
		msg = "None %s" % left_word
		msg_col = UiStyle.AMBER
	else:
		msg = "%d %s" % [spare, left_word]
	draw_string(mono, Vector2(0, y), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, msg_col)

	var pmsg := ""
	var pcol := UiStyle.NEAR_WHITE
	if preview != 0:
		pmsg = "%s%d  ->  %d / %d%s" % ["+" if preview > 0 else "-", absi(preview), after, limit_after, "  OVER" if will_over else ""]
		pcol = UiStyle.CORAL if will_over else UiStyle.NEAR_WHITE
	elif limit_delta > 0:
		pmsg = "made +%d" % limit_delta
		pcol = UiStyle.PHOSPHOR
	if pmsg != "":
		draw_string(mono, Vector2(0, y), pmsg, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 16, pcol)
