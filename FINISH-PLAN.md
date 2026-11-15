# Moonbound: plan to finish

Rule for the order: every phase ends with a game that could be submitted as it stands. Details (extra art, sound polish, more events) come only after Phase 5.

## What "finished" means (checked against the NASA Space Apps template headings)
- **Mission objective**: three contracts playable in order, each with a clear goal and a report.
- **Requirements, spacecraft design, instruments and vehicles**: the Build screen, with each room and lens tied to something it does in flight.
- **Constraints and difficulty**: weight, power, budget, time, crew health; a ship that is locked after contract 01; a bad ship can fly and fail with a stated reason.
- **Educational value**: REAL vs GAME labels with sources, the report, Practice mode.
- **Collaboration**: credits, AI disclosure and sources panel complete.
- **Playable by a stranger** in one sitting without help, from the title to the final report, and it does not lose their progress.

## Phase 0: protect the work (first, short)
- 125 files are uncommitted. Commit in logical chunks on a branch and tag it, before anything else (needs Sarah's go-ahead).

## Phase 1: make testing trustworthy
Earlier scripted tests set game values directly and missed real bugs. Replace that with real input.
- One command runs everything: fast logic tests, then real-input playthroughs (mouse, keys, button clicks), and writes one PASS/FAIL report with screenshots.
- Playthroughs: Orientale good run; Contract 02 good run; failure runs (bad ship, abort, range terminate, crew death, out of time). Sped up so each finishes in a few minutes.
- First job: find why the current Orientale playthrough stopped after the T-0:33 call, and confirm the simplified radio game by actually sending both photos.
- Done when: both contracts finish by real input with zero failures and no script errors in the log.

## Phase 2: clarity and fun, with a real person
Scripts cannot judge confusion. This is where "sending data is confusing" is caught.
- Sarah plays 30 minutes with a short checklist of what to note; I fix the top ten.
- One person who has never seen it plays silently while we watch (ideally a 4-H youth or educator). Note every place they stall. Fix those.
- Done when: a first-time player reaches the report without asking what to do.

## Phase 3: complete the game, in this order
1. **Save and continue**: autosave after each contract and crew change, Continue on the title, New Campaign wipes. The locked ship must survive closing the window.
2. **Ending flow**: a winning ending, a crew-lost ending, an "impossible contract" ending, and a clean New Campaign path.
3. **Contract 03, Impact Watch**: a scanner-style game (sweep, reject false sightings, log with timestamps, a sighting stays tentative until corroborated) plus a log-comparison step and a report. Settle the design with Sarah first (one page). If time runs short, ship a simpler log-and-compare version rather than skip it.
4. **Balance**: time, power, event costs, and the single tight Contract 02 ship (relax it if too narrow); target: a careful player wins, a careless one fails with a clear reason.

## Phase 4: quality gates
- Layout at five window sizes; no clipped text or hidden buttons (the repeat problem).
- Accessibility: keyboard-only play, nothing shown by colour alone, text size, no hard flashing (explosions), a visual cue for every sound.
- Performance on a modest laptop (crew outline glow and particles).
- Content audit: every REAL claim has a source; every GAME number is labelled; confirm the music's origin; AI disclosure matches every asset.

## Phase 5: ship
- Windows build and a web build (itch.io). Web needs a test of audio, saving and input; export templates must be installed.
- README, credits page, a 2-minute demo script, and a submission write-up mapped to the template headings above.
- Final full playthrough on the exported build.

## After that: details
Spares that events use; sourced NASA launch facts (each verified first); a real NASA image on the report; more events and variety; art and sound polish; extra crew roles.

## Risks and how we handle them
- **Contract 03 is the biggest piece**: design it before building; keep a simpler fallback.
- **Web export surprises** (audio, saving, input): test an early export at the end of Phase 1, not at the end.
- **Things only a person can judge** (fun, clarity, sound): Phase 2 is built around that; scripts cannot replace it.
- **Scope creep**: new ideas go on the "after" list, not into earlier phases.
- **Losing work**: Phase 0.

## Decisions needed (my defaults if no answer)
1. Save progress: yes, one slot, autosave.
2. Targets: Windows and web.
3. Deadline: unknown; the order above keeps every phase shippable.
4. Who plays in Phase 2: Sarah plus one fresh player.
