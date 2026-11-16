class_name ShipData
## Parts, rules and requirements for the ship builder.
##
## HONESTY NOTE: every mass, power and budget number here is a "game unit" picked for play balance.
## They are NOT NASA figures. Room names and what each one is for come from the team's Drive notes
## (03 Design references / room-reference.md). Edit the numbers here to rebalance the game.
##
## The opportunity cost is the point of the screen. A ship has 6 bays, a mass limit, a power budget
## (power made has to cover power used) and a money budget. A part that helps one need uses up
## room that another need could have used.

const RULES := {
	"bays": 6,
	"mass_limit": 20,
	"budget_limit": 50,
	"base_power": 6,
	"wing_power": 3,
	"wing_mass": 1,
	"wing_cost": 3,
	"wings_max": 2,
	"lens_mass": 1,
	"lens_cost": 2,
}

## The compact crew kit covers five needs without using a bay.
const KIT := {
	"name": "Compact crew kit",
	"mass": 2, "power": 1, "cost": 6,
	"provides": ["food", "waste", "sleep", "medical", "stowage"],
	"blurb": "Food warmer, sleeping bags, hygiene kit, medical kit and lockers in one pack. Covers five crew needs without using a bay.",
}

## What a crewed flight needs (room-reference.md: "What a crewed spacecraft needs").
## "kit" means the compact crew kit can cover it.
const FUNCTIONS := {
	"control": {"label": "Flight control", "room": "flight-deck", "kit": false},
	"air": {"label": "Air and water", "room": "life-support", "kit": false},
	"food": {"label": "Food", "room": "galley", "kit": true},
	"waste": {"label": "Waste and hygiene", "room": "hygiene", "kit": true},
	"sleep": {"label": "Sleep", "room": "crew-quarters", "kit": true},
	"medical": {"label": "Basic medical care", "room": "medical", "kit": true},
	"comms": {"label": "Communications", "room": "communications", "kit": false},
	"stowage": {"label": "Secured stowage", "room": "cargo", "kit": true},
}
const FUNCTION_ORDER := ["control", "air", "food", "waste", "sleep", "medical", "comms", "stowage"]

## "blurb" is the "Player use" column of the team's room table.
const ROOMS: Array[Dictionary] = [
	{"id": "flight-deck", "short": "FLIGHT DECK", "name": "Flight Deck", "mass": 3, "power": 2, "cost": 8, "provides": ["control"], "blurb": "Steer, monitor the route, and launch."},
	{"id": "life-support", "short": "LIFE SUPPORT", "name": "Life Support", "mass": 3, "power": 2, "cost": 7, "provides": ["air"], "blurb": "Keep cabin air and water available."},
	{"id": "communications", "short": "COMMS", "name": "Communications", "mass": 2, "power": 2, "cost": 5, "provides": ["comms"], "blurb": "Log sightings and send a report."},
	{"id": "observation", "short": "OBSERVATION", "name": "Observation Bay", "mass": 2, "power": 2, "cost": 6, "provides": ["camera"], "blurb": "Frame the target and capture a shot."},
	{"id": "galley", "short": "GALLEY", "name": "Galley", "mass": 2, "power": 1, "cost": 4, "provides": ["food"], "blurb": "Prepare and secure crew meals."},
	{"id": "crew-quarters", "short": "CREW QUARTERS", "name": "Crew Quarters", "mass": 3, "power": 1, "cost": 5, "provides": ["sleep"], "blurb": "Schedule crew rest and quiet time."},
	{"id": "hygiene", "short": "HYGIENE", "name": "Hygiene Bay", "mass": 2, "power": 1, "cost": 4, "provides": ["waste"], "blurb": "Handle waste and personal hygiene."},
	{"id": "medical", "short": "MEDICAL", "name": "Medical Bay", "mass": 2, "power": 1, "cost": 5, "provides": ["medical"], "blurb": "Treat hurt or sick crew in flight."},
	{"id": "cargo", "short": "CARGO", "name": "Cargo Bay", "mass": 2, "power": 0, "cost": 3, "provides": ["stowage"], "blurb": "Secure supplies before maneuvers."},
	{"id": "science-lab", "short": "SCIENCE LAB", "name": "Science Lab", "mass": 3, "power": 2, "cost": 5, "provides": [], "blurb": "Compare evidence and prepare findings."},
	{"id": "exercise", "short": "EXERCISE", "name": "Exercise Bay", "mass": 2, "power": 1, "cost": 4, "provides": [], "blurb": "Fit a workout into the crew schedule."},
	{"id": "airlock", "short": "AIRLOCK", "name": "Airlock", "mass": 3, "power": 1, "cost": 6, "provides": [], "blurb": "Stage an optional spacewalk."},
]

