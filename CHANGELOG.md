# Changelog

All notable changes to Planet Wars. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added — Iteration 1, core simulation
- `sim/world.gd`: planets, fleets, orders, `tick()`, `apply_orders()`, `winner()`, `state_hash()` per `docs/SPEC.md`.
- `sim/map_text.gd` (2010 text format in and out), `sim/map_generator.gd` (seeded, ring-of-homes layout).
- `sim/ascii.gd` debug renderer and `sim/match_runner.gd` to play a world with a bot per seat.
- Local opponent bots: `RandomBot`, `NearestBot`, `GreedyBot` in `sim/bots/`.
- 35 headless tests: growth, travel time, order validity, combat edge cases (ties, reinforcement,
  three-way arrivals), map round-trip, generator constraints, per-tick determinism, a pinned hash,
  and the benchmark (1000 Greedy-vs-Random games < 10 s, Greedy > 90 %).
- Sim purity lint now allows methods on a seeded `RandomNumberGenerator`.

### Added — Iteration 0, scaffold
- Godot 4.7.2 project with `sim/`, `game/`, `server/`, `tests/`, `tools/`, `docs/` layout.
- Headless test runner (`tests/run_tests.gd`) and non-aborting assertion base class; `make test`.
- Python (`uv`) tooling: `capture.py` stub, `lint_sim.py` purity lint, `check_repo.py` conventions.
- GitHub Actions and Forgejo CI running `make test` against the pinned Godot build.
- `docs/SPEC.md` — Planet Wars 2010 rules as the simulation baseline.
- `docs/STYLE_GUIDE.md`, the Godot theme resource, Exo 2 + Inter fonts, eight-image mood board.
- Static designs of the main menu and game screen for sign-off (`docs/design/`).
- `docs/ui-reviews/SURVEY.md` — the ten fixed review questions.
