# Impact Watch: "Nobody Saw the Same Moon" (design, not built yet)

Status: design only. Nothing here exists in the game yet. It is a two-person experience: **the flyer** decides what to capture and send; **Mission Control** reviews only what arrived and decides what can responsibly be concluded.

## The idea in one paragraph
One short far-side window. Three candidate sightings: (A) a real simulated impact seen independently by two crew, (B) a real simulated impact seen weakly by one, (C) a plausible artifact (a window reflection). The flyer marks sightings, then spends a limited downlink budget. Mission Control opens the case file offline, sees only what was delivered, classifies each candidate Supported / Possible / Insufficient, and cites records. The reveal: two records that sound like confirmation trace back to one witness.

## Build slices (each ends in something demoable)
1. **Scenario and evidence model** (pure code, testable): fixed seed; truth table (A real+corroborated, B real+weak, C artifact); evidence records with `id, type, time or time range, approx location or view direction, observer or instrument, source_id (crop/copy/retelling), cost, truth tag (kept aboard only)`.
2. **Witness window in the ship interior**: reuse `ship_interior.gd` and crew switching; each crew member has a viewpoint; "Mark sighting" records time, approximate position, confidence, and whether it is firsthand or a copy of another crew member's report.
3. **Downlink as a handoff**: reuse the downlink queue with a byte budget that makes sending everything impossible. Choices: tight crop (clear flash) vs wider frame (window edge for context) vs cheap crew log. One ship decision changes evidence: a second independent camera view (Observation Bay + the lens already supported) helps rule out the window artifact; a solar wing raises the usable downlink budget (the wing already widens the beam and adds reserve).
4. **Export for Mission Control / Open Impact Watch Case**: a JSON file written to `user://` and opened by a second copy. Only delivered records, no truth tags, no hidden fields, neutral filenames and IDs, no thumbnails derived from onboard-only data. Validate the format (version, required fields, id uniqueness, source links resolve) and show a readable error for anything else.
5. **Mission Control board**: timeline, lunar view (near/far side, approximate positions and view directions), evidence cards; link lines for shared `source_id`; classification with cited records; lock the verdict; then reveal.
6. **Scoring rule** (the tests are the specification):
   - records sharing a source count once; two crops of one frame are one source;
   - a copy or retelling adds no corroboration;
   - silence from someone who was looking elsewhere carries little weight;
   - Supported needs two independent sources; Possible needs one credible source; otherwise Insufficient;
   - a real event may correctly be rated Insufficient; the grade is about justification, not about the hidden truth.
7. **Reveal** (three labelled sections): what happened, what reached Earth, what the review could support; plus one concrete lesson for the flyer.
8. **Optional historical case**: NASA's published crew tablet annotations (preliminary science report) with the original credited audio and a transcript, clearly labelled historical versus simulated. Needs: confirm the exact record URLs and the credit line, and whether the audio can be bundled.

## Evidence fields informed by NASA's workflow
From the preliminary science report and the Lunar Science Operations Report (to be read in full and cited before building): observer, annotation, time, viewing conditions, and the review step on the ground. The Planetary Data System Artemis II archive is the model for record IDs and provenance. None of these have been read in full yet; they are listed here as the references to use.

## Tests to write first
- Same scenario, two downlink plans: the delivered set differs and the exported files differ.
- A duplicated observation gives no extra corroboration.
- A cautious verdict on a real event scores as justified.
- Exported file contains no truth, no unsent records, and no hidden fields.
- Invalid or tampered files fail with a readable message.
- A blind human test (someone who did not watch the flight) is **pending** until a second person tries it.

## Size
Slices 1 to 4 and 6 are small. Slice 5 (the board) is the largest. Estimate: several focused sessions. A demo-sized version needs slices 1 to 7. Slice 8 is optional and waits on rights and record checks.
