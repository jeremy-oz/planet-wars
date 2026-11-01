# tests/

Headless GDScript tests. Run with `make test` (or directly:
`godot --headless --path . -s tests/run_tests.gd`).

- `run_tests.gd` — discovers `test_*.gd` files recursively and runs every `test_*` method.
- `case.gd` — base class with non-aborting assertions (`assert_eq`, `assert_true`, …).
- Subdirectories mirror the source tree: `tests/sim/`, `tests/game/`, `tests/server/`.

Tests must be deterministic and must not touch rendering; the sim is tested as pure data.
