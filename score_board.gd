class_name ScoreBoard
extends RefCounted
## Grades and points for a flight, so every run can be compared with the last and with other players. Everything here is a GAME score,
## not a NASA measure. Six categories, 1,100 points at most, a letter grade from the percentage, then a difficulty multiplier turns it
## into the points that go on the leaderboard. The grades are strict: an A needs a near-perfect flight.

const DIFFICULTY := [
	{"name": "CADET", "mult": 1.0, "resources": 1.0, "shake": 1.0, "window": 1.0, "blurb": "The gentlest: longer windows, steady camera, plenty of time and power."},
	{"name": "PILOT", "mult": 1.25, "resources": 0.85, "shake": 1.25, "window": 0.85, "blurb": "Shorter windows, shakier camera and less time and power. 25% more points."},
	{"name": "DIRECTOR", "mult": 1.5, "resources": 0.7, "shake": 1.5, "window": 0.7, "blurb": "For experts: very short windows, a camera that really shakes, tight time and power. 50% more points."},
]
const GRADES := [["A", 92.0], ["B", 82.0], ["C", 70.0], ["D", 55.0]]
const SCORES_FILE := "user://moonbound_scores.json"
const MAX_SCORES := 10


static func difficulty(level: int) -> Dictionary:
	return DIFFICULTY[clampi(level, 0, DIFFICULTY.size() - 1)]


static func grade_for(percent: float) -> String:
	for g in GRADES:
		if percent >= float(g[1]):
			return String(g[0])
	return "F"


## Score one flight. run is the MissionRun, id the contract, level the difficulty. Returns
## {rows: [{name, pts, max, why}], total, max, percent, grade, points, mult}.
static func compute(run: MissionRun, id: int, level := 1) -> Dictionary:
	var rows: Array[Dictionary] = []
	# 1 DATA (300): did the evidence come home, and was it good
	var data := 0.0
	var why := ""
	if id == 2:
		var ev2: Dictionary = run.impact.get("eval", {})
		data = clampf(float(ev2.get("mean_credit", 0.0)) * 3.0, 0.0, 300.0) if bool(run.impact.get("sent", false)) else 0.0
		why = "Mission Control's credit for what you sent."
	else:
		var needed := 0
		var star_sum := 0.0
		var tag_sum := 0.0
		var recv_sum := 0.0
		for e in run.evidence:
			if not bool(e.get("needed", true)):
				continue
			needed += 1
			if bool(e.get("captured", true)):
				star_sum += float(e.get("stars", 0)) / 3.0
			tag_sum += 1.0 if bool(e.get("tag_ok", false)) else 0.0
			recv_sum += 1.0 if bool(e.get("received", false)) else 0.0
		if needed > 0:
			data = 150.0 * star_sum / needed + 50.0 * tag_sum / needed + 100.0 * recv_sum / needed
		why = "Photo quality (stars), tagging them right, and getting them home."
	rows.append({"name": "DATA", "pts": data, "max": 300.0, "why": why})
	# 2 SCIENCE (200): what you concluded
	var sci := 0.0
	match id:
		0:
			var nc: Dictionary = run.nasa_compare
			sci = (70.0 if nc.get("interior", false) else 0.0) + (70.0 if nc.get("rings", false) else 0.0) + (60.0 if bool(nc.get("done", false)) else 0.0)
		1:
			sci = {"STRONG": 200.0, "MODERATE": 130.0}.get(String(run.science.get("eval", {}).get("confidence", "")), 60.0)
		2:
			var res: Array = run.impact.get("eval", {}).get("results", [])
			var ok := 0
			for r in res:
				if bool(r.get("justified", false)):
					ok += 1
			sci = 200.0 * float(ok) / float(maxi(res.size(), 1))
	rows.append({"name": "SCIENCE", "pts": sci, "max": 200.0, "why": "How well you read the evidence."})
	# 3 FLIGHT (150): the way home
	var fl := 0.0
	var land: Dictionary = run.landing
	if not land.is_empty() and bool(land.get("landed", false)):
		var mph := float(land.get("speed_mph", 30.0))
		fl += 60.0 * clampf(1.0 - maxf(mph - 20.0, 0.0) / 20.0, 0.0, 1.0)
		fl += 50.0 * clampf(float(land.get("angle", 0.5)), 0.0, 1.0)
		fl += maxf(40.0 - 10.0 * float(land.get("over_seconds", 0.0)), 0.0)
	rows.append({"name": "FLIGHT", "pts": fl, "max": 150.0, "why": "A soft splashdown, a clean entry angle and a short time over the g limit."})
	# 4 CREW (200): everyone home and well
	var crew := 0.0
	var hp := 0.0
	var dead := 0
	for c in run.crew:
		hp += clampf(float(c["health"]), 0.0, 100.0)
		if float(c["health"]) <= 0.0:
			dead += 1
	if not run.crew.is_empty():
		crew = 150.0 * hp / (100.0 * run.crew.size())
	if run.damage_log.is_empty():
		crew += 50.0
	crew = maxf(crew - 100.0 * dead, 0.0)
	rows.append({"name": "CREW", "pts": crew, "max": 200.0, "why": "Health at the end, and nobody hurt along the way."})
	# 5 EFFICIENCY (150): time and power left (half of each is full marks)
	var eff := 75.0 * minf(run.fraction("time") * 2.0, 1.0) + 75.0 * minf(run.fraction("power") * 2.0, 1.0)
	rows.append({"name": "EFFICIENCY", "pts": eff, "max": 150.0, "why": "Time and power left over."})
	# 6 DECISIONS (100): choices that did not cost anyone health
	var dec := maxf(100.0 - 25.0 * float(run.damage_log.size()), 0.0)
	rows.append({"name": "DECISIONS", "pts": dec, "max": 100.0, "why": "Each injury costs you 25."})
	var total := 0.0
	var mx := 0.0
	for r in rows:
		r["pts"] = roundf(float(r["pts"]))
		total += float(r["pts"])
		mx += float(r["max"])
	var pct := 100.0 * total / mx
	var d := difficulty(level)
	return {"rows": rows, "total": int(total), "max": int(mx), "percent": pct, "grade": grade_for(pct), "mult": float(d["mult"]), "points": int(round(total * float(d["mult"]))), "difficulty": String(d["name"])}


