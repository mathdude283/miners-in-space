class_name GroundControl
## What the ground team says and does on launch day. The player plays the Launch Director in the
## Launch Control Center, then the flight team after liftoff.
##
## Sources (NASA pages read for this game; Artemis I and II are the examples):
##  - Launch Director runs the poll and the count; NASA Test Director (NTD) reports the team's status;
##    the Launch Positioning Engineer brings the team's go/no-go; integration console engineers each cover
##    one discipline; the Ground Launch Sequencer (GLS) runs the terminal count.
##    nasa.gov/missions/artemis/orion/artemis-i-mission-teams-the-crew-behind-the-uncrewed-mission/
##    nasa.gov/centers-and-facilities/kennedy/problem-solvers-prepare-for-artemis-launches/
##  - Terminal count milestones:
##    nasa.gov/blogs/artemis/2022/11/16/launch-managers-give-go-to-proceed-with-terminal-count-launch-set-for-147-a-m/
##  - Hold rules and the Artemis II launch day (flight termination system communication issue):
##    nasa.gov/blogs/missions/2026/04/01/live-artemis-ii-launch-day-updates/
##  - Weather limits: nasa.gov/artemis-ii-weather-criteria/
## The six "stations" below are the game's disciplines, adapted so each one can speak for one part of
## the player's ship. Real console names beyond the roles above are not on the NASA pages we read.

const WEATHER_LIMITS := [
	"Lightning: wait 30 minutes after lightning within 10 nautical miles of the flight path",
	"Winds: peak winds at liftoff limited to 29 to 39 knots, depending on height",
	"Temperature: no launch if both sensors read above 94.5 F for 30 minutes",
]

## Terminal count, counted down in seconds before liftoff. "dur" is how many real seconds the game
## spends getting to this call from the previous one. "prompt" calls wait for the Launch Director.
const COUNT: Array[Dictionary] = [
	{"t": -600.0, "dur": 0.0, "text": "Ground Launch Sequencer starts the terminal count.", "label": "T-10:00"},
	{"t": -360.0, "dur": 3.0, "text": "Core stage tanks pressurize. Orion pyros are armed.", "label": "T-6:00"},
	{"t": -300.0, "dur": 1.4, "text": "GLS is go for flight termination system arm.", "label": "T-5:00", "prompt": "Flight termination system arm. Your call?"},
	{"t": -240.0, "dur": 1.2, "text": "Core stage auxiliary power unit starts.", "label": "T-4:00"},
	{"t": -190.0, "dur": 1.2, "text": "Go for purge sequence 4.", "label": "T-3:10", "prompt": "Purge sequence 4. Your call?"},
	{"t": -90.0, "dur": 2.0, "text": "Core stage goes to internal power.", "label": "T-1:30"},
	{"t": -33.0, "dur": 1.8, "text": "Go for the automated launch sequencer.", "label": "T-0:33", "prompt": "Hand the count to the automated sequencer? After this the count cannot be held.", "last_hold": true},
	{"t": -30.0, "dur": 0.4, "text": "Core stage flight computer takes over.", "label": "T-0:30"},
	{"t": -12.0, "dur": 1.6, "text": "Hydrogen burn-off igniters.", "label": "T-0:12"},
	{"t": -10.0, "dur": 0.8, "text": "Engine start command.", "label": "T-0:10"},
	{"t": -6.36, "dur": 1.6, "text": "The four main engines start.", "label": "T-0:06"},
	{"t": 0.0, "dur": 2.0, "text": "Booster ignition. Liftoff.", "label": "T-0:00"},
]

## Ascent milestones, from the Artemis II press kit (mission elapsed time; NASA says real times may
## vary by several seconds, so the game says "about"). nasa.gov/artemis-ii-press-kit/
## "poll" marks the three where the game's flight team stops to make a call.
const ASCENT: Array[Dictionary] = [
	{"met": 9.0, "label": "+0:09", "name": "TOWER CLEAR", "text": "The rocket clears the launch tower.", "poll": false},
	{"met": 56.0, "label": "+0:56", "name": "SUPERSONIC", "text": "The rocket reaches supersonic speed.", "poll": false},
	{"met": 70.0, "label": "+1:10", "name": "MAX Q", "text": "Maximum dynamic pressure: the heaviest air load on the rocket.", "poll": true},
	{"met": 128.0, "label": "+2:08", "name": "BOOSTER SEPARATION", "text": "The solid rocket boosters separate.", "poll": true},
	{"met": 198.0, "label": "+3:18", "name": "LAUNCH ABORT SYSTEM JETTISON", "text": "The launch abort system is jettisoned.", "poll": true},
	{"met": 486.0, "label": "+8:06", "name": "CORE STAGE ENGINE CUTOFF", "text": "The core stage main engines shut down.", "poll": false},
	{"met": 498.0, "label": "+8:18", "name": "CORE STAGE SEPARATION", "text": "The core stage separates from the upper stage.", "poll": false},
]

