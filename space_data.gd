class_name SpaceData
extends RefCounted
## Contracts 04 to 06: design an uncrewed spacecraft for Earth wildfire, lunar ice or Neptune, choose its orbit, then run its mission.
## The part numbers (kg, W, $M) are REAL figures from the team's spacecraft sheet (see REAL-SPACECRAFT-SHEET.md). Everything that
## turns those numbers into a score (mass limits, burn units, science value, the mission events) is a GAME rule, and is labelled so.

## Subsystems: one of each is chosen. power is the continuous draw in watts (negative parts make power, see GENERATION).
const SUBSYSTEMS := ["hull", "power", "battery", "comms", "computer", "thermal", "propulsion", "tank", "gnc", "storage"]
const SUB_LABEL := {"hull": "STRUCTURE AND SHIELDING", "power": "POWER GENERATION", "battery": "BATTERY", "comms": "COMMUNICATIONS", "computer": "FLIGHT COMPUTER",
	"thermal": "THERMAL CONTROL", "propulsion": "PROPULSION", "tank": "FUEL TANK", "gnc": "ATTITUDE AND POINTING", "storage": "DATA STORAGE"}
const SUB_ROOM := {"hull": "HULL", "power": "POWER BAY", "battery": "POWER BAY", "comms": "COMMS", "computer": "CONTROL", "thermal": "THERMAL", "propulsion": "ENGINE",
	"tank": "ENGINE", "gnc": "NAVIGATION", "storage": "DATA VAULT"}

