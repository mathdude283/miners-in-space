extends Control
## Title screen. One primary button (Start), one quiet one (Credits).

const STAGES := ["Contract", "Build", "Fly", "Report"]
const PHOSPHOR := Color("c8ff36")
const NEAR_WHITE := Color("f2f5ff")
const COBALT := Color("1736cc")

## Scene that opens when the player presses Start.
@export_file("*.tscn") var next_scene: String = "res://mission_select.tscn"

@onready var background: TextureRect = $Background
@onready var stars: CPUParticles2D = $Stars
@onready var logo: TextureRect = $Content/Column/Logo
@onready var stages_row: HBoxContainer = $Content/Column/Stages
@onready var start_button: Button = $Content/Column/StartButton
@onready var hint: Label = $Content/Column/Hint
@onready var bottom_bar: Control = $BottomBar
@onready var credits_button: Button = $BottomBar/CreditsButton
@onready var credits_layer: Control = $CreditsLayer
@onready var credits_panel: Control = $CreditsLayer/Center/Panel
@onready var credits_close: Button = $CreditsLayer/Center/Panel/Column/CloseButton
@onready var fade: ColorRect = $Fade

var _starting := false
var _parallax := Vector2.ZERO


func _ready() -> void:
	Music.play("design")
	_build_stage_chips()
	_fit_to_size()
	resized.connect(_fit_to_size)
	start_button.resized.connect(_center_pivot.bind(start_button))
	logo.resized.connect(_center_pivot.bind(logo))

	start_button.pressed.connect(_on_start_pressed)
	start_button.mouse_entered.connect(_pop.bind(start_button, 1.05))
	start_button.mouse_exited.connect(_pop.bind(start_button, 1.0))
	start_button.focus_entered.connect(_pop.bind(start_button, 1.05))
	start_button.focus_exited.connect(_pop.bind(start_button, 1.0))
	credits_button.pressed.connect(_open_credits)
	credits_close.pressed.connect(_close_credits)
	# A way to the sound sliders and the sources, inside the credits box (the title page itself stays calm)
	var more := Button.new()
	more.text = "SOUND AND SOURCES"
	more.theme_type_variation = &"OutlineButton"
	more.add_theme_font_size_override("font_size", 22)
	more.custom_minimum_size = Vector2(330, 72)
	more.size_flags_horizontal = Control.SIZE_SHRINK_END
	more.pressed.connect(func(): add_child(SourcesPanel.new()))
	var col: Control = $CreditsLayer/Center/Panel/Column
	col.add_child(more)
	col.move_child(more, credits_close.get_index())

	credits_layer.hide()
	# Clicking anywhere outside the panel closes it too.
	$CreditsLayer/Dim.gui_input.connect(_on_dim_input)
	start_button.grab_focus()
	_play_intro()
	_play_idle()
	_show_ai_notice_once()


func _process(delta: float) -> void:
	# Gentle parallax: the moon plate shifts a little against the mouse.
	var mouse := get_viewport().get_mouse_position()
	var offset := (mouse / get_viewport_rect().size - Vector2(0.5, 0.5)) * -26.0
	_parallax = _parallax.lerp(offset, clampf(delta * 3.0, 0.0, 1.0))
	background.position = _parallax


func _unhandled_input(event: InputEvent) -> void:
	if credits_layer.visible and event.is_action_pressed("ui_cancel"):
		_close_credits()
		get_viewport().set_input_as_handled()


# ---------- layout helpers ----------

func _fit_to_size() -> void:
	background.pivot_offset = size * 0.5
	stars.position = size * 0.5
	stars.emission_rect_extents = size * 0.5


func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


func _pop(control: Control, target: float) -> void:
	var tw := create_tween()
	tw.tween_property(control, "scale", Vector2(target, target), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_stage_chips() -> void:
	for i in STAGES.size():
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(COBALT, 0.28)
		style.set_border_width_all(2)
		style.border_color = Color(0.62, 0.70, 0.95, 0.55)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 14
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		chip.add_theme_stylebox_override("panel", style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		chip.add_child(row)

		var num := Label.new()
		num.theme_type_variation = &"MonoLabel"
		num.text = "%02d" % (i + 1)
		num.add_theme_color_override("font_color", PHOSPHOR)
		row.add_child(num)

		var name_label := Label.new()
		name_label.theme_type_variation = &"MonoLabel"
		name_label.text = String(STAGES[i]).to_upper()
		name_label.add_theme_color_override("font_color", NEAR_WHITE)
		row.add_child(name_label)

		stages_row.add_child(chip)


# ---------- motion ----------

func _play_intro() -> void:
	fade.color.a = 1.0
	var reveal: Array[Control] = [logo]
	reveal.append_array(stages_row.get_children().map(func(n): return n as Control))
	reveal.append(start_button)
	reveal.append(hint)
	reveal.append(bottom_bar)
	for node in reveal:
		node.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	var t := 0.35
	for node in reveal:
		tw.parallel().tween_property(node, "modulate:a", 1.0, 0.55).set_delay(t)
		t += 0.12
	logo.scale = Vector2(0.94, 0.94)
	tw.parallel().tween_property(logo, "scale", Vector2.ONE, 0.9).set_delay(0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _play_idle() -> void:
	# Slow push-in on the moon plate.
	background.scale = Vector2(1.06, 1.06)
	var drift := create_tween().set_loops()
	drift.tween_property(background, "scale", Vector2(1.1, 1.1), 28.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(background, "scale", Vector2(1.06, 1.06), 28.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Logo glow breathes.
	var glow := create_tween().set_loops()
	glow.tween_property(logo, "self_modulate", Color(1.12, 1.12, 1.2, 1.0), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow.tween_property(logo, "self_modulate", Color(0.96, 0.96, 1.0, 1.0), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------- actions ----------

## The AI disclosure opens by itself the first time and stays until the player clicks it away.
## There is no timer: it only closes on a click, Esc or the button.
func _show_ai_notice_once() -> void:
	if PlayerData.ai_notice_seen:
		return
	await get_tree().create_timer(1.5).timeout
	if is_inside_tree() and not _starting and not credits_layer.visible:
		_open_credits()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_credits()


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween().set_parallel()
	tw.tween_property(fade, "color:a", 1.0, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_property(background, "scale", background.scale * 1.1, 0.6).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(next_scene)


func _open_credits() -> void:
	start_button.focus_mode = Control.FOCUS_NONE
	credits_layer.modulate.a = 0.0
	credits_layer.show()
	create_tween().tween_property(credits_layer, "modulate:a", 1.0, 0.18)
	credits_close.grab_focus()


func _close_credits() -> void:
	PlayerData.ai_notice_seen = true
	var tw := create_tween()
	tw.tween_property(credits_layer, "modulate:a", 0.0, 0.14)
	await tw.finished
	credits_layer.hide()
	start_button.focus_mode = Control.FOCUS_ALL
	start_button.grab_focus()
