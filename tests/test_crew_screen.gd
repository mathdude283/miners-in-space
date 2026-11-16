extends SceneTree
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
func _run() -> void:
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.new_campaign()
	var scene: Node = load("res://crew_screen.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.5).timeout
	check("three seats", scene._slots.size() == 3)
	check("seven people to pick from", scene._roster.size() == 7)
	check("seats start with Ada, Sam and Noor", scene._slots[0]["char"] == "ada" and scene._slots[1]["char"] == "sam" and scene._slots[2]["char"] == "noor")
	scene._select(1)
	scene._assign("ren")
	check("clicking a face puts them in the selected seat", scene._slots[1]["char"] == "ren")
	check("their own name comes with them", scene._slots[1]["field"].text == "Ren")
	scene._assign("ada")
	check("picking someone already seated swaps the two", scene._slots[1]["char"] == "ada" and scene._slots[0]["char"] == "ren")
	check("names follow the swap while not edited", scene._slots[0]["field"].text == "Ren" and scene._slots[1]["field"].text == "Ada")
	scene._slots[2]["field"].text = "[b]Zed[/b]"
	scene._slots[2]["field"].text_changed.emit(scene._slots[2]["field"].text)
	scene._select(2)
	scene._assign("jules")
	check("an edited name is kept when the look changes", scene._slots[2]["char"] == "jules" and scene._slots[2]["field"].text.contains("Zed"))
	scene._slots[0]["field"].text = ""
	scene._on_continue()
	await create_timer(1.0).timeout
	check("the chosen crew is saved with their looks", pd.crew[0]["char"] == "ren" and pd.crew[1]["char"] == "ada" and pd.crew[2]["char"] == "jules")
	check("roles stay with the seats", pd.crew[0]["role"] == "COMMANDER" and pd.crew[1]["role"] == "PILOT" and pd.crew[2]["role"] == "SCIENTIST")
	check("an empty name falls back to the character's name", pd.crew[0]["name"] == "Ren")
	check("markup is stripped from names", not String(pd.crew[2]["name"]).contains("[") and String(pd.crew[2]["name"]).length() <= 12)
	check("crew chosen is remembered", pd.campaign["crew_chosen"])
	check("moves on to the Build screen", current_scene != null and current_scene.name == "BuildScreen")
	var run = pd.start_run()
	check("a run starts with the chosen crew at full health", run.crew[0]["char"] == "ren" and run.crew[0]["health"] == 100.0)
	print("FAILS: ", fails)
	quit(fails)
