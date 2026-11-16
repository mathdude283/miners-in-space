extends Node
## Autoload: text never goes outside a button. Every Button that appears (and every Button whose text changes later) is checked a few
## times a second. Long text wraps onto more lines, and if it still would not fit the font shrinks a step at a time (never below
## MIN_FONT) until it does. When there is room again the original size comes back.

const MIN_FONT := 9
const CHECK_EVERY := 0.25

var _buttons: Array[Button] = []
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


## The Build screen keeps its original look: its buttons are left exactly as designed.
static func _in_build(b: Node) -> bool:
	var p: Node = b
	while p != null:
		var sc: Script = p.get_script()
		if sc != null and String(sc.resource_path).ends_with("build_screen.gd"):
			return true
		p = p.get_parent()
	return false


func _on_node_added(n: Node) -> void:
	if n is Button and not (n is CheckBox) and not (n is OptionButton):
		_buttons.append(n)
		_set_wrap.call_deferred(n)
		_check_later.call_deferred(n)


func _set_wrap(b: Button) -> void:
	if is_instance_valid(b) and not _in_build(b):
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _check_later(b: Button) -> void:
	if is_instance_valid(b):
		fit(b)


func _process(delta: float) -> void:
	_t += delta
	if _t < CHECK_EVERY:
		return
	_t = 0.0
	var keep: Array[Button] = []
	for b in _buttons:
		if is_instance_valid(b):
			keep.append(b)
			if b.is_visible_in_tree():
				fit(b)
	_buttons = keep


## Does this button's text fit inside it at this font size? (Public so tests can use it.)
static func fits(b: Button, font_size: int) -> bool:
	if b.text == "" or b.size.x < 8.0 or b.size.y < 8.0:
		return true
	var sb: StyleBox = b.get_theme_stylebox("normal")
	var pad := sb.get_minimum_size() if sb != null else Vector2.ZERO
	var avail := Vector2(b.size.x - pad.x - 6.0, b.size.y - pad.y)
	if b.icon != null:
		avail.x -= b.icon.get_width() + 6.0
	if avail.x < 4.0 or avail.y < 4.0:
		return true
	var font: Font = b.get_theme_font("font")
	var sz := font.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, avail.x, font_size, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY)
	# (a word wider than the button is broken across lines by the smart wrap, so only the height needs checking)
	return sz.y <= avail.y + 0.5


## Make the text fit: shrink the font until it does, or put the original size back if the original now fits.
static func fit(b: Button) -> void:
	if b.text == "" or _in_build(b):
		return
	if not b.has_meta("fit_orig"):
		b.set_meta("fit_orig", b.get_theme_font_size("font_size"))
		b.set_meta("fit_had_override", b.has_theme_font_size_override("font_size"))
	var orig: int = int(b.get_meta("fit_orig"))
	var size := orig
	while size > MIN_FONT and not fits(b, size):
		size -= 1
	if size == b.get_theme_font_size("font_size"):
		return
	if size == orig and not bool(b.get_meta("fit_had_override")):
		b.remove_theme_font_size_override("font_size")
	else:
		b.add_theme_font_size_override("font_size", size)
