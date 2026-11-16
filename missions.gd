class_name Missions
## Contract data for the mission select screen. Everything the player reads comes from here, so the
## team can edit wording without touching the layout.
##
## "id" matches PlayerData.Scenario (0 = MISSION_1, 1 = MISSION_2, 2 = MISSION_3).
## Wording follows the team's design brief (Drive: 03 Design references / moonbound-app-design.md).
## Duration, funding and difficulty are not in the brief yet, so they are not shown. Add them here
## once the team decides, then show them on the card.
## Contracts 01 and 02 are built; 03 stays locked until it is.

const LIST: Array[Dictionary] = [
	{
		"id": 0,
		"tag": "CONTRACT 01",
		"diagram": "orientale",
		"name": "ORIENTALE",
		"objective": "Photograph the Orientale basin, tag which picture shows WHERE it is and which shows WHAT THE SURFACE IS LIKE, and send them home. Both shots are needed if your ship carries both lenses; a one-lens ship needs its one shot. A shot counts when it is tagged the right way round, rated MODERATE or better, and received on Earth.",
		"card": "Photograph the Orientale basin with a wide shot and a close-up. Tag them, then send them home.",
		"short": "Photograph the basin, tag WHERE and WHAT IT IS LIKE, and send the shots home. A shot counts when tagged right, MODERATE or better, and received.",
		"evidence": ["WIDE IMAGE", "DETAIL TILE", "TAGGED"],
		"available": true,
		## What the ship must have, beyond the basics. lens: "any" or "both". lab: a Science Lab is required.
		"needs": {"lens": "any", "lab": false},
		## What the player is shown and photographs.
		"target": {"name": "Orientale", "desc": "dark Orientale basin", "noun": "basin"},
		## GAME numbers: minutes of operations and power units to spend in flight.
		"budget": {"time": 40.0, "power": 20.0},
		"objectives": [
			{"id": "photo", "label": "Photograph the basin (wide, close-up)"},
			{"id": "tag", "label": "Tag WHERE and WHAT IT IS LIKE"},
			{"id": "send", "label": "Send the photos to Earth"},
		],
	},
	{
		"id": 1,
		"tag": "CONTRACT 02",
		"diagram": "glushko_ohm",
		"name": "GLUSHKO AND OHM",
		"objective": "Compare two craters under different light. Re-observe Glushko, or observe Ohm to compare crater rays.",
		"evidence": ["A/B COMPARISON", "LIGHT DIRECTION"],
		"available": true,
		"needs": {"lens": "any", "lab": true},
		"target": {"name": "Glushko and Ohm", "desc": "crater", "noun": "crater", "kind": "crater"},
		## Two observations, a comparison in the Science Lab (marked by CraterScience), and random events the player decides.
		"science": "crater",
		"events": 2,
		"budget": {"time": 60.0, "power": 26.0},
		"objectives": [
			{"id": "first", "label": "Make the first observation"},
			{"id": "second", "label": "Make the second observation"},
			{"id": "compare", "label": "Compare the two photos in the Science Lab"},
			{"id": "send", "label": "Send the evidence to Earth"},
		],
		## The brief: re-observe Glushko in more comparable conditions, or observe Ohm to compare crater rays.
		"branch": {"id": "second", "prompt": "For the second observation:", "choices": [
			{"id": "reobserve", "label": "Re-observe Glushko in more comparable light"},
			{"id": "ohm", "label": "Observe Ohm to compare crater rays"},
		]},
	},
	{
		"id": 2,
		"tag": "CONTRACT 03",
		"diagram": "impact_watch",
		"name": "IMPACT WATCH",
		"objective": "Watch the far side through your windows and log what you see. Send what you can within the packet budget. Then review it as Mission Control: a sighting is only supported when independent sources agree.",
		"card": "Log sightings from your windows. Send what fits. Then review as Mission Control.",
		"short": "Log sightings, send what fits, review as Mission Control.",
		"evidence": ["SIGHTING LOG", "REVIEW"],
		"available": true,
		"needs": {"lens": "any", "lab": false},
		"target": {"name": "Impact Watch", "desc": "dark region", "noun": "region"},
		"budget": {"time": 50.0, "power": 22.0},
		"objectives": [{"id": "log", "label": "Log what you see"}, {"id": "send", "label": "Send within the packets"}, {"id": "review", "label": "Review as Mission Control"}],
	},
	{
		"id": 3, "tag": "CONTRACT 04", "diagram": "orbit", "kind": "spacecraft", "name": "EARTH WILDFIRE",
		"objective": "Design an uncrewed spacecraft that watches Earth for wildfires from low Earth orbit, then run its mission. Real part numbers, game limits.",
		"card": "Design a wildfire-watching spacecraft, pick its orbit, and run the mission.", "short": "Design a wildfire-watching spacecraft, pick its orbit, and run the mission.",
		"evidence": ["SPACECRAFT DESIGN", "ORBIT", "MISSION RESULT"],
		"available": true, "needs": {"lens": "any", "lab": false},
		"target": {"name": "Earth Wildfire", "desc": "target", "noun": "target"},
		"budget": {"time": 50.0, "power": 22.0}, "objectives": [],
	},
	{
		"id": 4, "tag": "CONTRACT 05", "diagram": "orbit", "kind": "spacecraft", "name": "LUNAR ICE",
		"objective": "Design a spacecraft for a low lunar polar orbit that searches for buried water ice, then run its mission.",
		"card": "Search the Moon poles for ice. Choose instruments and burns carefully.", "short": "Search the Moon poles for ice. Choose instruments and burns carefully.",
		"evidence": ["SPACECRAFT DESIGN", "ORBIT", "MISSION RESULT"],
		"available": true, "needs": {"lens": "any", "lab": false},
		"target": {"name": "Lunar Ice", "desc": "target", "noun": "target"},
		"budget": {"time": 50.0, "power": 22.0}, "objectives": [],
	},
	{
		"id": 5, "tag": "CONTRACT 06", "diagram": "orbit", "kind": "spacecraft", "name": "NEPTUNE",
		"objective": "Design a spacecraft to fly to Neptune, far from the Sun, where solar power fails and signals take hours. Then run its mission.",
		"card": "Fly to Neptune. Power, autonomy and a big dish decide everything.", "short": "Fly to Neptune. Power, autonomy and a big dish decide everything.",
		"evidence": ["SPACECRAFT DESIGN", "ORBIT", "MISSION RESULT"],
		"available": true, "needs": {"lens": "any", "lab": false},
		"target": {"name": "Neptune", "desc": "target", "noun": "target"},
		"budget": {"time": 50.0, "power": 22.0}, "objectives": [],
	},
]


