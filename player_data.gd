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
var campaign := {"done": [], "locked": false, "over": false, "won": false, "over_reason": "", "crew_chosen": false}
## The crew the player named. It is kept between missions.
var crew: Array[Dictionary] = CrewData.defaults()
## The mission being played right now (resources, objectives, choices, events, evidence).
var run: MissionRun = null
var mission_summaries = ["This is the mission 1 summary.", "This is the mission 2 summary.", "This is the mission 3 summary."]


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
	# Each solar wing adds to the power the crew can spend on jobs (a GAME rule)
	var wings := get_build().wings
	if run.resources.has("power"):
		run.resources["power"]["max"] = float(run.resources["power"]["max"]) + 3.0 * wings
		run.resources["power"]["cur"] = float(run.resources["power"]["cur"]) + 3.0 * wings
	return run


func current_mission() -> int:
	return int(scenario) if scenario != null else 0


## Start again from nothing: a new ship, a new crew, no contracts done.
func new_campaign() -> void:
	campaign = {"done": [], "locked": false, "over": false, "won": false, "over_reason": "", "crew_chosen": false}
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
	refresh_campaign()


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
	if crew.is_empty():
		campaign["over"] = true
		var causes: Array[String] = []
		for d in run.deaths():
			causes.append("%s: %s" % [d["name"], d["cause"]])
		campaign["over_reason"] = "The whole crew was lost. " + "  ".join(causes)


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
