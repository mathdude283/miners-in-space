class_name ImpactScenario
extends RefCounted
## Contract 03, Impact Watch: "Nobody Saw the Same Moon". The fixed, deterministic scenario (a FICTIONAL simulation).
##
## Three candidate events in one short far-side observation window (game time, about 90 seconds):
##   A  a simulated impact seen independently from two viewpoints (different screen positions, the same lunar place and time)
##   B  a simulated impact with one weak observation, plus a retelling by a second crew member (one witness, counted once)
##   C  a bright spot that is a reflection in the spacecraft window; the tight crop is persuasive, the wide frame shows it
##      moving with the window edge
## Everything here is invented game data: the flashes, the viewpoints, the lunar positions, the packet costs and the compressed
## time. No NASA measurement is used. (Real geometry from SPICE is a later, separate improvement.)
##
## A "product" is something the crew can send. Each has a cost in packets, an opaque-able identity, what it preserves, and
## (aboard only) which candidate it belongs to. The TRUTH lives only here and in the onboard run record, never in the file
## that goes to Mission Control.

const WINDOW_SECONDS := 90.0
const BASE_BUDGET := 12            # packets that can be delivered (GAME rule); a solar wing adds more
const WING_BUDGET := 4             # extra packets per solar wing (the wing widens the usable downlink)

## Viewpoints (observers). Each covers a box of the lunar far side; silence outside the box means nothing.
const VIEWPOINTS := {
	"V1": {"seat": "COMMANDER", "label": "Window 1 (Observation Bay)", "coverage": {"lat": [-10.0, 30.0], "lon": [128.0, 178.0]}},
	"V2": {"seat": "PILOT", "label": "Flight Deck window", "coverage": {"lat": [-5.0, 25.0], "lon": [138.0, 170.0]}},
	"V3": {"seat": "SCIENTIST", "label": "Science camera", "coverage": {"lat": [-50.0, -20.0], "lon": [-178.0, -150.0]}},
}

## The candidate events (TRUTH, aboard only).
const TRUTH := {
	"A": {"real": true, "what": "a real simulated impact flash, seen from Window 1 and from the Flight Deck window"},
	"B": {"real": true, "what": "a real simulated impact, only faintly seen by the Science camera"},
	"C": {"real": false, "what": "a reflection of a cabin light in Window 1, not an impact"},
}

