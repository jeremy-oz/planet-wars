# Changelog

All notable changes to Planet Wars. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added — Iteration 2, round 2 (owner survey)
- Training: our solar system. Nine levels from the Moon to Pluto, each with a one-line brief,
  1–3 stars by time, unlocks in order, progress kept on this computer. TRAINING leads the menu;
  the custom setup is now SKIRMISH. Result screen shows stars and NEXT / RETRY / TRAINING.
- Real worlds: 18 NASA surface maps on lit, turning spheres (you are always Earth); Hubble and
  Webb photographs as dimmed backdrops. `tools/fetch_art.py`, credits in `game/art/CREDITS.md`.
- Planet levels shown as 1–5 orbiting dots on every planet.
- Volume sliders have icons; clicking one mutes or restores that channel.

### Changed
- Captures play in two beats: the defender's count drains to zero, then the planet flips colour
  and counts up; flash, ripple and chime land on the flip.
- Ship counts sit under planets so the surface is visible.

### Added — Iteration 2, playable single-player
- Play against 1–3 bots (Random, Nearest, Greedy) at Relaxed, Normal or Sharp, on Small, Medium,
  Large or Huge (200-planet) maps from any seed, with a live preview on the setup screen.
- Controls: click or drag from your planets to a target; shift-click and box-select for several;
  double-click selects all; right-click or Esc cancels; 1–4 set the send share; space pauses;
  +/- change speed; scroll or pinch zooms; middle-drag or two-finger pans. Touch works as mouse.
- Look: GPU-drawn planets (highlight, rim, growth ring) and fleets (particle streams with trails),
  parallax starfield with nebulae, glow on everything owned.
- Juice: launch bursts and squash, capture flash with double ripple and pop, battle sparks, screen
  shake scaled to battle size, breathing planets, hover and selection rings, tweened counts and colours.
- Audio: synthesised pentatonic capture chimes, calm/tense music pads crossfaded by battle intensity,
  launch whoosh, impact thud, UI ticks; Music / Effects / Interface volume sliders.
- Screens: animated main menu with a live bot game, setup, settings, pause, and win/lose with stats
  and a ships-over-time chart. Every screen change fades through the void.
- Tooling: `make audio`, `make perf` (frame-time report in `docs/perf/`), `make capture` (screens,
  60 s recording and frame sheet for the UI review loop).

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
