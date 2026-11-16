class_name MissionEvents
extends RefCounted
## Things that happen during a mission that the player has to decide about. Every choice costs something, and every
## way a person can be hurt carries the reason, so the screen can say exactly why. All of this is a GAME rule:
## these are invented incidents, not NASA flight data. Pure data and rules, so the picks can be tested with a seed.

## A choice: label, what it costs (time and power in game units), an optional room it needs, and an optional harm.
##  time_with: room id -> time if the ship has that room (so a built room makes the problem cheaper).
##  hurt_all / hurt_one: {amount, reason, short, chance}. {who} in text is the person the event happened to.
const POOL: Array[Dictionary] = [
	{"id": "power_dip", "title": "POWER DIP",
		"text": "A solar panel glitch cuts the power for a while. What do you do?",
		"choices": [
			{"label": "Shed the loads and wait it out", "time": 5.0, "power": 0.0},
			{"label": "Run on the battery", "time": 0.0, "power": 6.0},
		]},
	{"id": "solar_flare", "title": "SOLAR FLARE WARNING",
		"text": "A flare warning comes in. Sheltering costs time. Carrying on is a gamble.",
		"choices": [
			{"label": "Shelter the crew", "time": 6.0, "power": 0.0, "needs_any": ["crew-quarters", "cargo"],
				"needs_why": "The ship has no Crew Quarters or Cargo Bay to shelter in."},
			{"label": "Keep working and hope", "time": 0.0, "power": 0.0,
				"hurt_all": {"amount": 22.0, "chance": 0.5, "short": "Radiation dose",
					"reason": "The flare hit while the crew stayed at their stations instead of sheltering, so everyone took extra radiation."}},
		]},
	{"id": "cabin_leak", "title": "CABIN LEAK",
		"text": "A small leak is venting cabin air.",
		"choices": [
			{"label": "Patch the leak", "time": 6.0, "power": 0.0, "time_with": {"life-support": 3.0}, "tire": 8.0},
			{"label": "Close the hatch and keep working", "time": 0.0, "power": 0.0,
				"hurt_all": {"amount": 14.0, "chance": 1.0, "short": "Thin cabin air",
					"reason": "The leak was left unpatched, so the cabin air thinned and the crew struggled to breathe."}},
		]},
	{"id": "comms_dropout", "title": "COMMS DROPOUT",
		"text": "The dish has lost its lock on Earth.",
		"choices": [
			{"label": "Wait for it to come back", "time": 5.0, "power": 0.0},
			{"label": "Re-aim the dish by hand", "time": 2.0, "power": 3.0},
		]},
	{"id": "rations", "title": "FOOD RUNNING LOW",
		"text": "A ration crate was crushed in the lockers. There is less food than planned.",
		"choices": [
			{"label": "Cook a proper meal in the Galley", "time": 4.0, "power": 1.0, "needs_any": ["galley"],
				"needs_why": "The ship has no Galley. The kit only has a food warmer."},
			{"label": "Cut rations and keep working", "time": 0.0, "power": 0.0,
				"hurt_all": {"amount": 10.0, "chance": 1.0, "short": "Short rations",
					"reason": "The crew worked on cut rations and wore down."}},
		]},
	{"id": "illness", "title": "{who} IS ILL",
		"text": "{who} has a fever and is struggling to work.",
		"choices": [
			{"label": "Treat {who} in the Medical Bay", "time": 4.0, "power": 1.0, "needs_any": ["medical"],
				"needs_why": "The ship has no Medical Bay."},
			{"label": "Keep going without treatment", "time": 0.0, "power": 0.0,
				"hurt_one": {"amount": 24.0, "chance": 1.0, "short": "Ill, untreated",
					"reason": "{who} fell ill and kept working with no treatment."}},
		]},
]


