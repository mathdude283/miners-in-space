class_name QuizData
extends RefCounted
## The questions Mission Control asks. Each one is about something the player just did, or about a real mission design from the team's
## spacecraft sheet. Every answer explains WHY, and says whether the fact is REAL (with its source) or a GAME rule.
## Format: {q, options: [..], answer: index, why, source}.

const AFTER_CONTRACT := {
	0: [
		{"q": "Your wide photo wanted HIGH Sun and your close-up wanted LOW Sun. Why does the Sun's height change what you see?",
			"options": ["Low Sun throws long shadows that show shape and texture. High Sun has almost none, so bright and dark patches stand out.", "A high Sun makes the camera use more power.", "The Moon's atmosphere bends the light."],
			"answer": 0, "why": "Shadows reveal relief, so low Sun is best for shape. With no shadows, differences in brightness, like bright rays, are easier to see.", "source": "REAL: LROC Sun Angles (lroc.im-ldi.com/images/790)"},
		{"q": "The Orientale Basin has bright rings around a dark centre. What made a basin like that?",
			"options": ["A giant impact long ago", "A river that dried up", "Wind blowing dust into rings"],
			"answer": 0, "why": "Basins with rings are made when a very large object hits. The rings are raised ground around the impact.", "source": "REAL: NASA and USGS describe Orientale as a multi-ring impact basin"},
		{"q": "On the real Artemis II flyby, what happened to radio contact behind the Moon?",
			"options": ["It was lost for about 40 minutes", "It got stronger", "Nothing changed"],
			"answer": 0, "why": "The Moon blocks the line to Earth, so there is no signal until the crew comes back round. NASA planned about 40 minutes.", "source": "REAL: NASA Artemis II flight day 6 (planned 6:44 to 7:25 p.m. EDT)"},
	],
	1: [
		{"q": "Which light shows bright crater RAYS best?",
			"options": ["High Sun, with no shadows", "Low Sun, with long shadows", "No Sun at all"],
			"answer": 0, "why": "Rays are bright streaks. Shadows hide brightness differences, so high Sun lets the rays stand out.", "source": "REAL: LROC Sun Angles"},
		{"q": "Two photos of one crater were taken in very different light. Can you compare them fairly?",
			"options": ["No. The shadows and brightness changed, so you cannot tell crater from lighting.", "Yes, a photo is a photo.", "Only if the camera was the same colour."],
			"answer": 0, "why": "A fair comparison changes one thing at a time. Matching the light is how scientists make photos comparable. (The score is a GAME rule.)", "source": "GAME rule built on the REAL Sun-angle idea"},
		{"q": "Young craters like Glushko and Ohm have bright rays. What are rays?",
			"options": ["Bright streaks of material thrown out by the impact", "Beams of sunlight", "Cracks from moonquakes"],
			"answer": 0, "why": "When a crater forms, it throws bright material far across the surface. Over time the rays fade, so bright rays mean a young crater.", "source": "REAL: USGS Gazetteer of Planetary Nomenclature (Glushko, Ohm)"},
	],
	2: [
		{"q": "Two records came from the same window: a log and a crop of its frame. How many independent witnesses is that?",
			"options": ["One", "Two", "Three"],
			"answer": 0, "why": "Copies and crops of one observation add detail, not a second witness. Independent means a different window or instrument.", "source": "GAME rule inspired by how scientists confirm things"},
		{"q": "A bright spot stays at the same place on the window frame while the Moon moves behind it. What is it most likely?",
			"options": ["A reflection in the window", "A real impact flash", "A new star"],
			"answer": 0, "why": "Something that moves with the window and not with the Moon is part of the spacecraft. A wide frame shows that, which is why context matters.", "source": "GAME scenario (fictional)"},
		{"q": "When only ONE source saw a flash, a careful scientist says it is...",
			"options": ["Possible, not confirmed", "Confirmed", "Impossible"],
			"answer": 0, "why": "One report is a lead, not proof. A real event can honestly stay 'possible' until something independent backs it.", "source": "GAME rule inspired by the scientific process"},
	],
}

