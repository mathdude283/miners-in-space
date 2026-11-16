class_name ImpactReview
extends RefCounted
## Mission Control's side: group the delivered records into candidate sightings, work out how many INDEPENDENT sources back each
## one, and judge a reviewer's verdict against the evidence that actually arrived. The hidden truth is never used to grade
## justification. A real event can correctly be rated Insufficient; a cautious verdict can be fully justified.
##
## GAME rules inspired by the scientific process. They are not NASA's formal confirmation criteria.
##   - Records that share a source group (a log, a crop and a wide frame from one window, or a retelling of someone else's
##     observation) are ONE source.
##   - Silence only counts against a candidate if the silent observer's coverage area included its place and time.
##   - A wide frame that shows a reflection moving with the window actively supports an artifact explanation.
##   - Two independent, compatible observations support a finding unless there is a strong reason to favour an artifact.

const TIME_GAP := 4.0          # seconds: observations this close in time can be the same candidate
const POS_GAP := 15.0          # degrees: and this close in place
const VERDICTS := ["supported", "possible", "insufficient", "artifact"]
const VERDICT_LABEL := {"supported": "Supported impact", "possible": "Possible impact", "insufficient": "Insufficient evidence", "artifact": "Likely artifact"}


static func _positive(r: Dictionary) -> bool:
	return String(r["finding"]) != "no_event_seen"


static func _dist(a: Dictionary, b: Dictionary) -> float:
	var dlon := absf(float(a["lon"]) - float(b["lon"]))
	if dlon > 180.0:
		dlon = 360.0 - dlon
	return maxf(absf(float(a["lat"]) - float(b["lat"])), dlon)


static func _inside(cov: Dictionary, pos: Dictionary) -> bool:
	return float(pos["lat"]) >= float(cov["lat"][0]) and float(pos["lat"]) <= float(cov["lat"][1]) and float(pos["lon"]) >= float(cov["lon"][0]) and float(pos["lon"]) <= float(cov["lon"][1])


## Candidate sightings found in the delivered records, in time order: {id, t, pos, records, groups, silent_inside, silent_outside}.
static func candidates(case: Dictionary) -> Array[Dictionary]:
	var recs: Array = case["records"]
	var pos_recs: Array = recs.filter(func(r): return _positive(r) and r["position"] != null)
	pos_recs.sort_custom(func(a, b): return float(a["time"][0]) < float(b["time"][0]))
	var clusters: Array[Dictionary] = []
	for r in pos_recs:
		var placed := false
		for c in clusters:
			if float(r["time"][0]) <= float(c["t"][1]) + TIME_GAP and float(r["time"][1]) >= float(c["t"][0]) - TIME_GAP and _dist(r["position"], c["pos"]) <= POS_GAP:
				c["records"].append(r)
				c["t"] = [minf(float(c["t"][0]), float(r["time"][0])), maxf(float(c["t"][1]), float(r["time"][1]))]
				placed = true
				break
		if not placed:
			clusters.append({"t": [float(r["time"][0]), float(r["time"][1])], "pos": {"lat": float(r["position"]["lat"]), "lon": float(r["position"]["lon"])}, "records": [r]})
	clusters.sort_custom(func(a, b): return float(a["t"][0]) < float(b["t"][0]))
	var out: Array[Dictionary] = []
	var n := 1
	for c in clusters:
		var groups := {}
		for r in c["records"]:
			groups[String(r["source_group"])] = true
		var inside: Array = []
		var outside: Array = []
		for r in recs:
			if _positive(r):
				continue
			if float(r["time"][1]) >= float(c["t"][0]) - 2.0 and float(r["time"][0]) <= float(c["t"][1]) + 2.0:
				if _inside(r["coverage"], c["pos"]):
					inside.append(r)
				else:
					outside.append(r)
		out.append({"id": "W%d" % n, "t": c["t"], "pos": c["pos"], "records": c["records"], "groups": groups.keys(), "silent_inside": inside, "silent_outside": outside})
		n += 1
	return out


## What the delivered evidence can justify for one candidate: {best, credit_for: {verdict: credit}, independent, artifact_support, weak, why}.
static func support(c: Dictionary) -> Dictionary:
	var independent: int = c["groups"].size()
	var artifact := false
	var max_conf := 0.0
	for r in c["records"]:
		if String(r["finding"]) == "reflection_moves_with_window":
			artifact = true
		max_conf = maxf(max_conf, float(r["confidence"]))
	var weak := max_conf <= 0.35
	var neg_inside: int = c["silent_inside"].size()
	var credit := {}
	var best := "insufficient"
	var why := ""
	if artifact:
		credit = {"artifact": 100, "insufficient": 70}
		best = "artifact"
		why = "A wide frame shows the spot moving with the window edge, not with the Moon."
	elif independent >= 2 and neg_inside == 0:
		credit = {"supported": 100, "possible": 80}
		best = "supported"
		why = "%d independent sources agree on time and place." % independent
	elif independent >= 2:
		credit = {"possible": 100, "supported": 50, "insufficient": 70}
		best = "possible"
		why = "Independent sources agree, but an observer whose coverage included the place saw nothing."
	elif independent == 1:
		credit = {"possible": 100, "insufficient": 100}
		best = "insufficient" if weak else "possible"
		why = "Only one source (%d record%s from the same witness or instrument). %s" % [c["records"].size(), "" if c["records"].size() == 1 else "s", "It is a weak report." if weak else "It is a firm report, but nothing independent backs it."]
	else:
		credit = {"insufficient": 100, "possible": 50}
		why = "No usable source."
	return {"best": best, "credit_for": credit, "independent": independent, "artifact_support": artifact, "weak": weak, "silent_inside": neg_inside, "why": why}


