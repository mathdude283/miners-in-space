extends SceneTree

var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _initialize() -> void:
	var pd = root.get_node("PlayerData")
	pd.new_campaign()
	check("a new campaign starts with nothing done, ship not locked", pd.campaign["done"].is_empty() and not pd.campaign["locked"] and not pd.campaign["over"])
	check("a new campaign has three crew at full health", pd.crew.size() == 3 and pd.crew[0]["health"] == 100.0)
	var st0 = pd.contract_status(0)
	check("contract 01 is open from the start", st0["open"] and not st0["done"])
	var st1 = pd.contract_status(1)
	check("contract 02 is not open yet and says why", not st1["open"] and String(st1["reason"]).length() > 5)

	# requirements read the ship
	var bare := BuildState.new()
	var req := Missions.requirements(1, bare)
	var labels: Array = req.map(func(r): return r["label"])
	check("contract 02 lists the Science Lab as a need", labels.has("Science Lab"))
	check("a bare ship meets none of them", req.all(func(r): return not r["ok"]))
	var ship := BuildState.new(); ship.load_starter(ShipData.STARTERS[1]); ship.set_wings(1)
	var req1 := Missions.requirements(0, ship)
	check("the evidence ship meets contract 01", req1.all(func(r): return r["ok"]))
	var req2 := Missions.requirements(1, ship)
	check("but not the Science Lab for contract 02", req2.any(func(r): return r["label"] == "Science Lab" and not r["ok"]))

	# completing contract 01 locks the ship and keeps the crew
	pd.build = ship
	pd.scenario = 0
	pd.start_run()
	pd.run.hurt(0, 500.0, "Test cause: ran out of air.")
	pd.run.hurt(1, 40.0, "Test bruise.")
	pd.complete_contract(0)
	pd.sync_crew_after_flight()
	check("completing a contract locks the ship", pd.campaign["locked"] and pd.campaign["done"] == [0])
	check("the dead are removed for good", pd.crew.size() == 2)
	check("the survivors recover on the ground", pd.crew[0]["health"] == 100.0 and pd.crew[0]["note"] == "")
	check("contract 01 now shows as complete", pd.contract_status(0)["done"] and not pd.contract_status(0)["open"])

	# with the locked ship lacking a lab, a contract that needs one is impossible
	pd.refresh_campaign()
	# (contract 02 is not built yet in this version, so the campaign counts as won rather than blocked)
	check("with nothing left to play the campaign is over", pd.campaign["over"])

	# losing everyone ends it with the causes
	pd.new_campaign()
	pd.build = ship
	pd.scenario = 0
	pd.start_run()
	pd.run.kill_all("The ship was destroyed.")
	pd.sync_crew_after_flight()
	check("no crew left ends the campaign", pd.campaign["over"] and pd.crew.is_empty())
	check("the reason names the cause", String(pd.campaign["over_reason"]).contains("destroyed"))
	check("an over campaign closes every contract", not pd.contract_status(0)["open"])
	pd.new_campaign()
	check("a new campaign starts fresh again", not pd.campaign["over"] and pd.crew.size() == 3 and pd.build == null)
	print("FAILS: ", fails)
	quit(fails)
