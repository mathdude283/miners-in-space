# Moonbound AI disclosure

Use this legend when sharing the asset folder, showing a mockup, or submitting the project. The transparent sprites are intended to be placed in the game. If an image is shown outside this folder, carry its disclosure with it in a caption, on-screen credit, or end card.

| Label | Meaning |
|---|---|
| **AI-generated art** | Created with OpenAI image generation. |
| **AI-background edit** | OpenAI image generation removed the exterior background. |
| **AI-assisted assembly** | Codex cropped, labeled, or arranged generated art into a reference sheet. |
| **AI-assisted writing** | Codex drafted the documentation and design ideas. |
| **NASA source** | An original agency record with its own source and credit. |

## Asset register

### 01 Room sprites

Each file below is **AI-generated art + AI-background edit**. The 12 square sprites were separated from four-room sheets using a crop. The wide observation detail was generated separately.

- `flight-deck.png`
- `life-support.png`
- `galley.png`
- `crew-quarters.png`
- `hygiene.png`
- `exercise.png`
- `medical.png`
- `cargo.png`
- `observation.png`
- `science-lab.png`
- `communications.png`
- `airlock.png`
- `observation-detail.png`

### 02 Hull sprites

Each file below is **AI-generated art**, generated on transparency and cropped from the same hull sheet.

- `shell-nose.png`
- `shell-bay-frame.png`
- `shell-engine.png`
- `shell-solar-wing.png`

### 03 Design references

| File | Disclosure |
|---|---|
| `00-labeled-overview.png` | AI-assisted assembly of AI-generated room art and equipment labels. |
| `shell-assembly-preview.png` | AI-assisted assembly of AI-generated room and hull sprites. |
| `moonbound-builder-concept.png` | AI-generated art. The screen, spacecraft, equipment, text, and lunar imagery inside the mockup are generated concept material. |
| `room-reference.md` | AI-assisted writing. NASA references are credited in the text. |
| `shell-assembly.md` | AI-assisted writing. |
| `moonbound-app-design.md` | AI-assisted writing. NASA references are credited in the text. |
| `play/overlay_camera_capture_confirmed.png`, `play/overlay_radio_signal_pulse.png` | AI-generated interface overlays from the Moonbound kit (Drive folder 04 App visual kit), used in the Moon photo and radio mini-games. |
| `decor/*.png` (16 Y2K Decorative Elements: decor_* and glossy_*) | AI-generated ornaments from the team Drive pack, downscaled for the game. Decoration only: never buttons or mission evidence. |
| `crew/<name>_portrait.png`, `_idle_front.png`, `_idle_right.png`, `_walk_0..3.png` (Ada, Sam, Noor, Jules, Imani, Ren, Tavi) | AI-generated character art from the team's Drive (Space App Remembers / Crew members folders), cropped and resized for the game. Used on the Choose your crew screen, the crew panel and the walkable ship. Replaces the earlier three crew portraits. Tavi comes from the Drive folder "tavi"; the soft grey halo around his walk sheet was cut away, and the sheet (a 2x2 grid read top-left, top-right, bottom-left, bottom-right) was split into four frames. |
| `sfx.gd` (all game sounds) | Sounds are synthesized in code by Claude Code. No recordings are used for sound effects. |
| `../audio/music/classical_*.mp3` (design, launch, cruise, orbit, event, landing) | Six short piano-and-strings pieces from the team's earlier web prototype. Per that project's disclosure they are original arrangements synthesized with AI assistance, with no copyrighted commercial audio samples or existing composition playback. The team should confirm this before release. |

This disclosure was also drafted with AI assistance. Update the register whenever a new asset or revised version is added. If the team imports the earlier local prototype or uses any earlier concept art, add those items too. The local prototype's HTML and JavaScript were drafted with Codex.

## Credit text for the app or demo

**AI-generated artwork.** Spacecraft rooms, hull parts, and interface concepts were created with OpenAI image generation using the team's Y2K direction. Codex assisted with asset preparation, research summaries, and design documentation. See the AI disclosure register for individual files.

Credit each real NASA photograph, recording, or annotation separately with its original source. If the game uses a crop or other adaptation, identify that change. The lunar image in the builder mockup is generated artwork and should carry that label if shown on its own.


### Drive art kit pieces added 15 Nov 2026 (`assets/ui/kit/`)

All from the team's Drive "04 App visual kit" and tracked in its asset manifest. Each is **AI-generated art** (OpenAI image generation) unless the Drive disclosure says otherwise. Used for: Mission Control coach portrait (`panel_mission_control`, portrait part only), evidence photo frame and observation pin (Impact Watch), Earth hologram (radio), planned loss of signal picture (radio blackout), data cartridge and lunar radar pictures (Impact Watch), mission report banner, achievement badges (report and ending), lunar terrain layer (ending). Also downloaded for later use: cabin viewport, radio signal badge, capture and reticle overlays, timeline marker, item slot frame, fly banner, Earth horizon layer.
