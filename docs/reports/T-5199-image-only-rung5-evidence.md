# T-5199: Rung-5 review of image-only evidence

**Status:** inception, exploring. Trigger: 832 field report on be.54.

## The problem

High-impact criteria (rung 5) are judged by a panel of three seats from three vendors. A seat
that cannot read the evidence returns `not-evaluated`, which neither blocks nor counts. The ledger
then needs at least two evaluating green seats from distinct vendors (`MIN_EVALUATING_SEATS = 2`,
lib/verdict_ledger.py:205). When the evidence is an image and only one seat kind on the host can
read images, the panel can never reach two. Every such criterion escalates to the operator, even
after the one seat that could look said green.

## What the code does today (2026-11-17)

- Vision per kind is declared in policy/review-backends.yaml (T-4944): claude `true`, codex `true`,
  antigravity `true` (T-5175, 2026-11-16), opencode `false`; ollama-loop undeclared (unknown).
  On this host, three vendors can see images (Anthropic, OpenAI, Google), so a full vision panel is
  possible here.
- The judge excludes blind kinds from the plan only when a criterion is a render or page criterion
  (lib/reviewer/judge_cli.py:1326-1336). A criterion whose evidence is an image file but which is not
  classed render/page still gets blind seats, which then return not-evaluated.
- A kind with no `vision:` entry counts as unknown, and is not excluded either.
- A seat is only credited with having seen a screenshot when its own verdict names the file
  (`_seat_named_screenshots`, lib/verdict_ledger.py:1695).

## Candidate answers

| | What | Keeps the two-vendor bar? | Cost |
|---|---|---|---|
| A | No rule change; 832 enables a second vision kind (codex or antigravity, `fw reviewer probe-vision`) | Yes | Their setup work |
| B | The planner excludes blind and unknown kinds for any criterion whose evidence is images, not only render/page; the refusal names "only N vision kinds on this host" and how to add one | Yes | Small build |
| C | Allow one vision seat to close image-only criteria at rung 5 | No | Lowers the bar for exactly the criteria that are hardest to check |
| D | When the bar cannot be met, close as a STEP-DOWN (rung 5 granted as 3) with the existing WARN | Partly | Reuses an existing, audited path; still a governance change |

## Dialogue Log

- 2026-11-17: the operator opened the conversation ("let's have that conversation"). Questions
  IW-1..IW-3 put to the operator, with the recommendation yes / yes / (a).
- 2026-11-17: 832 asked for the ruling (their operator would rather not judge T-893's screenshots
  himself). They were told the recommendation and its consequence: T-893 AC1 closes through the
  panel only once their host has a second vision kind.
- 2026-11-17: the operator, after hearing that option (b) (a lower-rung close) would unblock 832
  sooner: "Proceed as suggested and you see fit best." Outcome: keep the bar (IW-1 yes), exclude
  blind and unknown kinds from any image-evidence panel (IW-2), escalate with a how-to-add-one
  message when the bar cannot be met (IW-3 a). Candidates C and D rejected.

- 2026-11-17: GO recorded by the operator in Watchtower (commits 83676d1ac, 84b9e1cb5).
- 2026-11-17 16:03Z (recorded under build T-5209): 832 re-judged T-893 AC1 on be.55 at rung 5:
  claude-code GREEN, opencode GREEN, codex not-evaluated. Codex was not blind: its sandbox refused
  the local HTTP server and Chromium when it tried to reproduce the run. Findings for the build:
  1. **opencode green on image evidence.** AEF's registry has opencode `vision: false` (T-4944
     probe). Because the blind-kind exclusion fires only for render/page criteria, a seat that
     cannot see images was seated and counted. This is the hole B closes; 832 was asked to check
     their registry and whether the opencode verdict names the files.
  2. **"Cannot reproduce" is not "cannot view".** An image-evidence seat should judge the supplied
     images, not try to re-run the harness, and a seat that cannot reproduce must say so
     distinctly from one that cannot view.
  3. **probe-vision's default image is an AEF-only path,** so consumers cannot probe their kinds.

## Recommendation

GO on A + B (decided), with 832's findings in the build's scope (T-5209). Build slice: the judge treats any criterion whose evidence includes images like a
render/page criterion for seat planning, excludes kinds whose vision is `false` or undeclared, and
when fewer than two vision vendors remain, the refusal names the count and `fw reviewer
probe-vision` as the way to add one.
