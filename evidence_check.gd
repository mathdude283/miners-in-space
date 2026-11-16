class_name EvidenceCheck
extends RefCounted
## Orientale's evidence policy, in one place so the brief, the result screen and the report all say the same thing.
##
## For each shot the contract needs, four separate outcomes are kept:
##   CAPTURED  the shot was taken
##   TAGGED    the player said which picture shows WHERE and which shows WHAT THE SURFACE IS LIKE, and said it the right way round
##   RECEIVED  the photo finished transmitting and is on Earth
##   MEETS     captured, tagged correctly, rated MODERATE or better, and received
## Which shots are needed depends on the ship: both lenses fitted means both shots; one lens means that one shot.
## The contract is complete only when every needed shot MEETS the criteria. Anything else that reached Earth is still kept and
## credited as partial evidence.

const MIN_STARS := 2          # MODERATE or better (a GAME rule)
const LENS_LABEL := {"wide": "WIDE IMAGE", "close": "DETAIL TILE"}
const LENS_ROLE := {"wide": "shows WHERE the basin is", "close": "shows WHAT THE SURFACE IS LIKE"}


## The policy as one short paragraph for the brief.
static func policy(wide: bool, close: bool) -> String:
	var need := "both a wide image and a close-up (your ship carries both lenses)" if wide and close else ("a wide image (your ship carries only the wide lens)" if wide else ("a close-up (your ship carries only the close-up lens)" if close else "a photo"))
	return "This contract needs %s. A shot counts when it is captured, tagged the right way round, rated MODERATE or better, and received on Earth." % need


static func needed(wide: bool, close: bool) -> Array[String]:
	var out: Array[String] = []
	if wide:
		out.append("wide")
	if close:
		out.append("close")
	return out


## One row per needed shot: what happened to it, step by step, and why it does or does not count.
static func rows(photos: Array, received: Array, wide: bool, close: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lens in needed(wide, close):
		var ph := {}
		for p in photos:
			if String(p.get("lens", "")) == lens:
				ph = p
		var captured := not ph.is_empty()
		var tagged := captured and ph.has("tag_ok")
		var tag_ok := tagged and bool(ph["tag_ok"])
		var got := received.has(lens)
		var stars := int(ph.get("stars", 0)) if captured else 0
		var problems: Array[String] = []
		if not captured:
			problems.append("It was never photographed.")
		else:
			if not tag_ok:
				problems.append("It was tagged the wrong way round: the %s %s." % [LENS_LABEL[lens].to_lower(), LENS_ROLE[lens]])
			if stars < MIN_STARS:
				problems.append("It is a weak shot (%s). Framing, steadiness or light was too poor." % String(ph.get("confidence", "TENTATIVE")).to_lower())
			if not got:
				problems.append("It did not finish transmitting, so it never reached Earth.")
		out.append({"needed": true, "lens": lens, "key": lens, "label": LENS_LABEL[lens], "captured": captured, "tagged": tagged, "tag_ok": tag_ok,
			"received": got, "stars": stars, "confidence": String(ph.get("confidence", "NONE")) if captured else "NONE",
			"framing": float(ph.get("framing", 0.0)), "sharp": float(ph.get("sharp", 0.0)), "light": float(ph.get("light", 0.0)),
			"tex": ph.get("tex"), "problems": problems, "meets": captured and tag_ok and stars >= MIN_STARS and got,
			"crater": "", "pass": ""})
	return out


## {complete, any_received, why, fix} for a set of rows.
static func summary(rs: Array) -> Dictionary:
	var complete := not rs.is_empty()
	var any := false
	var bad: Array[String] = []
	for r in rs:
		if bool(r["received"]):
			any = true
		if not bool(r["meets"]):
			complete = false
			bad.append("%s: %s" % [String(r["label"]), " ".join(r["problems"])])
	var why := ""
	var fix := ""
	if not complete:
		why = "Not every needed shot meets the criteria. " + "  ".join(bad)
		fix = "Photograph every needed shot, tag them the right way round, aim for MODERATE or better (frame it, hold steady, wait for good light), and keep the dish on Earth until each bar fills. What reached Earth is kept."
	return {"complete": complete, "any_received": any, "why": why, "fix": fix}


## Short text for the four stages of one row.
static func stage_text(r: Dictionary) -> Dictionary:
	return {
		"captured": "YES" if bool(r["captured"]) else "NO",
		"tagged": "CORRECT" if bool(r["tag_ok"]) else ("WRONG WAY ROUND" if bool(r["tagged"]) else "NOT TAGGED"),
		"received": "ON EARTH" if bool(r["received"]) else "NOT RECEIVED",
		"meets": "YES" if bool(r["meets"]) else "NO",
	}
