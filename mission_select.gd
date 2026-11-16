extends Control
## Contract stage: pick a contract, then Accept. Back returns to the title.

const CARD_SCENE := preload("res://contract_card.tscn")

@export_file("*.tscn") var next_scene: String = "res://crew_screen.tscn"
@export_file("*.tscn") var back_scene: String = "res://title.tscn"

@onready var background: TextureRect = $Background
@onready var stars: CPUParticles2D = $Stars
@onready var header: Control = $Safe/Column/Header
@onready var prompt: Label = $Safe/Column/Prompt
@onready var cards_row: HBoxContainer = $Safe/Column/Cards
@onready var footer: Control = $Safe/Column/Footer
@onready var back_button: BaseButton = $Safe/Column/Footer/Row/BackButton
@onready var accept_button: Button = $Safe/Column/Footer/Row/AcceptButton
@onready var fade: ColorRect = $Fade
@onready var safe: MarginContainer = $Safe
@onready var hint: Label = $Safe/Column/Footer/Row/Hint

var _group := ButtonGroup.new()
var _selected := -1
var _leaving := false
var _parallax := Vector2.ZERO


func _ready() -> void:
	Music.play("design")
	PlayerData.refresh_campaign()
	for data in Missions.LIST:
		var d: Dictionary = data.duplicate(true)
		d["status"] = PlayerData.contract_status(int(data["id"]))
		var card := CARD_SCENE.instantiate()
		cards_row.add_child(card)
		card.setup(d, _group)
		card.chosen.connect(_on_card_chosen)
	_add_campaign_ui()

	accept_button.disabled = true
	accept_button.tooltip_text = "Pick a contract first."
	_update_hint()
	accept_button.pressed.connect(_on_accept_pressed)
	back_button.pressed.connect(_on_back_pressed)
	accept_button.resized.connect(func(): accept_button.pivot_offset = accept_button.size * 0.5)

	_fit_to_size()
	resized.connect(_fit_to_size)
	_add_decor()
	_focus_first_open_card()
	_play_intro()
	_play_idle()


func _process(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var offset := (mouse / get_viewport_rect().size - Vector2(0.5, 0.5)) * -18.0
	_parallax = _parallax.lerp(offset, clampf(delta * 3.0, 0.0, 1.0))
	background.position = _parallax


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


## The layout is designed on a 1920x1080 frame. On a wider or taller window the frame stays centered
## and only the background grows, so nothing drifts to the edges.
const FRAME := Vector2(1920, 1080)

## Y2K decoration pack from the team Drive: beside and behind the real UI, never clickable.
## The floating ornaments (star, ringed planet, arrows) were taken off this page. The four corner ornaments belong to the
## HUD frame and stay.
func _add_decor() -> void:
	pass


func _fit_to_size() -> void:
	var extra := (size - FRAME).max(Vector2.ZERO) * 0.5
	safe.add_theme_constant_override("margin_left", 90 + int(extra.x))
	safe.add_theme_constant_override("margin_right", 90 + int(extra.x))
	safe.add_theme_constant_override("margin_top", 24 + int(extra.y))
	safe.add_theme_constant_override("margin_bottom", 64 + int(extra.y))
	background.pivot_offset = size * 0.5
	stars.position = size * 0.5
	stars.emission_rect_extents = size * 0.5


func _focus_first_open_card() -> void:
	for card in cards_row.get_children():
		if not card.disabled:
			card.grab_focus()
			return


# ---------- actions ----------

func _on_card_chosen(mission_id: int) -> void:
	# Locked contracts cannot be taken, whatever toggled the card.
	for data in Missions.LIST:
		if int(data["id"]) == mission_id and not data["available"]:
			return
	_selected = mission_id
	accept_button.disabled = false
	accept_button.tooltip_text = ""
	_update_hint()


func _update_hint() -> void:
	if bool(PlayerData.campaign["over"]):
		hint.text = String(PlayerData.campaign["over_reason"])
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(620, 0)
		hint.add_theme_color_override("font_color", UiStyle.CORAL if not bool(PlayerData.campaign["won"]) else UiStyle.PHOSPHOR)
		return
	if _selected < 0:
		hint.text = "PICK A CONTRACT TO CONTINUE"
		hint.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.75))
	else:
		hint.text = "%s  -  NEXT: BUILD YOUR SHIP" % String(Missions.LIST[_selected]["name"])
		hint.add_theme_color_override("font_color", UiStyle.PHOSPHOR)