## Starting points taken from the team's three builder recipes. They are not perfect on purpose:
## the player adjusts them and sees what changes. The third recipe (research habitat) needs more
## bays than this ship has, so it is not offered.
const STARTERS: Array[Dictionary] = [
	{
		"name": "Compact flyby",
		"note": "Light and cheap. Check what it is missing.",
		"bays": ["flight-deck", "life-support", "observation", "", "", ""],
		"kit": true, "wings": 1, "wide": true, "close": false,
	},
	{
		"name": "Lunar evidence ship",
		"note": "Covers every need. Does it make enough power?",
		"bays": ["flight-deck", "life-support", "cargo", "observation", "communications", ""],
		"kit": true, "wings": 0, "wide": true, "close": false,
	},
]

## What each part is, for the inspector. Short on purpose.
##  why   - why a player would want it (ties to the crew needs and the contract)
##  flight - what it changes in the Moon games (a GAME rule, shown on the Build screen)
##  do    - what the player does in it
##  nasa  - a NASA fact, only where the NASA pages we checked say it (Orion pages describe Artemis II)
##  game  - used instead of "nasa" when it is a game idea or NASA does not say
##  source - which NASA page the fact comes from
## The facts were checked against the NASA pages in the team's notes. Where a page did not support the
## team's original wording (cargo "restrained, clear paths"; life support "reachable for servicing";
## "lab racks") the line was rewritten or left as a game note.
const INFO := {
	"flight-deck": {
		"real": "REAL: flight computers. Basic 5 kg, 10 W, $5M. Radiation-hardened 8 kg, 15 W, $12M. Autonomous 12 kg, 20 W, $22M (copes with delayed commands). NASA SmallSat Institute, avionics.",
		"why": "Someone has to fly it. Without flight controls the ship cannot be steered.",
		"do": "Steer, monitor the route, and launch.",
		"flight": "Steadier camera in the Moon photo: 20% less shake.",
		"nasa": "Orion's seats face the displays and controls at arm's length, and a harness holds each crew member in place.",
		"source": "NASA Orion crew systems",
	},
	"life-support": {
		"why": "The crew needs air and water the whole flight. Without them the crew must abort.",
		"do": "Keep cabin air and water available.",
		"nasa": "NASA's life support systems supply the water, air and oxygen a crew uses.",
		"source": "NASA life support systems (ECLSS)",
	},
	"communications": {
		"real": "REAL: antennas. Small 100 kg, 0.2 kW, $20M. Medium dish 300 kg, 0.8 kW, $65M. Large dish 900 kg, 3 kW, $250M (needs accurate pointing). NASA SmallSat Institute, communications.",
		"why": "A photo nobody receives is worth nothing. Radio is how the evidence gets home.",
		"do": "Log sightings and send a report.",
		"game": "A dedicated radio room is a game choice, so there is no NASA claim here.",
	},
	"observation": {
		"real": "REAL: visible camera 9 kg, 15 W, 25 MB per image, $6M. Precision pointing 25 kg, 30 W, about 0.05 degrees. NASA SmallSat Institute, guidance and control.",
		"why": "Your contract is a photograph. You need a window to see the Moon.",
		"do": "Frame the target and capture a shot.",
		"nasa": "The space station has an observation deck known as the Cupola. This room is a game version of that idea.",
		"source": "NASA astronaut-led ISS tour",
	},
	"galley": {
		"why": "Crews need food. A galley covers it, and the crew kit does too without using a bay.",
		"do": "Prepare and secure crew meals.",
		"nasa": "Orion has a food warmer and a water dispenser rather than a full galley.",
		"source": "NASA: living inside Orion",
	},
	"crew-quarters": {
		"why": "A crew has to sleep. Long flights justify dedicated quarters.",
		"do": "Schedule crew rest and quiet time.",
		"nasa": "On Orion, crew attach sleeping bags to the walls. The station has crew sleeping quarters. Sleep pods are a game idea.",
		"source": "NASA: living inside Orion; ISS tour",
	},
	"hygiene": {
		"why": "Waste handling is a basic crew need, and privacy matters on a long flight.",
		"do": "Handle waste and personal hygiene.",
		"nasa": "Orion has a compact toilet behind privacy doors, and room for personal hygiene kits.",
		"source": "NASA: living inside Orion",
	},
	"exercise": {
		"why": "Not needed for this contract. Long flights make exercise worth the weight.",
		"do": "Fit a workout into the crew schedule.",
		"nasa": "Orion carries a cable-based flywheel exerciser. The cycle and treadmill shown here are game stylizations.",
		"source": "NASA: living inside Orion",
	},
	"medical": {
		"why": "A kit covers first aid. A bay lets you treat hurt or sick crew in flight.",
		"do": "Walk a hurt or sick crew member here in flight and press E to treat them.",
		"nasa": "Orion carries a medical kit with first-aid items and diagnostic tools. The patient platform is a game option.",
		"source": "NASA: living inside Orion",
	},
	"cargo": {
		"why": "Supplies must be secured before maneuvers, or they break loose.",
		"do": "Secure supplies before maneuvers.",
		"game": "A game room for securing supplies. We could not confirm a NASA detail for it, so none is claimed.",
	},
	"science-lab": {
		"real": "REAL: spectrometer 15 kg, 25 W, 5 MB per observation, $14M. Thermal infrared imager 20 kg, 35 W, $14M. Team spacecraft sheet.",
		"why": "Contracts that compare evidence need it. The Orientale contract does not.",
		"do": "Compare evidence and prepare findings.",
		"flight": "A third try with each lens in the Moon photo.",
		"nasa": "The space station has dedicated laboratory modules. The larger lab here is a game option.",
		"source": "NASA astronaut-led ISS tour",
	},
	"airlock": {
		"why": "Only for spacewalks. This contract has none, so here it is dead weight.",
		"do": "Stage an optional spacewalk.",
		"nasa": "The station's spacewalk airlock is called Quest.",
		"source": "NASA astronaut-led ISS tour",
	},
	# equipment
	"kit": {
		"why": "Covers five crew needs without using a bay.",
		"do": "Nothing to do. It works quietly in the background.",
		"nasa": "Orion fits four crew in one capsule. A food warmer, water dispenser, sleeping bags, toilet and medical kit share that space.",
		"source": "NASA: living inside Orion",
	},
	"wing": {
		"real": "REAL: solar arrays. Small 300 W at 1 AU, 400 kg, $60M. Large 1,000 W, 3,500 kg, $650M. Output falls with distance from the Sun. NASA SmallSat Institute, power.",
		"why": "More power for the ship, for a little weight.",
		"do": "Nothing to do. It works on its own.",
		"flight": "More wings widen the radio beam, so the signal locks on more easily.",
		"nasa": "Orion's service module sits below the crew cabin and has four solar-array wings.",
		"source": "NASA Orion European Service Module",
	},
	"wide": {
		"real": "REAL: visible camera 9 kg, 15 W, 25 MB per image, $6M. Team spacecraft sheet.",
		"why": "A lens frames the shot. Either lens is enough to take the photo.",
		"do": "Frames the wide shot.",
		"game": "Game equipment.",
	},
	"close": {
		"real": "REAL: visible camera 9 kg, 15 W, 25 MB per image, $6M. Team spacecraft sheet.",
		"why": "A lens frames the shot. Either lens is enough to take the photo.",
		"do": "Frames the close-up tile.",
		"game": "Game equipment.",
	},
}


