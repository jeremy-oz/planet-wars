# Planet Wars — style guide

One visual and audio direction, chosen before any gameplay UI exists. Every screen is judged against
this document in the UI review loop. The Godot theme that encodes it is
`game/theme/planet_wars_theme.tres`; if the two disagree, this document wins and the theme gets fixed.

## 1. Direction in one line

**Quiet space, living light.** Auralux's minimalism (a dark void, pure circles, nothing that is not
information) plus Eufloria's softness (glow, breathing, organic ease — nothing snaps, nothing is hard).
The game should feel like a calm instrument you play, not a dashboard you operate.

Mood board: `docs/moodboard/` (eight rendered references, see §8).

## 2. Palette

Dark space, four player colours plus neutral. The player set is derived from the Okabe–Ito
colour-blind-safe palette and checked for deuteranopia, protanopia and tritanopia separation.
Never encode player identity by colour alone where it matters (ownership is also shown by ring
style and, later, by an optional symbol overlay in the colour-blind setting).

| Role | Name | Hex | Use |
|---|---|---|---|
| Background | Void | `#070A14` | the one true background; nothing darker exists |
| Surface | Deep | `#0F1424` | panels, overlays (at 85 % alpha over Void) |
| Surface raised | Slate | `#171D33` | buttons at rest, inputs |
| Line | Rim | `#2A3352` | 1 px rims at 60 % alpha; never a fully opaque border |
| Text | Ice | `#ECF1FA` | primary text, selection rings, focus |
| Text secondary | Mist | `#9AA6C0` | captions, labels, inactive |
| Text muted | Dusk | `#5E6A86` | hints, disabled |
| Player 1 | Sky | `#56B4E9` | |
| Player 2 | Amber | `#E69F00` | |
| Player 3 | Orchid | `#CC79A7` | |
| Player 4 | Mint | `#1FBF95` | Okabe–Ito bluish-green, lifted for a dark background |
| Neutral | Ash | `#8D97AB` | unowned planets |
| Danger | Ember | `#FF6B5C` | only for destructive confirmations (quit, leave game) |

Players 5–8 (Iteration 3) extend the set with Okabe–Ito yellow `#F0E442`, vermilion `#D55E00`,
blue `#0072B2`, and a desaturated lilac `#B8A9E8`, in that order.

Glow is always the entity's own colour at 25–40 % alpha, radius 1.6–2.2× the shape. Text is never
coloured by player except in ship-count labels on that player's planets.

Contrast (WCAG, on Void): Ice 17.4:1, Mist 8.1:1, Dusk 3.7:1 (hints only, ≥ 18 px), Sky 8.6:1,
Amber 8.8:1, Orchid 6.5:1, Mint 8.4:1, Ash 6.7:1, Ember 7.1:1 — all body text ≥ 4.5:1.

## 3. Typography

| Role | Font | Weight | Size (1600×900 design) | Tracking |
|---|---|---|---|---|
| Display title | **Exo 2** | 600 | 88 | +8 % , uppercase |
| Heading | Exo 2 | 600 | 36 | +4 %, uppercase |
| Ship count on planets | Exo 2 | 500 | 22 (scales with planet) | 0 |
| Body / UI | **Inter** | 400 | 18 | 0 |
| Button | Exo 2 | 600 | 20 | +6 %, uppercase |
| Caption | Inter | 400 | 14 | 0, Mist |

Exo 2 (OFL) carries the sci-fi tone without being retro; Inter (OFL) disappears into the UI. No third
font, ever. Both are variable fonts in `game/fonts/`. Minimum rendered size anywhere: 14 px.

## 4. Shape language

- **Circles.** Planets, selection rings, growth rings, fleet dots, radio dots, sliders' grabbers.
- **Pills.** Buttons and chips are full-radius pills (corner radius ≥ half height).
- **Soft rectangles.** Panels: radius 16, Deep at 85 % alpha, 1 px Rim at 60 %, a 24 px blurred shadow
  in Void at 50 %. Think frosted glass over space, not a window.