## Judge verdicts: [{candidate, verdict, cites}] against the case. Returns {results, mean_credit, complete, unjustified}.
static func evaluate(case: Dictionary, verdicts: Array) -> Dictionary:
	var cands := candidates(case)
	var by_id := {}
	for r in case["records"]:
		by_id[String(r["id"])] = r
	var results: Array[Dictionary] = []
	var unjustified := 0
	var total := 0.0
	for c in cands:
		var v := {}
		for x in verdicts:
			if String(x.get("candidate", "")) == String(c["id"]):
				v = x
		var sup := support(c)
		var verdict := String(v.get("verdict", ""))
		var cites: Array = v.get("cites", [])
		var note := ""
		var credit := 0
		if verdict == "" or not VERDICTS.has(verdict):
			note = "No verdict was given."
		else:
			credit = int(sup["credit_for"].get(verdict, 0))
			var cand_ids := {}
			for r in c["records"]:
				cand_ids[String(r["id"])] = true
			var cited_groups := {}
			var valid_cites := 0
			for id in cites:
				if cand_ids.has(String(id)):
					valid_cites += 1
					cited_groups[String(by_id[String(id)]["source_group"])] = true
			var double_counted: bool = valid_cites > cited_groups.size() and verdict == "supported"
			if verdict == "supported" and cited_groups.size() < 2:
				credit = int(credit * 0.5)
				note = "You cited %d source%s as if they were independent. Records from the same witness count once." % [valid_cites, "" if valid_cites == 1 else "s"] if double_counted else "Supported needs two independent sources cited; you cited %d." % cited_groups.size()
			elif verdict == "artifact":
				var has_ctx := false
				for id in cites:
					if by_id.has(String(id)) and String(by_id[String(id)]["finding"]) == "reflection_moves_with_window":
						has_ctx = true
				if not has_ctx:
					credit = int(credit * 0.5)
					note = "To call it an artifact, cite the wide frame that shows it moving with the window."
			elif valid_cites == 0:
				credit = int(credit * 0.8)
				note = "You gave no records to back your verdict."
			if credit == 0:
				note = "The delivered evidence does not justify %s. %s" % [String(VERDICT_LABEL[verdict]).to_lower(), String(sup["why"])]
		var justified := credit >= 70
		if not justified:
			unjustified += 1
		total += float(credit)
		results.append({"candidate": c["id"], "verdict": verdict, "credit": credit, "justified": justified, "note": note, "support": sup, "cites": cites})
	var mean := total / maxf(float(cands.size()), 1.0)
	return {"results": results, "mean_credit": mean, "complete": not cands.is_empty() and unjustified == 0 and mean >= 70.0, "unjustified": unjustified, "candidates": cands}


## The reveal, in three labelled sections, from the onboard run record (truth stays aboard) and the evaluation.
## map: opaque record id -> product id. Also names one concrete thing the flyer could have sent differently.
static func reveal(case: Dictionary, map: Dictionary, eval: Dictionary, budget: int, sent_cost: int) -> Dictionary:
	var sent_products := {}
	for rid in map:
		sent_products[String(map[rid])] = true
	var what_happened: Array[String] = []
	for cid in ["A", "B", "C"]:
		what_happened.append("%s: %s." % [cid, String(ImpactScenario.TRUTH[cid]["what"])])
	var reached: Array[String] = []
	for p in ImpactScenario.products():
		if sent_products.has(String(p["id"])):
			reached.append("%s (%d packets): %s" % [String(p["id"]), int(p["cost"]), String(p["text"])])
	reached.append("Packets used: %d of %d. Everything else stayed aboard." % [sent_cost, budget])
	var could_support: Array[String] = []
	for r in eval["results"]:
		could_support.append("%s: the evidence could justify '%s'. %s You said '%s' (%s)." % [r["candidate"], String(VERDICT_LABEL[r["support"]["best"]]), String(r["support"]["why"]), String(VERDICT_LABEL.get(r["verdict"], "nothing")), "justified" if r["justified"] else "not justified"])
	return {"what_happened": what_happened, "reached": reached, "could_support": could_support, "lesson": lesson(sent_products, budget, sent_cost)}


## One concrete lesson: the cheapest unsent product that would have upgraded what Mission Control could conclude.
static func lesson(sent: Dictionary, budget: int, sent_cost: int) -> String:
	var left := budget - sent_cost
	# candidate A: needs a second independent window
	var a_groups := {}
	for pid in ["A1", "A2", "A3", "A4", "A5"]:
		if sent.has(pid):
			a_groups[String(ImpactScenario.product(pid)["group"])] = true
	if a_groups.size() < 2:
		var which := "A4 (the Flight Deck log, 1 packet)" if not sent.has("A4") else "A5"
		return "Candidate A was seen from two windows, but only %d reached Earth. Sending %s would have given Mission Control a second independent source and made the impact supportable. Repeated logs or crops from one window never replace another observer." % [a_groups.size(), which]
	if not sent.has("C3") and (sent.has("C1") or sent.has("C2")):
		return "Candidate C looked like a flash in the tight crop. The wide frame C3 (4 packets) shows the spot moving with the window edge, which would have let Mission Control call it an artifact. A tight crop alone cannot rule out a reflection."
	if sent.has("B3") and not sent.has("B1"):
		return "A retelling (B3) is not a witness. Sending the original log B1 (1 packet) gives Mission Control the firsthand report."
	return "You sent independent evidence and the context that matters. With %d packets to spare, a crop of the faint candidate B would still not make it independent: one weak witness stays inconclusive." % maxi(left, 0)