## What the ship's parts change in the Moon games (GAME rules, labeled as such on screen).
## shake multiplies camera shake, tries is how many shots each lens gets, beam is how wide the radio lock is.
## crew: the named crew, so a fit pilot's steady hands count too.
static func flight_perks(s: BuildState, crew: Array = []) -> Dictionary:
	var shake := 1.0
	var tries := 2
	var rows: Array[Dictionary] = []
	var deck := s.has_room("flight-deck")
	if deck:
		shake *= 0.8
	rows.append({"game": "photo", "label": "FLIGHT DECK", "on": deck, "text": "steadier camera", "off": "add a Flight Deck for a steadier camera"})
	var lab := s.has_room("science-lab")
	if lab:
		tries = 3
	rows.append({"game": "photo", "label": "SCIENCE LAB", "on": lab, "text": "a third try with each lens", "off": "add a Science Lab for a third try"})
	var pilot := false
	for c in crew:
		if String(c.get("role", "")) == "PILOT" and float(c.get("health", 0.0)) > 0.0:
			pilot = true
	if pilot:
		shake *= 0.9
	rows.append({"game": "photo", "label": "PILOT", "on": pilot, "text": "steady hands", "off": ""})
	var beam := 0.26 + 0.04 * s.wings
	rows.append({"game": "radio", "label": "SOLAR WINGS", "on": s.wings > 0, "text": "a wider radio beam", "off": "add solar wings for a wider radio beam"})
	return {"shake": shake, "tries": tries, "beam": beam, "rows": rows}


## One short line for a game's intro: what the ship gives you, or what would help.
static func perk_summary(perks: Dictionary, game: String) -> String:
	var on: Array[String] = []
	var off: Array[String] = []
	for r in perks.get("rows", []):
		if r["game"] != game:
			continue
		if r["on"]:
			on.append("%s: %s." % [String(r["label"]).capitalize(), r["text"]])
		elif String(r["off"]) != "":
			off.append(r["off"])
	var s := " ".join(on)
	if not off.is_empty():
		s += ("  " if s != "" else "") + "In Build you can " + ", or ".join(off) + "."
	return s if s != "" else "No ship bonuses for this game."


static func info(key: String) -> Dictionary:
	return INFO.get(key, {})


static func room(id: String) -> Dictionary:
	for r in ROOMS:
		if r["id"] == id:
			return r
	return {}


static func room_texture(id: String) -> Texture2D:
	return load("res://assets/ui/build/rooms/%s.webp" % id) as Texture2D


static func function_label(fn: String) -> String:
	return FUNCTIONS[fn]["label"] if FUNCTIONS.has(fn) else fn
