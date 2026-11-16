class_name ImpactCase
extends RefCounted
## The case file that goes from the flyer to Mission Control, and the onboard run record that stays behind.
##
## The REVIEWER FILE holds only products that were delivered in full, described by what they show and where they came from.
## It never holds the answer key, the scenario, a seed, undelivered products, hidden fields, thumbnails, or names that leak any of
## that: record IDs are opaque hashes that change with a per-export salt, and the file name is random.
## The ONBOARD RUN RECORD (user://impact_runs/) holds the truth and what stayed aboard, and is bound to the exported case by its
## opaque case ID and a hash of the records, so the original session can reopen the right reveal.
##
## All of this is a fictional game. It does not use NASA's confirmation criteria.

const SCHEMA := 1
const MAX_BYTES := 200000
const MAX_RECORDS := 64
const MAX_TEXT := 300
const TOP_KEYS := ["schema", "case_id", "records", "note"]
const RECORD_KEYS := ["id", "type", "observer", "time", "position", "screen", "coverage", "finding", "confidence", "text", "source_group", "derived_from", "relation"]
const TYPES := ["crew_log", "tight_crop", "wide_context"]
const RELATIONS := ["firsthand", "crop_of_frame", "wide_of_frame", "retelling"]
const FINDINGS := ["flash", "flash_on_surface", "faint_flicker", "reflection_moves_with_window", "no_event_seen"]
const FORBIDDEN := ["truth", "seed", "scenario", "answer", "answer_key", "undelivered", "onboard", "real", "cand", "candidate_truth"]
const RUNS_DIR := "user://impact_runs"


static func _hex(text: String, n: int) -> String:
	return text.sha256_text().substr(0, n).to_upper()


## Build the reviewer file from the products that were delivered in full. observers maps a viewpoint id to the name to show
## (the crew's own names). Returns {"case": reviewer file, "map": opaque record id -> product id (aboard only)}.
static func build_export(delivered: Array, salt: String, observers := {}) -> Dictionary:
	var by_id := {}
	for pid in delivered:
		var p := ImpactScenario.product(String(pid))
		if not p.is_empty():
			by_id[String(pid)] = p
	var ids := {}
	var groups := {}
	for pid in by_id:
		ids[pid] = "R-" + _hex(salt + "rec" + String(pid), 6)
	for pid in by_id:
		groups[String(by_id[pid]["group"])] = "G-" + _hex(salt + "grp" + String(by_id[pid]["group"]), 6)
	var recs: Array[Dictionary] = []
	var map := {}
	for pid in by_id:
		var p: Dictionary = by_id[pid]
		var vp: Dictionary = ImpactScenario.VIEWPOINTS[p["viewpoint"]]
		var parent := String(p["from"])
		var derived := ""
		if parent != "":
			derived = String(ids[parent]) if ids.has(parent) else String(groups.get(String(ImpactScenario.product(parent)["group"]), "G-" + _hex(salt + "grp" + String(ImpactScenario.product(parent)["group"]), 6)))
		var has_pos := float(p["err"]) > 0.0
		var name := String(observers.get(String(p["viewpoint"]), vp["label"]))
		recs.append({
			"id": ids[pid], "type": p["type"], "observer": (String(vp["label"]) if name == String(vp["label"]) else "%s (%s)" % [name, vp["label"]]),
			"time": [float(p["t"][0]), float(p["t"][1])],
			"position": {"lat": float(p["lat"]), "lon": float(p["lon"]), "err": float(p["err"])} if has_pos else null,
			"screen": [int(p["screen"][0]), int(p["screen"][1])] if has_pos and (int(p["screen"][0]) + int(p["screen"][1])) > 0 else null,
			"coverage": {"lat": [float(vp["coverage"]["lat"][0]), float(vp["coverage"]["lat"][1])], "lon": [float(vp["coverage"]["lon"][0]), float(vp["coverage"]["lon"][1])]},
			"finding": p["finding"], "confidence": float(p["conf"]), "text": p["text"],
			"source_group": groups[String(p["group"])], "derived_from": derived, "relation": p["relation"],
		})
		map[ids[pid]] = pid
	recs.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))     # an order that does not leak the product order
	var case := {"schema": SCHEMA, "case_id": "CASE-" + _hex(salt + "case", 8), "records": recs, "note": "Simulated evidence from a fictional mission. Game rules, not NASA criteria."}
	return {"case": case, "map": map}