func _on_accept_pressed() -> void:
	if _selected < 0:
		return
	PlayerData.scenario = _selected
	# The crew is chosen once and the ship is built once: after the first contract both carry on.
	if bool(PlayerData.campaign["locked"]):
		_leave("res://flight.tscn")
	elif not bool(PlayerData.campaign["crew_chosen"]):
		_leave(next_scene)
	else:
		_leave("res://build_screen.tscn")


## Impact Watch is a two-person game: the second person opens the flyer's case file here, or the flyer opens the review that came back.
func _open_case_dialog() -> void:
	DirAccess.make_dir_recursive_absolute("user://impact_cases")
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = false
	dlg.filters = PackedStringArray(["*.json ; Impact Watch files"])
	dlg.title = "Open an Impact Watch case or review file"
	dlg.size = Vector2i(1100, 700)
	dlg.current_dir = ProjectSettings.globalize_path("user://impact_cases")
	dlg.file_selected.connect(open_case_file)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


## Open a case file (to review it) or a review file (to see how it was judged, with the reveal). Public so a test can use it.
func open_case_file(path: String) -> String:
	var parsed = null
	if FileAccess.file_exists(path) and FileAccess.open(path, FileAccess.READ) != null:
		var f := FileAccess.open(path, FileAccess.READ)
		if f.get_length() <= ImpactCase.MAX_BYTES:
			parsed = JSON.parse_string(f.get_as_text())
	var msg := ""
	var c: ImpactControl = null
	if parsed is Dictionary and (parsed as Dictionary).has("verdicts"):
		var found := {}
		var dir := DirAccess.open("user://impact_cases")
		if dir != null:
			for fn in dir.get_files():
				var r := ImpactCase.load_case("user://impact_cases/" + fn)
				if bool(r["ok"]) and String(r["case"]["case_id"]) == String(parsed.get("case_id", "")):
					found = r["case"]
		if found.is_empty():
			msg = "This review is for a case that is not on this computer. Open it on the flyer's computer."
		else:
			var v := ImpactCase.validate_verdict_file(parsed, found)
			if not bool(v["ok"]):
				msg = String(v["error"])
			else:
				c = ImpactControl.new()
				c.case = found
				c.given_verdicts = parsed["verdicts"]
	else:
		var r := ImpactCase.load_case(path)
		if not bool(r["ok"]):
			msg = String(r["error"])
		else:
			c = ImpactControl.new()
			c.case = r["case"]
			c.standalone = true
	if c != null:
		var run := ImpactCase.load_run(String(c.case["case_id"]))
		if not run.is_empty() and String(run.get("case_hash", "")) == ImpactCase.case_hash(c.case):
			c.map = run.get("map", {})
			c.budget = int(run.get("budget", 0))
			c.sent_cost = int(run.get("sent_cost", 0))
		c.finished.connect(func(_r): c.queue_free())
		add_child(c)
		return ""
	hint.text = msg
	hint.add_theme_color_override("font_color", UiStyle.CORAL)
	return msg


