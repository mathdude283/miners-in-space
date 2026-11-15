class_name ShipView
extends Control
## The ship, assembled left to right from the team's hull pieces: nose, one frame per bay, engine.
## Solar wings sit behind the hull above and below the middle. Hatch lights between the pieces show
## which links are complete. Snap positions come from the bay grid below, not from the artwork.

signal bay_picked(index: int)
signal bay_remove(index: int)
signal bay_hovered(index: int)

const CELL := 118.0
const NOSE: Texture2D = preload("res://assets/ui/build/hull/shell-nose.webp")
const ENGINE: Texture2D = preload("res://assets/ui/build/hull/shell-engine.webp")
const WING: Texture2D = preload("res://assets/ui/build/hull/shell-solar-wing.webp")

var state: BuildState
var _slots: Array[BaySlot] = []
var _group := ButtonGroup.new()
var _nose: TextureRect
var _engine: TextureRect
var _wing_up: TextureRect
var _wing_down: TextureRect
var _links: Control
var _wing_count := 0
var _flight := false              # flight view: rooms the player did not build do not exist
var _link_x0 := 0.0
var _hull_y := 0.0
var _built := 0                   # how many rooms exist, in flight view


func _ready() -> void:
	custom_minimum_size = Vector2(900, 336)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wing_up = _art(WING)
	_wing_down = _art(WING)
	_wing_down.flip_v = true
	_nose = _art(NOSE)
	_engine = _art(ENGINE)
	for i in ShipData.RULES["bays"]:
		var s := BaySlot.make(i, _group)
		s.pressed.connect(func(): bay_picked.emit(i))
		s.remove_requested.connect(func(idx): bay_remove.emit(idx))
		s.hovered.connect(func(idx): bay_hovered.emit(idx))
		add_child(s)
		_slots.append(s)
	_links = Control.new()
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_links.draw.connect(_draw_links)
	add_child(_links)
	resized.connect(_layout)
	_layout()


func _art(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func bind(s: BuildState) -> void:
	state = s
	s.changed.connect(refresh)
	refresh()


## index of the bay that is currently aimed at, or -1
func selected_bay() -> int:
	for s in _slots:
		if s.button_pressed:
			return s.index
	return -1


func clear_selection() -> void:
	for s in _slots:
		s.button_pressed = false


## Show the ship for the flight screen: no buttons, no names, nothing to click. A bay the player left
## empty is not part of the ship that launches, so the hull closes up with no gap.
func set_flight_mode() -> void:
	_flight = true
	for s in _slots:
		s.read_only = true
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.focus_mode = Control.FOCUS_NONE
		s.set_room(s.room_id)
	refresh()
	_layout()


func bay_slot(i: int) -> BaySlot:
	return _slots[i]


func refresh() -> void:
	if state == null or _slots.is_empty():
		return
	for i in _slots.size():
		var was := _slots[i].room_id
		_slots[i].set_room(state.bays[i])
		if was == "" and state.bays[i] != "":
			_slots[i].pop()
	var target := state.wings
	_wing_up.visible = target >= 1
	_wing_down.visible = target >= 2
	if target > _wing_count:
		var w := _wing_up if target == 1 else _wing_down
		w.pivot_offset = Vector2(w.size.x * 0.5, w.size.y if w == _wing_up else 0.0)
		w.scale = Vector2(0.8, 0.8)
		create_tween().tween_property(w, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wing_count = target
	_links.queue_redraw()


func _layout() -> void:
	if _slots.is_empty():
		return
	# In flight only the rooms that were built exist, packed together from the nose.
	var shown: Array[int] = []
	for i in _slots.size():
		if not _flight or (state != null and state.bays[i] != ""):
			shown.append(i)
		else:
			_slots[i].visible = false
	_built = shown.size()
	var n := shown.size()
	var nose_w := CELL * 1.04
	var engine_w := CELL * 0.886
	var total := nose_w + n * CELL + engine_w
	var x0 := (size.x - total) * 0.5
	var wing_w := CELL * 1.08
	var wing_h := wing_w * 341.0 / 420.0
	var hull_y := wing_h - 6.0
	_nose.position = Vector2(x0, hull_y)
	_nose.size = Vector2(nose_w, CELL * 0.96)
	_link_x0 = x0 + nose_w
	_hull_y = hull_y
	for k in n:
		var slot := _slots[shown[k]]
		slot.visible = true
		slot.position = Vector2(x0 + nose_w + k * CELL, hull_y)
		slot.size = Vector2(CELL, CELL)
	_engine.position = Vector2(x0 + nose_w + n * CELL, hull_y)
	_engine.size = Vector2(engine_w, CELL)
	# Wings sit over the join between the middle two bays
	var mid := x0 + nose_w + (n * 0.5) * CELL
	_wing_up.size = Vector2(wing_w, wing_h)
	_wing_up.position = Vector2(mid - wing_w * 0.5, 4.0)
	_wing_down.size = Vector2(wing_w, wing_h)
	_wing_down.position = Vector2(mid - wing_w * 0.5, hull_y + CELL - 4.0)
	_links.size = size
	_links.position = Vector2.ZERO
	_links.queue_redraw()


func _draw_links() -> void:
	if state == null or _slots.is_empty():
		return
	if _flight:
		# Every piece that exists is joined to the next one
		var fy := _hull_y + CELL * 0.5
		for k in _built + 1:
			var fr := Rect2(_link_x0 + k * CELL - 9, fy - 5, 18, 10)
			_links.draw_rect(fr.grow(5), Color(UiStyle.PHOSPHOR, 0.18))
			_links.draw_rect(fr, UiStyle.PHOSPHOR)
		return
	var n := _slots.size()
	var y := _slots[0].position.y + CELL * 0.5
	for k in n + 1:
		var x: float = _slots[0].position.x + k * CELL
		var left_ok := k == 0 or state.bays[k - 1] != ""
		var right_ok := k == n or state.bays[k] != ""
		var lit := left_ok and right_ok
		var r := Rect2(x - 9, y - 5, 18, 10)
		if lit:
			_links.draw_rect(r.grow(5), Color(UiStyle.PHOSPHOR, 0.18))
			_links.draw_rect(r, UiStyle.PHOSPHOR)
		else:
			_links.draw_rect(r, Color(UiStyle.MIDNIGHT, 0.9))
			_links.draw_rect(r, Color(UiStyle.EDGE), false, 1.5)
