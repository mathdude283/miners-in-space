extends SceneTree

var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _initialize() -> void:
	var b := BuildState.new()
	check("new ship has 6 empty bays", b.bays.size() == 6 and b.used_bays() == 0)
	check("empty ship is not ready", not b.is_ready())

	# Starters
	var s0 := BuildState.new(); s0.load_starter(ShipData.STARTERS[0])
	var t0 := s0.totals()
	print("  flyby totals: ", t0["mass"], " mass, ", t0["draw"], "/", t0["gen"], " power, cost ", t0["cost"])
	var p0 := s0.problems().map(func(p): return p["label"])
	print("  flyby problems: ", p0)
	check("flyby is missing comms (teaches the trade-off)", p0.has("Communications"))

	var s1 := BuildState.new(); s1.load_starter(ShipData.STARTERS[1])
	var t1 := s1.totals()
	print("  evidence totals: ", t1["mass"], " mass, ", t1["draw"], "/", t1["gen"], " power, cost ", t1["cost"])
	check("lunar evidence starter is NOT ready: it lacks power", not s1.is_ready() and s1.problems().map(func(p): return p["label"]).has("Power"))
	check("evidence starter is within weight and budget", int(t1["mass"]) <= 18 and int(t1["cost"]) <= 45)

	# Each room once
	var b2 := BuildState.new()
	check("place flight deck", b2.place_room("flight-deck") == 0)
	check("same room twice is refused", b2.place_room("flight-deck") == -1)
	check("place into chosen empty bay", b2.place_room("cargo", 4) == 4 and b2.bays[4] == "cargo")
	b2.undo()
	check("undo removes the last room", b2.bays[4] == "")

	# Opportunity cost: everything does not fit
	var b3 := BuildState.new()
	for r in ShipData.ROOMS:
		b3.place_room(r["id"])
	check("only 6 of 12 rooms fit", b3.used_bays() == 6)
	check("overbuilt ship is not ready", not b3.is_ready())

	# Mass / power / budget failures and fixes
	var b4 := BuildState.new()
	for id in ["flight-deck", "life-support", "science-lab", "airlock", "crew-quarters", "observation"]:
		b4.place_room(id)
	b4.kit = true; b4.wide = true; b4.close = true; b4.wings = 2
	var t4 := b4.totals()
	print("  heavy ship: mass ", t4["mass"], " power ", t4["draw"], "/", t4["gen"], " cost ", t4["cost"])
	check("heavy ship fails weight", int(t4["mass"]) > 18)



	var s2 := BuildState.new(); s2.load_starter(ShipData.STARTERS[1]); s2.set_wings(1)
	check("adding one solar wing makes the evidence starter ready", s2.is_ready())
	check("auto-fix no longer exists", not BuildState.new().has_method("apply_fix"))
	print("FAILS: ", fails)
	quit(fails)