## What the page says about the campaign, and a way to start over.
func _add_campaign_ui() -> void:
	var c := PlayerData.campaign
	if bool(c["over"]):
		prompt.text = "YOU FINISHED EVERY CONTRACT" if bool(c["won"]) else "CAMPAIGN OVER"
		prompt.add_theme_color_override("font_color", UiStyle.PHOSPHOR if bool(c["won"]) else UiStyle.CORAL)
	elif bool(c["locked"]):
		prompt.text = "YOUR SHIP IS LOCKED FOR THE REST OF THE GAME  -  CONTRACTS OPEN IN ORDER"
	else:
		prompt.text = "CONTRACTS OPEN IN ORDER  -  FINISH ONE TO UNLOCK THE NEXT"
	var row := back_button.get_parent()
	var nb := Button.new()
	nb.text = "NEW CAMPAIGN"
	nb.theme_type_variation = &"OutlineButton"
	nb.focus_mode = Control.FOCUS_NONE
	nb.add_theme_font_size_override("font_size", 15)
	nb.custom_minimum_size = Vector2(160, 44)
	nb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var armed := [false]
	nb.pressed.connect(func():
		if bool(PlayerData.campaign["over"]) or armed[0] or (not bool(PlayerData.campaign["locked"]) and PlayerData.campaign["done"].is_empty()):
			PlayerData.start_over()
			get_tree().reload_current_scene()
		else:
			armed[0] = true
			nb.text = "SURE? ALL PROGRESS GOES"
			get_tree().create_timer(3.0).timeout.connect(func():
				armed[0] = false
				nb.text = "NEW CAMPAIGN"))
	row.add_child(nb)
	row.move_child(nb, 1)
	var ob := Button.new()
	ob.text = "OPEN A FILE"
	ob.tooltip_text = "Open an Impact Watch case file to review it, or a review file that came back."
	ob.theme_type_variation = &"OutlineButton"
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_size_override("font_size", 15)
	ob.custom_minimum_size = Vector2(140, 44)
	ob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ob.pressed.connect(_open_case_dialog)
	row.add_child(ob)
	row.move_child(ob, 2)
	var sb := Button.new()
	sb.text = "SOUND AND SOURCES"
	sb.theme_type_variation = &"OutlineButton"
	sb.focus_mode = Control.FOCUS_NONE
	sb.add_theme_font_size_override("font_size", 15)
	sb.custom_minimum_size = Vector2(210, 44)
	sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sb.pressed.connect(func(): add_child(SourcesPanel.new()))
	row.add_child(sb)
	row.move_child(sb, 2)
	var pb := Button.new()
	pb.text = "PRACTICE"
	pb.theme_type_variation = &"OutlineButton"
	pb.focus_mode = Control.FOCUS_NONE
	pb.add_theme_font_size_override("font_size", 15)
	pb.custom_minimum_size = Vector2(130, 44)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.pressed.connect(func(): add_child(PracticeMenu.new()))
	row.add_child(pb)
	row.move_child(pb, 3)


func _on_back_pressed() -> void:
	_leave(back_scene)


func _leave(scene_path: String) -> void:
	if _leaving:
		return
	_leaving = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween().set_parallel()
	tw.tween_property(fade, "color:a", 1.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(background, "scale", background.scale * 1.06, 0.45).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(scene_path)


# ---------- motion ----------

func _play_intro() -> void:
	fade.color.a = 1.0
	header.modulate.a = 0.0
	prompt.modulate.a = 0.0
	footer.modulate.a = 0.0
	var cards := cards_row.get_children()
	for card in cards:
		card.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(header, "modulate:a", 1.0, 0.5).set_delay(0.15)
	tw.parallel().tween_property(prompt, "modulate:a", 1.0, 0.4).set_delay(0.35)
	var t := 0.45
	for card in cards:
		var target_alpha := 1.0 if not card.disabled else 0.72
		tw.parallel().tween_property(card, "modulate:a", target_alpha, 0.5).set_delay(t)
		t += 0.12
	tw.parallel().tween_property(footer, "modulate:a", 1.0, 0.4).set_delay(t)


func _play_idle() -> void:
	background.scale = Vector2(1.05, 1.05)
	var drift := create_tween().set_loops()
	drift.tween_property(background, "scale", Vector2(1.09, 1.09), 30.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(background, "scale", Vector2(1.05, 1.05), 30.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
