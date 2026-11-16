# Moonbound: sources, credits and open submission questions

Moonbound is a **fictional educational mission inspired by Artemis II**. It is not NASA data, not flight software, and NASA does not endorse or sponsor it. Everything labelled REAL in the game traces to a source below. Everything else is a GAME rule.

Last checked: 15 November 2026 (pages as they read on that date; NASA marks the figures "approximate" and "subject to change").

## NASA and USGS sources

| Source | What the game uses it for | Credit / licence |
|---|---|---|
| [Artemis II Press Kit](https://www.nasa.gov/artemis-ii-press-kit/) (page updated 1 Apr 2026) | Terminal countdown milestones and hold rules in `ground_control.gd` and `count_panel.gd`; ascent milestones (tower clear +0:09, max Q +1:10, booster separation +2:08, abort system jettison +3:18); flight timeline for the flyby and return; planned loss of contact "30-50 minutes". | NASA content, generally not subject to copyright in the US. Acknowledge NASA as the source. |
| [Artemis II flight day 6: lunar flyby updates](https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/) | Planned blackout 6:44 to 7:25 p.m. EDT, "about 40 minutes"; Orientale described as a nearly 600-mile-wide crater straddling the near and far sides; Glushko described with white streaks up to 500 miles. | Same. |
| [Artemis II Lunar Targeting Plan](https://science.nasa.gov/resource/artemis-ii-lunar-targeting-plan/) | The idea that targets are chosen for the lighting at the time of observation. | Same. |
| [Artemis II Preliminary Lunar Science Report](https://science.nasa.gov/feature/artemis-ii-preliminary-lunar-science-report/) | The crew were trained to recognise how sun angle changes what they see, and lighting artifacts must be told apart from real features (Contract 02 copy). | Same. Its figures carry their own credit lines (for example NASA/GSFC/Intuitive Machines). None are bundled yet. |
| Artemis II flight day 8, 9 and 10 pages, [flight day 10 live re-entry updates](https://www.nasa.gov/blogs/missions/2026/04/10/artemis-ii-flight-day-10-re-entry-live-updates/) | The return to Earth (`return_phase.gd`): service module separation, an 18-second raise burn, entry at about 400,000 ft with up to 3.9 g, about six minutes of blackout, drogues near 22,000 ft, three mains near 6,000 ft, about 20 mph at splashdown off San Diego, Navy recovery. | Same. |
| [USGS Gazetteer: Glushko](https://planetarynames.wr.usgs.gov/Feature/2195) | Name and about 40 km diameter (Contract 02). | USGS Astrogeology; cite the feature record. |
| [USGS Gazetteer: Ohm](https://planetarynames.wr.usgs.gov/Feature/4417) | Name, far-side location, about 62 km diameter (Contract 02). | Same. |
| [LROC "Sun Angles"](https://lroc.im-ldi.com/images/790) | Low Sun shows shadows and texture; high Sun removes shadows so brightness differences such as rays stand out (the Contract 02 photo and comparison rules). | NASA/GSFC/Arizona State University (LROC). Check the page's credit line before reuse. |
| Ground launch pages named in the header of `ground_control.gd` (Artemis I and II launch teams, terminal count, weather criteria) | Roles on launch day, the final poll, weather limits. | NASA content. |
| NASA Orion, life support and ISS crew-systems pages named in the Build inspector (`ship_data.gd`) | Why a crew needs each room. | NASA content. |
| [NASA Images and Media Usage Guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/) | Rules we follow: credit NASA, no implied endorsement, no NASA insignia, mark AI-generated material. | n/a |

## Known mismatches with the sources (to fix or label)

1. **Flight termination system arm.** The press kit lists it at **T-4:30**. FIXED: `ground_control.gd` now asks for the Launch Director's call at T-4:30 (checked by `tests/test_batch2.gd`).
2. **Hold after T-1:30.** The press kit says a stop after T-1:30 and before the automated launch sequencer recycles to T-10 if launch window remains (no time limit given). FIXED: the game now recycles the count to T-10:00 if you stop after T-1:30 (checked by `tests/test_batch2.gd` and `tests/test_count.gd`).
3. **Loss of contact length.** The press kit says "30-50 minutes, depending on when they launched"; the flight-day-6 blog says planned 6:44 to 7:25 p.m. (about 41 min) and "about 40 minutes". No observed duration was found on the pages read. The radio game uses a short game-time blackout, labelled GAME.
4. **Glushko size.** USGS gives about 40 km; the NASA blog says 27 miles (about 43 km). Use "about 40 km (USGS)".
5. **Parachute heights.** The press kit (pre-flight) says drogues at 25,000 ft; flight-day pages say about 22,000 ft planned and 23,400 ft actual. The game uses about 22,000 ft and says so.

## Third-party assets and licences

| Item | Status |
|---|---|
| Fonts: Archivo Black, IBM Plex Mono, Instrument Sans | SIL Open Font Licence; licence texts are in `assets/fonts/`. |
| Artwork, crew, ornaments | AI-generated by the team (image generation) with the team's Y2K direction. Listed file by file in `assets/ui/AI-DISCLOSURE.md`. |
| Sound effects | Synthesised in code (`sfx.gd`). |
| Music (`assets/audio/music/classical_*.mp3`) | Copied from the team's earlier web prototype, whose disclosure says they are original synthesised piano and strings with no copyrighted samples. **Provenance is not independently confirmed.** |
| NASA insignia, logo, "meatball", worm | **Not used.** No NASA logo file is in `assets/`. The word "NASA" appears only in source credits and REAL labels. |
| Real NASA images | **One bundled:** NASA's annotated far-side view from the Artemis II flyby (`assets/nasa/`, credit in `assets/nasa/CREDITS.md`), shown in the report and used in the Orientale comparison. Licence still to be confirmed by the team. |

## Unresolved for the team before submission

1. **Space Apps terms and the team's challenge page could not be read** (the fetch tool returned a certificate error for spaceappschallenge.org). Someone on the team must read https://www.spaceappschallenge.org/legal/ and the challenge page and confirm: the licence submissions are released under, the rules on third-party and AI-generated material, and what licence documentation to include (a LICENSE file is not in the project).
2. Confirm the music's origin in writing.
3. Confirm whether the AI-generated art meets the challenge rules on AI content, and mark it as AI-generated where the rules ask.
4. Decide a project licence and add a LICENSE file.
5. Add the exact credit line for every NASA/LROC image if any is added.
6. Check that the fictional framing ("inspired by Artemis II") appears on the title or credits page.
