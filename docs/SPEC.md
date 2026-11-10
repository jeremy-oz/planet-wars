# Planet Wars — simulation spec (baseline)

Status: **baseline rules, Iteration 0.** These are the Google AI Challenge 2010 *Planet Wars* rules,
restated precisely enough to implement and test. Pacing (growth, speeds, map size) will be tuned toward
Auralux's calm-but-decisive feel in Iteration 4; the *structure* below is meant to survive that tuning.

Everything in this document is implemented in `sim/` and nothing else. The sim is pure: given a map,
a seed and a sequence of order lists, it produces exactly the same state on every machine.

## 1. Entities

### Planet
| Field | Type | Notes |
|---|---|---|
| `id` | int | 0-based, stable for the life of a game |
| `position` | Vector2 (float) | map units; used only for distances |
| `owner` | int | `0` = neutral, `1..N` = player |
| `ships` | int | ≥ 0 |
| `growth` | int | ships added per tick while owned by a player; 0–5 on classic maps; its level |
| `progress` | int | ships fed toward the next level (growing planets, §5); 0 when off |

### Fleet
| Field | Type | Notes |
|---|---|---|
| `owner` | int | player `1..N` |
| `ships` | int | > 0 |
| `source` | planet id | where it launched |
| `destination` | planet id | where it lands |
| `trip_length` | int | total ticks for the journey, fixed at launch |
| `remaining` | int | ticks until arrival; `trip_length` at launch, arrives when it reaches 0 |

### Player
| Field | Type | Notes |
|---|---|---|
| `id` | int | `1..N`, N ≤ 8 |
| `alive` | bool | owns ≥ 1 planet **or** has ≥ 1 fleet in flight |

### World
Planets, fleets, players, `tick_count`, a seeded `RandomNumberGenerator` (used only by the map
generator and any future rule that needs randomness), and the `sim_version` string.

## 2. Orders

An order is `(player, source, destination, ships)`. Each tick every player submits a list of orders
(possibly empty). An order is **valid** iff:

1. `source != destination`;
2. the player owns `source` at the moment orders are applied;
3. `1 ≤ ships ≤ planets[source].ships`.

Invalid orders are dropped silently by the sim (the server reports them to the client; that is the
server's job, not the sim's). Orders from one player are applied in the order given, so two orders from
the same source in one tick each see the ships left by the previous one.

Applying an order subtracts `ships` from the source and creates a fleet with
`trip_length = remaining = travel_time(source, destination)`.

## 3. Distance and travel time

```
distance(a, b)  = ceil( euclidean_distance(a.position, b.position) )
travel_time     = max(1, distance)        # ticks
```

`ceil` on the float distance, then integer ticks. Positions are read from the map file as floats and
never modified, so the result is identical everywhere as long as `sqrt` is IEEE-754 (it is).

## 4. Tick order (one `tick()` call)

Exactly this sequence, nothing interleaved:

1. **Apply orders** for every player (section 2). Order of players: ascending player id.
2. **Growth.** On ticks where `tick_count % growth_every == 0` (default `growth_every` = 1, every tick),
   every planet with `owner != 0` gains `growth` ships. Neutral planets do not grow. `growth_every`
   is a match setting (the pace), not part of the map. **Capacity** (`cap_per_level`, a match
   setting, default 0 = none): a planet stops growing at `cap_per_level * max(growth, 1)` ships;
   growth tops it up to that and never lowers a planet already above it.
3. **Advance fleets.** Every fleet's `remaining -= 1`.
4. **Resolve arrivals.** For every planet with at least one fleet at `remaining == 0`, resolve combat
   (section 5). Arrived fleets are removed.
5. **Update players.** Recompute `alive`; `tick_count += 1`.

Fleets launched in step 1 of a tick are advanced in step 3 of the same tick, so a 1-tick trip arrives
at the end of the tick it was launched. (Same as the 2010 engine.)

## 5. Combat resolution (simultaneous)

Per planet, per tick, after all fleets that arrive this tick are known:

1. Build a table `force[owner] = ships`, starting with the planet's current owner and ships
   (including neutral, owner `0`), then add every arriving fleet's ships to its owner's entry.
   Fleets of the same owner **merge** — reinforcing your own planet is just a merge with no fight.
2. If only one owner has force, no combat: that owner's ships are set (handles reinforcement).
3. Otherwise sort forces descending. Let `top` be the largest, `second` the next largest.
   - If `top.ships > second.ships`: the planet goes to `top.owner` with `top.ships - second.ships`
     ships. *Ownership only changes if the winner is not already the owner.*
   - If `top.ships == second.ships` (tie): the planet **keeps its current owner** with `0` ships.
     (A neutral planet stays neutral with 0; an owned planet stays owned with 0 and will grow next tick.)
4. A three-way (or more) arrival uses the same rule: only the two largest forces matter; everyone else
   is annihilated.

**Planet shield (`shield`, a match setting, default 0).** In step 1 the current owner's entry starts
at `ships + shield * growth` when the owner is a player; neutral planets have no shield. If the owner
holds, the shield took the first hits: the planet keeps `min(ships + friendly arrivals, top - second)`.
The shield is not state; it is whole again next tick, so separate arrivals each meet it.
Reinforcement with no enemy present is a plain merge. `ships_to_take(planet, ticks)` gives what one
attacking fleet needs: the garrison after growth (up to capacity), plus the shield, plus one.

**Growing planets (`max_growth`, a match setting, default 0 = off; needs a capacity).** After a
reinforcement merge in step 2, the landed ships that put the planet above its capacity leave the
garrison and go into `progress`. While `progress >= upgrade_cost_per_level * (growth + 1)` and
`growth < max_growth`, that cost is paid and `growth` rises by one (raising capacity and shield).
At `max_growth` any leftover progress returns to the garrison. A battle never feeds progress; a
change of owner resets it to 0 (the level stays). `ships_to_grow(planet)` gives the ships its owner
must land to buy the next level: the room left plus the rest of the cost.

This is the 2010 rule set exactly (with `shield = 0`). The tie rule is the one most often got wrong; the test suite covers it.

## 6. Game end

`winner()` returns:

- `-1` while more than one player is alive and `tick_count < max_ticks`;
- the surviving player's id when exactly one player is alive;
- on `tick_count == max_ticks` (default **1000**), the player with the most ships summed over planets
  **and** fleets in flight; a tie returns `0` (draw).

A player with no planets but a fleet in flight is still alive (the fleet may capture something).

## 7. Map format (text)

One entity per line, `#` starts a comment, blank lines ignored. The 2010 format, kept verbatim so the
public map corpus loads unchanged:

```
# P x y owner ships growth
P 11.5 7.25 1 100 5
P 3.0  2.0  0  45 3
# F owner ships source destination trip_length remaining   (optional, for saved mid-game states)
F 1 25 0 1 9 3
```

Planet ids are assigned in file order starting at 0. The map header may carry `# players: N`;
otherwise N is the highest owner id present.

## 8. Random map generator

`generate(seed: int, players: int, planets: int, size: Vector2) -> String` returns a map file. It uses
only the world's seeded RNG, so a seed string fully identifies a map. Fairness (mirror symmetry,
equal starting distances) is Iteration 4; Iteration 1 only guarantees: one home planet per player
with 100 ships and growth 5, planets at least 2 units apart, all other planets neutral.

## 9. Determinism contract

- `state_hash() -> String`: a hash over every planet `(id, owner, ships, growth, progress)` and every fleet
  `(owner, ships, source, destination, trip_length, remaining)` in canonical order, plus `tick_count`.
  Implemented with integer arithmetic only (FNV-1a over the field bytes), never over floats.
- Replaying the same map + seed + per-tick order lists on any platform yields the same
  `state_hash()` at every tick. CI runs this check.
- Clients and servers refuse to talk unless `sim_version` matches (Iteration 3).

## 10. Deliberately not in the baseline

Fleet redirection, fleet-vs-fleet combat in flight, fog of war, planet upgrades, player powers,
teams. Each of these is a later-iteration *mode* that extends the tick sequence without changing
the rules above.