## One real second of the game is this many seconds on the count clock during a hold.
const HOLD_TIME_SCALE := 20.0
## Between T-6:00 and T-1:30 a hold is limited to 3 minutes, or the count recycles to T-10:00.
const HOLD_LIMIT_SECONDS := 180.0
## The count clock is negative before liftoff, so "before T-6:00" means a number below -360. These are the lines the
## hold rules are drawn on. Everything on screen about holds (the guidance, the hold limit, the recycle, and the
## sequencer lockout) comes from hold_zone() so they cannot disagree.
const HOLD_FREE_THROUGH := -360.0      # at and before T-6:00: a hold can last as long as the launch window
const HOLD_LIMITED_UNTIL := -90.0      # after T-6:00 up to T-1:30: limited to HOLD_LIMIT_SECONDS, or the count recycles


## The count time at which the automated sequencer takes the count (the milestone marked last_hold).
static func sequencer_t() -> float:
	for m in COUNT:
		if m.get("last_hold", false):
			return float(m["t"])
	return -33.0


## Which hold rule applies at count time t: "free", "limited", "late" or "locked".
##  free     at or before T-6:00: as long as the launch window.
##  limited  after T-6:00 up to T-1:30: 3 minutes, or the count recycles to T-10:00.
##  late     from T-1:30 until the sequencer takes the count: still holdable.
##  locked   the sequencer has the count: no hold at all.
static func hold_zone(t: float, locked: bool) -> String:
	if locked:
		return "locked"
	if t <= HOLD_FREE_THROUGH:
		return "free"
	if t < HOLD_LIMITED_UNTIL:
		return "limited"
	return "late"


## The plain-English guidance for a zone, built from the same numbers.
static func hold_guidance(zone: String) -> String:
	match zone:
		"locked":
			return "The automated sequencer has the count. Any stop now ends the attempt for the day."
		"free":
			return "A hold at or before T-6:00 can last as long as the launch window."
		"limited":
			return "A hold now is limited to %d minutes, or the count recycles to T-10:00." % int(HOLD_LIMIT_SECONDS / 60.0)
		_:
			var s := sequencer_t()
			return "A hold is still possible, but the sequencer takes the count at T-%d:%02d." % [int(-s) / 60, int(-s) % 60]


## The room, as the Launch Director hears it. `range_issue` replays a real Artemis II event: the
## Eastern Range found a flight termination system communication issue and called no-go until a
## confidence test passed. The range cannot be overridden.
static func stations(s: BuildState, range_issue: bool) -> Array[Dictionary]:
	var t := s.totals()
	var R := ShipData.RULES
	var have: Dictionary = t["have"]
	var out: Array[Dictionary] = []

	out.append({"id": "weather", "name": "WEATHER", "who": "Launch weather team", "go": true, "block": false,
		"call": "Favorable. No launch criteria are violated."})

	if range_issue:
		out.append({"id": "range", "name": "RANGE", "who": "Eastern Range", "go": false, "block": true,
			"call": "Flight termination system comms issue. No assurance it works means no-go."})
	else:
		out.append({"id": "range", "name": "RANGE", "who": "Eastern Range", "go": true, "block": false,
			"call": "Range is green. Flight termination system verified."})

	if int(t["mass"]) > int(R["mass_limit"]):
		out.append({"id": "lift", "name": "PROPULSION", "who": "Integration console", "go": false, "block": false,
			"call": "Weight is %d against a limit of %d. The engines cannot lift this." % [t["mass"], R["mass_limit"]]})
	else:
		out.append({"id": "lift", "name": "PROPULSION", "who": "Integration console", "go": true, "block": false,
			"call": "Weight %d of %d. Lift is good." % [t["mass"], R["mass_limit"]]})

	if not have.has("control"):
		out.append({"id": "guidance", "name": "GUIDANCE", "who": "Integration console", "go": false, "block": false,
			"call": "No flight deck. Nobody can steer this ship."})
	else:
		out.append({"id": "guidance", "name": "GUIDANCE", "who": "Integration console", "go": true, "block": false,
			"call": "Flight controls are ready."})

	if int(t["margin"]) < 0:
		out.append({"id": "power", "name": "POWER", "who": "Integration console", "go": false, "block": false,
			"call": "Power is short: %d used and %d made." % [t["draw"], t["gen"]]})
	else:
		out.append({"id": "power", "name": "POWER", "who": "Integration console", "go": true, "block": false,
			"call": "Power %d used of %d made. Good." % [t["draw"], t["gen"]]})

	var crew_missing := ""
	var crew_names := {"air": "air and water", "food": "food", "waste": "waste handling", "sleep": "sleep", "medical": "medical care", "stowage": "secured stowage"}
	for f in ["air", "food", "waste", "sleep", "medical", "stowage"]:
		if not have.has(f):
			crew_missing = crew_names[f]
			break
	if crew_missing != "":
		out.append({"id": "crew", "name": "CREW SYSTEMS", "who": "Integration console", "go": false, "block": false,
			"call": "The crew has no %s." % crew_missing})
	else:
		out.append({"id": "crew", "name": "CREW SYSTEMS", "who": "Integration console", "go": true, "block": false,
			"call": "Crew needs are covered."})

	if not have.has("comms"):
		out.append({"id": "comms", "name": "COMMS", "who": "Integration console", "go": false, "block": false,
			"call": "No radio. We cannot send data home."})
	else:
		out.append({"id": "comms", "name": "COMMS", "who": "Integration console", "go": true, "block": false,
			"call": "Radio is ready."})

	if not have.has("camera"):
		out.append({"id": "payload", "name": "PAYLOAD", "who": "Integration console", "go": false, "block": false,
			"call": "No window. The camera has nothing to see through."})
	elif not (s.wide or s.close):
		out.append({"id": "payload", "name": "PAYLOAD", "who": "Integration console", "go": false, "block": false,
			"call": "No lens. The camera cannot frame a shot."})
	else:
		out.append({"id": "payload", "name": "PAYLOAD", "who": "Integration console", "go": true, "block": false,
			"call": "Camera and lens are ready."})
	return out


