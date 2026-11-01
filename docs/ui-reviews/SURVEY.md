# Player survey — UI review loop

Ten fixed questions, asked at the end of every iteration from 2 onward, answered 1–5
(1 = poor, 5 = excellent) plus optional free text. The questions never change so scores are
comparable across iterations. Scores must not drop on any question without a written reason in
that iteration's `findings.md`.

Answer after playing at least two full games on the build under review.

| # | Question | Score 1–5 | Notes |
|---|---|---|---|
| 1 | **Clarity of game state.** At any moment, can you tell who owns what and who is winning? | | |
| 2 | **Ease of sending fleets.** Is selecting a source and target effortless, including partial sends? | | |
| 3 | **Feedback on actions.** When you do something, does the game clearly acknowledge it (visually and audibly)? | | |
| 4 | **Readability at a glance.** Can you read ship counts, rings and fleets without squinting or leaning in? | | |
| 5 | **Menu navigation.** Are menus, settings and pause quick and obvious? | | |
| 6 | **Visual appeal.** Does it look like a finished indie game you would show a friend? | | |
| 7 | **Audio.** Do the music and sounds fit, help, and never annoy? | | |
| 8 | **Onboarding.** Could a new player learn the controls in 30 seconds without instructions? | | |
| 9 | **Performance feel.** Smooth and responsive, no hitches, on your machine? | | |
| 10 | **Would you play again tonight?** | | |

Free text:

- What was the single most annoying thing?
- What was the single best moment?
- Anything you expected to be able to do but couldn't?

## Process

1. `tools/capture.py --iteration N` saves screenshots and a 60 s recording to `docs/ui-reviews/iter-N/`.
2. This survey is filled in by the owner (every iteration) and by playtesters (optional in 3, expected from 4).
3. Reviewer agents with no memory of building the iteration get the captures and the ten questions.
4. `docs/ui-reviews/iter-N/findings.md` records scores vs the previous iteration, the top three issues,
   what is fixed now and what is deferred (and why).
5. The top three are fixed and re-captured before the PR opens.
