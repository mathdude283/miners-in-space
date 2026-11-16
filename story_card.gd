class_name StoryCard
extends Control
## Mission Control talking to the player between scenes: the opening briefing, and a short debrief after each contract that
## says what the player just did and what comes next. A few pages, one click each. It is fiction inspired by Artemis II.

signal finished

var pages: Array[String] = []
var title_text := "MISSION CONTROL"

var _i := 0
var _coach: CoachPanel
var _btn: Button
var _count: Label


## The opening briefing for a new campaign.
static func briefing() -> Array[String]:
	return [
		"Welcome, Flight Director. This is Mission Control. In April 2026, NASA's Artemis II crew flew around the Moon. You are about to run a FICTIONAL mission inspired by that flight.",
		"You have three contracts and ONE ship. You build the ship once, and after your first contract it is locked. Choose your crew, build carefully, and above all bring them home.",
		"Contract 01: photograph the Orientale Basin. Contract 02: compare two craters under different light. Contract 03: work out what you can honestly conclude when nobody saw the same Moon. Good luck.",
	]


## After contract `id` is done: what you did, then what is next. `log` is the campaign log (PlayerData.campaign["log"]).
static func debrief(id: int, log: Array) -> Array[String]:
	var pages_out: Array[String] = []
	var entry := {}
	for e in log:
		if int(e.get("id", -1)) == id:
			entry = e
	if not entry.is_empty():
		pages_out.append("%s is in the books. %s %s" % [String(entry.get("name", "That contract")), String(entry.get("headline", "")), String(entry.get("detail", ""))])
	match id:
		0:
			pages_out.append("Next is Glushko and Ohm: two craters, and the light on them changes what you can see. Plan your Sun pass before you shoot, and compare like with like.")
		1:
			pages_out.append("The last contract is Impact Watch. Something may flash on the far side, and your windows will not all see it. What you send decides what Mission Control can truly conclude.")
	return pages_out


func _ready() -> void:
	theme = load("res://assets/themes/moonbound_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	_count = UiStyle.mono_label("", 14, UiStyle.AMBER)
	col.add_child(_count)
	_coach = CoachPanel.new(1200.0, 28)
	col.add_child(_coach)
	_btn = Button.new()
	_btn.theme_type_variation = &"PrimaryButton"
	_btn.add_theme_font_size_override("font_size", 26)
	_btn.custom_minimum_size = Vector2(360, 84)
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.pressed.connect(advance)
	col.add_child(_btn)
	_show()


func _show() -> void:
	if pages.is_empty():
		finished.emit()
		queue_free()
		return
	_coach.say(pages[_i])
	_count.text = "%s   %d / %d" % [title_text, _i + 1, pages.size()]
	_btn.text = "NEXT" if _i < pages.size() - 1 else "GOT IT"


## Go to the next page, or close after the last. Public so a test can stand in for the click.
func advance() -> void:
	if _i < pages.size() - 1:
		_i += 1
		Sfx.play("click", -6.0)
		_show()
	else:
		finished.emit()
		queue_free()
