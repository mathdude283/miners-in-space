class_name HowToCard
extends Control
## A "how to play" card that stays on screen until the player clicks GOT IT.
## A small button (or the H key) brings it back. It never closes by itself, and no game key closes it:
## SPACE is the hold key in the photo game, so these buttons are click-only (no keyboard focus).

var _card: PanelContainer
var _reopen: Button


func setup(title_text: String, rows: Array) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(440, 0)
	_card.add_theme_stylebox_override("panel", UiStyle.panel(16, 0.92))
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_card.add_child(col)
	col.add_child(UiStyle.mono_label(title_text, 14, UiStyle.PHOSPHOR))
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var tag := UiStyle.mono_label(String(r[0]), 14, UiStyle.PHOSPHOR)
		tag.custom_minimum_size = Vector2(104, 0)
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(tag)
		var l := Label.new()
		l.text = String(r[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(280, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.92))
		row.add_child(l)
		col.add_child(row)
	var ok := Button.new()
	ok.text = "GOT IT"
	ok.theme_type_variation = &"OutlineButton"
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_font_size_override("font_size", 16)
	ok.custom_minimum_size = Vector2(140, 42)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(_close)
	col.add_child(ok)

	_reopen = Button.new()
	_reopen.text = "?  HOW TO PLAY   [H]"
	_reopen.theme_type_variation = &"OutlineButton"
	_reopen.focus_mode = Control.FOCUS_NONE
	_reopen.add_theme_font_size_override("font_size", 15)
	_reopen.custom_minimum_size = Vector2(240, 42)
	_reopen.hide()
	_reopen.pressed.connect(_open)
	add_child(_reopen)


func is_open() -> bool:
	return _card.visible


func _open() -> void:
	_card.show()
	_reopen.hide()


func _close() -> void:
	_card.hide()
	_reopen.show()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		if _card.visible:
			_close()
		else:
			_open()
