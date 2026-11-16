# Real spacecraft numbers (the team's spacecraft sheet)

Source: the team's design sheet "Spacecraft templates and subsystems" (pasted into the project on 15 Nov 2026). It lists NASA SmallSat Institute "State of the Art" pages as its references. **These numbers have not been checked against those pages by the game's author.** Items marked CHECK look odd or were flagged by the sheet itself. The game shows a short REAL line on the matching part in the Build inspector. Game units (weight, power, cost on the Build screen) are different and stay GAME numbers.

Where the sheet says "$" with a bare number it is read here as $M (millions); that reading is an assumption.

## Spacecraft templates (not used by Contracts 01 to 03; kept for later contracts)
| Property | Local Orbit | Local Landing | Long Orbit | Long Landing |
|---|---|---|---|---|
| Intended crew | 4 | 2 | 4 | 4 |
| Bare platform mass | 8,500 kg | 5,000 kg | 90,000 kg | 125,000 kg |
| Base platform cost | $650M | $900M | $20,000M | $30,000M |
| Maximum bays | 5 | 6 | 8 | 10 |
| Instrument mounts | 3 | 3 | 6 | 6 |
| Electrical limit | 30 kW | 35 kW | 200 kW | 300 kW |
| Basic propellant | 2,500 kg | 12,000 kg | 30,000 kg | 60,000 kg |
| Cost per bay / empty-bay mass | $35M / 350 kg | $55M / 450 kg | $300M / 2,500 kg | $400M / 3,000 kg |
Budget cap in the sheet: 4,500 M.

## Subsystems
- Structure and shielding: Light frame 300 kg, $40M, shielding 1/5. Standard 1,000 kg, $160M, 3/5. Hardened 20,000 kg, $950M, 5/5. (CHECK the Hardened mass.)
- Power generation: small solar arrays 300 W at 1 AU, 400 kg, $60M. Large arrays 1,000 W, 3,500 kg, $650M. GPHS-type RTG about 0.25 kW, 58 kg, $200M, probe only (the sheet says verify the mass). Solar output should fall with distance from the Sun.
- Battery: small 20 kWh, 250 kg, $12M. Medium 60 kWh, 750 kg, $28M. Large "3180 kWh", 2,300 kg, $70M (CHECK: 3180 kWh looks like a typo).
- Communications: small antenna 0.2 kW, 100 kg, $20M. Medium dish 0.8 kW, 300 kg, $65M. Large dish 3 kW, 900 kg, $250M. Upgrades: backup transmitter 5 kg, $8M. Relay capability 8 kg, $12M, +15 W.
- Flight computer: Basic 5 kg, 10 W, $5M, reliability 1/5. Radiation-hardened 8 kg, 15 W, $12M, 4/5. Autonomous 12 kg, 20 W, $22M, 4/5.
- Thermal: passive 10 kg, 0 W, $4M. Heaters and radiators 15 kg, 40 W, $9M. Advanced loop 35 kg, 25 W, $20M.
- Propulsion: monopropellant 12 kg, 220 s, 10 W, $8M. Bipropellant 25 kg, 310 s, 15 W, $20M. Small ion 15 kg, 2,000 s, 150 W, $24M. Tank sizes S/M/L depend on the template (game numbers, not NASA standard tanks).
- Attitude control and pointing: basic wheels and sensors 10 kg, 15 W, $5M, about 1 degree. Precision 25 kg, 30 W, $15M, about 0.05 degrees.
- Data storage: small 32 GB, 3 kg, 4 W, $3M. Medium 128 GB, 6 kg, 6 W, $7M. Large 512 GB, 10 kg, 10 W, $12M.

## Instruments
Visible camera 9 kg, 15 W, 25 MB per image, $6M. Thermal infrared imager 20 kg, 35 W, 8 MB per scan, $14M. Radar (SAR) 170 kg, 450 W, 100 to 500 MB per scene, $45M. Spectrometer 15 kg, 25 W, 5 MB per observation, $14M. Magnetometer 4 kg, 4 W, $5M. Neutron spectrometer 8 kg, 8 W, $12M. Atmospheric descent probe 300 kg, self powered, $65M. Laser altimeter 14 kg, 35 W, 27 kbps, $18M.

## Orbits and flight paths (for later contracts)
Low Earth sun-synchronous (500 to 700 km, Earth wildfire), low lunar polar (50 to 100 km, lunar ice), high elliptical (optional Earth/Moon), deep-space cruise and encounter (Earth to Neptune). Missions listed: Earth to Moon, Earth to Neptune, Earth to Earth.

## What the player maintains (idea for a future mission view)
Power Bay (reroute power, shed loads), Comms (realign antenna, prioritise data), Data Vault (clear backlog), Instrument Bay (calibrate, retarget), Control (reboot, backup), Thermal (heaters, radiators), Engine (schedule burns), Navigation (pointing), Hull (safe mode, inspect). Moonbound's walkable ship already does this for its own rooms.

## References named in the sheet (links without tracking tags)
https://www.nasa.gov/smallsat-institute/sst-soa/structures-materials-and-mechanisms/ ; https://www.nasa.gov/smallsat-institute/sst-soa/power-subsystems/ ; https://www.nasa.gov/smallsat-institute/sst-soa/soa-communications/ ; https://www.nasa.gov/smallsat-institute/sst-soa/small-spacecraft-avionics/ ; https://www.nasa.gov/smallsat-institute/sst-soa/thermal-control/ ; https://www.nasa.gov/smallsat-institute/sst-soa/in-space_propulsion/ ; https://www.nasa.gov/smallsat-institute/sst-soa/guidance-navigation-and-control/ ; https://science.nasa.gov/mission/new-horizons/ ; https://science.nasa.gov/mission/mars-2020-perseverance/rover-components/#power ; https://science.nasa.gov/mission/voyager/planetary-voyage/ ; PDS Lunar Prospector neutron spectrometer context record.
