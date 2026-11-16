class_name SourcesPanel
extends Control
## "Sound, sources and credits": the volume sliders, what is REAL (with where it comes from), what is GAME, and the AI
## disclosure in short. Opens over any screen. Click GOT IT or press Escape to close.

signal closed

const REAL := [
	["Glushko", "A young crater on the west rim of Olbers, about 40 km across, with bright rays. USGS Gazetteer of Planetary Nomenclature, Moon, feature 2195.", "https://planetarynames.wr.usgs.gov/Feature/2195"],
	["Ohm", "A far-side crater about 62 km across with rays that reach hundreds of km. USGS Gazetteer, feature 4417.", "https://planetarynames.wr.usgs.gov/Feature/4417"],
	["Sun angle", "Low Sun casts sharp shadows that show texture. High Sun casts none, so brightness differences like rays stand out. LROC 'Sun Angles'.", "https://lroc.im-ldi.com/images/790"],
	["Countdown", "T-6:00 pyros armed, T-4:30 flight termination system armed, T-33 s go for the automated sequencer, and the hold rules (3 minutes between T-6:00 and T-1:30). NASA Artemis II Press Kit.", "https://www.nasa.gov/artemis-ii-press-kit/"],
	["Blackout", "The Moon blocked radio for about 40 minutes (planned 6:44 to 7:25 p.m. EDT). NASA flight day 6 lunar flyby updates. The game's blackout is much shorter and is a GAME rule.", "https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/"],
	["NASA image", "The real far-side view in the report: annotated, credit NASA, from the flight day 6 blog. Your photos are SIMULATED.", "https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/"],
	["Real spacecraft numbers", "The REAL line on a part in Build (antennas, solar arrays, flight computers, cameras, spectrometer) comes from the team's spacecraft sheet, which cites NASA's SmallSat Institute pages. Not yet checked line by line. Game weight, power and cost are GAME numbers. Full table: REAL-SPACECRAFT-SHEET.md.", "https://www.nasa.gov/smallsat-institute/sst-soa/"],
	["Launch day", "The Launch Director's poll, the NASA Test Director, the Ground Launch Sequencer and weather limits. NASA Artemis I and II launch pages (listed in the game's source notes).", "https://www.nasa.gov/artemis-ii-weather-criteria/"],
	["Weather", "Lightning, wind and temperature limits follow NASA's Artemis II weather criteria page.", "https://www.nasa.gov/artemis-ii-weather-criteria/"],
	["Return to Earth", "Crew module separation, the raise burn, entry at about 400,000 ft with up to 3.9 g, about six minutes of blackout, drogues near 22,000 ft, mains near 6,000 ft, splashdown at about 20 mph off San Diego, and recovery by the Navy. NASA Artemis II flight day 10 pages (April 2026).", "https://www.nasa.gov/blogs/missions/2026/04/10/artemis-ii-flight-day-10-re-entry-live-updates/"],
	["Rooms", "Why a crew needs each room follows NASA pages on Orion, life support and the space station (named in the Build inspector).", ""],
]
const GAME := "Weight, power, budget and time numbers, the three Sun passes and their waiting times, the comparability score, crew health, hearts and energy, random events, and the scoring are game rules. They are not NASA data."
const AI := "Artwork and the crew were made with AI image generation from the team's Y2K direction. Sounds are synthesized in code. The six music pieces are original synthesized piano and strings, with no commercial samples. Code, text and tests were written with AI assistance (Claude Code and Codex). NASA does not endorse or sponsor this game."


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if theme == null:
		theme = load("res://assets/themes/moonbound_theme.tres")
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1100, 0)
	p.add_theme_stylebox_override("panel", UiStyle.panel(26, 0.97))
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 16)
	var cart := TextureRect.new()
	cart.texture = load("res://assets/ui/kit/moonbound03_data_cartridge.png")
	cart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cart.custom_minimum_size = Vector2(96, 64)
	hrow.add_child(cart)
	hrow.add_child(UiStyle.heading("SOUND, SOURCES AND CREDITS"))
	col.add_child(hrow)

	# Sound
	col.add_child(UiStyle.mono_label("SOUND   (press M anywhere to mute everything)", 14, UiStyle.PHOSPHOR))
	col.add_child(_slider("MUSIC", Music.music_volume, func(v): Music.set_music(v)))
	col.add_child(_slider("SOUND EFFECTS", Music.sfx_volume, func(v): Music.set_sfx(v)))

	# Sources
	col.add_child(UiStyle.mono_label("REAL, AND WHERE IT COMES FROM", 14, UiStyle.PHOSPHOR))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1040, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for r in REAL:
		list.add_child(_row("REAL", String(r[0]), String(r[1]), UiStyle.PHOSPHOR, String(r[2]) if r.size() > 2 else ""))
	list.add_child(_row("GAME", "Numbers and rules", GAME, UiStyle.AMBER))
	list.add_child(_row("AI", "How it was made", AI, UiStyle.CHROME))
	var ok := Button.new()
	ok.text = "GOT IT"
	ok.theme_type_variation = &"PrimaryButton"
	ok.add_theme_font_size_override("font_size", 28)
	ok.custom_minimum_size = Vector2(260, 84)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_close)
	col.add_child(ok)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()


func _slider(title: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiStyle.mono_label(title, 15, UiStyle.NEAR_WHITE)
	l.custom_minimum_size = Vector2(190, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(520, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	var pct := UiStyle.mono_label("%d%%" % int(round(value * 100.0)), 15, Color(UiStyle.NEAR_WHITE, 0.75))
	pct.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(v):
		pct.text = "%d%%" % int(round(v * 100.0))
		on_change.call(v))
	row.add_child(s)
	row.add_child(pct)
	return row


func _row(tag: String, title: String, text: String, color: Color, url := "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var t := UiStyle.mono_label(tag, 13, color)
	t.custom_minimum_size = Vector2(60, 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(t)
	var l := VBoxContainer.new()
	l.custom_minimum_size = Vector2(940, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := Label.new()
	body.text = "%s.  %s" % [title, text]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(UiStyle.NEAR_WHITE, 0.92))
	body.custom_minimum_size = Vector2(940, 0)
	l.add_child(body)
	if url != "":
		var lk := LinkButton.new()
		lk.text = url
		lk.uri = url
		lk.add_theme_font_size_override("font_size", 13)
		l.add_child(lk)
	row.add_child(l)
	return row
