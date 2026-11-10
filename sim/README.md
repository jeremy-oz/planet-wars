# sim/

The pure, deterministic game simulation. **No rendering, no I/O, no unseeded randomness.**
Same inputs → same outputs, byte for byte, on every platform. This directory is shared verbatim
by the client (`game/`) and the dedicated server (`server/`).

See `docs/SPEC.md` for the rules. Everything is preloaded by path, nothing uses `class_name`.

| File | What |
|---|---|
| `world.gd` | `World` with inner `Planet`, `Fleet`, `Order`; `tick()`, `apply_orders()`, `winner()`, `state_hash()`. Pace settings `growth_every`, `shield` (ships per growth level on owned planets), `cap_per_level` (planets stop growing when full) and `max_growth` (ships landed on a full planet of yours buy levels); `ships_to_take()` / `ships_to_grow()` price them for bots and previews. |
| `map_text.gd` | `parse(text) -> World` (null + `last_error` on bad input), `serialize(world) -> String`. |
| `map_generator.gd` | `generate(seed, players, planets, size) -> String` map text; seed fully identifies the map. |
| `ascii.gd` | `render(world) -> String` for debugging; never prints. |
| `match_runner.gd` | `play(world, {player: bot}) -> {winner, ticks, hash}`. |
| `bots/` | `RandomBot`, `NearestBot`, `GreedyBot` (`grow_value` sets its appetite for growing its own planets), `CoachBot` (one move at a time, defence first; feeds the training coach); `decide(world, player) -> Array[Order]`. |

`SIM_VERSION` in `world.gd` must bump whenever a rule or the hash changes (the pinned-hash test enforces it).
