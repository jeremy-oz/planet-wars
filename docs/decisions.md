# Decisions

One line per decision: what — why. Newest at the bottom. Reversals get a new line, never an edit.

## Iteration 0

- Godot 4.7.2 pinned in `.godot-version` — the version installed locally; CI downloads exactly it so headless tests and exports match.
- GL Compatibility renderer — the only renderer that ships on web (Iteration 6) and on a Pi; 2D glow is done with additive sprites and shaders, not Forward+ bloom.
- Makefile, not `just` — `just` is not installed here and `make` is everywhere CI runs; targets are tiny wrappers so switching later is cheap.
- Own 80-line test runner instead of GUT/gdUnit — zero dependencies on a fresh clone, runs under `--headless -s`, output readable in CI logs; revisit if we need mocking or coverage.
- Tests extend `"res://tests/case.gd"` by path, not `class_name` — the global class cache in `.godot/` does not exist on a fresh clone, and the Makefile's `--import` step should not be load-bearing for test discovery.
- `make test` runs `godot --import` first — fonts and other resources need importing before scenes load headlessly; one extra second per run is worth never debugging a missing `.godot/` cache.
- Python tooling in `tools/` as plain scripts with a `uv` project, no packaging — run via `uv run python x.py`; nothing in Python ships in the game.
- `tools/lint_sim.py` forbids clock, OS, unseeded RNG, scene nodes and I/O in `sim/` — determinism is non-negotiable and a grep is cheaper than a desync.
- Both `.github/` and `.forgejo/` workflows — the plan says "Forgejo/GitHub"; they share one `make test` so neither drifts.
- Exo 2 (display) + Inter (UI), both OFL variable fonts — one sci-fi voice, one invisible voice, redistributable; variable weight means two files cover every style.
- Player palette from Okabe–Ito, Mint lifted to `#1FBF95` — colour-blind safe by construction; the lift fixes contrast on the dark background.
- Mood board rendered locally with FLUX.2-klein 4B (Apache-2.0) from the style guide's own prompts — keeps the references in-repo without redistributing Auralux/Eufloria screenshots.
- Static design screens are real Godot scenes using the theme, screenshotted by `tools/snapshot.gd` — the sign-off is on the thing that ships, not a mockup that drifts from it.
- Combat ties leave the planet with its current owner and 0 ships (2010 rule) — simplest rule that is already battle-tested by thousands of bots; written down because it is the one everyone gets wrong.
- `state_hash()` uses FNV-1a over integer fields only — float formatting differs across platforms; integers do not.
