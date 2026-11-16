extends SceneTree
## Contracts 04 to 06: the data model (limits, power, instruments, phases), good and poor designs, the screens, and the campaign.
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()
const GOOD := {
	3: {"hull": "standard", "power": "solar_l", "battery": "bat_m", "comms": "dish_m", "computer": "cpu_r", "thermal": "th_h", "propulsion": "bi", "tank": "tank_1", "gnc": "gnc_b", "storage": "st_m", "instruments": ["thermal_ir", "radar", "visible"], "orbit": "leo"},
	4: {"hull": "standard", "power": "solar_l", "battery": "bat_m", "comms": "dish_m", "computer": "cpu_r", "thermal": "th_h", "propulsion": "bi", "tank": "tank_2", "gnc": "gnc_p", "storage": "st_m", "instruments": ["neutron", "spectrometer", "laser"], "orbit": "polar"},
	5: {"hull": "standard", "power": "rtg4", "battery": "bat_m", "comms": "dish_l", "computer": "cpu_a", "thermal": "th_h", "propulsion": "ion", "tank": "tank_2", "gnc": "gnc_p", "storage": "st_m", "instruments": ["magnetometer", "probe", "visible", "spectrometer"], "orbit": "cruise"},
}
const BEST_CHOICES := {3: [0, 0, 0, 0, 0, 1], 4: [0, 0, 0, 0, 0, 0], 5: [0, 0, 0, 1, 0, 0]}
func _run() -> void:
	await process_frame
	var pd = root.get_node("PlayerData")
	pd.autosave_enabled = false
	pd.new_campaign()
	for id in [3, 4, 5]:
		var m: Dictionary = SpaceData.mission(id)
		var d: Dictionary = SpaceData.derive(id, GOOD[id])
		check("%s: the good design is legal (%s)" % [m["name"], str(d["problems"])], bool(d["ok"]))
		var sc: Dictionary = SpaceData.score(id, GOOD[id], BEST_CHOICES[id], 1)
		check("%s: a good design played well earns an A (%d%%)" % [m["name"], int(sc["percent"])], String(sc["grade"]) == "A")
		check("%s: every phase worked" % m["name"], int(sc["wins"]) == (m["phases"] as Array).size())
		# a poor design
		var poor := {"hull": "light", "power": "solar_s", "battery": "bat_s", "comms": "ant_s", "computer": "cpu_b", "thermal": "th_p", "propulsion": "mono", "tank": "tank_0", "gnc": "gnc_b", "storage": "st_s", "instruments": ["visible"], "orbit": "heo"}
		var sp: Dictionary = SpaceData.score(id, poor, [0, 0, 0, 0, 0, 0], 1)
		check("%s: a poor design earns a D or F (%d%%)" % [m["name"], int(sp["percent"])], String(sp["grade"]) in ["D", "F"])
	# limits
	var over := GOOD[5].duplicate(true)
	over["hull"] = "hardened"
	over["power"] = "rtg"
	var dov: Dictionary = SpaceData.derive(5, over)
	check("Neptune: one RTG cannot run a big dish (not enough power)", not bool(dov["ok"]) and str(dov["problems"]).contains("power"))
	var sol := GOOD[5].duplicate(true)
	sol["power"] = "solar_l"
	check("Neptune: solar arrays make almost nothing out there", float(SpaceData.derive(5, sol)["gen"]) < 5.0 and not bool(SpaceData.derive(5, sol)["ok"]))
	var many := GOOD[3].duplicate(true)
	many["instruments"] = ["thermal_ir", "radar", "visible", "spectrometer"]
	check("Wildfire: a fourth instrument is over the three mounts", str(SpaceData.derive(3, many)["problems"]).contains("mounts"))
	var heavy := GOOD[3].duplicate(true)
	heavy["hull"] = "hardened"
	check("Wildfire: the hardened hull is too heavy for this template", str(SpaceData.derive(3, heavy)["problems"]).contains("Too heavy"))
	check("the RTG is not offered for Earth missions", SpaceData.parts_for(3, "power").size() == 2 and SpaceData.parts_for(5, "power").size() == 5)
	check("an incomplete design cannot launch", not bool(SpaceData.derive(3, {"instruments": [], "orbit": ""})["ok"]))
	# campaign gating and completion
	check("the design contracts wait for Contract 01", not pd.contract_status(3)["open"] and String(pd.contract_status(3)["short"]).contains("FINISH 01"))
	pd.campaign["done"] = [0]
	check("Contract 04 opens after Contract 01", pd.contract_status(3)["open"] and not pd.contract_status(4)["open"])
	pd.refresh_campaign()
	check("the design contracts never end the campaign", not bool(pd.campaign["over"]))
	var r: Dictionary = SpaceData.score(3, GOOD[3], BEST_CHOICES[3], 1)
	pd.complete_spacecraft(3, r)
	check("finishing one adds it to the story with a grade and points", pd.campaign["done"].has(3) and pd.campaign["log"].size() == 1 and String(pd.campaign["log"][0]["grade"]) == "A" and int(pd.campaign["points"]) > 0)
	check("and opens the next one", pd.contract_status(4)["open"])
	# the screens
	pd.scenario = 3
	var sd = load("res://space_design.tscn").instantiate()
	root.add_child(sd)
	current_scene = sd
	await create_timer(0.8).timeout
	check("the design screen cannot launch an empty design", sd._launch.disabled)
	sd.picks = GOOD[3].duplicate(true)
	sd._refresh()
	check("and can launch a legal one", not sd._launch.disabled)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/out/space_design.png"))
	sd.queue_free()
	await process_frame
	pd.space_picks = GOOD[3].duplicate(true)
	var so = load("res://space_ops.tscn").instantiate()
	root.add_child(so)
	current_scene = so
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/out/space_ops.png"))
	for k in [0, 0, 0, 0, 0, 1]:
		so.choose(k)
		so._i += 1
		so._show_phase()
		await process_frame
	await create_timer(0.4).timeout
	check("the mission ends on a result with a grade", so._result.has("grade") and String(so._result["grade"]) == "A")
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/out/space_result.png"))
	# mission select shows page two
	var ms = load("res://mission_select.tscn").instantiate()
	pd.campaign["briefed"] = true
	root.add_child(ms)
	current_scene = ms
	await create_timer(2.4).timeout
	ms.show_page(1)
	await create_timer(0.5).timeout
	var vis := 0
	for c in ms.cards_row.get_children():
		if c.visible:
			vis += 1
	check("page two shows the three spacecraft contracts", vis == 3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/out/space_select.png"))
	print("FAILS: ", fails)
	quit(fails)