## Pick count different events for this run, using the run's own random numbers so a seed repeats them.
## Each comes back with {who} already filled in for the person it happens to.
static func pick(run: MissionRun, count: int) -> Array[Dictionary]:
	var ids: Array[int] = []
	for i in POOL.size():
		ids.append(i)
	# Shuffle with the run's generator (so it repeats for the same seed)
	for i in range(ids.size() - 1, 0, -1):
		var j := run.rng.randi_range(0, i)
		var tmp := ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	# Looking after the crew matters: with two or more events, one of them is always a health event
	if count >= 2:
		var ill := -1
		for i in POOL.size():
			if String(POOL[i]["id"]) == "illness":
				ill = i
		if ill >= 0 and not ids.slice(0, count).has(ill):
			ids.erase(ill)
			ids.insert(run.rng.randi_range(0, count - 1), ill)
	var out: Array[Dictionary] = []
	for k in mini(count, ids.size()):
		var ev: Dictionary = (POOL[ids[k]] as Dictionary).duplicate(true)
		var alive: Array[int] = []
		for c in run.crew.size():
			if not run.is_dead(c):
				alive.append(c)
		ev["who_index"] = alive[run.rng.randi_range(0, alive.size() - 1)] if not alive.is_empty() else 0
		var who := String(run.crew[int(ev["who_index"])]["name"]) if not run.crew.is_empty() else "Someone"
		ev["who"] = who
		ev["title"] = String(ev["title"]).replace("{who}", who.to_upper())
		ev["text"] = String(ev["text"]).replace("{who}", who)
		for ch in ev["choices"]:
			ch["label"] = String(ch["label"]).replace("{who}", who)
			for key in ["hurt_all", "hurt_one"]:
				if ch.has(key):
					ch[key]["reason"] = String(ch[key]["reason"]).replace("{who}", who)
		out.append(ev)
	return out


## Can this choice be made on this ship? Returns "" if yes, otherwise the reason it cannot.
static func blocked(choice: Dictionary, state: BuildState) -> String:
	if not choice.has("needs_any"):
		return ""
	for room in choice["needs_any"]:
		if state != null and state.has_room(String(room)):
			return ""
	return String(choice.get("needs_why", "The ship does not have what this needs."))


## Minutes this choice costs on this ship.
static func time_cost(choice: Dictionary, state: BuildState) -> float:
	var t := float(choice.get("time", 0.0))
	if choice.has("time_with") and state != null:
		for room in choice["time_with"]:
			if state.has_room(String(room)):
				t = minf(t, float(choice["time_with"][room]))
	return t


## Carry the choice out on the run. Returns the lines to show the player and who (if anyone) was lost.
static func apply(run: MissionRun, ev: Dictionary, choice_index: int, state: BuildState, actor: int) -> Dictionary:
	var ch: Dictionary = ev["choices"][choice_index]
	var lines: Array[String] = []
	var lost: Array[String] = []
	var t := time_cost(ch, state)
	var p := float(ch.get("power", 0.0))
	if t > 0.0:
		run.drain("time", t)
		lines.append("Cost %d minutes." % int(t))
	if p > 0.0:
		run.drain("power", p)
		lines.append("Cost %d power." % int(p))
	if ch.has("tire") and actor >= 0 and actor < run.crew.size():
		run.tire(actor, float(ch["tire"]))
		lines.append("%s is tired from the work." % run.crew[actor]["name"])
	if ch.has("hurt_all"):
		var h: Dictionary = ch["hurt_all"]
		if run.rng.randf() < float(h.get("chance", 1.0)):
			for n in run.hurt_all(float(h["amount"]), String(h["reason"]), String(h.get("short", ""))):
				lost.append(n)
			lines.append(String(h["reason"]))
		else:
			lines.append("Luck held. Nobody was hurt this time.")
	if ch.has("hurt_one"):
		var h: Dictionary = ch["hurt_one"]
		var idx := int(ev.get("who_index", 0))
		if run.rng.randf() < float(h.get("chance", 1.0)):
			if run.hurt(idx, float(h["amount"]), String(h["reason"]), String(h.get("short", ""))):
				lost.append(String(run.crew[idx]["name"]))
			lines.append(String(h["reason"]))
	run.log_event(String(ev["title"]), String(ch["label"]))
	return {"lines": lines, "lost": lost}
