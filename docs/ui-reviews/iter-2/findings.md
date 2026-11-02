# UI review — iteration 2 findings

First iteration with a UI review loop, so there is no previous score to compare against.

## Scores

| # | Question | Owner | Heuristic reviewer | Notes |
|---|---|---|---|---|
| 1 | Clarity of game state | ok | 2 | which colour is you; numbers unlabelled |
| 2 | Ease of sending fleets | ok, but busy | 4 | |
| 3 | Feedback on actions | ok | 3 | |
| 4 | Readability at a glance | capture too quick | 3 | count contrast 2.0–2.6:1 |
| 5 | Menu navigation | ok | 3 | |
| 6 | Visual appeal | **below 4** | 4 | done-when needs ≥ 4 from the owner |
| 7 | Audio | ok for now | n/a | done-when needs ≥ 4 from the owner |
| 8 | Onboarding | ok | 2 | |
| 9 | Performance feel | good | 3 | |
| 10 | Play again tonight | **no** | 3 | |

Reviewer scores are for the *before* build (`before/`); the owner scores the fixed build.

## Owner survey, 2026-11-02 (verbatim)

No numeric scores were given; the table above paraphrases. Answers as written:

1. ok
2. ok, but very busy from the beginning ie the levels are not clear
3. audio is fine but we might find more / themes later
4. change of sides is too quick (show one side number going down and then flipping to the other side number going up)
5. ok (icons in sliders will be better)
6. planets are not realistic (can we use real planets or stars from nasa? also backgrounds from real nasa photos, we should also create a theme later if we have enough related photos)
7. ok for now
8. ok
9. good
10. nope (not strong attraction or motivation, ie a reason to see or hear to play more)

Reference given: Auralux gameplay video (https://youtu.be/XeyRrwR6C6k).

**Done-when status:** not met. Visual appeal is below 4 (Q6) and the owner would not play a sixth game (Q10).

## Captures

- **Before fixes:** `before/`, which is what the three reviewers saw.
- **After round-1 fixes:** `round-1/` (screens, recording, frame sheet) and `a11y/`.
- **After round-2 fixes (owner survey):** `screens/`, `game.mp4`, `frames.png`.
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

## Round 2 — the owner's survey, fixed now

The owner's answers (above) failed the done-when on two counts: visual appeal under 4, and no wish to play a sixth game. Follow-up answers, 2026-11-02: "levels are not clear" meant **both** game levels and planet levels; the long-term hook is "visit a constellation … grow in skills … stars become harder"; for now, "call it training in our own solar system".

1. **No reason to play again (Q10), no clear levels (Q2).** A **Training** ladder: nine levels flying out from Earth, the Moon to Pluto, each with a one-line brief that teaches one idea. The first level has five planets and one weak bot; the last is 24 planets and two sharp commanders. You always launch from Earth and the enemy holds the named world. Wins earn 1–3 stars by time, the next world unlocks, and progress is kept on this computer. TRAINING is now the first button on the main menu; the old setup is SKIRMISH. Every level is tested winnable by a bot in your seat, inside the 3-star par.
2. **Planets are not realistic (Q6).** Planets are now **real NASA surface maps** (Earth, Mars, Jupiter, Io, Europa, Pluto … 18 worlds) on a lit, turning sphere. Owners show as a colour wash, an atmosphere halo and coloured level dots. Backgrounds are dimmed **Hubble and Webb photographs** (Cosmic Cliffs, Pillars of Creation, Carina, Whirlpool). Ship counts moved under each planet so the surface shows. Sources and credits: `game/art/CREDITS.md`, from `tools/fetch_art.py`.
3. **Captures change sides too fast (Q4).** A capture plays in two beats: the defender's count drains to zero in their colour (0.5 s), then the planet flips and counts up in yours (0.4 s). The flash, ripple and chime land on the flip.

Also fixed:

- **Planet levels (Q2).** The growth arc became 1–5 dots orbiting each planet: one dot per level, the same on every planet. Level 2's brief explains it.
- **Slider icons (Q5).** Music, Effects and Interface have drawn icons. The speaker's waves follow the volume, and clicking an icon mutes or restores that channel.

**Round-1 fix 3 revisited.** Neutral planets were hollow discs. They are now real grey rock, desaturated, with no atmosphere and grey level dots, while owned worlds always have a coloured halo. Neutral versus owned still does not depend on hue.

### Deferred from the owner's survey

| Finding | To | Why |
|---|---|---|
| Constellation campaign, skills that grow, harder stars | Iteration 5 | The plan's campaign (20 maps, bot ladder) and player powers are Iteration 5. Training is the first chapter of that campaign. |
| More audio, themes (Q3, "ok for now") | Iteration 7 | The original soundtrack with adaptive layers is Iteration 7. A photo theme per chapter can come with the constellations. |
| Themes built from related photos (Q6) | Iteration 5 | Each constellation chapter gets its own backdrop set. `fetch_art.py` already takes any NASA, ESA/Webb or ESA/Hubble image. |

## Round 3 — owner play-test, 2026-11-02

Owner, verbatim: "fix: when paused, the music continues · fix: users are allowed to pause, but not to reset (give up) · I am stuck at Mars (training). during the training stage, there should be a clear guide to "train" users to pass the planet/star". Follow-ups: RESTART in the pause menu is enough (it was hidden behind "≡"); guide style **lesson + live coach**; after repeated losses **offer an easier retry**; the player is **teens / adults, casual**.

**Why Mars was a wall.** A pace check played every world by following good advice at one move every 1–3 s. From Venus on, every world was lost: bots sent from all their planets every 0.5–1 s, while a person drags one fleet at a time. The old fairness test used a bot that reacted every tick, so it could not see this.

1. **Training coach.** Each world opens with a short lesson for one skill, and the match waits until you do it: send (Moon), levels (Mercury), send share (Venus), box-select once you own two planets (Mars), defend (Jupiter), and so on. Rings and a gold arrow on the map show where. During play the coach warns in red when a planet will fall ("Io is under attack: 30 ships incoming. Send 12 from Earth to hold it") and, after 6 s idle, points at a good move. HINT / H asks any time. Defeat screens say what to try next.
2. **Rebalanced for people.** Training commanders make one move per decision and think every 1–2 s. A new test follows the coach at one move every 2 s and must win all nine worlds with 2 stars in reach. Star times were re-set from those runs.
3. **Easier retry.** Two losses in a row on a world offer EASIER <WORLD>: the enemy thinks one notch slower and your home fleet is 1.5×. A win is worth 1 star and opens the next world.

Also fixed: pausing fades the music out and holds its place (it comes back on resume, or when you leave a paused game); the in-game menu button reads "≡ MENU".
