extends Node


enum EngineType { SOLIDSMALL, SOLIDMEDIUM, SOLIDLARGE, LIQUIDSMALL, LIQUIDMEDIUM, LIQUIDLARGE }
enum Scenario { MISSION_1, MISSION_2, MISSION_3 }
var fuel_amount = 0
var scenario = null
## The ship the player is building. Created on first use and kept between screens.
var build: BuildState = null
## True once the player has dismissed the AI disclosure this session.
var ai_notice_seen := false
## Outcome of the last flight: {success, stage, reason}. Mission data is lost on a failed flight.
var flight_result: Dictionary = {}
var mission_data_lost := false
## Shown on the Build screen after a count is scrubbed.
var scrub_note := ""
## Photos from the last flight that reached Earth, for the Report stage.
var evidence: Array[Dictionary] = []
## The campaign: which contracts are done, whether the ship is locked, and whether it is over.
## The ship is built once, in the first contract, and from the moment that contract is completed it is the ship
## for the rest of the game. When the whole crew is gone, or the ship cannot do the next contract, the campaign ends.
var campaign := fresh_campaign()
## The crew the player named. It is kept between missions.
var crew: Array[Dictionary] = CrewData.defaults()
## The mission being played right now (resources, objectives, choices, events, evidence).
var run: MissionRun = null
## Progress is saved after every change that matters. Tests run with --script and never touch the real save.
var autosave_enabled := not OS.get_cmdline_args().has("--script")
var mission_summaries = ["This is the mission 1 summary.", "This is the mission 2 summary.", "This is the mission 3 summary."]


## Power each solar wing adds to the run's reserve (a GAME rule). The camera-fault card reads this too, so it never double counts.
const WING_RESERVE := 3.0


## Begin a fresh run of the chosen contract with the current crew at full health.
func start_run() -> MissionRun:
	var fresh: Array[Dictionary] = []
	for c in crew:
		var d := (c as Dictionary).duplicate()
		d["energy"] = 100.0
		d["health"] = 100.0
		d["morale"] = 100.0
		d["note"] = ""
		d["cause"] = ""
		fresh.append(d)
	run = MissionRun.start(current_mission(), fresh)
	# the difficulty chosen for this campaign tightens time and power
	for k in run.resources:
		run.resources[k]["max"] = float(run.resources[k]["max"]) * difficulty_factor("resources")
		run.resources[k]["cur"] = float(run.resources[k]["cur"]) * difficulty_factor("resources")
	# Each solar wing adds to the power the crew can spend on jobs (a GAME rule)
	var wings := get_build().wings
	if run.resources.has("power"):
		run.resources["power"]["max"] = float(run.resources["power"]["max"]) + WING_RESERVE * wings
		run.resources["power"]["cur"] = float(run.resources["power"]["cur"]) + WING_RESERVE * wings
	return run


func current_mission() -> int:
	return int(scenario) if scenario != null else 0


## A campaign with nothing done. "log" is the story so far (one entry per finished contract), "memorial" is anyone lost,
## "studied" is the real places the player observed, "briefed" is whether the opening briefing was shown, and "debrief" is the
## contract whose debrief Mission Control still has to give (-1 for none).
static func fresh_campaign() -> Dictionary:
	return {"done": [], "locked": false, "over": false, "won": false, "over_reason": "", "crew_chosen": false,
		"log": [], "memorial": [], "studied": [], "briefed": false, "debrief": -1, "difficulty": 1, "points": 0}


## The parts chosen on the spacecraft design screen, read by the mission screen.
var space_picks := {}


## A spacecraft contract finished: it counts, its grade and points go in the story, and the campaign points grow.
func complete_spacecraft(id: int, result: Dictionary) -> void:
	if campaign["done"].has(id):
		return
	var m := Missions.get_mission(id)
	var entry := {"id": id, "tag": String(m["tag"]), "name": String(m["name"]).capitalize(),
		"headline": "You designed a spacecraft for %s and ran its mission: grade %s." % [String(m["name"]).to_lower(), String(result["grade"])],
		"detail": "%d of %d choices worked. The design was %s." % [int(result.get("wins", 0)), (result.get("results", []) as Array).size(), "legal" if bool(result["design"]["ok"]) else "not legal"],
		"score": int(result["percent"]), "grade": String(result["grade"]), "points": int(result["points"]), "rows": (result["rows"] as Array).duplicate(true)}
	campaign["done"].append(id)
	campaign["log"].append(entry)
	campaign["points"] = int(campaign.get("points", 0)) + int(entry["points"])
	autosave()


