# tools/

Python (`uv`) tooling only. Nothing here ships in the game.

| Command | Purpose |
|---|---|
| `uv run python capture.py --iteration N` | Capture screenshots + a 60 s recording for the UI review loop (stub until Iteration 2). |
| `uv run python lint_sim.py` | Fail if `sim/` uses anything non-deterministic (unseeded RNG, wall clock, OS, rendering). |
| `uv run python check_repo.py` | Repo conventions: CHANGELOG has an Unreleased section, decisions log is one line per decision, GDScript uses tabs. |
| `uv run pytest` | Tests for the tools themselves. |

Run everything via the repo-root `Makefile` (`make test`).