## From the team's spacecraft sheet: three missions and the choices that make each one work.
const PLANNER := [
	{"mission": "EARTH WILDFIRE", "intro": "Your spacecraft must watch Earth for fires, again and again.", "qs": [
		{"q": "Which orbit suits repeated mapping of Earth for wildfires?",
			"options": ["Low Earth, sun-synchronous (about 500 to 700 km)", "Deep-space cruise toward Neptune", "Low lunar polar orbit"],
			"answer": 0, "why": "A low Earth orbit passes over the ground again and again, and a sun-synchronous one sees each place in similar light.", "source": "REAL numbers from the team's spacecraft sheet (orbit table)"},
		{"q": "Smoke and cloud hide the ground from a normal camera. Which instrument sees through them?",
			"options": ["Radar (SAR): about 170 kg, 450 W", "Visible camera: 9 kg, 15 W", "Magnetometer: 4 kg, 4 W"],
			"answer": 0, "why": "Radar makes its own signal, so clouds and smoke do not block it. It costs a lot of power, which is the trade-off.", "source": "REAL numbers from the team's spacecraft sheet (instruments)"},
		{"q": "Which instrument measures the heat a fire gives off?",
			"options": ["Thermal infrared imager: 20 kg, 35 W", "Spectrometer for reflected colour only", "Laser altimeter"],
			"answer": 0, "why": "Hot things shine in thermal infrared. The imager estimates brightness temperature in kelvin.", "source": "REAL numbers from the team's spacecraft sheet (instruments)"},
	]},
	{"mission": "LUNAR ICE", "intro": "Your spacecraft must look for water ice near the Moon's poles.", "qs": [
		{"q": "Which orbit gives strong coverage of the lunar poles?",
			"options": ["Low lunar polar orbit (about 50 to 100 km)", "Low Earth, sun-synchronous", "High elliptical around Earth only"],
			"answer": 0, "why": "A polar orbit passes over both poles every circuit. Low means close, so instruments see detail.", "source": "REAL numbers from the team's spacecraft sheet (orbit table)"},
		{"q": "Which instrument counts neutrons, a clue to buried hydrogen such as ice?",
			"options": ["Neutron spectrometer: 8 kg, 8 W", "Visible camera", "Thermal infrared imager"],
			"answer": 0, "why": "Hydrogen slows neutrons, so fewer escape where ice may be. The instrument reports a count rate in counts per second.", "source": "REAL numbers from the team's spacecraft sheet; NASA PDS lunar neutron spectrometer record"},
		{"q": "In low lunar orbit, what happens when the Moon is between your spacecraft and Earth?",
			"options": ["You lose contact until you come round again", "Nothing, radio goes through the Moon", "The signal gets stronger"],
			"answer": 0, "why": "The Moon blocks radio, just as it did behind the real Artemis II flyby. Planners store data and send it when contact returns.", "source": "REAL: the sheet's lunar occultation note; NASA flight day 6"},
	]},
	{"mission": "NEPTUNE", "intro": "Your spacecraft must fly to Neptune, a very long way from the Sun.", "qs": [
		{"q": "Why does a Neptune spacecraft need a radioisotope power source (RTG) and not just solar arrays?",
			"options": ["Sunlight is extremely weak that far out, and an RTG works anywhere", "Solar arrays are too cheap", "Neptune has no gravity"],
			"answer": 0, "why": "Solar power falls with distance from the Sun. A GPHS-type RTG gives about 0.25 kW at 58 kg and slowly decays, but needs no sunlight.", "source": "REAL numbers from the team's spacecraft sheet (power); NASA New Horizons used an RTG"},
		{"q": "A signal takes hours to reach Neptune. Which flight computer is best?",
			"options": ["Autonomous: handles faults and delayed commands by itself", "Basic: needs ground commands", "No computer at all"],
			"answer": 0, "why": "With a long delay you cannot wait for Earth to fix a fault. An autonomous computer decides on its own.", "source": "REAL numbers from the team's spacecraft sheet (flight computer)"},
		{"q": "Which antenna suits deep space, and what does it need?",
			"options": ["A large dish (3 kW, 900 kg) with accurate pointing", "A small antenna with no pointing", "A magnetometer"],
			"answer": 0, "why": "A high-gain dish concentrates the signal, but its narrow beam must be pointed accurately, which is why the sheet adds precision pointing (about 0.05 degrees).", "source": "REAL numbers from the team's spacecraft sheet (communications, pointing)"},
	]},
]


## The questions to ask after a contract (an empty list if there are none).
static func for_contract(id: int) -> Array:
	return (AFTER_CONTRACT.get(id, []) as Array).duplicate(true)


## All nine planner questions in order, each with its mission name for the heading.
static func planner() -> Array:
	var out: Array = []
	for m in PLANNER:
		for q in m["qs"]:
			var d: Dictionary = (q as Dictionary).duplicate(true)
			d["mission"] = m["mission"]
			d["intro"] = m["intro"]
			out.append(d)
	return out
