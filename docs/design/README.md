# Static designs — Iteration 0 sign-off

| Screen | Scene | Status |
|---|---|---|
| `main_menu.png` | `game/ui/main_menu_static.tscn` | signed off 2026-11-01 |
| `game_screen.png` | `game/ui/game_screen_mock.tscn` | signed off 2026-11-01 |

Both are real Godot scenes using `game/theme/planet_wars_theme.tres` and the drawing primitives in
`game/theme/palette.gd`, captured by `make design` (`tools/snapshot.gd`) at 1600×900.
Per the plan, no gameplay UI is built until these are signed off; sign-off is recorded in
`docs/decisions.md`.