const PARTS := {
	"hull": [
		{"id": "light", "name": "Light frame", "kg": 300, "w": 0, "m": 40, "shield": 1, "note": "Lightweight. Limited radiation and debris protection."},
		{"id": "standard", "name": "Standard", "kg": 1000, "w": 0, "m": 160, "shield": 3, "note": "Balanced protection and mass."},
		{"id": "hardened", "name": "Hardened", "kg": 20000, "w": 0, "m": 950, "shield": 5, "note": "Shielding around sensitive electronics. Very heavy. (CHECK: sheet mass)"},
	],
	"power": [
		{"id": "solar_s", "name": "Small solar arrays", "kg": 400, "w": 0, "gen": 300, "m": 60, "note": "300 W at 1 AU. Weak far from the Sun."},
		{"id": "solar_l", "name": "Large solar arrays", "kg": 3500, "w": 0, "gen": 1000, "m": 650, "note": "1,000 W at 1 AU. Fragile, and degrade with radiation."},
		{"id": "rtg", "name": "One GPHS-type RTG", "kg": 58, "w": 0, "gen": 250, "rtg": true, "m": 200, "note": "About 0.25 kW anywhere, no eclipse. Low output, slowly decays. (CHECK: sheet mass)"},
		{"id": "rtg2", "name": "Two RTGs", "kg": 116, "w": 0, "gen": 500, "rtg": true, "m": 400, "note": "0.5 kW anywhere. (GAME: the sheet lists one RTG; more units multiply it.)"},
		{"id": "rtg4", "name": "Four RTGs", "kg": 232, "w": 0, "gen": 1000, "rtg": true, "m": 800, "note": "1 kW anywhere, at a high cost."},
	],
	"battery": [
		{"id": "bat_s", "name": "Small battery", "kg": 250, "w": 0, "kwh": 20, "m": 12, "note": "20 kWh. Limited reserve in eclipse."},
		{"id": "bat_m", "name": "Medium battery", "kg": 750, "w": 0, "kwh": 60, "m": 28, "note": "60 kWh. Balanced."},
		{"id": "bat_l", "name": "Large battery", "kg": 2300, "w": 0, "kwh": 3180, "m": 70, "note": "Great reserve, more mass. (CHECK: the sheet says 3180 kWh)"},
	],
	"comms": [
		{"id": "ant_s", "name": "Small antenna", "kg": 100, "w": 200, "link": 1, "m": 20, "note": "Low gain. Limited data return."},
		{"id": "dish_m", "name": "Medium dish", "kg": 300, "w": 800, "link": 2, "m": 65, "note": "Directional, more data return."},
		{"id": "dish_l", "name": "Large dish", "kg": 900, "w": 3000, "link": 3, "m": 250, "note": "High gain. Needs accurate pointing for deep space."},
	],
	"computer": [
		{"id": "cpu_b", "name": "Basic computer", "kg": 5, "w": 10, "rel": 1, "m": 5, "note": "Needs ground commands, so it suffers from signal delay."},
		{"id": "cpu_r", "name": "Radiation-hardened", "kg": 8, "w": 15, "rel": 4, "m": 12, "note": "Survives flares and belts."},
		{"id": "cpu_a", "name": "Autonomous", "kg": 12, "w": 20, "rel": 4, "auto": true, "m": 22, "note": "Handles faults and delayed commands on its own."},
	],
	"thermal": [
		{"id": "th_p", "name": "Passive (coatings, insulation)", "kg": 10, "w": 0, "mode": 0, "m": 4, "note": "No power needed."},
		{"id": "th_h", "name": "Heaters and radiators", "kg": 15, "w": 40, "mode": 1, "m": 9, "note": "Heaters switch on when it gets cold."},
		{"id": "th_a", "name": "Advanced loop", "kg": 35, "w": 25, "mode": 2, "m": 20, "note": "Active circulation for demanding designs."},
	],
	"propulsion": [
		{"id": "mono", "name": "Chemical monopropellant", "kg": 12, "w": 10, "isp": 220, "m": 8, "note": "Small maneuvers and course corrections."},
		{"id": "bi", "name": "Chemical bipropellant", "kg": 25, "w": 15, "isp": 310, "m": 20, "note": "Higher maneuver capability."},
		{"id": "ion", "name": "Small ion propulsion", "kg": 15, "w": 150, "isp": 2000, "m": 24, "note": "Very fuel-efficient, very low thrust."},
	],
	"tank": [],          # filled from TANKS by template
	"gnc": [
		{"id": "gnc_b", "name": "Basic wheels and sensors", "kg": 10, "w": 15, "point": 1.0, "m": 5, "note": "About 1 degree pointing. Routine."},
		{"id": "gnc_p", "name": "Precision pointing", "kg": 25, "w": 30, "point": 0.05, "m": 15, "note": "About 0.05 degrees. For precision cameras and high-gain dishes."},
	],
	"storage": [
		{"id": "st_s", "name": "Small storage", "kg": 3, "w": 4, "gb": 32, "m": 3, "note": "32 GB."},
		{"id": "st_m", "name": "Medium storage", "kg": 6, "w": 6, "gb": 128, "m": 7, "note": "128 GB."},
		{"id": "st_l", "name": "Large storage", "kg": 10, "w": 10, "gb": 512, "m": 12, "note": "512 GB. For image-heavy missions."},
	],
}

## Fuel tank sizes in kg of propellant, by template (GAME capacities, not NASA standard tanks).
const TANKS := {
	"local": [["Small tank", 10], ["Medium tank", 30], ["Large tank", 60]],
	"long": [["Small tank", 150], ["Medium tank", 350], ["Large tank", 600]],
}

## Instruments. mounts are limited by the template. rate is the data one day of use produces (MB, GAME scale).
const INSTRUMENTS := [
	{"id": "visible", "name": "Visible camera", "kg": 9, "w": 15, "m": 6, "mb": 25, "note": "Visible-light pictures of clouds, terrain and targets."},
	{"id": "thermal_ir", "name": "Thermal infrared imager", "kg": 20, "w": 35, "m": 14, "mb": 8, "note": "Thermal infrared radiance and brightness temperature (K)."},
	{"id": "radar", "name": "Radar (SAR)", "kg": 170, "w": 450, "m": 45, "mb": 300, "note": "Sees through clouds and smoke."},
	{"id": "spectrometer", "name": "Spectrometer", "kg": 15, "w": 25, "m": 14, "mb": 5, "note": "Light intensity at different wavelengths."},
	{"id": "magnetometer", "name": "Magnetometer", "kg": 4, "w": 4, "m": 5, "mb": 1, "note": "Magnetic field strength and direction (nT)."},
	{"id": "neutron", "name": "Neutron spectrometer", "kg": 8, "w": 8, "m": 12, "mb": 1, "note": "Neutron count rate (counts/s). Clue to buried hydrogen."},
	{"id": "probe", "name": "Atmospheric descent probe", "kg": 300, "w": 0, "m": 65, "mb": 1, "note": "Self powered. Pressure, temperature and gas mix on the way down."},
	{"id": "laser", "name": "Laser altimeter", "kg": 14, "w": 35, "m": 18, "mb": 2, "note": "Distance to the surface and elevation (m)."},
]

