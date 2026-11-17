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

## Recommendation

GO on A + B. Build slice: the judge treats any criterion whose evidence includes images like a
render/page criterion for seat planning, excludes kinds whose vision is `false` or undeclared, and
when fewer than two vision vendors remain, the refusal names the count and `fw reviewer
probe-vision` as the way to add one.
