class_name PracticeMenu
extends Control
## Practice: play the photo and radio mini-games any time. Nothing is saved, nothing is spent and no mission is
## affected. A banner says PRACTICE the whole time. Escape or CLOSE leaves.

signal closed

var _game: Control
var _panel: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if theme == null:
		theme = load("res://assets/themes/moonbound_theme.tres")
	_show_menu()


func _show_menu() -> void:
	if _panel != null:
		_panel.queue_free()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_panel = root
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(900, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(28, 0.97))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	col.add_child(UiStyle.mono_label("PRACTICE", 15, UiStyle.PHOSPHOR))
	col.add_child(UiStyle.heading("TRY A MINI-GAME"))
	var l := Label.new()
	l.text = "Nothing here is saved or spent. Learn the controls, then fly for real."
	l.add_theme_font_size_override("font_size", 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(840, 0)
	col.add_child(l)
	for opt in [
		["MOON PHOTO", "Aim, hold, release at the real Orientale basin (Contract 01).", "basin"],
		["CRATER PHOTO, LOW SUN", "Shadows show the crater's shape (Contract 02).", "crater_low"],
		["CRATER PHOTO, HIGH SUN", "No shadows, so bright rays stand out (Contract 02).", "crater_high"],
		["SEND PHOTOS HOME", "Keep the radio beam on Earth until each photo arrives.", "radio"],
		["LAUNCH: MAX Q", "Hold SPACE while the pressure is over the limit. It tells you what you did wrong.", "maxq"],
		["LAUNCH: BOOSTER SEPARATION", "Press SPACE once, inside the green window. Try again as often as you like.", "sep"],
	]:
		var b := Button.new()
		b.text = "%s\n%s" % [opt[0], opt[1]]
		b.theme_type_variation = &"OutlineButton"
		b.add_theme_font_size_override("font_size", 19)
		b.custom_minimum_size = Vector2(0, 84)
		b.focus_mode = Control.FOCUS_NONE
		var kind: String = opt[2]
		b.pressed.connect(func(): start(kind))
		col.add_child(b)
	var close := Button.new()
	close.text = "CLOSE"
	close.theme_type_variation = &"PrimaryButton"
	close.add_theme_font_size_override("font_size", 26)
	close.custom_minimum_size = Vector2(260, 80)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close)
	col.add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _game == null:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()


## Start one of the practice games. Public so a test can stand in for the button.
func start(kind: String) -> void:
	if _game != null:
		return
	if _panel != null:
		_panel.hide()
	if kind == "maxq" or kind == "sep":
		var ac := AscentControl.new()
		ac.mode = kind
		ac.preview = true
		_game = ac
	elif kind == "radio":
		var g := DownlinkGame.new()
		var photos: Array[Dictionary] = []
		for lens in ["wide", "close"]:
			photos.append({"lens": lens, "stars": 2, "confidence": "MODERATE", "tex": _dummy_photo(lens)})
		g.photos = photos
		_game = g
	else:
		var g := PhotoGame.new()
		if kind == "basin":
			g.target = Missions.get_mission(0)["target"]
		else:
			var crater := "glushko"
			var info: Dictionary = CraterScience.CRATERS[crater]
			g.target = {"name": info["name"], "desc": info["desc"], "noun": "crater", "kind": "crater"}
			g.crater_id = crater
			var pa := CraterScience.pass_by_id("early" if kind == "crater_low" else "noon").duplicate()
			pa["crater"] = crater
			g.sun = pa
			g.has_lens = {"wide": true, "close": false}
		_game = g
	add_child(_game)
	if _game.has_signal("done"):
		_game.done.connect(_on_game_finished)
	else:
		_game.finished.connect(_on_game_finished)
	var banner := UiStyle.mono_label("PRACTICE   -   nothing is saved", 15, UiStyle.AMBER)
	banner.position = Vector2(20, 8)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.name = "PracticeBanner"
	add_child(banner)


func _on_game_finished(_result: Dictionary) -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	var b := get_node_or_null("PracticeBanner")
	if b != null:
		b.queue_free()
	_show_menu()


## A grey picture to send in the radio practice. It is not a real photo.
func _dummy_photo(lens: String) -> Texture2D:
	var img := Image.create(256, 160, false, Image.FORMAT_RGB8)
	for y in 160:
		for x in 256:
			var g := 0.28 + 0.25 * float(y) / 160.0 + (0.08 if (x / 24 + y / 24) % 2 == 0 else 0.0)
			img.set_pixel(x, y, Color(g * 0.9, g * 0.93, g))
	return ImageTexture.create_from_image(img)