## The three missions. template picks the limits; sun is how much sunlight there is compared with Earth (solar output scales by it).
const MISSIONS := {
	3: {"id": "wildfire", "tag": "CONTRACT 04", "name": "EARTH WILDFIRE", "template": "local", "mount": 3, "max_w": 30000, "platform_kg": 8500, "platform_m": 650, "mass_cap": 17000, "cost_cap": 4500, "sun": 1.0,
		"goal": "Watch Earth for fires, again and again, and return pictures and heat maps.",
		"orbits": [
			{"id": "leo", "name": "Low Earth, sun-synchronous (500 to 700 km)", "good": true, "note": "Repeated Earth mapping, short ground-station passes, periodic eclipses."},
			{"id": "lunar", "name": "Low lunar polar (50 to 100 km)", "good": false, "note": "Great for the Moon's poles. Nothing to see of Earth's fires."},
			{"id": "heo", "name": "High elliptical", "good": false, "note": "Long time near the high point. Poor for repeated mapping."},
			{"id": "deep", "name": "Deep-space cruise", "good": false, "note": "Leaves Earth behind."}],
		"value": {"thermal_ir": 40, "radar": 35, "visible": 20, "spectrometer": 15}, "needs_link": 1, "needs_gb": 128, "eclipse_h": 0.6, "burns": 2, "hazard": 1,
		"phases": [
			{"room": "ENGINE", "title": "ORBIT INSERTION", "text": "The launch vehicle leaves you in a rough orbit. You must burn to reach the mapping orbit. (Burn units are a GAME rule: fuel times efficiency.)", "options": [
				{"label": "Burn now, as planned", "test": "burns>=2", "good": "The burn put you in the right orbit.", "bad": "You ran short of fuel and ended in a poor orbit.", "pts": 20},
				{"label": "Save fuel and accept a rougher orbit", "test": "always", "good": "The orbit is usable, but coverage is patchy.", "bad": "", "pts": 8}]},
			{"room": "POWER BAY", "title": "ECLIPSE", "text": "Every orbit passes through Earth's shadow for about 36 minutes. The arrays make nothing, so the battery carries the load. (REAL: periodic eclipses in sun-synchronous orbit.)", "options": [
				{"label": "Keep everything running on battery", "test": "eclipse_ok", "good": "The battery carried the whole spacecraft through the shadow.", "bad": "The battery ran flat in the shadow and systems browned out.", "pts": 20},
				{"label": "Shed the instruments until sunlight returns", "test": "always", "good": "You lost an orbit of data but nothing broke.", "bad": "", "pts": 10}]},
			{"room": "INSTRUMENT BAY", "title": "FIRES REPORTED", "text": "Three fires start under thick smoke. Which instrument do you point?", "options": [
				{"label": "Use the thermal infrared imager", "test": "has:thermal_ir", "good": "Heat shows through haze: you mapped all three fires.", "bad": "You have no thermal imager aboard.", "pts": 25},
				{"label": "Use the radar", "test": "has:radar", "good": "Radar sees through smoke: the fire scars are mapped.", "bad": "You have no radar aboard.", "pts": 22},
				{"label": "Use the visible camera", "test": "has:visible", "good": "The smoke hid two of the three fires.", "bad": "You have no visible camera aboard.", "pts": 10}]},
			{"room": "DATA VAULT", "title": "STORAGE FILLING", "text": "Radar and cameras make a lot of data. The vault is nearly full before the next ground pass.", "options": [
				{"label": "Keep it all", "test": "gb>=128", "good": "The vault was big enough to keep everything.", "bad": "The vault filled up and new data was lost.", "pts": 20},
				{"label": "Delete low-value data", "test": "always", "good": "You kept the best data and cleared space.", "bad": "", "pts": 12}]},
			{"room": "COMMS", "title": "GROUND STATION PASS", "text": "Short ground-station passes are all you get in low Earth orbit. Send what you can. (REAL: short passes.)", "options": [
				{"label": "Send the highest-value data first", "test": "link>=2", "good": "A good link returned the important maps in one pass.", "bad": "A weak link returned only part of the data.", "pts": 25},
				{"label": "Send everything in order", "test": "link>=3", "good": "A strong link returned everything.", "bad": "The pass ended with the best data still aboard.", "pts": 15}]},
			{"room": "HULL", "title": "SPACE WEATHER", "text": "A burst of radiation crosses the orbit. Sensitive electronics can be damaged.", "options": [
				{"label": "Enter safe mode until it passes", "test": "always", "good": "Safe mode protected the electronics. You lost a day of science.", "bad": "", "pts": 12},
				{"label": "Keep observing", "test": "shield>=3", "good": "The hull shielded the electronics and you kept observing.", "bad": "The radiation damaged a sensor.", "pts": 20}]},
		]},
	4: {"id": "lunar_ice", "tag": "CONTRACT 05", "name": "LUNAR ICE", "template": "local", "mount": 3, "max_w": 30000, "platform_kg": 8500, "platform_m": 650, "mass_cap": 17000, "cost_cap": 4500, "sun": 1.0,
		"goal": "Orbit the Moon's poles and look for signs of buried water ice.",
		"orbits": [
			{"id": "polar", "name": "Low lunar polar (50 to 100 km)", "good": true, "note": "Strong coverage of the lunar poles. Earth contact is cut by the Moon."},
			{"id": "leo", "name": "Low Earth, sun-synchronous", "good": false, "note": "Good for Earth. The Moon is far away."},
			{"id": "heo", "name": "High elliptical (Earth/Moon)", "good": false, "note": "Long contact windows, but far from the poles."},
			{"id": "deep", "name": "Deep-space cruise", "good": false, "note": "Does not stop at the Moon."}],
		"value": {"neutron": 45, "spectrometer": 25, "laser": 20, "thermal_ir": 20, "radar": 15, "visible": 10}, "needs_link": 2, "needs_gb": 32, "eclipse_h": 0.6, "burns": 4, "hazard": 2,
		"phases": [
			{"room": "ENGINE", "title": "LUNAR ORBIT INSERTION", "text": "To be captured by the Moon and reach a low polar orbit you need real burns. Fuel and efficiency decide whether you can. (Burn units are a GAME rule.)", "options": [
				{"label": "Capture burn, then a polar orbit burn", "test": "burns>=4", "good": "Captured, and into a polar orbit.", "bad": "You ran out of fuel and ended in a high, poor orbit.", "pts": 25},
				{"label": "Capture only, accept a tilted orbit", "test": "burns>=2", "good": "Captured, but the orbit misses part of the pole.", "bad": "Not enough fuel to be captured.", "pts": 12}]},
			{"room": "NAVIGATION", "title": "POINTING AT THE POLE", "text": "Narrow-beam instruments and the dish must point accurately while the Moon turns below.", "options": [
				{"label": "Use precise pointing for the instruments", "test": "point<=0.1", "good": "Pointing held to a tiny fraction of a degree.", "bad": "Basic pointing blurred the measurements.", "pts": 20},
				{"label": "Use wide, forgiving scans", "test": "always", "good": "Coverage is coarse but complete.", "bad": "", "pts": 10}]},
			{"room": "INSTRUMENT BAY", "title": "ICE SEARCH", "text": "Hydrogen slows neutrons, so fewer escape where ice may be buried. What do you rely on?", "options": [
				{"label": "Neutron spectrometer count rate", "test": "has:neutron", "good": "The neutron counts dipped over the permanently shadowed craters: a clue to buried hydrogen.", "bad": "You carry no neutron spectrometer.", "pts": 28},
				{"label": "Spectrometer on the surface", "test": "has:spectrometer", "good": "Surface light signs suggest ice, but only at the surface.", "bad": "You carry no spectrometer.", "pts": 16},
				{"label": "Laser altimeter shapes", "test": "has:laser", "good": "You mapped the crater shapes where ice can hide, but not the ice.", "bad": "You carry no laser altimeter.", "pts": 12}]},
			{"room": "COMMS", "title": "BEHIND THE MOON", "text": "Each orbit the Moon is between you and Earth. There is no contact until you come round again. (REAL: occultation, like Artemis II behind the Moon.)", "options": [
				{"label": "Store data and send it when contact returns", "test": "gb>=32", "good": "The vault held everything until contact returned.", "bad": "The vault was too small and data was lost.", "pts": 20},
				{"label": "Send partial data before the blackout", "test": "link>=2", "good": "A decent link got the key results home before the blackout.", "bad": "The link was too weak to send in time.", "pts": 14}]},
			{"room": "THERMAL", "title": "COLD SHADOW", "text": "Over the permanently shadowed craters it is extremely cold. Electronics need to stay warm.", "options": [
				{"label": "Run the heaters", "test": "thermal>=1", "good": "Heaters kept the electronics warm.", "bad": "With only passive control, a sensor got too cold.", "pts": 20},
				{"label": "Rely on insulation", "test": "thermal>=0", "good": "Insulation was enough for a short pass.", "bad": "", "pts": 10}]},
			{"room": "CONTROL", "title": "COMPUTER FAULT", "text": "A cosmic ray flips a bit in the flight computer while you are out of contact.", "options": [
				{"label": "Let it recover by itself", "test": "rel>=4", "good": "The radiation-hardened computer rebooted and carried on.", "bad": "The basic computer froze until the ground could fix it.", "pts": 20},
				{"label": "Wait for the ground to send a fix", "test": "always", "good": "Contact returned and the ground fixed it. You lost an orbit.", "bad": "", "pts": 8}]},
		]},
	5: {"id": "neptune", "tag": "CONTRACT 06", "name": "NEPTUNE", "template": "long", "mount": 6, "max_w": 200000, "platform_kg": 90000, "platform_m": 20000, "mass_cap": 120000, "cost_cap": 24000, "sun": 0.0011,
		"goal": "Fly to Neptune, a very long way from the Sun, and study the planet.",
		"orbits": [
			{"id": "cruise", "name": "Deep-space cruise, Neptune encounter", "good": true, "note": "Earth-to-Neptune trajectory. Long signal delay, limited data rate."},
			{"id": "leo", "name": "Low Earth, sun-synchronous", "good": false, "note": "Never leaves Earth."},
			{"id": "lunar", "name": "Low lunar polar", "good": false, "note": "Stops at the Moon."},
			{"id": "heo", "name": "High elliptical", "good": false, "note": "Stays near Earth."}],
		"value": {"magnetometer": 35, "probe": 40, "visible": 25, "spectrometer": 20, "thermal_ir": 10, "laser": 5}, "needs_link": 3, "needs_gb": 128, "eclipse_h": 0.0, "burns": 6, "hazard": 3,
		"phases": [
			{"room": "POWER BAY", "title": "FAR FROM THE SUN", "text": "At Neptune the Sun is about 900 times fainter than at Earth, so solar arrays make almost nothing. (REAL: solar output falls with distance; New Horizons used an RTG.)", "options": [
				{"label": "Run on the RTG", "test": "power_ok", "good": "The RTG kept every system alive in the dark.", "bad": "Without enough power at this distance, systems went dark.", "pts": 30},
				{"label": "Shut down all but the essentials", "test": "always", "good": "The spacecraft survived on a trickle and returns little.", "bad": "", "pts": 10}]},
			{"room": "CONTROL", "title": "SIGNAL DELAY", "text": "A signal takes hours to reach Neptune. A fault will not wait for a reply from Earth. (REAL: long signal delay.)", "options": [
				{"label": "Trust the flight computer to handle it", "test": "auto", "good": "The autonomous computer diagnosed and fixed the fault by itself.", "bad": "Without autonomy the fault sat there waiting for Earth's reply, and you lost days.", "pts": 28},
				{"label": "Wait for ground commands", "test": "always", "good": "Hours later the fix arrived. You lost time.", "bad": "", "pts": 8}]},
			{"room": "NAVIGATION", "title": "ENCOUNTER POINTING", "text": "During the flyby the spacecraft and dish must point precisely while moving fast.", "options": [
				{"label": "Use precision pointing", "test": "point<=0.1", "good": "Precise pointing caught the planet in every frame and kept the dish on Earth.", "bad": "Basic pointing smeared the images and the high-gain beam wandered.", "pts": 24},
				{"label": "Use wide scans", "test": "always", "good": "Wide scans caught the planet, but with less detail.", "bad": "", "pts": 10}]},
			{"room": "INSTRUMENT BAY", "title": "ENCOUNTER SCIENCE", "text": "Neptune has a strong magnetic field and a deep atmosphere. What do you study?", "options": [
				{"label": "Magnetic field with the magnetometer", "test": "has:magnetometer", "good": "You measured the field strength and direction (nT).", "bad": "You carry no magnetometer.", "pts": 24},
				{"label": "Drop the atmospheric descent probe", "test": "has:probe", "good": "The probe returned pressure, temperature and gas mix on its way down.", "bad": "You carry no descent probe.", "pts": 28},
				{"label": "Take pictures", "test": "has:visible", "good": "Good pictures of the clouds and rings.", "bad": "You carry no camera.", "pts": 12}]},
			{"room": "COMMS", "title": "A SLOW LINK HOME", "text": "The link is slow and far. Only a high-gain dish pointed accurately can return much. (REAL: limited data rate.)", "options": [
				{"label": "Send the best data with the big dish", "test": "link>=3", "good": "The large dish returned the key results over days.", "bad": "The link was too weak: most data stayed aboard.", "pts": 28},
				{"label": "Send a short summary only", "test": "always", "good": "A summary reached Earth. The rest is lost.", "bad": "", "pts": 10}]},
			{"room": "THERMAL", "title": "DEEP COLD", "text": "Far from the Sun the spacecraft is very cold, and the electronics must not freeze.", "options": [
				{"label": "Run heaters and radiators", "test": "thermal>=1", "good": "Heaters kept the electronics in range.", "bad": "Passive control let a bus freeze.", "pts": 20},
				{"label": "Rely on the RTG's waste heat", "test": "rtg", "good": "The RTG's heat kept the spacecraft warm for free.", "bad": "Without an RTG there is no waste heat to use.", "pts": 20}]},
		]},
}


