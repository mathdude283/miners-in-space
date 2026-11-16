extends SceneTree
## Impact Watch core: the fixed scenario, the reviewer export, validation, shared sources, coverage, justified verdicts,
## the binding of a verdict to its case, and the reveal. No screens.
var fails := 0
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _initialize() -> void:
	_run()

func _verdict(cand: String, v: String, cites: Array) -> Dictionary:
	return {"candidate": cand, "verdict": v, "cites": cites}

func _result(ev: Dictionary, cand: String) -> Dictionary:
	for r in ev["results"]:
		if r["candidate"] == cand:
			return r
	return {}

func _rid(exp: Dictionary, pid: String) -> String:
	for k in exp["map"]:
		if exp["map"][k] == pid:
			return k
	return ""

func _run() -> void:
	# ---- the scenario
	check("the budget cannot send everything", ImpactScenario.budget(0) < ImpactScenario.total_cost() and ImpactScenario.budget(2) < ImpactScenario.total_cost())
	check("a justified path fits the smallest budget", ImpactScenario.cheapest_justified_cost() <= ImpactScenario.budget(0))
	check("a solar wing raises the budget", ImpactScenario.budget(1) > ImpactScenario.budget(0))

	# ---- run 1: independent evidence and the wide context
	var run1 := ["A1", "A4", "B1", "C1", "C3"]
	var e1 := ImpactCase.build_export(run1, "salt-one", {"V1": "Ada", "V2": "Sam", "V3": "Noor"})
	var c1: Dictionary = e1["case"]
	check("the export validates", ImpactCase.validate(c1)["ok"])
	check("it holds only the delivered records", c1["records"].size() == 5)
	var cands1 := ImpactReview.candidates(c1)
	check("three candidate sightings are found from the evidence alone", cands1.size() == 3)
	var ev1 := ImpactReview.evaluate(c1, [
		_verdict("W1", "supported", [_rid(e1, "A1"), _rid(e1, "A4")]),
		_verdict("W2", "insufficient", [_rid(e1, "B1")]),
		_verdict("W3", "artifact", [_rid(e1, "C3")])])
	check("two independent observations support A", _result(ev1, "W1")["justified"] and _result(ev1, "W1")["credit"] == 100)
	check("the weak real impact B can correctly stay unresolved", _result(ev1, "W2")["justified"] and _result(ev1, "W2")["credit"] == 100)
	check("the wide frame justifies calling C an artifact", _result(ev1, "W3")["justified"] and _result(ev1, "W3")["credit"] == 100)
	check("run 1 completes the review", ev1["complete"])

	# ---- run 2: tight crops and repeated logs from one window
	var run2 := ["A1", "A2", "B1", "B3", "C1", "C2"]
	var cost2 := 0
	for pid in run2:
		cost2 += int(ImpactScenario.product(pid)["cost"])
	check("run 2 also fits the base budget", cost2 <= ImpactScenario.budget(0))
	var e2 := ImpactCase.build_export(run2, "salt-two")
	var c2: Dictionary = e2["case"]
	var ev2 := ImpactReview.evaluate(c2, [
		_verdict("W1", "supported", [_rid(e2, "A1"), _rid(e2, "A2")]),
		_verdict("W2", "supported", [_rid(e2, "B1"), _rid(e2, "B3")]),
		_verdict("W3", "supported", [_rid(e2, "C2")])])
	check("a log and a crop from one window do not make A supported", not _result(ev2, "W1")["justified"])
	check("the note says records from one witness count once", String(_result(ev2, "W1")["note"]).contains("count once") or String(_result(ev2, "W1")["note"]).contains("independent"))
	check("a weak report and its retelling are one source, so B cannot be supported", not _result(ev2, "W2")["justified"])
	check("C with only a tight crop cannot be supported", not _result(ev2, "W3")["justified"])
	var ev2b := ImpactReview.evaluate(c2, [
		_verdict("W1", "possible", [_rid(e2, "A1"), _rid(e2, "A2")]),
		_verdict("W2", "insufficient", [_rid(e2, "B1"), _rid(e2, "B3")]),
		_verdict("W3", "possible", [_rid(e2, "C2")])])
	check("careful verdicts on run 2 are justified", ev2b["complete"])
	var ev2c := ImpactReview.evaluate(c2, [
		_verdict("W1", "possible", [_rid(e2, "A1")]),
		_verdict("W2", "insufficient", [_rid(e2, "B1")]),
		_verdict("W3", "artifact", [_rid(e2, "C2")])])
	check("calling C an artifact without the wide frame is not justified", not _result(ev2c, "W3")["justified"])
	check("the two runs allow different justified conclusions", _result(ev1, "W1")["support"]["best"] == "supported" and _result(ev2b, "W1")["support"]["best"] == "possible" and _result(ev1, "W3")["support"]["best"] == "artifact" and _result(ev2b, "W3")["support"]["best"] == "possible")

	# ---- the file changes with the downlink, and says nothing hidden
	var js1 := JSON.stringify(c1)
	var js2 := JSON.stringify(c2)
	check("a different downlink gives a different file", js1 != js2 and ImpactCase.case_hash(c1) != ImpactCase.case_hash(c2))
	check("an undelivered product's words are not in the file", not js1.contains("Flight Deck frame") and not js1.contains("Tight crop") and not js1.contains("reflection of a cabin light"))
	check("no truth, seed or scenario words are in the file", not js1.to_lower().contains("truth") and not js1.to_lower().contains("seed") and not js1.contains("GRP_") and not js1.contains("scenario"))
	check("record IDs are opaque and change with the salt", _rid(e1, "A1") != "A1" and ImpactCase.build_export(run1, "other")["case"]["records"][0]["id"] != c1["records"][0]["id"])
	check("the case ID is opaque", String(c1["case_id"]).begins_with("CASE-") and not String(c1["case_id"]).contains("A1"))
	check("the file name is random and neutral", ImpactCase.random_name().begins_with("impact_case_") and not ImpactCase.random_name().contains("A1"))
	var no_thumbs := true
	for r in c1["records"]:
		for k in r.keys():
			if ["tex", "texture", "image", "thumb", "thumbnail", "png"].has(String(k)):
				no_thumbs = false
	check("no thumbnails or images are carried", no_thumbs)
	check("the crew's own names show as observers", String(c1["records"][0]["observer"]).contains("Ada") or String(c1["records"][0]["observer"]).contains("Sam") or String(c1["records"][0]["observer"]).contains("Noor"))

	# ---- retellings point at their source without exposing an unsent original
	var e3 := ImpactCase.build_export(["B3"], "salt-three")
	var r3: Dictionary = e3["case"]["records"][0]
	check("a retelling whose original was not sent points at a neutral source group", String(r3["derived_from"]).begins_with("G-") and r3["derived_from"] == r3["source_group"])
	check("and that file still validates", ImpactCase.validate(e3["case"])["ok"])
	var e4 := ImpactCase.build_export(["B1", "B3"], "salt-four")
	var b1_id := _rid(e4, "B1")
	var b3_rec := {}
	for r in e4["case"]["records"]:
		if r["id"] == _rid(e4, "B3"):
			b3_rec = r
	check("when both are sent the retelling points at the original record", b3_rec["derived_from"] == b1_id)
	check("both records share one source group", e4["case"]["records"][0]["source_group"] == e4["case"]["records"][1]["source_group"])

	# ---- coverage: silence outside someone's view is not evidence against
	var e5 := ImpactCase.build_export(["A1", "N1"], "salt-five")
	var cs5 := ImpactReview.candidates(e5["case"])
	check("the silent log is outside the coverage of candidate A", cs5.size() == 1 and cs5[0]["silent_inside"].size() == 0 and cs5[0]["silent_outside"].size() == 1)
	var sup5 := ImpactReview.support(cs5[0])
	check("so it changes nothing about what A can support", sup5["best"] == "possible" and sup5["silent_inside"] == 0)
	var e6 := ImpactCase.build_export(["A1", "A4"], "salt-six")
	var forged: Dictionary = e6["case"].duplicate(true)
	forged["records"].append({"id": "R-AAAAAA", "type": "crew_log", "observer": "Someone", "time": [20.0, 26.0], "position": null, "screen": null,
		"coverage": {"lat": [0.0, 30.0], "lon": [130.0, 170.0]}, "finding": "no_event_seen", "confidence": 0.8, "text": "Nothing seen.", "source_group": "G-BBBBBB", "derived_from": "", "relation": "firsthand"})
	var sup6 := ImpactReview.support(ImpactReview.candidates(forged)[0])
	check("silence from an observer who WAS looking there does count (supported becomes possible)", sup6["best"] == "possible" and sup6["silent_inside"] == 1)

	# ---- validation: invalid files get readable errors
	var bad := {
		"not a dictionary": [1, 2],
		"wrong version": {"schema": 99, "case_id": "CASE-AAAAAAAA", "records": c1["records"]},
		"answer key": {"schema": 1, "case_id": "CASE-AAAAAAAA", "records": c1["records"], "truth": "A"},
		"unknown top field": {"schema": 1, "case_id": "CASE-AAAAAAAA", "records": c1["records"], "extra": 1},
		"no records": {"schema": 1, "case_id": "CASE-AAAAAAAA", "records": []},
		"bad case id": {"schema": 1, "case_id": "x", "records": c1["records"]},
	}
	for k in bad:
		var v := ImpactCase.validate(bad[k])
		check("rejects: %s (%s)" % [k, v["error"]], not v["ok"] and String(v["error"]).length() > 10)
	var dup: Dictionary = c1.duplicate(true)
	dup["records"].append(dup["records"][0].duplicate(true))
	check("rejects a duplicate record ID", not ImpactCase.validate(dup)["ok"])
	var dangling: Dictionary = c1.duplicate(true)
	dangling["records"][0]["derived_from"] = "R-FFFFFF"
	check("rejects a source reference that points nowhere", not ImpactCase.validate(dangling)["ok"])
	var badid: Dictionary = c1.duplicate(true)
	badid["records"][0]["id"] = "A1"
	check("rejects a malformed record ID", not ImpactCase.validate(badid)["ok"])
	var hidden: Dictionary = c1.duplicate(true)
	hidden["records"][0]["real"] = true
	check("rejects a hidden field on a record", not ImpactCase.validate(hidden)["ok"])
	var longtext: Dictionary = c1.duplicate(true)
	longtext["records"][0]["text"] = "x".repeat(ImpactCase.MAX_TEXT + 1)
	check("rejects over-long text", not ImpactCase.validate(longtext)["ok"])
	var many: Dictionary = c1.duplicate(true)
	for i in 70:
		var rr: Dictionary = c1["records"][0].duplicate(true)
		rr["id"] = "R-%06X" % (0x100000 + i)
		many["records"].append(rr)
	check("rejects too many records", not ImpactCase.validate(many)["ok"])
	var tmp := "user://impact_test"
	DirAccess.make_dir_recursive_absolute(tmp)
	var gp := FileAccess.open(tmp + "/garbage.json", FileAccess.WRITE)
	gp.store_string("this is not json {{{")
	gp.close()
	var lg := ImpactCase.load_case(tmp + "/garbage.json")
	check("a garbage file gives a readable error, not a crash (%s)" % lg["error"], not lg["ok"] and String(lg["error"]).length() > 10)
	var big := FileAccess.open(tmp + "/big.json", FileAccess.WRITE)
	big.store_string("a".repeat(ImpactCase.MAX_BYTES + 10))
	big.close()
	check("an oversized file is refused before reading", not ImpactCase.load_case(tmp + "/big.json")["ok"])
	check("a missing file is refused", not ImpactCase.load_case(tmp + "/nope.json")["ok"])
	check("saving a valid case works and loads back", ImpactCase.save_case(c1, tmp + "/ok.json") == "" and ImpactCase.load_case(tmp + "/ok.json")["ok"] and ImpactCase.case_hash(ImpactCase.load_case(tmp + "/ok.json")["case"]) == ImpactCase.case_hash(c1))
	check("saving an invalid case is refused", ImpactCase.save_case(dup, tmp + "/dup.json") != "")

	# ---- the run record keeps the truth; the verdict is bound to its case
	ImpactCase.save_run(c1, e1["map"], 8, ImpactScenario.budget(0))
	var run := ImpactCase.load_run(String(c1["case_id"]))
	check("the onboard run record can be found by the case ID", not run.is_empty() and run["case_hash"] == ImpactCase.case_hash(c1))
	check("and it, not the reviewer file, holds the map back to the products", run["map"].size() == 5 and not JSON.stringify(c1).contains("\"map\""))
	var vf := ImpactCase.build_verdict_file(c1, [_verdict("W1", "supported", [])])
	check("a verdict file binds to its case", ImpactCase.validate_verdict_file(vf, c1)["ok"])
	check("it will not open for another case", not ImpactCase.validate_verdict_file(vf, c2)["ok"])
	var tampered: Dictionary = c1.duplicate(true)
	tampered["records"][0]["text"] = "changed"
	check("or for a case that was changed", not ImpactCase.validate_verdict_file(vf, tampered)["ok"])

	# ---- the reveal
	var rv1 := ImpactReview.reveal(c1, e1["map"], ev1, ImpactScenario.budget(0), 8)
	check("the reveal has three sections", rv1["what_happened"].size() > 0 and rv1["reached"].size() > 0 and rv1["could_support"].size() == 3)
	check("what happened names the real impacts and the artifact", String(rv1["what_happened"][2]).contains("reflection"))
	check("what reached Earth lists the delivered products and the packets used", String(rv1["reached"][-1]).contains("Packets used: 8"))
	var rv2 := ImpactReview.reveal(c2, e2["map"], ev2b, ImpactScenario.budget(0), cost2)
	check("run 2's lesson says a second independent window was missing", String(rv2["lesson"]).contains("independent") and String(rv2["lesson"]).contains("A4"))
	check("run 1's lesson is different", rv1["lesson"] != rv2["lesson"])
	print("FAILS: ", fails)
	quit(fails)
