---
tags: [game-dev, godot, planet-wars, claude-code, plan]
created: 2026-11-01
status: draft
---

# Planet Wars — iterative build plan

A Galcon / Auralux / Eufloria-style game: planets grow ships, you send fleets, you win the map. **Built for human players** — me and my friends, online. Bots exist only as local opponents and to fill empty seats. Eight iterations, each shippable on its own, from a text-mode sim to a release-grade game. Hand one iteration at a time to Claude Code.

## Ground rules (paste these into every Claude Code session)

- Repo: `planet-wars/`. One iteration = one branch + one PR. Don't start the next iteration until the current one's **Done when** list is green.
- Stack: **Godot 4.x (GDScript)** for everything in the game and the dedicated server. **Python (`uv`)** only for build/CI/dev tooling. No other languages unless this plan says so.
- The **simulation is pure and deterministic**: no rendering, no randomness without an explicit seed, same inputs → same outputs. It lives in `sim/` and is tested headlessly with `godot --headless -s`. This is what makes online play desync-free later, so it is non-negotiable.
- Tests before features. Every iteration adds tests; CI runs them.
- Keep a `CHANGELOG.md` and a `docs/decisions.md` (one line per decision, with why).
- No telemetry, ads or third-party trackers, ever. Self-hostable by design.
- When in doubt, ask one question, then pick the simplest option that keeps the sim pure.
- **UI improves every iteration.** No iteration closes until the UI review loop below has run and its top three findings are fixed or explicitly deferred in `docs/ui-reviews/`.
- **Polished from the first playable build.** "Programmer art" is not allowed in anything I will play. The first thing I see must look and sound like a finished indie game, even if it only has one mode. Motivation depends on it. A style guide exists before the first scene is built, and every screen is judged against it.

## UI review loop (runs at the end of every iteration from 2 onward)