## A difficulty setting for this campaign: key is resources, shake, window or mult (see ScoreBoard.DIFFICULTY).
func difficulty_factor(key: String) -> float:
	return float(ScoreBoard.difficulty(int(campaign.get("difficulty", 1)))[key])


## One line of the story for a finished contract: what the player did, how well (a 0 to 100 GAME score).
func log_entry(id: int) -> Dictionary:
	var m := Missions.get_mission(id)
	var e := {"id": id, "tag": String(m["tag"]), "name": String(m["name"]).capitalize(), "headline": "Contract complete.", "detail": "", "score": 70}
	if run == null:
		return e
	match id:
		0:
			var got := 0
			var best := 0
			for ev in run.evidence:
				if bool(ev.get("received", false)):
					got += 1
					best = maxi(best, int(ev.get("stars", 0)))
			e["headline"] = "You photographed the Orientale Basin: %d photo%s reached Earth." % [got, "" if got == 1 else "s"]
			var bits: Array[String] = []
			if best > 0:
				bits.append("Your best shot scored %d of 3 stars." % best)
			var nc: Dictionary = run.nasa_compare
			if not nc.is_empty():
				bits.append("Against NASA's real view you found the dark interior: %s, and the bright rings: %s." % ["yes" if nc.get("interior", false) else "no", "yes" if nc.get("rings", false) else "no"])
			if bool(run.fault.get("happened", false)):
				bits.append("A camera fault hit mid-flight and you worked around it.")
			e["detail"] = " ".join(bits)
			e["score"] = clampi(40 + 20 * best, 40, 100)
		1:
			var ev1: Dictionary = run.science.get("eval", {})
			var conf := String(ev1.get("confidence", "TENTATIVE"))
			e["headline"] = "You compared two craters under different light and reached %s confidence." % conf.to_lower()
			e["detail"] = "Which way the light came from, and where the rays show best, were part of your call. Comparability (a game rule) was %d%%." % int(float(ev1.get("comparability", 0.0)) * 100.0)
			e["score"] = {"STRONG": 100, "MODERATE": 78}.get(conf, 55)
		2:
			var ev2: Dictionary = run.impact.get("eval", {})
			var res: Array = ev2.get("results", [])
			var ok := 0
			for r in res:
				if bool(r.get("justified", false)):
					ok += 1
			e["headline"] = "Mission Control gave justified verdicts on %d of %d sightings." % [ok, res.size()]
			e["detail"] = "You sent %d of %d packets. Average credit %d%%. Records from one witness counted once." % [int(run.impact.get("sent_cost", 0)), int(run.impact.get("budget", 0)), int(float(ev2.get("mean_credit", 0.0)))]
			e["score"] = clampi(int(float(ev2.get("mean_credit", 70.0))), 40, 100)
	# the grade and points for this flight (a GAME score), which replace the rough score above
	var sb := ScoreBoard.compute(run, id, int(campaign.get("difficulty", 1)))
	e["score"] = int(sb["percent"])
	e["grade"] = String(sb["grade"])
	e["points"] = int(sb["points"])
	e["rows"] = (sb["rows"] as Array).duplicate(true)
	return e


## Write the campaign to the save slot (once the crew has been chosen).
func autosave() -> void:
	if autosave_enabled and bool(campaign["crew_chosen"]):
		SaveGame.save(self)


## Load the saved campaign, if there is one.
func continue_saved() -> bool:
	return SaveGame.load_into(self)


## The player chose New Campaign: forget the saved one too.
func start_over() -> void:
	if autosave_enabled:
		SaveGame.erase()
	new_campaign()


## Start again from nothing: a new ship, a new crew, no contracts done.
func new_campaign() -> void:
	campaign = fresh_campaign()
	build = null
	crew = CrewData.defaults()
	run = null
	scenario = null
	flight_result = {}
	evidence = []
	scrub_note = ""