- **No hard edges.** No 1 px opaque borders, no square corners, no drop shadows with hard offsets.
- **Planets.** *(Changed in Iteration 2, round 2, at the owner's request: "real planets".)* A real
  surface map (NASA; see `game/art/CREDITS.md`) on a sphere lit from the upper left, turning slowly.
  Owned worlds take a 30 % wash of the owner colour, a soft atmosphere halo and a limb glow in that
  colour; neutral worlds are desaturated grey rock with a faint Ash rim and no halo. You are always
  Earth; enemy homes are other planets; neutral levels 4–5 are planets, 1–3 are moons. Size scales
  with level: radius `0.42 + 0.13 × growth` map units (40 px per unit at 1× zoom), capped at 0.36 ×
  the distance to the nearest neighbour so planets never touch. Lines never get thinner than 2 px.
- **Level dots.** One dot per level (1–5) on a faint orbit just outside the planet, in owner colour
  (Ash for neutral), orbiting slowly. Replaces the growth arc: a count of dots reads as "level 3"
  where an arc's length did not.
- **Ship counts.** Under the planet, below the orbit (and below the selection ring when selected),
  Ice on owned and #C9D0DE on neutral, with a dark outline. 15 px minimum on screen.
- **Backdrops.** Hubble/Webb photographs, cover-fitted, at about 20 % brightness, drifting very
  slowly, under the parallax star layers.
- **Fleets.** Streams of 2–4 px dots in owner colour behind a soft glowing head, with a faint additive
  trail along a gentle curve. Size reads as strength: one dot per ship (up to 80), and width, length,
  dot size and head glow grow with √ships, so 2 ships are a faint wisp and 100 a wide bright swarm.
  Drawn on the GPU.
- **Selection.** Ice ring, 2 px, 6 px outside the planet; pulses 1.0→1.06 over 1.2 s while selected.
- **Hover.** Halo brightens 20 %, ring appears at 50 % alpha in 120 ms.
- **Captures.** Two beats: the count drains to zero in the defender's colour (0.5 s, smoothstep),
  then the colour flips with flash, ripple, pop and chime, and the count rises in the attacker's
  colour (0.4 s, ease-out).

## 5. Motion

- Every state change animates. Nothing teleports: ship counts tween, ownership cross-fades, panels
  slide 12 px and fade, menus stagger 40 ms per item.
- Durations: **150 ms** for micro feedback (hover, press), **220 ms** for state changes (count, ring),
  **300 ms** for screen transitions. Never longer than 400 ms for anything the player waits on.
- Easing: ease-out cubic for things appearing or responding to input; ease-in-out sine for things
  moving on their own (fleets, breathing). Overshoot (back ease, 1.1×) only on capture pops.
- Idle: planets breathe (scale 1.00→1.02, 4 s, sine); halos drift (alpha ±5 %, 6 s).
- Impact: capture = flash to Ice 80 ms, ripple ring expanding 2.5× over 400 ms, 2–6 px screen shake
  scaled to ships involved; launch = brief squash (0.94) then dots burst out.
- **Reduced motion** setting removes shake, breathing and parallax, keeps 150 ms fades.

## 6. Audio direction

- **Key and scale.** Everything musical is in **C major pentatonic** (C D E G A) so any overlap is
  consonant, Auralux-style. Capture chimes pick a note by planet size (bigger = lower).
- **Ambient pad.** A slow, warm pad in the same key, two layers (calm / tension) crossfaded by the
  share of ships in flight. −18 LUFS, never attention-grabbing.
- **Fleet launch.** Filtered-noise whoosh, 300 ms, pitched down for larger fleets.
- **Arrival / combat.** Soft low thud + a short shimmer in the winner's note.
- **UI.** Short sine ticks (5 ms attack, 60 ms decay); hover is 6 dB quieter than click.
- Separate music / effects / UI sliders; defaults 70 / 80 / 60 %. Nothing plays before the main menu
  has fully faded in.

## 7. Layout and UI rules

- Design canvas 1600×900, `canvas_items` stretch, `expand` aspect; safe area inset 32 px; touch
  targets ≥ 44 px; all controls reachable by keyboard (Iteration 4) — plan for it now.
- The map is the UI. HUD elements float as glass pills at the edges; nothing covers the centre.
- At most one accent at a time: the thing you can act on is Ice; everything else is Mist/Dusk.
- Copy is lowercase-calm in body, uppercase-wide in headings and buttons, never shouty in both.
- Empty states and errors use the same voice: short, kind, specific ("Lost the server. Rejoining…").

## 8. Mood board

`docs/moodboard/01–08` were rendered locally (FLUX.2-klein, Apache-2.0) from this guide so that the
references are ours to keep in the repo; they stand in for Auralux / Eufloria screenshots, which we do
not redistribute. Read them in order: the void → planets in the palette → the growth ring → fleet
streams → a capture ripple → Eufloria-style softness → a playable background → the glass HUD.

## 9. HUD (Iteration 2)

Matches the signed-off mock: player totals with a share bar top-left; clock, speed, pause and menu
top-right; send share (25/50/75/100 %) bottom-centre with a one-line contextual hint above it that
always says what the next click will do. A first-game tip sits top-centre until the first send.

## 10. Static design (Iteration 0 sign-off)

`docs/design/main_menu.png` and `docs/design/game_screen.png` are rendered from the static scenes
`game/ui/main_menu_static.tscn` and `game/ui/game_screen_mock.tscn` using the theme. Re-render with
`make design`. No gameplay UI is built until these are signed off.
