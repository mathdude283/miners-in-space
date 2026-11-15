class_name Decor
extends RefCounted
## Decorative Y2K art from the team's Drive pack "16 Y2K Decorative Elements".
## The pack's rules, kept here: ornaments only (never buttons, never evidence), always beneath or beside real
## UI, never interactive, full image with its transparency (no cropping), and no text inside the art.
## Every piece added here ignores the mouse, so none of it can ever be clicked or block a click.

const DIR := "res://assets/ui/decor/"
const FRAME := Vector2(1920, 1080)

static var _cache := {}


static func tex(key: String) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = load(DIR + key + ".png")
	return _cache[key]


## Adds one decoration. opts: alpha, spin (seconds per full turn), bob (pixels up and down),
## pulse (0..1 gentle breathing), flip_h, before (a sibling node to sit behind).
static func add(parent: Node, key: String, rect: Rect2, opts := {}) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(key)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.focus_mode = Control.FOCUS_NONE
	t.position = rect.position
	t.size = rect.size
	t.pivot_offset = rect.size * 0.5
	var alpha: float = opts.get("alpha", 1.0)
	t.modulate.a = alpha
	t.flip_h = opts.get("flip_h", false)
	parent.add_child(t)
	var before: Node = opts.get("before")
	if before != null:
		parent.move_child(t, before.get_index())
	var spin: float = opts.get("spin", 0.0)
	if spin > 0.0:
		var tw := t.create_tween().set_loops()
		tw.tween_property(t, "rotation", TAU, spin).from(0.0)
	var bob: float = opts.get("bob", 0.0)
	if bob > 0.0:
		var base := t.position
		var tw2 := t.create_tween().set_loops()
		tw2.tween_property(t, "position:y", base.y + bob, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw2.tween_property(t, "position:y", base.y - bob, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse: float = opts.get("pulse", 0.0)
	if pulse > 0.0:
		var tw3 := t.create_tween().set_loops().set_parallel()
		tw3.tween_property(t, "scale", Vector2.ONE * (1.0 + pulse * 0.25), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw3.tween_property(t, "modulate:a", alpha * (1.0 - pulse * 0.5), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw3.chain().tween_property(t, "scale", Vector2.ONE, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw3.parallel().tween_property(t, "modulate:a", alpha, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t


## A 1920x1080 layer that stays centered on the screen, matching the centered frame the screens lay out in.
## Put it behind the real UI by passing the node it should sit under.
static func frame_layer(root: Control, before: Node = null) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = FRAME
	root.add_child(layer)
	if before != null:
		root.move_child(layer, before.get_index())
	var fit := func() -> void:
		layer.position = (root.size - FRAME) * 0.5
	root.resized.connect(fit)
	fit.call_deferred()
	return layer