## What this contract needs from the ship, with a yes or no for each. s is the ship, or null if there is none yet.
## Every contract needs a window to see through, a lens, and a radio; some need more (needs in the data).
static func requirements(id: int, s: BuildState) -> Array[Dictionary]:
	var needs: Dictionary = get_mission(id).get("needs", {})
	var out: Array[Dictionary] = []
	out.append({"label": "Observation Bay (a window)", "ok": s != null and s.has_room("observation"), "fix": "an Observation Bay"})
	if String(needs.get("lens", "any")) == "both":
		out.append({"label": "Both lenses", "ok": s != null and s.wide and s.close, "fix": "both lenses"})
	else:
		out.append({"label": "A lens", "ok": s != null and (s.wide or s.close), "fix": "a lens"})
	out.append({"label": "Communications", "ok": s != null and s.has_room("communications"), "fix": "a Communications room"})
	if bool(needs.get("lab", false)):
		out.append({"label": "Science Lab", "ok": s != null and s.has_room("science-lab"), "fix": "a Science Lab"})
	return out


## What later contracts will ask of the ship, as plain lines. The ship is locked after the first contract, so the
## Build screen tells the player now. Each is {text, ok} where ok says whether this ship already has it.
static func later_needs(id: int, s: BuildState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in LIST:
		if int(m["id"]) <= id or not bool(m.get("available", false)):
			continue
		var needs: Dictionary = m.get("needs", {})
		if bool(needs.get("lab", false)):
			out.append({"text": "Contract %02d needs a Science Lab" % (int(m["id"]) + 1), "ok": s != null and s.has_room("science-lab")})
		if String(needs.get("lens", "any")) == "both":
			out.append({"text": "Contract %02d needs both lenses" % (int(m["id"]) + 1), "ok": s != null and s.wide and s.close})
	return out


## Is this ship ready for contract id, and exactly what is missing or over a limit? Built from the same checks the Build
## screen shows (BuildState.checks) plus what the contract itself asks for. Each issue is {text, key, fix}; key goes to the
## Build screen's inspect action. A not-ready ship may still fly where the campaign rules allow it.
static func readiness(id: int, s: BuildState) -> Dictionary:
	var issues: Array[Dictionary] = []
	for c in s.checks():
		if not c["ok"]:
			issues.append({"text": "%s: %s" % [String(c["label"]), String(c["why"])], "key": String(c["key"]), "fix": String(c["fix"])})
	var needs: Dictionary = get_mission(id).get("needs", {})
	if bool(needs.get("lab", false)) and not s.has_room("science-lab"):
		issues.append({"text": "Science Lab: missing", "key": "room:science-lab", "fix": "Add Science Lab"})
	if String(needs.get("lens", "any")) == "both" and not (s.wide and s.close):
		issues.append({"text": "Both lenses: missing", "key": "lens", "fix": "Pack both lenses"})
	return {"ready": issues.is_empty(), "issues": issues, "name": String(get_mission(id)["name"])}


## The contract with this id (the list index). Out-of-range ids give the first contract.
static func get_mission(id: int) -> Dictionary:
	return LIST[clampi(id, 0, LIST.size() - 1)]
