class_name SaveGame
extends RefCounted
## One save slot for the campaign: which contracts are done, the locked ship, and the crew (names, roles, health).
## It is written after every change that matters (crew named, contract finished, crew lost) so closing the window never loses progress.
## A flight in progress is not saved: closing mid-flight returns to the last saved point, which is the start of that contract.

const PATH := "user://moonbound_save.json"
const VERSION := 1


## The campaign as plain data. `pd` is the PlayerData autoload (passed in so tests can use any stand-in).
static func to_dict(pd) -> Dictionary:
	var b: BuildState = pd.build
	var ship := {}
	if b != null:
		ship = {"bays": Array(b.bays), "kit": b.kit, "wings": b.wings, "wide": b.wide, "close": b.close}
	var crew: Array = []
	for c in pd.crew:
		crew.append((c as Dictionary).duplicate())
	return {"version": VERSION, "campaign": (pd.campaign as Dictionary).duplicate(true), "crew": crew, "ship": ship}


## Put saved data back. Returns false (and changes nothing) if it is not a valid save.
static func apply(pd, d: Dictionary) -> bool:
	if int(d.get("version", 0)) != VERSION or not (d.get("campaign") is Dictionary) or not (d.get("crew") is Array):
		return false
	var c: Dictionary = d["campaign"]
	var done: Array = []
	for x in c.get("done", []):
		done.append(int(x))
	var camp := {"done": done, "locked": bool(c.get("locked", false)), "over": bool(c.get("over", false)), "won": bool(c.get("won", false)),
		"over_reason": String(c.get("over_reason", "")), "crew_chosen": bool(c.get("crew_chosen", false)),
		"log": [], "memorial": [], "studied": [], "briefed": bool(c.get("briefed", false)), "debrief": int(c.get("debrief", -1)),
		"difficulty": clampi(int(c.get("difficulty", 1)), 0, 2), "points": int(c.get("points", 0))}
	for e in c.get("log", []):
		if e is Dictionary:
			var d2: Dictionary = (e as Dictionary).duplicate()
			d2["id"] = int(d2.get("id", 0))
			d2["score"] = int(d2.get("score", 70))
			camp["log"].append(d2)
	for mm in c.get("memorial", []):
		if mm is Dictionary:
			camp["memorial"].append((mm as Dictionary).duplicate())
	for sp in c.get("studied", []):
		camp["studied"].append(String(sp))
	var crew: Array[Dictionary] = []
	for x in d["crew"]:
		if not (x is Dictionary):
			return false
		var m: Dictionary = x
		var id := String(m.get("char", ""))
		var fresh := CrewData.make(id, CrewData.clean_name(String(m.get("name", "")), CrewData.char_name(id)), String(m.get("role", "")))
		fresh["energy"] = float(m.get("energy", 100.0))
		fresh["health"] = float(m.get("health", 100.0))
		fresh["morale"] = float(m.get("morale", 100.0))
		fresh["note"] = String(m.get("note", ""))
		fresh["cause"] = String(m.get("cause", ""))
		crew.append(fresh)
	var ship = d.get("ship", {})
	pd.new_campaign()
	pd.campaign = camp
	pd.crew = crew
	if ship is Dictionary and not (ship as Dictionary).is_empty():
		var b: BuildState = pd.get_build()
		var bays: Array[String] = []
		for x in ship.get("bays", []):
			bays.append(String(x))
		bays.resize(b.bays.size())
		for i in bays.size():
			if bays[i] == null:
				bays[i] = ""
		b.bays.assign(bays)
		b.kit = bool(ship.get("kit", false))
		b.wings = int(ship.get("wings", 0))
		b.wide = bool(ship.get("wide", false))
		b.close = bool(ship.get("close", false))
	return true


static func save(pd, path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(pd), "\t"))
	f.close()
	return true


static func has_save(path := PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION or not (d.get("campaign") is Dictionary):
		return false
	return bool((d["campaign"] as Dictionary).get("crew_chosen", false))


## Load the saved campaign into `pd`. False if there is no save or it cannot be read.
static func load_into(pd, path := PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		return false
	return apply(pd, d)


static func erase(path := PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)


## A short line for the Continue button: how far the campaign has got.
static func summary(path := PATH) -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (d is Dictionary) or not (d.get("campaign") is Dictionary):
		return ""
	var c: Dictionary = d["campaign"]
	var n := (c.get("done", []) as Array).size()
	var crew := (d.get("crew", []) as Array).size()
	if bool(c.get("over", false)):
		return "Finished: %d contracts, %d crew" % [n, crew]
	return "%d contract%s done, %d crew" % [n, "" if n == 1 else "s", crew]
