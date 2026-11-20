# T-5310 — Standing risk arc

**Status:** EXPLORING. Inception opened 2026-11-20 on ring20's proposal (msg a6cdde77, relaying the operator).

## Trigger

ring20 created a standing arc "risk" (their arc-012, never closed) and used a 14-risk matrix to assess their pool's "option B" (their T-2794). The operator noted AEF has a risk process that is not actively used and wants it revived in this form.

## What AEF has today

- `.context/project/concerns.yaml` supports `type: risk`, but only 5 risks exist (R-018, R-024, R-032, R-036, R-037), against 136 gaps. No likelihood or impact score, no rule that a risk gets a mitigation task, no "introduced by this change?" question.

## ring20's template (msg c06b5f30, 2026-11-20)

One matrix per change being assessed. Header: the change, and the baseline it is compared with.

**Scales.** Likelihood 1 rare, 2 unlikely, 3 possible, 4 likely, 5 almost certain. Impact 1 negligible, 2 minor, 3 moderate (one job or result wrong), 4 major (token stolen or data leaked, contained), 5 severe (node or network compromised, accounts lost). Score = L × I, 1-25. Bands: low 1-5, medium 6-12, high 15-25.

**Summary table columns:** # | risk | domain | how to detect the door is open | how to detect it happening | impact | likelihood | exists anyway (baseline)? | introduced by the change? | key mitigation.

**Per risk, actor split:** # | actor (own agent unintentional / human unintentional / outsider intentional / provider-host / intruder) | how | L | I | score | mitigated L × I | mitigated score.

**Rule:** every risk with any actor scoring 6 or more gets a mitigation task in the standing risk arc. The decision on a change rests on what it INTRODUCES, not on risks that exist anyway.

## Worked example: ring20 T-2794, option B

Option B: a model with write tools and a shell in a sandbox on a pool node; the diff comes back to .107 for review. Worst unmitigated → mitigated score, and whether the change introduces it:

| # | Risk | Score | New? |
|---|------|-------|------|
| 1 | prompt injection | 12 → 5 | no, reduced (sandbox) |
| 2 | login token theft | 9 → 2 | no |
| 3 | data sent out | 6 → 3 | no, reduced |
| 4 | sandbox escape | 8 → 3-4 | NEW, small |
| 5 | reach into the LAN | 8 → 2-4 | no, reduced |
| 6 | backdoor in the diff | 12 → 4-6 | no (volume) |
| 7 | gamed tests | 12 → 2 | no, easier to block |
| 8 | runaway job | 9 → 1-3 | no, reduced |
| 9 | subscription burn | 12 → 2-4 | PARTLY NEW (scale) |
| 10 | leftovers between jobs | 6 → 2-3 | no, reduced |
| 11 | dependencies from the internet | 12 → 2-3 | no, reduced |
| 12 | no audit trail | 9 → 2-4 | PARTLY NEW (unattended) |
| 13 | provider terms | 10 → 6 | PARTLY NEW (scale) |
| 14 | wrong code merged | 9 → 4-6 | no |

Net: the change adds scale, unattended running and the sandbox boundary. The five controls it needs: a token proxy, a tamper-proof command log reviewed with the diff, read-only tests, a per-job token budget, and checking provider terms.

Actor split for risk 1: own agents unintentional 3×4=12 → 2×2=4; human unintentional 2×3=6 → 1×2=2; outsider via planted web text 3×4=12 → 1×2=2; hosting provider 1×5=5 → 5 (not introduced); node intruder 2×5=10 → 5 (not introduced).

## ring20's view on the open questions

- Risks live in the concerns register (type risk) with the score fields; mitigation tasks join the standing arc.
- A matrix is required for any change that alters a trust boundary: new sandbox, new credential use, new network path, new unattended automation.
- The agent drafts and scores; the operator confirms the scores in a walkthrough, one risk at a time.

## Dialogue Log

- 2026-11-20, ring20 (relaying the operator): proposal and questions (msg a6cdde77).
- 2026-11-20, agent: filed T-5310, asked for the template; ring20 sent template, worked example and their view (msg c06b5f30).

## Reflection and challenge (agent, 2026-11-20)

**For it.** It fills a real hole: changes that cross a trust boundary (new review seats, sandboxes, hooks that run unattended, new routes to the hub) are discussed in task text and then forgotten. Today alone produced two such cases (T-5309 attaches screenshots to codex; T-5300 lets a submitter withdraw a pool job). "Introduced by this change, or there anyway?" is the strongest part: it stops a change being blocked for risks it does not add, and it stops a change hiding a risk it does add.

**Against it, or where to be careful.**
- *Cost.* A 14-row matrix for every change would bury real work. ring20's trigger (only changes that alter a trust boundary) keeps it rare; the trigger must be written so an agent can tell.
- *Operator load.* ring20's operator confirmed every score in a walkthrough. Today the operator pushed back hard on being asked to rubber-stamp screenshots. Scores are judgement, but most are not risk acceptance. Proposed split: the agent drafts and scores; an independent reviewer agent checks the scores and the actor split (as for other reviewer-judged criteria); the operator decides only what is risk acceptance: a NEW risk that stays at 6 or more after mitigation, or anything high (15+).
- *Fake precision.* L × I invites arguing about 3 versus 4. The bands and the "new?" column carry the decision; the exact number matters less. Keep the scale, do not build machinery on exact scores.
- *Register drift.* AEF's gaps register works because audit reads it. A risk with score 6+ and no mitigation task must show in `fw audit`, or the arc becomes the next unused process.

**Fit with AEF.** Risks stay in `.context/project/concerns.yaml` (type risk) with added fields: likelihood, impact, actors (per-actor L/I and mitigated L/I), introduced_by (task), exists_anyway, mitigation_task. One standing arc "risk" that never closes holds the mitigation tasks. A matrix template under `.tasks/templates/` or `docs/templates/`. Consumers get template, fields and the audit check through `fw upgrade`.
