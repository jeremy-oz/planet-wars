# Planet Wars

A Galcon / Auralux / Eufloria-style game: planets grow ships, you send fleets, you win the map.
Built for human players online, self-hosted, no telemetry. See `PLAN.md` for the iteration plan.

## How to play

### Get it running

1. Install [Godot 4.7](https://godotengine.org/download) (free; the standard version, not .NET).
2. Get the code (later, `git pull` gets the newest version):
   ```
   git clone https://github.com/jeremy-oz/planet-wars
   cd planet-wars
   ```
3. Run it: `godot --path .` from the folder (if `godot` is on your `PATH`), or open Godot, choose
   **Import**, pick `project.godot`, then press **Play** (F5). The first launch takes a few seconds
   while Godot imports the art.

### The goal

You are **blue**. Every planet you own makes ships; the number under a planet is its ships. Send
fleets to take grey (neutral) and enemy planets. Take every planet to win.

Start with **Training**: nine short worlds from the Moon to Pluto, each opening with a one-skill
lesson. Faster wins earn more stars. A coach points at a good move when you're idle; press **H**
for a hint any time. Lost twice? Try the easier retry. **Skirmish** sets up your own map, bots,
difficulty and pace.

### Controls

| To | Do |
|---|---|
| Send ships | Drag from your planet to any planet, or click your planet, then click the target |
| Switch source | With one planet selected, click another of yours |
| Send from several | Drag a box around them, shift-click each, or double-click to select all; then click a target |
| Reinforce a planet | Drag onto it, or select several and click it |
| Choose how much to send | Keys **1–4** (25 / 50 / 75 / 100 %) or the buttons at the bottom |
| Cancel | Right-click |
| Pause / menu | **Space** / **Esc** |
| Zoom | Scroll |
| Hint (Training) | **H** |

The line above the send buttons always says what your next click will do, and hovering a target
shows the fight before you commit ("40 vs 31 · takes it").

### Rules worth knowing

- **Levels.** The dots around a planet are its level: more dots, more ships made, but it costs
  more to take.
- **Shields.** Every planet you own has a shield of 5 ships per level dot that attackers must break
  first, and it is whole again a moment later. One big attack beats several small ones.
- **Fleets** fly in a straight line and can't be redirected; a bigger fleet looks bigger.
- **Pace.** Calm (the default) gives battles time to unfold; Skirmish also offers Fast, the arcade
  feel.

Planet surfaces are NASA maps and the skies are Hubble and Webb photographs; see
[`game/art/CREDITS.md`](game/art/CREDITS.md).

## Develop

Requirements: [Godot 4.7.2](https://godotengine.org/download) on your `PATH` as `godot`,
[uv](https://docs.astral.sh/uv/), `make`.

```
make test      # what CI runs: lint, headless GDScript tests, tooling tests
make perf      # 200-planet frame-time report into docs/perf/ (needs a display)
make capture   # UI review screenshots + 60 s recording into docs/ui-reviews/ (needs a display, ffmpeg)
make help      # everything else
```

Open the project in the Godot editor from `project.godot`.

## Layout

| Path | What |
|---|---|
| `sim/` | Pure, deterministic simulation. No rendering, no clock, no unseeded RNG. |
| `game/` | Client: scenes, UI, theme, fonts, audio. |
| `server/` | Headless dedicated server. |
| `tests/` | Headless GDScript tests (`make test-godot`). |
| `tools/` | Python (`uv`) dev tooling only. |
| `docs/` | `SPEC.md`, `STYLE_GUIDE.md`, `decisions.md`, mood board, designs, UI reviews. |

## Licence

Code MIT, assets CC-BY (to be formalised in Iteration 8). Fonts are SIL OFL (see `game/fonts/`).
Images in `game/art/` keep their own terms: NASA public domain, or CC BY 4.0 with the credit in
`game/art/CREDITS.md`.
