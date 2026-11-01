# Planet Wars

A Galcon / Auralux / Eufloria-style game: planets grow ships, you send fleets, you win the map.
Built for human players online, self-hosted, no telemetry. See `PLAN.md` for the iteration plan.

## Develop

Requirements: [Godot 4.7.2](https://godotengine.org/download) on your `PATH` as `godot`,
[uv](https://docs.astral.sh/uv/), `make`.

```
make test      # what CI runs: lint, headless GDScript tests, tooling tests
make design    # re-render the static design screens into docs/design/
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