## True if the reviewer file is acceptable. {ok, error}. Never throws on bad input.
static func validate(d) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return _bad("This is not an Impact Watch case file.")
	for k in d.keys():
		if FORBIDDEN.has(String(k).to_lower()):
			return _bad("This file carries a field (%s) that a reviewer file must not contain." % String(k))
		if not TOP_KEYS.has(String(k)):
			return _bad("This file has an unexpected field (%s)." % String(k))
	if not d.has("schema") or typeof(d["schema"]) not in [TYPE_INT, TYPE_FLOAT] or int(d["schema"]) != SCHEMA:
		return _bad("This case file is from a different version (needs schema %d)." % SCHEMA)
	if typeof(d.get("case_id")) != TYPE_STRING or not _is_id(String(d["case_id"]), "CASE-", 8):
		return _bad("The case ID is missing or malformed.")
	if typeof(d.get("records")) != TYPE_ARRAY:
		return _bad("The file has no evidence records.")
	var recs: Array = d["records"]
	if recs.is_empty():
		return _bad("The case has no delivered evidence to review.")
	if recs.size() > MAX_RECORDS:
		return _bad("The case has too many records (%d, the limit is %d)." % [recs.size(), MAX_RECORDS])
	if JSON.stringify(d).length() > MAX_BYTES:
		return _bad("The case file is too large.")
	var seen := {}
	var groups := {}
	for r in recs:
		if typeof(r) != TYPE_DICTIONARY:
			return _bad("A record is not in the expected format.")
		for k in r.keys():
			if FORBIDDEN.has(String(k).to_lower()) or not RECORD_KEYS.has(String(k)):
				return _bad("A record has an unexpected field (%s)." % String(k))
		var id := String(r.get("id", ""))
		if not _is_id(id, "R-", 6):
			return _bad("A record ID is malformed.")
		if seen.has(id):
			return _bad("Two records share the ID %s." % id)
		seen[id] = true
		if not TYPES.has(String(r.get("type", ""))):
			return _bad("Record %s has an unknown type." % id)
		if not RELATIONS.has(String(r.get("relation", ""))):
			return _bad("Record %s has an unknown relation." % id)
		if not FINDINGS.has(String(r.get("finding", ""))):
			return _bad("Record %s has an unknown finding." % id)
		if typeof(r.get("text")) != TYPE_STRING or String(r["text"]).length() > MAX_TEXT:
			return _bad("Record %s has missing or over-long text." % id)
		if typeof(r.get("observer")) != TYPE_STRING or String(r["observer"]).length() > 80:
			return _bad("Record %s has a missing or over-long observer." % id)
		var t = r.get("time")
		if typeof(t) != TYPE_ARRAY or t.size() != 2 or typeof(t[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(t[1]) not in [TYPE_INT, TYPE_FLOAT] or float(t[0]) > float(t[1]) or float(t[0]) < 0.0 or float(t[1]) > 300.0:
			return _bad("Record %s has an invalid time range." % id)
		var c = r.get("confidence")
		if typeof(c) not in [TYPE_INT, TYPE_FLOAT] or float(c) < 0.0 or float(c) > 1.0:
			return _bad("Record %s has an invalid confidence." % id)
		var pos = r.get("position")
		if pos != null:
			if typeof(pos) != TYPE_DICTIONARY or not pos.has("lat") or not pos.has("lon") or float(pos["lat"]) < -90.0 or float(pos["lat"]) > 90.0 or float(pos["lon"]) < -180.0 or float(pos["lon"]) > 180.0:
				return _bad("Record %s has an invalid position." % id)
		var cov = r.get("coverage")
		if typeof(cov) != TYPE_DICTIONARY or typeof(cov.get("lat")) != TYPE_ARRAY or typeof(cov.get("lon")) != TYPE_ARRAY or cov["lat"].size() != 2 or cov["lon"].size() != 2:
			return _bad("Record %s has an invalid coverage area." % id)
		var g := String(r.get("source_group", ""))
		if not _is_id(g, "G-", 6):
			return _bad("Record %s has a malformed source group." % id)
		groups[g] = true
	for r in recs:
		var df := String(r.get("derived_from", ""))
		if df == "":
			continue
		if df.begins_with("R-"):
			if not _is_id(df, "R-", 6) or not seen.has(df):
				return _bad("Record %s points at a record that is not in the file." % String(r["id"]))
		elif not _is_id(df, "G-", 6):
			return _bad("Record %s has a malformed source reference." % String(r["id"]))
	return {"ok": true, "error": ""}


static func _bad(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}


static func _is_id(s: String, prefix: String, n: int) -> bool:
	if not s.begins_with(prefix) or s.length() != prefix.length() + n:
		return false
	for ch in s.substr(prefix.length()):
		if not (ch in "0123456789ABCDEF"):
			return false
	return true


## A stable fingerprint of the delivered records, used to bind a verdict to the case it reviewed.
static func case_hash(case_in: Dictionary) -> String:
	# Normalise through JSON first so the same case hashes the same before and after being saved and loaded (ints become floats)
	var case: Dictionary = JSON.parse_string(JSON.stringify(case_in))
	var recs: Array = case["records"].duplicate(true)
	recs.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	return JSON.stringify({"case_id": case["case_id"], "records": recs}, "", true).sha256_text()


# ---------------------------------------------------------------- files

static func random_name() -> String:
	return "impact_case_%s.json" % _hex(str(Time.get_ticks_usec()) + str(randi()), 8)


static func save_case(case: Dictionary, path: String) -> String:
	var v := validate(case)
	if not bool(v["ok"]):
		return String(v["error"])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Could not write the file."
	f.store_string(JSON.stringify(case, "  ", true))
	f.close()
	return ""


## Read and validate a reviewer file. {ok, error, case}. The size is checked before reading.
static func load_case(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "That file could not be found.", "case": {}}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "That file could not be opened.", "case": {}}
	if f.get_length() > MAX_BYTES:
		return {"ok": false, "error": "That file is too large to be an Impact Watch case.", "case": {}}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	var v := validate(parsed)
	if not bool(v["ok"]):
		return {"ok": false, "error": String(v["error"]), "case": {}}
	return {"ok": true, "error": "", "case": parsed}


# ---------------------------------------------------------------- the onboard run record (keeps the truth)

## Save what stayed aboard. Never written into the reviewer file. map is record id -> product id.
static func save_run(case: Dictionary, map: Dictionary, sent_cost: int, budget: int) -> void:
	DirAccess.make_dir_recursive_absolute(RUNS_DIR)
	var f := FileAccess.open("%s/%s.json" % [RUNS_DIR, String(case["case_id"])], FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"case_id": case["case_id"], "case_hash": case_hash(case), "map": map, "sent_cost": sent_cost, "budget": budget}, "  ", true))
	f.close()


static func load_run(case_id: String) -> Dictionary:
	if not _is_id(case_id, "CASE-", 8):
		return {}
	var path := "%s/%s.json" % [RUNS_DIR, case_id]
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}


## A committed review, bound to the case it reviewed. verdicts: [{candidate, verdict, cites}].
static func build_verdict_file(case: Dictionary, verdicts: Array) -> Dictionary:
	return {"schema": SCHEMA, "case_id": case["case_id"], "case_hash": case_hash(case), "verdicts": verdicts}


static func validate_verdict_file(d, case: Dictionary) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or int(d.get("schema", 0)) != SCHEMA:
		return _bad("This is not a review file from this version.")
	if String(d.get("case_id", "")) != String(case["case_id"]) or String(d.get("case_hash", "")) != case_hash(case):
		return _bad("This review was made for a different case, or the case was changed.")
	if typeof(d.get("verdicts")) != TYPE_ARRAY or d["verdicts"].size() > 16:
		return _bad("The review has no verdicts, or too many.")
	return {"ok": true, "error": ""}