static func mission(id: int) -> Dictionary:
	return MISSIONS.get(id, {})


static func is_space(id: int) -> bool:
	return MISSIONS.has(id)


## The parts available for a subsystem on this mission (tanks depend on the template; the RTG is only for deep space).
static func parts_for(id: int, sub: String) -> Array:
	var m := mission(id)
	if sub == "tank":
		var out: Array = []
		for i in TANKS[String(m["template"])].size():
			var t: Array = TANKS[String(m["template"])][i]
			out.append({"id": "tank_%d" % i, "name": String(t[0]), "kg": int(t[1]), "w": 0, "fuel": int(t[1]), "m": 0, "note": "%d kg of propellant (a GAME capacity)." % int(t[1])})
		return out
	var list: Array = []
	for p in PARTS[sub]:
		if bool(p.get("rtg", false)) and id != 5:
			continue
		list.append(p)
	return list


static func _find(list: Array, pid: String) -> Dictionary:
	for p in list:
		if String(p["id"]) == pid:
			return p
	return {}


## Work out everything about a design. picks: {sub: part id, "instruments": [ids], "orbit": id}. Returns the numbers the checks and the
## mission events use, plus "problems" (what stops launch).
static func derive(id: int, picks: Dictionary) -> Dictionary:
	var m := mission(id)
	var d := {"kg": float(m["platform_kg"]), "cost": float(m["platform_m"]), "draw": 0.0, "gen": 0.0, "kwh": 0.0, "shield": 0, "link": 0, "rel": 0, "auto": false, "mode": 0,
		"isp": 0, "fuel": 0, "gb": 0, "point": 99.0, "rtg": false, "instruments": [], "problems": [], "complete": true}
	for sub in SUBSYSTEMS:
		var p := _find(parts_for(id, sub), String(picks.get(sub, "")))
		if p.is_empty():
			d["complete"] = false
			d["problems"].append("Choose %s." % String(SUB_LABEL[sub]).to_lower())
			continue
		d["kg"] += float(p["kg"])
		d["cost"] += float(p["m"])
		# GAME duty cycles: the transmitter is on a fifth of the time, the engine only when it burns
		d["draw"] += float(p.get("w", 0)) * (0.2 if sub == "comms" else (0.1 if sub == "propulsion" else 1.0))
		d["shield"] = maxi(int(d["shield"]), int(p.get("shield", 0)))
		d["link"] = maxi(int(d["link"]), int(p.get("link", 0)))
		d["rel"] = maxi(int(d["rel"]), int(p.get("rel", 0)))
		d["auto"] = bool(d["auto"]) or bool(p.get("auto", false))
		d["mode"] = maxi(int(d["mode"]), int(p.get("mode", 0)))
		d["isp"] = maxi(int(d["isp"]), int(p.get("isp", 0)))
		d["fuel"] += int(p.get("fuel", 0))
		d["gb"] += int(p.get("gb", 0))
		d["point"] = minf(float(d["point"]), float(p.get("point", 99.0)))
		d["kwh"] += float(p.get("kwh", 0.0))
		if p.has("gen"):
			d["gen"] += float(p["gen"]) * (1.0 if bool(p.get("rtg", false)) else float(m["sun"]))
		d["rtg"] = bool(d["rtg"]) or bool(p.get("rtg", false))
	for iid in picks.get("instruments", []):
		var ins := _find(INSTRUMENTS, String(iid))
		if ins.is_empty():
			continue
		d["kg"] += float(ins["kg"])
		d["cost"] += float(ins["m"])
		d["draw"] += float(ins["w"]) * 0.5          # GAME duty cycle: instruments are not all on at once
		d["instruments"].append(String(iid))
	d["burns"] = float(d["fuel"]) * float(d["isp"]) / 1000.0           # GAME rule: burn units = kg of fuel x efficiency / 1000
	d["margin"] = float(d["gen"]) - float(d["draw"])
	if (d["instruments"] as Array).size() > int(m["mount"]):
		d["problems"].append("Only %d instrument mounts: remove %d." % [int(m["mount"]), (d["instruments"] as Array).size() - int(m["mount"])])
	if (d["instruments"] as Array).is_empty():
		d["problems"].append("Fit at least one instrument.")
	if float(d["kg"]) > float(m["mass_cap"]):
		d["problems"].append("Too heavy: %d kg against a limit of %d kg (a GAME limit)." % [int(d["kg"]), int(m["mass_cap"])])
	if float(d["cost"]) > float(m["cost_cap"]):
		d["problems"].append("Over budget: $%dM against a cap of $%dM." % [int(d["cost"]), int(m["cost_cap"])])
	if float(d["draw"]) > float(m["max_w"]):
		d["problems"].append("The electrical distribution limit is %d kW." % int(float(m["max_w"]) / 1000.0))
	if float(d["margin"]) < 0.0:
		d["problems"].append("Not enough power: %.1f W made, %.1f W used. Solar output falls with distance from the Sun." % [float(d["gen"]), float(d["draw"])])
	if String(picks.get("orbit", "")) == "":
		d["problems"].append("Choose an orbit.")
	d["ok"] = (d["problems"] as Array).is_empty()
	return d


