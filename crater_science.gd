class_name CraterScience
extends RefCounted
## The rules for Contract 02, Glushko and Ohm. Pure data and maths, no screens, so they can be tested.
##
## REAL (sourced):
##  - Glushko is a young crater on the west rim of Olbers (about 8 N, 77.7 W, about 40 km across) with a bright ray system.
##    Source: USGS Gazetteer of Planetary Nomenclature, Moon, feature 2195.
##  - Ohm is on the far side (about 18.3 N, 113.8 W, about 62 km across) with a ray system that reaches hundreds of km.
##    Source: USGS Gazetteer of Planetary Nomenclature, Moon, feature 4417.
##  - Low Sun casts long shadows that show texture and relief. High Sun casts no resolvable shadows, so differences in
##    brightness (like bright rays) stand out. Source: LROC "Sun Angles" (lroc.im-ldi.com/images/790).
## GAME (our rules): the three Sun passes, how long they take to wait for, and the comparability score below.

const PASSES: Array[Dictionary] = [
	{"id": "early", "label": "EARLY PASS", "elev": 0.22, "dir": -1, "wait": 0.0, "text": "Low Sun from the left"},
	{"id": "noon", "label": "MIDDAY PASS", "elev": 0.90, "dir": 0, "wait": 8.0, "text": "High Sun, nearly overhead"},
	{"id": "late", "label": "LATE PASS", "elev": 0.22, "dir": 1, "wait": 16.0, "text": "Low Sun from the right"},
]
## Going back to a pass you already used at the same crater means waiting for the next orbit.
const REPEAT_WAIT := 10.0
const COMPARABLE := 0.5            # below this the pair is not a fair comparison
const STRONG := 0.85
const HIGH_SUN := 0.6              # at or above this the Sun is high enough for rays to show

const DIRECTIONS := {-1: "FROM THE LEFT", 0: "OVERHEAD", 1: "FROM THE RIGHT"}

const CRATERS := {
	"glushko": {"name": "Glushko", "desc": "young crater with bright rays", "noun": "crater", "size": 0.8, "ray_len": 1.0,
		"fact": "Glushko is a young crater on the west rim of Olbers, about 40 km across, with a bright ray system. (USGS Gazetteer)"},
	"ohm": {"name": "Ohm", "desc": "far-side crater with long rays", "noun": "crater", "size": 1.15, "ray_len": 1.9,
		"fact": "Ohm is a far-side crater about 62 km across. Its rays reach hundreds of km. (USGS Gazetteer)"},
}


static func pass_by_id(id: String) -> Dictionary:
	for p in PASSES:
		if p["id"] == id:
			return p
	return PASSES[0]


## Minutes the crew waits for this pass. used is the list of {crater, pass} already observed.
static func wait_for(crater: String, pass_id: String, used: Array) -> float:
	for u in used:
		if u["crater"] == crater and u["pass"] == pass_id:
			return REPEAT_WAIT
	return float(pass_by_id(pass_id)["wait"])


## Which crater each observation is of, given the branch the player chose.
static func crater_for(observation: int, branch: String) -> String:
	if observation == 0:
		return "glushko"
	return "ohm" if branch == "ohm" else "glushko"


## GAME rule: how fair a comparison of two photos is, 0 to 1. Same Sun height and the same side scores 1.
static func comparability(a: Dictionary, b: Dictionary) -> float:
	var de := absf(float(a["sun_elev"]) - float(b["sun_elev"]))
	var dd := absf(float(a["sun_dir"]) - float(b["sun_dir"])) * 0.5
	return clampf(1.0 - de / 0.68 * 0.6 - dd * 0.4, 0.0, 1.0)


## Which photo shows the rays best: "a", "b" or "same". REAL rule: high Sun makes brightness differences stand out.
static func rays_best(a: Dictionary, b: Dictionary) -> String:
	var ea := float(a["sun_elev"])
	var eb := float(b["sun_elev"])
	if absf(ea - eb) < 0.3:
		return "same"
	return "a" if ea > eb else "b"


## What the player says each photo's light was, judged from the picture. Overhead Sun leaves no shadows to read.
static func direction_name(d: int) -> String:
	return String(DIRECTIONS.get(d, "OVERHEAD"))


## Marks the comparison. branch is "reobserve" or "ohm". a and b are the two photos. says is the player's answers:
## {dir_a, dir_b, rays}. Returns what the report and the result screen show.
static func evaluate(branch: String, a: Dictionary, b: Dictionary, says: Dictionary) -> Dictionary:
	var comp := comparability(a, b)
	var dir_a_ok := int(says.get("dir_a", 99)) == int(a["sun_dir"])
	var dir_b_ok := int(says.get("dir_b", 99)) == int(b["sun_dir"])
	var truth := rays_best(a, b)
	var rays_ok := String(says.get("rays", "")) == truth
	var usable := true
	var why := ""
	var fix := ""
	var lines: Array[String] = []
	if branch == "ohm":
		var a_high := float(a["sun_elev"]) >= HIGH_SUN
		var b_high := float(b["sun_elev"]) >= HIGH_SUN
		if not (a_high and b_high):
			usable = false
			var which := "Neither photo was" if not a_high and not b_high else ("The Glushko photo was not" if not a_high else "The Ohm photo was not")
			why = "%s taken in high Sun. Low Sun casts shadows that hide brightness differences, so the rays did not show and there was nothing to compare." % which
			fix = "Plan the MIDDAY PASS for both crater photos: high Sun is when rays stand out."
	else:
		if comp < COMPARABLE:
			usable = false
			why = "The two Glushko photos were taken in very different light (comparability %d%%). Shadows and brightness changed, so you cannot tell what is the crater and what is the lighting." % int(comp * 100.0)
			fix = "For the second photo, plan the same pass as the first, or one with similar Sun height and side."
	var score := 0.5 * comp if branch != "ohm" else 0.5
	score += 0.15 * (1.0 if dir_a_ok else 0.0) + 0.15 * (1.0 if dir_b_ok else 0.0) + 0.2 * (1.0 if rays_ok else 0.0)
	if branch == "ohm":
		score += 0.5 * minf(float(a["sun_elev"]), float(b["sun_elev"])) / 0.9
	var confidence := "STRONG" if score >= STRONG else ("MODERATE" if score >= 0.6 else "TENTATIVE")
	lines.append("Light direction, photo A: %s." % ("correct" if dir_a_ok else "wrong (it was %s)" % direction_name(int(a["sun_dir"])).to_lower()))
	lines.append("Light direction, photo B: %s." % ("correct" if dir_b_ok else "wrong (it was %s)" % direction_name(int(b["sun_dir"])).to_lower()))
	var rays_txt := {"a": "photo A", "b": "photo B", "same": "both about equally"}
	lines.append("Rays show best in %s. %s" % [rays_txt[truth], "You said so." if rays_ok else "You said %s." % rays_txt.get(String(says.get("rays", "")), "nothing")])
	lines.append("Comparability (GAME rule): %d%%." % int(comp * 100.0))
	return {"usable": usable, "why": why, "fix": fix, "comparability": comp, "confidence": confidence, "score": score,
		"dir_a_ok": dir_a_ok, "dir_b_ok": dir_b_ok, "rays_ok": rays_ok, "rays_truth": truth, "lines": lines, "branch": branch}