# ---------------------------------------------------------------- the leaderboard (this computer only)

static func load_scores(path := SCORES_FILE) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Array else []


## Add a finished campaign to the leaderboard. Returns its rank (1 = best), or 0 if it did not make the list.
static func submit(entry: Dictionary, path := SCORES_FILE) -> int:
	var list := load_scores(path)
	list.append(entry)
	list.sort_custom(func(a, b): return int(a.get("points", 0)) > int(b.get("points", 0)))
	var rank := 0
	for i in list.size():
		if list[i] == entry:
			rank = i + 1
			break
	list = list.slice(0, MAX_SCORES)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(list, "  "))
		f.close()
	return rank if rank <= MAX_SCORES else 0


# ---------------------------------------------------------------- badges and personal bests

const BEST_FILE := "user://moonbound_best.json"


## Badges earned on this flight: [{name, file, why}]. Awarded for doing something well, never for just finishing.
static func badges(sb: Dictionary, run: MissionRun) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by := {}
	for r in sb["rows"]:
		by[String(r["name"])] = float(r["pts"]) / float(r["max"])
	for e in run.evidence:
		if int(e.get("stars", 0)) >= 3 and bool(e.get("received", false)):
			out.append({"name": "PERFECT SHOT", "file": "badge_trophy", "why": "A 3-star photo that reached Earth."})
			break
	if float(by.get("SCIENCE", 0.0)) >= 0.9:
		out.append({"name": "SHARP EYES", "file": "badge_crystal", "why": "Read the evidence almost perfectly."})
	if float(by.get("FLIGHT", 0.0)) >= 0.9:
		out.append({"name": "SOFT LANDING", "file": "badge_gold_wings", "why": "A gentle, clean way home."})
	if run.damage_log.is_empty() and run.alive_count() == run.crew.size():
		out.append({"name": "NOBODY HURT", "file": "badge_experience", "why": "The whole crew, untouched."})
	if float(by.get("EFFICIENCY", 0.0)) >= 0.8:
		out.append({"name": "LEAN AND FAST", "file": "badge_rocket", "why": "Plenty of time and power left."})
	return out


## Remember the best points for a contract. Returns {best, new_best}.
static func record_best(id: int, points: int, path := BEST_FILE) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	if not (d is Dictionary):
		d = {}
	var key := str(id)
	var old := int(d.get(key, 0))
	var is_new := points > old
	if is_new:
		d[key] = points
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(d))
			f.close()
	return {"best": maxi(old, points), "new_best": is_new and old > 0, "first": old == 0}