## Does this design pass a phase test? Tests are small strings: "always", "has:ID", "key>=n", "key<=n", or a named check.
static func passes(id: int, d: Dictionary, test: String) -> bool:
	var m := mission(id)
	if test == "always":
		return true
	if test.begins_with("has:"):
		return (d["instruments"] as Array).has(test.substr(4))
	if test == "eclipse_ok":
		return float(d["kwh"]) * 1000.0 >= float(d["draw"]) * float(m["eclipse_h"])
	if test == "power_ok":
		return float(d["margin"]) >= 0.0
	if test == "auto":
		return bool(d["auto"])
	if test == "rtg":
		return bool(d["rtg"])
	for op in [">=", "<="]:
		if test.contains(op):
			var parts := test.split(op)
			var v := float(d.get(parts[0], 0.0))
			if parts[0] == "thermal":
				v = float(d["mode"])
			return v >= float(parts[1]) if op == ">=" else v <= float(parts[1])
	return false


## The science value of the instruments chosen (0 to 100), by how well they suit this mission.
static func science_value(id: int, d: Dictionary) -> int:
	var tot := 0
	var value: Dictionary = mission(id)["value"]
	for iid in d["instruments"]:
		tot += int(value.get(iid, 0))
	return mini(tot, 100)


## Score a finished mission. choices: the index picked at each phase. Returns {rows, total, max, percent, grade, points, results, headline}.
static func score(id: int, picks: Dictionary, choices: Array, level := 1) -> Dictionary:
	var m := mission(id)
	var d := derive(id, picks)
	var phases: Array = m["phases"]
	var results: Array = []
	var ops := 0.0
	var ops_max := 0.0
	var best := 0.0
	var wins := 0
	for i in phases.size():
		var opts: Array = phases[i]["options"]
		var top := 0.0
		for o in opts:
			top = maxf(top, float(o["pts"]))
		ops_max += top
		var o: Dictionary = opts[clampi(int(choices[i]) if i < choices.size() else 0, 0, opts.size() - 1)]
		var good := passes(id, d, String(o["test"]))
		var got := float(o["pts"]) if good else float(o["pts"]) * 0.2
		ops += got
		if good:
			wins += 1
		results.append({"title": phases[i]["title"], "room": phases[i]["room"], "choice": o["label"], "good": good, "text": String(o["good"]) if good else String(o["bad"]), "pts": int(got)})
	var orbit_ok := false
	for ob in m["orbits"]:
		if String(ob["id"]) == String(picks.get("orbit", "")) and bool(ob["good"]):
			orbit_ok = true
	var sci := float(science_value(id, d)) * (1.0 if orbit_ok else 0.25)
	var rows: Array[Dictionary] = []
	rows.append({"name": "ORBIT", "pts": 100.0 if orbit_ok else 0.0, "max": 100.0, "why": "The right orbit for the job."})
	rows.append({"name": "SCIENCE", "pts": sci * 2.5, "max": 250.0, "why": "How well your instruments suit this mission."})
	rows.append({"name": "OPERATIONS", "pts": ops / maxf(ops_max, 1.0) * 400.0, "max": 400.0, "why": "Your choices when things happened, and whether your design could carry them out."})
	var spare := (float(m["cost_cap"]) - float(d["cost"])) / (float(m["cost_cap"]) - float(m["platform_m"]))
	rows.append({"name": "BUDGET", "pts": 150.0 * clampf(spare * 2.0, 0.0, 1.0), "max": 150.0, "why": "Money left under the cap, after the platform (half left is full marks)."})
	rows.append({"name": "DESIGN", "pts": (100.0 if bool(d["ok"]) else 0.0), "max": 100.0, "why": "A legal design: power, mass, mounts and budget."})
	var total := 0.0
	var mx := 0.0
	for r in rows:
		r["pts"] = roundf(float(r["pts"]))
		total += float(r["pts"])
		mx += float(r["max"])
	var pct := 100.0 * total / mx
	var diff := ScoreBoard.difficulty(level)
	return {"rows": rows, "total": int(total), "max": int(mx), "percent": pct, "grade": ScoreBoard.grade_for(pct), "mult": float(diff["mult"]),
		"points": int(round(total * float(diff["mult"]))), "difficulty": String(diff["name"]), "results": results, "wins": wins, "design": d, "orbit_ok": orbit_ok}