static func ship_no_gos(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in rows:
		if not r["go"] and not r["block"]:
			out.append(r)
	return out


static func blockers(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in rows:
		if r["block"]:
			out.append(r)
	return out


## What the NTD says to the Launch Director once the room has answered.
static func ntd_line(rows: Array[Dictionary]) -> String:
	var n := 0
	for r in rows:
		if not r["go"]:
			n += 1
	if n == 0:
		return "Launch Director, NTD. Our launch team is ready to proceed. We are working no constraints."
	return "Launch Director, NTD. We are working %d %s." % [n, "constraint" if n == 1 else "constraints"]


## The flight team's stations on the way up. These are the Artemis I mission control positions (Booster,
## FDO trajectory, EECOM life support, MPO power, INCO data). NASA does not say the Flight Director polls
## the room at these points, so the polling itself is game design.
## nasa.gov/missions/artemis/orion/artemis-i-mission-control-at-a-glance/
static func ascent_stations(s: BuildState, poll_index: int) -> Array[Dictionary]:
	var t := s.totals()
	var have: Dictionary = t["have"]
	var out: Array[Dictionary] = []
	out.append({"id": "booster", "name": "BOOSTER", "who": "Boosters and core stage", "go": true, "block": false,
		"call": "Boosters and core stage are performing."})
	if not have.has("control"):
		out.append({"id": "fdo", "name": "FDO", "who": "Flight dynamics", "go": false, "block": false,
			"call": "Trajectory is leaving the plan. Nothing is steering."})
	else:
		out.append({"id": "fdo", "name": "FDO", "who": "Flight dynamics", "go": true, "block": false,
			"call": "Trajectory is on the plan."})
	if int(t["margin"]) < 0:
		out.append({"id": "mpo", "name": "MPO", "who": "Power and structure", "go": false, "block": false,
			"call": "Power is falling: %d used, %d made." % [t["draw"], t["gen"]]})
	else:
		out.append({"id": "mpo", "name": "MPO", "who": "Power and structure", "go": true, "block": false,
			"call": "Power is good."})
	var air_bad := not have.has("air")
	if air_bad and poll_index >= 2:
		out.append({"id": "eecom", "name": "EECOM", "who": "Cabin air and cooling", "go": false, "block": false,
			"call": "The cabin air system is not holding."})
	else:
		out.append({"id": "eecom", "name": "EECOM", "who": "Cabin air and cooling", "go": true, "block": false,
			"call": "Cabin air is good."})
	if not have.has("comms") and poll_index >= 1:
		out.append({"id": "inco", "name": "INCO", "who": "Data and telemetry", "go": false, "block": false,
			"call": "The data link to the ship is weak."})
	else:
		out.append({"id": "inco", "name": "INCO", "who": "Data and telemetry", "go": true, "block": false,
			"call": "Data link is good."})
	return out
