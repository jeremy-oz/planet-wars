# UI review — iteration 2 findings

First iteration with a UI review loop, so there is no previous score to compare against.

## Scores

| # | Question | Owner | Heuristic reviewer | Notes |
|---|---|---|---|---|
| 1 | Clarity of game state | _pending_ | 2 | which colour is you; numbers unlabelled |
| 2 | Ease of sending fleets | _pending_ | 4 | |
| 3 | Feedback on actions | _pending_ | 3 | |
| 4 | Readability at a glance | _pending_ | 3 | count contrast 2.0–2.6:1 |
| 5 | Menu navigation | _pending_ | 3 | |
| 6 | Visual appeal | _pending_ | 4 | done-when needs ≥ 4 from the owner |
| 7 | Audio | _pending_ | n/a | done-when needs ≥ 4 from the owner |
| 8 | Onboarding | _pending_ | 2 | |
| 9 | Performance feel | _pending_ | 3 | |
| 10 | Play again tonight | _pending_ | 3 | |

Reviewer scores are for the *before* build (`before/`); the owner scores the fixed build.

## Captures

- **Before fixes:** `before/`, which is what the three reviewers saw.
- **After fixes:** `screens/`, `game.mp4`, `frames.png` and `a11y/`.
- **Reviews:** in `reviews/`: heuristic, accessibility, first-time player.

Two reviewer findings were capture artefacts, not game bugs:

- **Forced ending.** The script forced a "victory" at 0:18.
- **Default setup screenshot.** The setup screenshot showed default settings while the recorded match had 3 opponents.

The capture now plays a real game to victory and to defeat, and shows the setup for the recorded match.

## Top three, fixed now

1. **"Which planet is mine?"** All three reviewers raised it.
   - A bobbing **YOU** marker sits above your planets until your first send.
   - The HUD reads **you 114**.
   - The first-game tip says "you are blue … take them all to win".
2. **Ship-count contrast.** It measured 2.0:1 on gold, 2.3:1 on blue and 2.6:1 on green.
   - Owned planet bodies are now 62 % of the player colour, and every count has a dark outline. That gives about 4.6–4.8:1 before the outline helps.
   - Neutral counts are lighter (#C9D0DE).
3. **Colour-blind players confuse a player colour with neutral.** Under deuteranopia and protanopia, pink collapsed to the neutral grey.
   - Neutral planets are now **hollow**: a dark core with a bright rim. Neutral versus owned no longer depends on colour.

Also fixed, because two reviewers raised it as the main reason a new player loses ships without knowing why:

- **Attack preview.** While aiming, the target shows **"37 vs 45 · not enough"** in red, or **"· takes it"** in green. Enemy defenders include their growth during the trip. Your own planets show "+N reinforce".

## Deferred, and why

| Finding | To | Why |
|---|---|---|
| Opponent colours too similar for colour-blind players (pink ≈ green under deuteranopia), per-player symbols | Iteration 4 | Colour-blind palettes are explicitly in Iteration 4's scope. Neutral vs owned is fixed now. |
| Tutorial / how-to-play, explaining rings and growth | Iteration 4 | Three guided tutorial maps are Iteration 4's scope. The hint line and attack preview cover the basics now. |
| Reduced-motion setting | Iteration 7 | Accessibility pass. The renderers already have a `reduced_motion` switch, which only needs a settings toggle. |
| Planet hit targets under 44 px | Iteration 4 | Hit-testing already adds 14 screen px around every planet. Revisit with touch play on iPad in Iteration 6. |
| "Under attack" / "planet lost" alerts | Iteration 4 | Game-feel pass ("impact frames, UI micro-interactions"). |
| Jargon on setup ("Greedy", "Map seed") | Iteration 4 | Map seeds as shareable strings and difficulty presets are redesigned there. |
| Fleet clutter on huge maps | Iteration 7 | Art pass. Fleets are now GPU-drawn, so LOD is cheap to add later. |
| Confirmation before Restart / Main menu | Iteration 4 | Low risk in single-player. Needed once games are online. |