## Everything that could be sent. id, candidate (truth), observer viewpoint, source_group (the witness or instrument chain:
## crops, logs and retellings of one observation share a group), type, cost, time range, lunar position and the observer's
## own screen position, finding (controlled vocabulary the reviewer can read), confidence 0..1 (the observer's own), text,
## and derived_from for crops and retellings.
const PRODUCTS: Array[Dictionary] = [
	{"id": "A1", "cand": "A", "viewpoint": "V1", "group": "GRP_W1", "type": "crew_log", "cost": 1, "t": [21.0, 23.0], "lat": 12.0, "lon": 148.0, "err": 6.0,
		"screen": [412, 236], "finding": "flash", "conf": 0.8, "from": "", "relation": "firsthand",
		"text": "Window 1 log: bright flash on the Moon about 0:22, upper right of the window."},
	{"id": "A2", "cand": "A", "viewpoint": "V1", "group": "GRP_W1", "type": "tight_crop", "cost": 3, "t": [21.5, 22.5], "lat": 12.0, "lon": 148.0, "err": 4.0,
		"screen": [412, 236], "finding": "flash", "conf": 0.9, "from": "A1", "relation": "crop_of_frame",
		"text": "Tight crop of the Window 1 frame: a sharp bright point on the dark surface."},
	{"id": "A3", "cand": "A", "viewpoint": "V1", "group": "GRP_W1", "type": "wide_context", "cost": 4, "t": [21.5, 22.5], "lat": 12.0, "lon": 148.0, "err": 8.0,
		"screen": [412, 236], "finding": "flash_on_surface", "conf": 0.9, "from": "A1", "relation": "wide_of_frame",
		"text": "Wide Window 1 frame: the flash sits well inside the Moon's disk; the window edge is clear of it."},
	{"id": "A4", "cand": "A", "viewpoint": "V2", "group": "GRP_W2", "type": "crew_log", "cost": 1, "t": [21.0, 24.0], "lat": 10.0, "lon": 152.0, "err": 8.0,
		"screen": [130, 301], "finding": "flash", "conf": 0.7, "from": "", "relation": "firsthand",
		"text": "Flight Deck window log: a flash on the Moon around 0:22, low left of my window."},
	{"id": "A5", "cand": "A", "viewpoint": "V2", "group": "GRP_W2", "type": "tight_crop", "cost": 3, "t": [21.5, 23.5], "lat": 10.0, "lon": 152.0, "err": 6.0,
		"screen": [130, 301], "finding": "flash", "conf": 0.8, "from": "A4", "relation": "crop_of_frame",
		"text": "Tight crop of the Flight Deck frame: a bright point at the same moment."},
	{"id": "B1", "cand": "B", "viewpoint": "V3", "group": "GRP_CAM", "type": "crew_log", "cost": 1, "t": [48.0, 54.0], "lat": -34.0, "lon": -171.0, "err": 10.0,
		"screen": [260, 410], "finding": "faint_flicker", "conf": 0.3, "from": "", "relation": "firsthand",
		"text": "Science camera log: maybe a faint flicker near 0:51. I am not sure."},
	{"id": "B2", "cand": "B", "viewpoint": "V3", "group": "GRP_CAM", "type": "tight_crop", "cost": 3, "t": [49.0, 53.0], "lat": -34.0, "lon": -171.0, "err": 9.0,
		"screen": [260, 410], "finding": "faint_flicker", "conf": 0.3, "from": "B1", "relation": "crop_of_frame",
		"text": "Tight crop of the Science camera frame: a faint smudge that may be noise."},
	{"id": "B3", "cand": "B", "viewpoint": "V2", "group": "GRP_CAM", "type": "crew_log", "cost": 1, "t": [48.0, 56.0], "lat": -34.0, "lon": -171.0, "err": 12.0,
		"screen": [0, 0], "finding": "faint_flicker", "conf": 0.3, "from": "B1", "relation": "retelling",
		"text": "Flight Deck log: the Scientist mentioned a flicker around 0:51. I did not see it myself."},
	{"id": "N1", "cand": "A", "viewpoint": "V3", "group": "GRP_CAM", "type": "crew_log", "cost": 1, "t": [18.0, 26.0], "lat": 0.0, "lon": 0.0, "err": 0.0,
		"screen": [0, 0], "finding": "no_event_seen", "conf": 0.8, "from": "", "relation": "firsthand",
		"text": "Science camera log: nothing seen between 0:18 and 0:26."},
	{"id": "C1", "cand": "C", "viewpoint": "V1", "group": "GRP_W1", "type": "crew_log", "cost": 1, "t": [69.0, 72.0], "lat": 5.0, "lon": 160.0, "err": 6.0,
		"screen": [300, 180], "finding": "flash", "conf": 0.7, "from": "", "relation": "firsthand",
		"text": "Window 1 log: a bright spot about 1:10, left of centre."},
	{"id": "C2", "cand": "C", "viewpoint": "V1", "group": "GRP_W1", "type": "tight_crop", "cost": 3, "t": [69.5, 71.5], "lat": 5.0, "lon": 160.0, "err": 4.0,
		"screen": [300, 180], "finding": "flash", "conf": 0.8, "from": "C1", "relation": "crop_of_frame",
		"text": "Tight crop of the Window 1 frame: a sharp bright point. It looks like a flash."},
	{"id": "C3", "cand": "C", "viewpoint": "V1", "group": "GRP_W1", "type": "wide_context", "cost": 4, "t": [69.5, 71.5], "lat": 5.0, "lon": 160.0, "err": 8.0,
		"screen": [300, 180], "finding": "reflection_moves_with_window", "conf": 0.9, "from": "C1", "relation": "wide_of_frame",
		"text": "Wide Window 1 frame: the spot sits on the window frame and moves with the window edge, not with the Moon."},
]


static func products() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in PRODUCTS:
		out.append((p as Dictionary).duplicate(true))
	return out


static func product(id: String) -> Dictionary:
	for p in PRODUCTS:
		if p["id"] == id:
			return (p as Dictionary).duplicate(true)
	return {}


static func total_cost() -> int:
	var t := 0
	for p in PRODUCTS:
		t += int(p["cost"])
	return t


## The packets this ship can deliver: a base amount plus more for each solar wing (a GAME rule). It is always less than
## total_cost(), so the player cannot send everything.
static func budget(wings: int) -> int:
	return BASE_BUDGET + WING_BUDGET * clampi(wings, 0, 2)


## What the cheapest justified path costs: A needs two independent logs (2), B one log (1), C a log and the wide frame (5).
static func cheapest_justified_cost() -> int:
	return 2 + 1 + 5
