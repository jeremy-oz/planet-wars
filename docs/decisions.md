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
- Static main menu and game screen signed off by the owner on 2026-11-01 — gameplay UI (Iteration 2) may now be built against them and the style guide.

## Iteration 1

- Sim entities are inner classes (`World.Planet`, `World.Fleet`, `World.Order`), not Dictionaries — typed member access is several times faster in GDScript and the benchmark runs 1000 games in under 2 s.
- Orders are a flat Array applied per player in ascending id — matches SPEC §4 step 1 without relying on `sort_custom` stability.
- Travel times are cached in an n×n matrix built lazily — bots query distances O(P²) per tick; `ceil(sqrt)` once per pair is enough.
- `MapText.parse` returns null and sets `last_error` instead of `push_error` — the server will relay the message to a client, and CI logs stay free of backtraces for expected failures.
- Map generator places home planets on a ring around the centre — always succeeds for 1–8 players and is roughly fair; true symmetry waits for Iteration 4.
- A pinned `state_hash()` test guards the rules — any behavioural change to the sim breaks it on purpose, forcing a `SIM_VERSION` bump and a re-pin in the same PR.
- Bots live in `sim/bots/` under the purity lint — a bot that reads the clock or unseeded RNG would make single-player replays non-deterministic.
- No UI review loop for Iteration 1 — the plan starts the loop at Iteration 2 and this iteration has no visible UI.

## Iteration 2

- One tick every 0.25 s at 1× (speeds ½×, 1×, 2×, 4×) — fleets cross a medium map in 5–8 s, Galcon-brisk; the calm Auralux pacing pass is Iteration 4.
- Human sends are queued and applied on the next tick, with the whoosh and squash played on click — keeps the sim's tick-ordered input while the UI answers in the same frame.
- The send share is taken of what each source holds when the order is applied, not when clicked — a click can never ask for ships that are no longer there.
- Bots think every 4/2/1 ticks for Relaxed/Normal/Sharp — reaction speed is the most legible difficulty knob and needs no new bot code.
- Fleets and planets are drawn by MultiMesh + shaders, not `_draw` — the CPU version ran at 12 fps on a 200-planet stress map (≈60 000 draw calls a frame); the GPU version runs at 240 fps with 4 700 fleets in flight.
- Fleet instances are written once at launch; the shader computes position from a `sim_time` uniform — per-frame cost no longer grows with fleets, which is what Iteration 7's 1000-planet target needs.
- Bots may decide a tick's orders during the frames before it (`Session.think_ahead`) — the world cannot change between ticks, so results are identical (tested), and the 8 ms of thinking no longer lands in one frame.
- HUD totals and music tension read a per-tick cache in `Session` — re-summing every fleet each frame cost more than drawing them.
- All audio is synthesised by `tools/make_audio.py` (numpy) and committed as WAV — no licensing questions, deterministic, and a fresh clone plays without Python.
- Music is two looping pads (calm, tense) in C major pentatonic, crossfaded by the share of ships in flight — the same adaptive idea Iteration 7 extends, at no extra cost now.
- Capture chimes pick the note from planet size and the octave from who captured — you can hear your own progress without looking.
- Screens are built in code with theme type variations rather than hand-written `.tscn` files — the scenes are mostly generated layout, and code keeps the stagger/juice wiring next to the nodes it animates.
- A demo driver plays the human seat through the real UI path (selection, drag line, send) with a visible cursor — the 60 s review recording shows interaction feedback, not just bots.
- Tests run on the first frame of the SceneTree, not in `_initialize` — only then is the root in the tree, so screen smoke tests get real `_ready()` calls.
- Settings are kept in memory only — persisting them is in Iteration 4's scope.

### Iteration 2, round 2 (owner survey)

