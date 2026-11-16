extends SceneTree
## The REAL spacecraft line in the Build inspector: parts that have real numbers show them (kg, W, $M); parts with none show nothing.
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
	for k in ["flight-deck", "communications", "observation", "science-lab", "wing", "wide", "close"]:
		var info: Dictionary = ShipData.info(k)
		check("%s has a REAL line with real units" % k, String(info.get("real", "")).begins_with("REAL:") and String(info["real"]).contains("kg"))
	check("a crew room with no real figure shows none", String(ShipData.info("galley").get("real", "")) == "")
	var pi = load("res://part_inspector.gd").new()
	root.add_child(pi)
	await process_frame
	pi.theme = load("res://assets/themes/moonbound_theme.tres")
	pi.show_part({"name": "Communications", "mass": 2, "power": 2, "cost": 5}, ShipData.info("communications"), "ADD", true)
	check("the inspector shows the antenna numbers", pi._real.text.contains("Medium dish 300 kg") and pi._real_tag.text == "REAL")
	pi.show_part({"name": "Galley", "mass": 2, "power": 1, "cost": 4}, ShipData.info("galley"), "ADD", true)
	check("and nothing for a part without them", pi._real.text == "" and pi._real_tag.text == "")
	check("the sheet is kept in the project with its CHECK flags", FileAccess.file_exists("res://REAL-SPACECRAFT-SHEET.md") and FileAccess.get_file_as_string("res://REAL-SPACECRAFT-SHEET.md").contains("CHECK"))
	print("FAILS: ", fails)
	quit(fails)
