# Changelog

All notable changes to Planet Wars. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added — Iteration 0, scaffold
- Godot 4.7.2 project with `sim/`, `game/`, `server/`, `tests/`, `tools/`, `docs/` layout.
- Headless test runner (`tests/run_tests.gd`) and non-aborting assertion base class; `make test`.
- Python (`uv`) tooling: `capture.py` stub, `lint_sim.py` purity lint, `check_repo.py` conventions.
- GitHub Actions and Forgejo CI running `make test` against the pinned Godot build.
- `docs/SPEC.md` — Planet Wars 2010 rules as the simulation baseline.
- `docs/STYLE_GUIDE.md`, the Godot theme resource, Exo 2 + Inter fonts, eight-image mood board.
- Static designs of the main menu and game screen for sign-off (`docs/design/`).
- `docs/ui-reviews/SURVEY.md` — the ten fixed review questions.
