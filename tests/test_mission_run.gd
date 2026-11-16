extends SceneTree

var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _plan(s: BuildState, m: int) -> Array[Dictionary]:
	return load("res://flight.gd").make_plan(s, m)

func _first(s: BuildState, m: int) -> Dictionary:
	for e in _plan(s, m):
		if not e["ok"]:
			return e
	return {}

func _initialize() -> void:
	# ---- mission data
	check("three contracts", Missions.LIST.size() == 3)
	check("get_mission clamps a bad id", Missions.get_mission(99)["name"] == "IMPACT WATCH" and Missions.get_mission(-5)["name"] == "ORIENTALE")
	for m in Missions.LIST:
		check("%s has objectives, target, budget, needs" % m["name"], m.has("objectives") and m.has("target") and m.has("budget") and m.has("needs"))
	check("contract 02 has the re-observe / Ohm branch", Missions.get_mission(1)["branch"]["choices"].size() == 2)

	# ---- run: resources
	var crew: Array[Dictionary] = CrewData.defaults()
	var r := MissionRun.start(0, crew, 7)
	check("run starts with the contract's budget", r.left("time") == 40.0 and r.left("power") == 20.0)
	check("spend works", r.spend("time", 15.0) and r.left("time") == 25.0)
	check("overspend is refused and spends nothing", not r.spend("time", 30.0) and r.left("time") == 25.0)
	r.restore("time", 100.0)
	check("restore stops at the maximum", r.left("time") == 40.0)
	check("fraction", absf(r.fraction("power") - 1.0) < 0.001)
	check("unknown resource is zero and unspendable", r.left("nope") == 0.0 and not r.spend("nope", 1.0))

	# ---- run: objectives and choices
	check("objectives start undone", r.progress() == Vector2i(0, 3) and not r.all_done())
	r.complete("photo"); r.complete("tag")
	check("progress counts", r.progress() == Vector2i(2, 3) and r.is_done("photo") and not r.is_done("send"))
	r.complete("nonsense")
	check("unknown objective is ignored", r.progress() == Vector2i(2, 3))
	r.complete("send")
	check("all done", r.all_done())
	r.choose("second", "ohm")
	check("choice is remembered", r.chosen("second") == "ohm" and r.chosen("other") == "")
	r.log_event("Power dip", "shed load")
	check("event log", r.events.size() == 1 and r.events[0]["choice"] == "shed load")

	# ---- run: crew copies, does not share
	var a := MissionRun.start(0, crew, 1)
	a.hurt(0, 30.0); a.tire(1, 120.0)
	check("hurt lowers health, tire clamps at zero", a.crew[0]["health"] == 70.0 and a.crew[1]["energy"] == 0.0)
	check("run crew is a copy of the roster", crew[0]["health"] == 100.0)
	a.hurt(2, 500.0)
	check("health cannot go below zero, role is no longer fit", a.crew[2]["health"] == 0.0 and not a.crew_fit("SCIENTIST") and a.crew_fit("PILOT"))

	# ---- reasons and deaths
	var b := MissionRun.start(0, crew, 3)
	var heard := []
	b.crew_hurt.connect(func(i, amount, reason, died): heard.append([i, amount, reason, died]))
	var died1 := b.hurt(0, 30.0, "Ada is starving: no food left.", "Starving")
	check("a hurt reports who, how much and why", heard.size() == 1 and heard[0][2] == "Ada is starving: no food left." and not heard[0][3] and not died1)
	check("the short reason shows in how they are doing", b.status_line(0) == "Starving")
	var died2 := b.hurt(0, 500.0, "Nothing left to eat or drink.")
	check("the last heart is a death with a cause", died2 and b.is_dead(0) and b.crew[0]["cause"] == "Nothing left to eat or drink.")
	check("the death signal says died", heard.size() == 2 and heard[1][3])
	check("the dead are listed with their cause", b.deaths().size() == 1 and b.deaths()[0]["cause"] == "Nothing left to eat or drink.")
	check("the dead cannot be hurt again", not b.hurt(0, 10.0, "x") and heard.size() == 2)
	check("status for the dead says lost", b.status_line(0).begins_with("Lost"))
	check("alive count drops", b.alive_count() == 2)
	check("hearts are health over twenty", absf(b.hearts(1) - 5.0) < 0.001)
	b.crew[1]["energy"] = 30.0
	check("tired is said plainly", b.status_line(1).begins_with("Tired"))
	var gone := b.kill_all("The ship was destroyed.")
	check("kill_all returns who was lost", gone.size() == 2 and b.alive_count() == 0)
	check("crew summary shows LOST", b.crew_summary().contains("LOST"))
	check("everything that hurt is in the log", b.damage_log.size() >= 3)

	# ---- seeded randomness is repeatable
	var s1 := MissionRun.start(0, [], 123); var s2 := MissionRun.start(0, [], 123)
	check("same seed gives the same random numbers", s1.rng.randi() == s2.rng.randi())

	# ---- crew names are cleaned
	check("name trims and strips markup", CrewData.clean_name("  [b]Ma[/b]ya  ", "X") == "bMa/bya".substr(0, 12) or CrewData.clean_name("  [b]Ma[/b]ya  ", "X") == "bMa/bya")
	check("empty name falls back", CrewData.clean_name("   ", "Ada") == "Ada")
	check("long name is cut", CrewData.clean_name("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "X").length() == CrewData.MAX_NAME)

	# ---- mission-aware plan
	var lab_ship := BuildState.new(); lab_ship.load_starter(ShipData.STARTERS[1]); lab_ship.set_wings(1)
	check("contract 01: the evidence ship flies", _first(lab_ship, 0).is_empty())
	check("contract 02 needs a science lab: PHOTO fails without one", _first(lab_ship, 1).get("name", "") == "PHOTO")
	var with_lab := BuildState.new(); with_lab.load_starter(ShipData.STARTERS[1]); with_lab.set_wings(1)
	with_lab.place_room("science-lab", 5); with_lab.set_wings(2); with_lab.remove_bay(2)   # the lab draws power (two wings) and weighs 3 (the crew kit covers the cargo bay)
	check("contract 02 passes the lab check with a lab", _first(with_lab, 1).is_empty())
	check("default argument still works (older callers)", load("res://flight.gd").make_plan(lab_ship).size() == 5)

	# ---- perks
	var bare := BuildState.new()
	var p0 := ShipData.flight_perks(bare)
	check("bare ship: no bonuses", p0["shake"] == 1.0 and p0["tries"] == 2 and absf(p0["beam"] - 0.26) < 0.001)
	var p1 := ShipData.flight_perks(with_lab)
	check("flight deck steadies the camera, lab adds a try", absf(p1["shake"] - 0.8) < 0.001 and p1["tries"] == 3)
	check("two wings (this ship) widen the beam", absf(p1["beam"] - 0.34) < 0.001)
	with_lab.set_wings(1)
	check("one wing is the old radio beam", absf(ShipData.flight_perks(with_lab)["beam"] - 0.30) < 0.001)
	with_lab.set_wings(2)
	check("two wings widen the beam", absf(ShipData.flight_perks(with_lab)["beam"] - 0.34) < 0.001)
	var p2 := ShipData.flight_perks(with_lab, crew)
	check("a fit pilot steadies the camera a bit more", absf(p2["shake"] - 0.72) < 0.001)
	var hurt_crew: Array[Dictionary] = CrewData.defaults(); hurt_crew[1]["health"] = 0.0
	check("a downed pilot does not", absf(ShipData.flight_perks(with_lab, hurt_crew)["shake"] - 0.8) < 0.001)
	check("perk summary mentions what is fitted", ShipData.perk_summary(p1, "photo").contains("Flight Deck"))
	check("perk summary suggests what would help", ShipData.perk_summary(p0, "photo").contains("In Build you can"))

	print("FAILS: ", fails)
	quit(fails)