1. **Build and capture.** Export a build; capture screenshots of every screen and a 60-second screen recording of a typical game (`tools/capture.py`). Save to `docs/ui-reviews/iter-N/`.
2. **Player survey (me).** Claude Code presents `docs/ui-reviews/SURVEY.md` — ten fixed questions, 1–5 scale plus free text — and waits for my answers. Fixed questions so scores are comparable across iterations: clarity of game state, ease of sending fleets, feedback on actions, readability at a glance, menu navigation, visual appeal, audio, onboarding, performance feel, "would I play again tonight".
3. **Agent review (when appropriate).** Spawn one or more reviewer agents with *no memory of building it*, given only the screenshots, recording, and the question list. Use them for: heuristic/usability pass (Nielsen's ten), accessibility pass (contrast, target sizes, colour-blind check), and a "first-time player" walkthrough from the recording. Skip when the iteration has no visible UI change.
4. **Playtester survey (friends), from Iteration 3.** Same survey, sent after an online session. Optional in 3, expected from 4.
5. **Synthesise.** `docs/ui-reviews/iter-N/findings.md`: scores vs previous iteration, top three issues, what will be fixed now, what is deferred and why.
6. **Fix the top three**, re-capture, and only then open the PR.

Scores must not drop on any question between iterations without a written reason.

## Iteration 0 — Scaffold

**Goal:** empty but runnable project with CI.

- Godot 4 project, `sim/`, `game/`, `server/`, `tests/`, `tools/` (Python, `uv`), `docs/`, `docs/ui-reviews/` with `SURVEY.md` (the ten fixed questions) and `tools/capture.py` stub.
- `godot --headless` test command passes on an empty suite; `uv run` tooling works.
- Forgejo/GitHub CI workflow.
- `docs/SPEC.md` — Planet Wars 2010 rules as the baseline (planet position, owner, ships, growth rate; fleets with source, destination, ships, trip length, turns remaining; simultaneous combat resolution), with a note that pacing will be tuned toward Auralux later.
- `docs/STYLE_GUIDE.md` + a Godot theme resource: pick one visual direction now (reference: Auralux's minimalism, Eufloria's organic softness) — palette (dark space, 4 player colours + neutral, all colour-blind safe), typography (one display font, one UI font), shape language (soft circles, glow, no hard edges), motion rules (every state change animates, 150–300 ms, eased), and audio direction (musical chimes, ambient pad). Include a mood board of 6–10 reference images. Build the main menu and a mock game screen as a **static design** first; I sign off before any gameplay UI is built.

**Done when:** fresh clone → `just test` (or `make test`) passes; CI green; I have signed off the static design of the menu and game screen.

## Iteration 1 — Core simulation

**Goal:** the complete game rules, no graphics.

- `sim/world.gd`: planets, fleets, players, `tick()`, `apply_orders()`, `winner()`, `state_hash()`.
- Rules: growth per tick for owned planets, neutral planets don't grow, fleet travel by distance, combat = largest force wins and keeps the difference, ties leave the planet neutral/unchanged.
- Map loader (text format) and a seeded random map generator.
- ASCII renderer for debugging.
- Local opponent bots in GDScript: `RandomBot`, `NearestBot`, `GreedyBot` — these are for playing against, not a product.
- Tests: growth, travel time, combat edge cases (tie, reinforce own planet, three-way arrivals), determinism (same seed + same orders twice → identical `state_hash()`).

**Done when:** 1000 headless `GreedyBot` vs `RandomBot` games run in under 10 s; Greedy wins > 90 %; all tests pass.

## Iteration 2 — Playable single-player, already beautiful

**Goal:** I can play against a bot and it looks and sounds like a real game.

- 2D scene built strictly to the style guide: planets with soft glow and a growth ring, ship-count labels that tween, fleets as glowing particle streams with trails, subtle nebula/starfield parallax background.
- Juice from day one: ship-launch burst, capture flash and ripple, screen-shake scaled to battle size, planet "breathing" when idle, hover highlights.
- Audio from day one: capture chimes keyed to a scale (Auralux-style), ambient pad, ship-launch whoosh, UI clicks; volume settings.
- Menus: animated main menu, settings, pause overlay, win/lose screen with a short stats summary — all themed, all animated.
- Input: click/drag planet → planet; multi-select; send-percentage slider (25/50/75/100); right-click cancel. Touch-friendly from day one (iPad later).
- Speed control, pause, restart, "new random map", pick opponent bot and difficulty.
- 60 fps on a 200-planet map with all effects on.

**Done when:** I play five games on my laptop without a bug; I *want* to play a sixth; a friend learns the controls in 30 s without instructions; the UI review loop scores visual appeal and audio ≥ 4/5.

## Iteration 3 — Online multiplayer (the whole point)

**Goal:** play with friends over the internet on a server I host.

- Headless Godot dedicated server export (`server/`); server runs the authoritative sim; clients send orders only and render what the server says.
- Godot high-level multiplayer (ENet): orders via RPC, state via `MultiplayerSynchronizer` or periodic snapshots + interpolation — pick one, record why.
- Lobby: create/join by 4-letter code, 2–8 players, pick map and speed, ready-up, host can start.
- Reconnect handling (rejoin by code, resume same seat), server-side validation of every order, graceful handling of a dropped player (seat becomes a bot or neutral — host chooses).
- `Dockerfile` + `docker-compose.yml`; runs on a Raspberry Pi 5 and a small Hetzner VM; `docs/HOSTING.md` for both, including port/firewall and Tailscale-only option.
- Version check: client and server refuse to connect on mismatched sim versions.

**Done when:** four people on different networks play a full game on my Hetzner server with no desync; one of them drops and rejoins; `state_hash()` matches on all clients at game end.

## Iteration 4 — Game feel, second pass

**Goal:** from "looks great" to "feels great".

- Second juice pass driven by survey findings: anticipation on launch, impact frames on captures, camera ease on big fights, UI micro-interactions.
- Pacing pass: tune growth, speed and fleet travel toward Auralux's calm-but-decisive feel; expose presets (Galcon-fast / Auralux-calm).
- Map generator v2: symmetric maps for fairness, chokepoints, size presets, seeds shareable as strings.
- Tutorial: three guided maps, themed like the rest of the game.
- Settings persisted; colour-blind palettes; keyboard shortcuts; music/sfx mix pass.

**Done when:** a playtest with three friends online, each plays 20+ minutes unprompted and asks for another round.

## Iteration 5 — Modes, content, mods

**Goal:** replayability for a regular group.

- Modes: Classic, Teams, King of the Hill, Assassin (secret target), Stealth (hidden fleets), Rush (short timer).
- Player powers/classes (3–5), balanced with bot self-play as a sanity check, then human playtests.
- Campaign: 20 hand-made maps with an escalating bot ladder, for solo nights.
- In-game map editor; maps shared as text or QR string; server can load a custom map.
- Data-driven rules in JSON (growth curves, powers, modes) so a mode can be added without code.

**Done when:** every mode works online with 4 players; the campaign is finishable; a JSON-only mod that halves growth works.

## Iteration 6 — Web and iPad

**Goal:** send a link, play in the browser.

- Godot web export; works in Chrome/Safari on a school laptop and on iPad.
- WebSocket transport alongside ENet so browser clients can join the same server as desktop clients.
- Spectator mode; replay recording on the server and a replay viewer in-game.
- Optional accounts via self-hosted **Nakama** (or FastAPI + SQLite if simpler): nicknames, friends list, match history, Elo. Guest play always allowed.
- Admin panel for the host: see lobbies, kick, close, restart server.

**Done when:** a friend with only the URL plays a full game on an iPad against someone on a desktop client.

## Iteration 7 — Polish and reliability

**Goal:** no excuses.

- Art pass: consistent style guide, shaders (planet surfaces, fleet trails, nebula backgrounds), UI redesign, animated menus.
- Original soundtrack with adaptive layers tied to battle intensity.
- Accessibility: full keyboard/controller play, remappable keys, reduced-motion mode, screen-reader labels on menus.
- Localisation: English (AU), Traditional Chinese; string tables, no hard-coded text.
- Performance: 1000-planet maps at 60 fps on integrated graphics; 8-player server on a Pi 5 under 20 % CPU; profiling report in `docs/`.
- Network robustness: simulated packet loss and latency tests; graceful degradation.

**Done when:** a month of weekly games with friends with zero crashes or desyncs; new players never ask "how do I…" after the tutorial.

## Iteration 8 — "AAA" release

**Goal:** something I'd put on Steam without apologising.

- Platform builds: Windows, macOS, Linux, web, Android, iOS; signed releases; itch and Steam pipeline; auto-update for desktop.
- Public server browser (opt-in; self-hosters can stay private) and matchmaking for strangers, with host-side moderation tools.
- Documentation site: player guide, host guide, modder guide.
- Privacy policy (nothing collected by default), licence (MIT code, CC-BY assets), contributor guide.
- Two-week open beta, then 1.0.

**Done when:** release build passes the open beta with no P1 bugs; a stranger self-hosts a server from the host guide alone.

## Suggested first prompt to Claude Code

> Read `PLAN.md`. Execute **Iteration 0** only. Follow the ground rules. When done, show me the test command output and stop.

Then, per iteration: "Execute Iteration N. Don't touch anything outside its scope."

## Parked (not in scope unless I say so)

- Python bot API, bot tournaments, bot ladder — classroom use, separate project if ever
- Luanti/Minecraft-style voxel skin as a joke mode
- Physical board game export (print-and-play map + rules)