## Can this contract be played now, and if not, exactly why? needs lists what the ship must have.
func contract_status(id: int) -> Dictionary:
	var m := Missions.get_mission(id)
	if String(m.get("kind", "")) == "spacecraft":
		# Spacecraft design contracts have their own ship each time. They open in a chain once Contract 01 is done.
		var so := {"open": true, "reason": "", "done": campaign["done"].has(id), "impossible": false, "needs": [], "short": ""}
		var prev := 0 if id == 3 else id - 1
		if so["done"]:
			so["open"] = false
			so["reason"] = "You completed this contract."
			so["short"] = "COMPLETE"
		elif not campaign["done"].has(prev):
			so["open"] = false
			so["reason"] = "Finish contract %02d first." % (prev + 1)
			so["short"] = "FINISH %02d FIRST" % (prev + 1)
		return so
	var s: BuildState = build
	var needs := Missions.requirements(id, s)
	var out := {"open": true, "reason": "", "done": campaign["done"].has(id), "impossible": false, "needs": needs, "short": ""}
	if bool(campaign["over"]):
		out["open"] = false
		out["reason"] = String(campaign["over_reason"])
		out["short"] = "CAMPAIGN OVER"
	elif out["done"]:
		out["open"] = false
		out["reason"] = "You completed this contract."
		out["short"] = "COMPLETE"
	elif not bool(m.get("available", false)):
		out["open"] = false
		out["reason"] = "This contract is not built yet in this version."
		out["short"] = "NOT BUILT YET"
	elif id > 0 and not campaign["done"].has(id - 1):
		out["open"] = false
		out["reason"] = "Finish contract %02d first. Contracts open in order." % id
		out["short"] = "FINISH %02d FIRST" % id
	elif bool(campaign["locked"]):
		var missing: Array[String] = []
		for n in needs:
			if not n["ok"]:
				missing.append(String(n["fix"]))
		if not missing.is_empty():
			out["open"] = false
			out["impossible"] = true
			out["reason"] = "Your ship does not have %s. It was locked when you finished the first contract, so it cannot do this contract." % " or ".join(missing)
			out["short"] = "SHIP LACKS " + String(needs.filter(func(n): return not n["ok"])[0]["label"]).to_upper()
	return out


## Work out whether the campaign has ended: the next contract cannot be done with the locked ship, or all are done.
func refresh_campaign() -> void:
	if bool(campaign["over"]):
		return
	var next := -1
	for m in Missions.LIST:
		if String(m.get("kind", "")) == "spacecraft":
			continue                     # the design contracts are extra: the campaign ends after the first three
		if bool(m.get("available", false)) and not campaign["done"].has(int(m["id"])):
			next = int(m["id"])
			break
	if next < 0:
		campaign["over"] = true
		campaign["won"] = true
		campaign["over_reason"] = "You finished every contract in this version."
		return
	var st := contract_status(next)
	if bool(st["impossible"]):
		campaign["over"] = true
		campaign["over_reason"] = String(st["reason"])


## A contract was completed: it counts, the ship is locked for good, and the surviving crew carries on.
func complete_contract(id: int) -> void:
	if not campaign["done"].has(id):
		campaign["done"].append(id)
	campaign["locked"] = true
	var done_before := false
	for old in campaign["log"]:
		if int(old.get("id", -1)) == id:
			done_before = true
	if not done_before:
		var entry := log_entry(id)
		campaign["log"].append(entry)
		campaign["points"] = int(campaign.get("points", 0)) + int(entry.get("points", 0))
		if id == 0 and not campaign["studied"].has("Orientale Basin"):
			campaign["studied"].append("Orientale Basin")
		if id == 1 and run != null and String(run.science.get("eval", {}).get("branch", "")) == "ohm" and not campaign["studied"].has("Ohm"):
			campaign["studied"].append("Ohm")
		campaign["debrief"] = id
	refresh_campaign()
	autosave()


## After every flight: the dead are gone for good, the survivors recover on the ground. No one left ends the campaign.
func sync_crew_after_flight() -> void:
	if run == null:
		return
	var survivors: Array[Dictionary] = []
	for c in run.crew:
		if float(c["health"]) > 0.0:
			var d := (c as Dictionary).duplicate()
			d["energy"] = 100.0
			d["health"] = 100.0
			d["morale"] = 100.0
			d["note"] = ""
			survivors.append(d)
	crew = survivors
	for dead in run.crew:
		if float(dead["health"]) <= 0.0:
			var known := false
			for m in campaign["memorial"]:
				if String(m.get("name", "")) == String(dead["name"]):
					known = true
			if not known:
				campaign["memorial"].append({"name": String(dead["name"]), "role": String(dead["role"]), "char": String(dead["char"]), "cause": String(dead.get("cause", ""))})
	if crew.is_empty():
		campaign["over"] = true
		var causes: Array[String] = []
		for d in run.deaths():
			causes.append("%s: %s" % [d["name"], d["cause"]])
		campaign["over_reason"] = "The whole crew was lost. " + "  ".join(causes)
	autosave()


func get_build() -> BuildState:
	if build == null:
		build = BuildState.new()
	return build


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Below this the small text would shrink past readable.
	DisplayServer.window_set_min_size(Vector2i(1280, 720))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
