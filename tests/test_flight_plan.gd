extends SceneTree

var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _plan(s: BuildState) -> Array[Dictionary]:
	return load("res://flight.gd").make_plan(s)

func _first(s: BuildState) -> Dictionary:
	var p := _plan(s)
	for e in p:
		if not e["ok"]:
			return e
	return {}

func _initialize() -> void:
	# A good ship flies all the way
	var good := BuildState.new(); good.load_starter(ShipData.STARTERS[1]); good.set_wings(1)
	check("good ship: no failing stage", _first(good).is_empty())

	# Flyby starter has no radio -> fails at RADIO (the last stage)
	var fly := BuildState.new(); fly.load_starter(ShipData.STARTERS[0])
	var f := _first(fly)
	print("  flyby: ", f)
	check("flyby fails at RADIO", f.get("name", "") == "RADIO")

	# Lunar evidence starter lacks power -> fails in the CLIMB
	var ev := BuildState.new(); ev.load_starter(ShipData.STARTERS[1])
	f = _first(ev)
	print("  evidence: ", f)
	check("no wing fails at CLIMB (power)", f.get("name", "") == "CLIMB" and f.get("kind", "") == "power")

	# Too heavy
	var heavy := BuildState.new(); heavy.load_starter(ShipData.STARTERS[1]); heavy.set_wings(1)
	heavy.kit = true; heavy.wide = true; heavy.close = true
	heavy.remove_bay(5)
	heavy.place_room("science-lab"); heavy.place_room("airlock")
	var hs := heavy.totals()
	print("  heavy totals: ", hs["mass"], " mass, cost ", hs["cost"])
	f = _first(heavy)
	check("overweight or over budget stops LIFTOFF", f.get("name", "") == "LIFTOFF")

	# Each missing need ends at its own stage
	var no_ctl := BuildState.new(); no_ctl.load_starter(ShipData.STARTERS[1]); no_ctl.set_wings(1); no_ctl.remove_bay(0)
	check("no flight deck fails CLIMB (control)", _first(no_ctl).get("kind", "") == "control")
	var no_air := BuildState.new(); no_air.load_starter(ShipData.STARTERS[1]); no_air.set_wings(1); no_air.remove_bay(1)
	check("no life support fails ORBIT", _first(no_air).get("name", "") == "ORBIT")
	var no_win := BuildState.new(); no_win.load_starter(ShipData.STARTERS[1]); no_win.set_wings(1); no_win.remove_bay(3)
	check("no observation bay fails PHOTO", _first(no_win).get("name", "") == "PHOTO")
	var no_lens := BuildState.new(); no_lens.load_starter(ShipData.STARTERS[1]); no_lens.set_wings(1); no_lens.wide = false
	check("no lens fails PHOTO", _first(no_lens).get("name", "") == "PHOTO")
	var no_comms := BuildState.new(); no_comms.load_starter(ShipData.STARTERS[1]); no_comms.set_wings(1); no_comms.remove_bay(4)
	check("no radio fails RADIO", _first(no_comms).get("name", "") == "RADIO")
	var no_kit := BuildState.new(); no_kit.load_starter(ShipData.STARTERS[1]); no_kit.set_wings(1); no_kit.kit = false
	check("no crew kit (no food etc) fails ORBIT", _first(no_kit).get("name", "") == "ORBIT")

	# Earliest failure wins
	var empty := BuildState.new()
	check("empty ship: first failure is the earliest stage it breaks", _first(empty).get("name", "") in ["CLIMB"])
	print("FAILS: ", fails)
	quit(fails)
