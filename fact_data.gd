class_name FactData
extends RefCounted
## "Did you know?" facts shown while you play. Each is a short, true statement with where it comes from. REAL facts come from NASA, USGS
## or well-known spaceflight physics; sources named here must be confirmed against the pages before submission (see SOURCES.md).
## Facts are grouped by what the player is doing, so they are about the thing on screen.

const FACTS := {
	"power": [
		["Sunlight gets weaker with the square of the distance from the Sun. At Neptune, about 30 times farther than Earth, it is about 900 times fainter.", "REAL: inverse-square law; NASA Neptune facts"],
		["New Horizons, which flew past Pluto, ran on a radioisotope power source (RTG) that turns the heat of decaying plutonium-238 into electricity.", "REAL: NASA New Horizons mission"],
		["The Voyager probes, launched in 1977, still send data because their RTGs keep making power with no sunlight.", "REAL: NASA Voyager mission"],
		["Solar panels lose a little power over time as radiation damages them, which is why mission planners add margin.", "REAL: NASA SmallSat Institute, power subsystems"],
	],
	"comms": [
		["Radio waves travel at the speed of light. From Neptune a signal takes more than four hours to reach Earth.", "REAL: light-travel time at about 30 AU"],
		["The Moon is about 384,000 km away, so a radio signal takes about 1.3 seconds to get there.", "REAL: Earth-Moon distance"],
		["The Moon blocks radio, so a spacecraft behind it is out of contact. Artemis II lost contact for about 40 minutes on its flyby.", "REAL: NASA Artemis II flight day 6"],
		["A dish with a narrow beam sends much more data than a small antenna, but it has to be pointed accurately at Earth.", "REAL: NASA SmallSat Institute, communications"],
	],
	"orbit": [
		["A sun-synchronous orbit crosses any given place at the same local time of day, so pictures taken days apart have similar lighting.", "REAL: sun-synchronous orbit (NASA Earth Observatory)"],
		["A satellite in low Earth orbit travels at about 7.8 km/s and goes around in roughly 90 minutes, so it passes through Earth's shadow every orbit.", "REAL: low Earth orbit physics"],
		["The Moon always shows the same face to Earth. The far side can only be seen from a spacecraft, as Artemis II crew did.", "REAL: NASA Moon facts"],
		["A polar orbit goes over both poles, so as the planet turns beneath it the spacecraft sees every part of the surface.", "REAL: polar orbit (NASA)"],
	],
	"instruments": [
		["Hot things glow in thermal infrared. Satellites use that to find active fires through haze, day or night.", "REAL: NASA FIRMS fire detection"],
		["Radar makes its own signal, so it can see through clouds and smoke, and in the dark.", "REAL: NASA synthetic aperture radar"],
		["In 1998 Lunar Prospector's neutron spectrometer found extra hydrogen near the Moon's poles, a sign of water ice.", "REAL: NASA Lunar Prospector"],
		["In 2009 NASA's LCROSS probe hit a permanently shadowed crater near the Moon's south pole and found water in the plume.", "REAL: NASA LCROSS mission"],
		["A magnetometer measures the strength and direction of a magnetic field. It found that Neptune's field is tilted far from its spin axis.", "REAL: NASA Voyager 2 at Neptune"],
	],
	"computer": [
		["Spacecraft computers must survive radiation that flips bits in ordinary chips, so they use special radiation-hardened parts.", "REAL: NASA SmallSat Institute, avionics"],
		["With hours of signal delay, deep-space probes cannot wait for Earth to fix a fault, so they carry fault protection that acts on its own.", "REAL: NASA deep-space mission operations"],
	],
	"thermal": [
		["Space has no air to carry heat away, so spacecraft use coatings, heaters and radiators to stay in a safe temperature range.", "REAL: NASA SmallSat Institute, thermal control"],
		["Some permanently shadowed craters at the Moon's poles are among the coldest places measured in the solar system.", "REAL: NASA LRO Diviner"],
	],
	"engine": [
		["Efficiency of a rocket engine is measured by specific impulse. Ion engines get about 2,000 s, ten times a simple chemical thruster, but push very gently.", "REAL: NASA SmallSat Institute, propulsion"],
		["To be captured into orbit around a planet or the Moon, a spacecraft must burn to slow down. Without that burn it just flies past.", "REAL: orbital mechanics"],
	],
	"hull": [
		["Radiation from solar flares can damage electronics and harm people, so shielding and shelter matter for any long flight.", "REAL: NASA space radiation"],
		["Orion's heat shield had to handle temperatures of about 5,000 degrees F (2,760 C) when it came back from the Moon on Artemis I.", "REAL: NASA Artemis I"],
	],
	"data": [
		["A spacecraft usually collects far more data than it can send at once, so it stores it and sends the most valuable first.", "REAL: NASA mission operations"],
	],
	"navigation": [
		["Pointing accuracy matters: a camera or dish off by a fraction of a degree can miss its target entirely at long range.", "REAL: NASA SmallSat Institute, guidance and control"],
	],
	"moon": [
		["Low Sun makes long shadows that show the shape of the ground. High Sun hides shadows, so bright rays and colour changes stand out.", "REAL: LROC Sun Angles"],
		["The Orientale Basin is a multi-ring impact basin. Its rings are raised ground thrown up when a huge object hit.", "REAL: NASA and USGS"],
		["Young craters such as Glushko and Ohm have bright rays of material thrown out by the impact. Rays fade with age.", "REAL: USGS Gazetteer of Planetary Nomenclature"],
		["The Moon has almost no atmosphere, so shadows there are sharp and the sky is black even in daylight.", "REAL: NASA Moon facts"],
	],
	"artemis": [
		["Orion hit the atmosphere at about 400,000 ft on its return, felt up to 3.9 g, and splashed down at about 20 mph under parachutes.", "REAL: NASA Artemis II flight day 10"],
		["On the real launch, the flight termination system is armed at T-4:30, and a hold after T-1:30 recycles the count.", "REAL: NASA Artemis II press kit"],
		["Before liftoff the Launch Director polls every station for a go or no-go. A single no-go stops the count.", "REAL: NASA launch operations"],
	],
	"science": [
		["Scientists call something confirmed only when independent sources agree. A single report is a lead, not proof.", "GAME rule inspired by the scientific process"],
		["A good comparison changes one thing at a time. Photos taken in different light cannot be compared fairly.", "REAL idea: controlled comparison; LROC Sun Angles"],
	],
}

