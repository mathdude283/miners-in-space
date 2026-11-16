extends SceneTree

var fails := 0
var got := {}

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _make(s: BuildState):
	var run = load("res://mission_run.gd").start(0, CrewData.defaults(), 5)
	var op = load("res://ship_interior.gd").new()
	op.state = s
	op.run = run
	op.mission_id = 0
	root.add_child(op)
	return op

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_run()

func _rooms(op) -> Array:
	return op._pads.map(func(p): return p["room"])

func _run() -> void:
	await process_frame
	var s := BuildState.new(); s.load_starter(ShipData.STARTERS[1]); s.set_wings(1)
	var op = _make(s)
	await create_timer(0.3).timeout
	check("one pad per built room, in ship order", _rooms(op) == ["flight-deck", "life-support", "cargo", "observation", "communications"])
	check("no pad for a room that was not built", not _rooms(op).has("galley") and not _rooms(op).has("science-lab"))
	var xs: Array = op._pads.map(func(p): return p["x"])
	var sorted := true
	for i in range(1, xs.size()):
		if xs[i] <= xs[i - 1]:
			sorted = false
	check("pads run left to right", sorted)
	check("three crew on deck", op._astros.size() == 3)

	var IC = load("res://ship_interior.gd")
	var photo: Dictionary = IC.TASKS["observation"]
	var send: Dictionary = IC.TASKS["communications"]
	check("photo is ready at the start", op.check_task(photo) == "")
	check("sending is refused before there is a photo", op.check_task(send).contains("photo first"))

	# resources
	var a: Dictionary = op.run.crew[0]
	a["energy"] = 5.0
	check("a tired crew member cannot take the photo", op.check_task(photo).contains("too tired"))
	op._select(1)
	check("someone else can", op.check_task(photo) == "")
	op._select(0); a["energy"] = 100.0
	var t_before: float = op.run.left("time")
	op.run.resources["time"]["cur"] = 3.0
	check("not enough time is refused", op.check_task(photo).contains("time"))
	op.run.resources["time"]["cur"] = t_before
	op.run.resources["power"]["cur"] = 1.0
	check("not enough power is refused", op.check_task(photo).contains("power"))
	op.run.resources["power"]["cur"] = 30.0

	# a fake photo lets sending be checked
	op._shots["wide"] = {"lens": "wide", "score": 0.9, "stars": 3, "confidence": "STRONG", "tag_ok": true}
	check("sending is allowed once there is something to send", op.check_task(send) == "")
	op._received.append("wide")
	check("sending is refused when everything has been sent", op.check_task(send).contains("sent"))

	# position and pads
	op.teleport_to("observation")
	check("standing on the observation pad finds it", op._near_pad().get("room", "") == "observation")
	op.teleport_to("flight-deck")
	check("the Flight Deck now has a job (the camera diagnosis)", op._near_pad().get("task", {}).get("kind", "") == "diagnose")
	check("with no fault the diagnosis says there is nothing to diagnose", String(op.check_task(op._near_pad()["task"])).contains("Nothing to diagnose"))
	op.teleport_to("life-support")
	check("a pad with no job says so", op._near_pad().get("task", {"x": 1}).is_empty())

	# crew switching
	op._select(2)
	check("selecting a crew member changes who acts", op._sel == 2 and op._astros[2].selected and not op._astros[0].selected)

	# finishing
	op.finished.connect(func(r): got = r)
	op.finish_ops()
	check("finish reports photos and what reached Earth", got.has("shots") and got["shots"]["photos"].size() == 1 and got["sent"]["received"] == ["wide"])
	check("finish says it was not a time-out", got.get("time_out", true) == false)
	op.queue_free()

	# a ship with extra rooms gets their jobs
	var s2 := BuildState.new(); s2.load_starter(ShipData.STARTERS[1]); s2.set_wings(2)
	s2.remove_bay(2); s2.place_room("crew-quarters", 5)
	var op2 = _make(s2)
	await create_timer(0.3).timeout
	check("a crew quarters gives a rest pad", _rooms(op2).has("crew-quarters"))
	var rest: Dictionary = IC.TASKS["crew-quarters"]
	check("rest is refused when not tired", op2.check_task(rest).contains("not tired"))
	op2.run.crew[0]["energy"] = 30.0
	check("rest is allowed when tired", op2.check_task(rest) == "")
	var t0: float = op2.run.left("time")
	op2.teleport_to("crew-quarters")
	await op2._perform(rest)
	check("resting wins energy back (and 6 minutes of hunger costs a little)", absf(float(op2.run.crew[0]["energy"]) - 66.4) < 0.01 and absf(t0 - op2.run.left("time") - 6.0) < 0.01)
	# starvation: no energy left means lost hearts, and the message says why
	op2.run.crew[1]["energy"] = 0.0
	var seen := []
	op2.run.crew_hurt.connect(func(i, amount, reason, died): seen.append(reason))
	op2._metabolize(5.0)
	check("someone with no energy loses health", float(op2.run.crew[1]["health"]) < 100.0)
	check("the reason says exhausted (this ship has a Crew Quarters)", seen.size() > 0 and String(seen[0]).contains("exhausted"))
	op2.queue_free()
	# a ship with no Galley or Crew Quarters says starving
	var s4 = BuildState.new(); s4.load_starter(ShipData.STARTERS[1]); s4.set_wings(1)
	var op4 = _make(s4)
	await create_timer(0.3).timeout
	op4.run.crew[0]["energy"] = 0.0
	var seen4 := []
	op4.run.crew_hurt.connect(func(i, amount, reason, died): seen4.append(reason))
	op4._metabolize(5.0)
	check("with no food or rest on the ship the reason says starving", seen4.size() > 0 and String(seen4[0]).contains("starving"))
	# a death takes the person off the ship
	op4._select(1)
	op4.run.hurt(1, 500.0, "Test cause.")
	await create_timer(1.6).timeout
	check("a dead crew member is taken off the ship", op4._removed[1] and not op4._astros[1].visible)
	check("control moves to someone who is alive", op4._sel != 1 and not op4.run.is_dead(op4._sel))
	check("a dead crew member cannot be picked", (op4._select(1) == null) and op4._sel != 1)
	op4.queue_free()

	# running out of time ends the operations
	var s3 := BuildState.new(); s3.load_starter(ShipData.STARTERS[1]); s3.set_wings(1)
	var op3 = _make(s3)
	await create_timer(0.3).timeout
	got = {}
	op3.finished.connect(func(r): got = r)
	op3.run.resources["time"]["cur"] = 0.0
	await create_timer(0.3).timeout
	check("zero time ends operations with a time-out", got.get("time_out", false) == true)

	print("FAILS: ", fails)
	quit(fails)
