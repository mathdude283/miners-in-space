extends SceneTree
## The title screen with a saved campaign: the big button says CONTINUE, says how far you got, loads the campaign, and a quiet
## NEW CAMPAIGN button wipes it only after a second press. Without a save the title is unchanged (START).
## This test borrows the real save slot, so it puts back whatever was there before it ran.
var OUT := ProjectSettings.globalize_path("res://tests/out/")
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _wait(sec: float) -> void:
	await create_timer(sec).timeout
func _find_button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if String(b.text) == text:
			return b
	return null
func _run() -> void:
	var SG = load("res://save_game.gd")
	var had_save: bool = FileAccess.file_exists(SG.PATH)
	var old_text := FileAccess.get_file_as_string(SG.PATH) if had_save else ""
	var pd = root.get_node("PlayerData")
	pd.autosave_enabled = true
	pd.ai_notice_seen = true
	await process_frame
	# 1. no save: the title is the plain START
	SG.erase()
	pd.new_campaign()
	var t0: Node = load("res://title.tscn").instantiate()
	root.add_child(t0)
	current_scene = t0
	await _wait(1.6)
	check("with no save the button says START", t0.start_button.text == "START")
	check("and there is no NEW CAMPAIGN button", _find_button(t0, "NEW CAMPAIGN") == null)
	t0.queue_free()
	await process_frame
	# 2. a save with a finished contract and a hurt crew member
	pd.new_campaign()
	pd.campaign["crew_chosen"] = true
	var c: Array[Dictionary] = []
	c.append(CrewData.make("ada", "Maya", "COMMANDER"))
	c.append(CrewData.make("sam", "Jo", "PILOT"))
	c[1]["health"] = 55.0
	pd.crew = c
	var b: BuildState = pd.get_build()
	for i in ["flight-deck", "life-support", "observation", "communications", "science-lab"].size():
		b.bays[i] = ["flight-deck", "life-support", "observation", "communications", "science-lab"][i]
	b.wide = true
	b.kit = true
	b.wings = 2
	pd.complete_contract(0)
	check("the campaign was saved when the contract completed", SG.has_save())
	pd.new_campaign()                                   # like closing the game and opening it again
	var t1: Node = load("res://title.tscn").instantiate()
	root.add_child(t1)
	current_scene = t1
	await _wait(1.8)
	check("with a save the button says CONTINUE", t1.start_button.text == "CONTINUE")
	check("and CONTINUE fits its button", t1.start_button.get_theme_font("font").get_string_size("CONTINUE", HORIZONTAL_ALIGNMENT_LEFT, -1, t1.start_button.get_theme_font_size("font_size")).x < t1.start_button.size.x - 20.0)
	check("the hint says how far you got", t1.hint.text.contains("1 CONTRACT DONE") and t1.hint.text.contains("2 CREW"))
	var nb := _find_button(t1, "NEW CAMPAIGN")
	check("a quiet NEW CAMPAIGN button is there", nb != null)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "title_continue.png")
	# NEW CAMPAIGN needs two presses
	nb.pressed.emit()
	await process_frame
	check("one press only asks 'sure'", SG.has_save() and nb.text.begins_with("SURE"))
	# 3. CONTINUE loads the campaign
	t1.start_button.pressed.emit()
	await _wait(1.2)
	check("CONTINUE loads the finished contract", pd.campaign["done"].has(0) and bool(pd.campaign["locked"]))
	check("and the crew with their health", pd.crew.size() == 2 and pd.crew[0]["name"] == "Maya" and is_equal_approx(float(pd.crew[1]["health"]), 55.0))
	check("and the ship", pd.get_build().has_room("science-lab") and pd.get_build().wings == 2)
	# 4. the second press wipes the save
	if is_instance_valid(t1):
		t1.queue_free()
	var t2: Node = load("res://title.tscn").instantiate()
	root.add_child(t2)
	current_scene = t2
	await _wait(1.8)
	var nb2 := _find_button(t2, "NEW CAMPAIGN")
	nb2.pressed.emit()
	nb2.pressed.emit()
	await process_frame
	check("a second press wipes the save", not SG.has_save())
	check("and the title goes back to START", t2.start_button.text == "START")
	# put the real save back exactly as it was
	if had_save:
		var f := FileAccess.open(SG.PATH, FileAccess.WRITE)
		f.store_string(old_text)
		f.close()
	else:
		SG.erase()
	pd.autosave_enabled = false
	print("FAILS: ", fails)
	quit(fails)