- Planets are drawn with real surface maps (NASA public domain; Uranus from Solar System Scope, CC BY 4.0) on a shader sphere — the owner asked for real planets; one Texture2DArray keeps all 200 planets in a single draw call.
- Backdrops are Hubble/Webb photographs (CC BY 4.0) drawn at about 20 % brightness — real, but play must stay readable; "very busy" was part of the same survey.
- Images are fetched and converted by `tools/fetch_art.py` and committed with `game/art/CREDITS.md` — like the audio, a fresh clone needs no network, and every image has a recorded source and licence.
- Ownership is a colour wash, an atmosphere halo and coloured level dots, not a fully recoloured planet — the real surface is the point; the halo keeps owned vs neutral independent of hue.
- Ship counts sit under planets, not on them — the surface would otherwise be hidden behind the number.
- Captures animate in two beats (drain in the defender's colour, then flip and count up) — owner Q4. Visual only; the sim still resolves arrivals in one tick.
- Training (nine solar-system levels) is pulled forward from Iteration 5's campaign — the owner would not play a sixth game without a reason to; the plan's done-when needs that. Constellations and skills stay in Iteration 5.
- Training progress is saved to `user://progress.cfg` now, ahead of Iteration 4's settings persistence — unlocks are meaningless if they reset every launch.
- Star pars are multiples of a Greedy bot's time in your seat (3★ ≈ 3.5×+10 s, 2★ ≈ 6×+20 s) — a bot reacts every tick, so its time is a floor; a test keeps every level winnable by it inside the 3-star par. *(Replaced in round 3: pars now come from human-paced play.)*
- A level's enemy is keyed by seat, not planet id — hand-made maps list the enemy home last.

### Iteration 2, round 3 (owner: "stuck at Mars")

- Training is tuned against a person, not a bot: a test follows the coach's advice with one move every 2 s and must win every world (normal and easier retry) — a pace check showed that play lost every world from Venus on; the old fairness test used a bot reacting every tick.
- Training commanders make one move per decision (`bot_moves: 1`) and think every 2 s on most worlds (new "gentle" pace) — the gap was moves per second, not strategy: a bot sent from every planet at once while a person drags one at a time.
- The coach's advice comes from a new sim bot (`sim/bots/coach_bot.gd`, defence first, keeps a reserve near the enemy) — one source of truth for the hints, the arrow and the fairness test, so "follow the arrow" provably wins.
- Lessons hold the match until you do the thing (one skill per world) and live hints only appear when you are idle 6 s or a planet is about to fall — teaching without nagging; the last world keeps only danger warnings.
- After two losses in a row the defeat screen offers an easier retry (enemy one notch slower, your home fleet ×1.5) worth 1 star — owner's choice; it still opens the next world so nobody is stuck again.
- Pausing fades the music out and holds its place; leaving a paused game restores it — owner report.
- The pause menu's button reads "≡ MENU" instead of "≡" — the owner did not find RESTART behind the bare icon.
- Pars: 3★ ≈ 2× the time at one move a second + 15 s; 2★ ≈ 1.5× the slower of the 2 s and 2.5 s runs + 30 s — stars measure play a person can reach.

### Iteration 2, round 4 (owner: Uranus is hard, visuals "200 % better", fleets look the same size)
- Fleet size follows ship count much more strongly (one dot per ship up to 80; width, length, dot size and glow ∝ √ships) — the old √ships scaling was too gentle to read; √ keeps a 300-ship stream from covering the map.
- Uranus left as it is — the owner called being stuck "not necessarily bad", and the easier retry after two losses already covers it.

### Iteration 2, round 5 (owner: "planets change hands very quickly … clicking correctly and quickly becomes very important", Uranus)
- Pacing pass pulled forward from Iteration 4 — owner's choice, because the complaint is the game's core feel, not polish.
- Tune against a measured number (your planets lost per minute while following the coach) — it was 5–20 at the old pace on the late worlds, and the reference research (Auralux, Galcon, Eufloria) pointed at production 5–10× lower than ours and at defenders having an edge.
- Calm pace = 0.4 s ticks (fleets 2.5 units/s), growth every 3rd tick (top planet ≈ 4 ships/s), garrison edge 100 % — the variant that cut your planets lost to 0–8 a minute and won every world at one move every 1, 2 and 3 s; slower growth alone (or a 50 % edge) still left Neptune and Pluto churning.
- Garrison edge applies to owned planets only, not neutrals — expansion costs stay readable from the number on the planet; holding is what gets cheaper.
- Growth pacing and the edge are match settings in the sim (`growth_every`, `defense`, SPEC §4–§5) — with the defaults (1, 0) the 2010 rules are unchanged, so all sim tests and the map corpus still hold.
- Fast stays as a Skirmish option — some players will want the arcade pace, and the plan's Iteration 4 asks for both presets.
- The 3-star test follows the coach at one move a second instead of the Greedy autopilot — under the edge the coach plays better than Greedy (Greedy now loses Pluto), and stars should measure play a person can reach.
- Two-step captures, combat in space, a "send all" shortcut and difficulty from maps go to Iteration 4 — each is a bigger rules or UI change, and the calm pace already fixed the measured problem.

### Iteration 2, round 6 (owner: "too many planets too quickly. Check Auralux for the formations")
- Training maps are hand-designed symmetric formations built by `game/training/formations.gd` (draw one side; it mirrors or rotates for the other seats) — Auralux's maps are hand-placed and symmetric with a starter cluster per home and a contested centre; random scatters had none of that.
- Planet counts 5, 6, 7, 8, 9, 10, 10, 13, 13 (was 5 … 24), at most +3 a step and capped at 13 — the owner found the ramp too steep, and research put Auralux's late maps around 12–20 suns.
- The round-5 garrison edge (2× strength) became a flat shield of 5 ships per growth level — a multiplier also doubled a planet's growth, so a big untouched planet out-grew any attacker and symmetric maps stalemated (Uranus timed out every run). A flat shield protects thin planets, which is where the churn was, without making stockpiles invulnerable; it is Auralux's fixed planet health in our terms.
- Bots and the coach pay the shield again for each separate arrival — they used to count fleets already flying as part of the next attack and trickled ships into a fresh shield; the shield now rewards one concentrated attack.
- Shield 5, not 3 or 8 — 3 let Venus, Jupiter and Pluto churn and lose; 8 dragged Uranus past 15 minutes.
- Harder worlds give you a head start (Jupiter 1.3×, Uranus 1.2×, Neptune 1.45×, Pluto 1.15×) instead of lopsided maps — a symmetric map against an equal bot is a coin flip, and Auralux's early levels lean the player's way; the maps stay fair to read.
- The 3-star test takes the coach's best of one move every 1, 1.5 and 2 s — three-player worlds swing with how the two bots fight each other, so a single pace is a noisy measure of what a quick player can reach.