## Which fact group goes with each spacecraft room.
const ROOM_TAG := {"POWER BAY": "power", "COMMS": "comms", "INSTRUMENT BAY": "instruments", "CONTROL": "computer", "THERMAL": "thermal", "ENGINE": "engine",
	"HULL": "hull", "DATA VAULT": "data", "NAVIGATION": "navigation"}


## One fact for a group. n picks which one (it wraps), so the same screen can show a different fact each time.
static func get_fact(tag: String, n := 0) -> Dictionary:
	var list: Array = FACTS.get(tag, [])
	if list.is_empty():
		return {}
	var f: Array = list[abs(n) % list.size()]
	return {"text": String(f[0]), "source": String(f[1]), "tag": tag}


## A fact about the room something is happening in.
static func for_room(room: String, n := 0) -> Dictionary:
	return get_fact(String(ROOM_TAG.get(room, "orbit")), n)


## A fact for the mission being designed: its orbit and its instruments, then the power and comms that decide it.
static func for_mission(id: int, n := 0) -> Dictionary:
	var tags := {3: ["orbit", "instruments", "power", "comms", "hull"], 4: ["moon", "instruments", "comms", "engine", "thermal"], 5: ["power", "comms", "computer", "navigation", "thermal"]}
	var list: Array = tags.get(id, ["orbit"])
	return get_fact(String(list[abs(n) % list.size()]), abs(n) / list.size())


## A short line of the kind "DID YOU KNOW: ... (source)".
static func line(f: Dictionary) -> String:
	if f.is_empty():
		return ""
	return "DID YOU KNOW:  %s   (%s)" % [String(f["text"]), String(f["source"])]


static func count() -> int:
	var n := 0
	for k in FACTS:
		n += (FACTS[k] as Array).size()
	return n
