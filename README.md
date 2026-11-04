# Planet Wars

A Galcon / Auralux / Eufloria-style game: planets grow ships, you send fleets, you win the map.
Built for human players online, self-hosted, no telemetry. See `PLAN.md` for the iteration plan.

## Play

```
godot --path .          # or open project.godot in the editor and press F5
```

Start with **Training**: nine short levels across our solar system, from the Moon to Pluto. You
launch from Earth; take every planet to win, faster for more stars. Each world opens with a short
lesson, and a coach points at a good move when you're stuck (press **H** for a hint any time).
Lost twice? Try the easier retry. **Skirmish** sets up your own map, bots and difficulty.

Every planet you own has a shield (5 ships per level dot) that attackers must break first, so plan
one strong attack rather than several small ones. Skirmish
also offers a Fast pace (the arcade feel).

Drag from your blue planet to another to send ships. Or click: a click on your own planet
always selects it, a click on any other planet sends there (and clears the selection); reinforce
your own planets by dragging;
1–4 set how much to send; space pauses; Esc opens the menu. The dots around a planet are its
level: more dots, more ships grown.

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
