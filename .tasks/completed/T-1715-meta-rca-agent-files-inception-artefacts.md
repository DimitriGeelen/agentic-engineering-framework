---
id: T-1715
name: "Meta-RCA: agent files inception artefacts without ## Recommendation block, forcing human to decide on incomplete advisory (T-679 rule recurring violation)"
description: >
  Inception: Meta-RCA: agent files inception artefacts without ## Recommendation block, forcing human to decide on incomplete advisory (T-679 rule recurring violation)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [meta-RCA, governance-rule-decay, T-679-family, recurring]
components: []
related_tasks: [T-679, T-1259, T-1260, T-1713, T-1714]
created: 2026-05-04T08:13:50Z
last_update: 2026-05-04T09:56:18Z
date_finished: 2026-05-04T09:56:18Z
---

# T-1715: Meta-RCA: agent files inception artefacts without ## Recommendation block, forcing human to decide on incomplete advisory (T-679 rule recurring violation)

## Problem Statement

This session, in the same conversation:
- T-1709 filed as inception → full `## Recommendation: GO` block with
  rationale + evidence + risk acknowledged.
- T-1713 filed as inception → NO `## Recommendation` block.
- T-1714 filed as inception → NO `## Recommendation` block (caught and
  added retroactively after human pushback).

CLAUDE.md §"Presenting Work for Human Review (T-679)" is explicit:

> "Write your recommendation into the task file — Add a `## Recommendation`
> section (Watchtower reads this) with: **Recommendation:** GO / NO-GO /
> DEFER, **Rationale:** Why, **Evidence:** Bullet list."
>
> "You are the advisory. The human is the decision-maker. Never present
> a blank decision for them to fill in — always tell them what you
> recommend and why."

The agent applied the rule on T-1709 and skipped it on T-1713 + T-1714
in the same session. The human caught T-1714 and pushed back ("no
recommendation, no rationality on t1714"). The pattern is established;
the rule isn't being applied consistently.

For whom: any human reviewing inception/decision artefacts via Watchtower
or task files. Why now: human pushback is the cost ceiling for "rule
exists in CLAUDE.md as advisory text but isn't structurally enforced" —
T-1550 codified this exact failure mode (L-300: "Behavioral rules in
CLAUDE.md (advisory text) fail to fix recurring patterns"). T-1715 is
the structural-enforcement inception for the T-679 rule specifically.

## RCA

**Symptom:** Agent files inception artefacts (`workflow_type: inception`,
`status: captured`) without a `## Recommendation` block. Human reviewing
via Watchtower or chat sees `Decision: pending` with no advisory
context. Forced to either ask the agent to fill it in (this session)
or fill it in themselves (T-1679 origin incident).

**Root cause:** The T-679 rule lives in CLAUDE.md §"Presenting Work for
Human Review" as advisory prose. It is enforced ONLY at the
`fw inception decide` boundary (T-1259/T-1260 added refusal under
`$CLAUDECODE=1`). At the inception-FILING boundary (`fw inception start`
or `fw work-on --type inception`), there is no equivalent gate. The
agent can file an inception, set `status: captured`, walk away, and
Watchtower will display it for review with an empty Recommendation.

The deeper structural enabler: CLAUDE.md is the agent's prompt context.
Rules in advisory prose compete with task-specific cognitive load. When
the agent is mid-conversation and the user says "incept this", the
agent reaches for `fw inception start`, fills the structured sections
(Problem Statement, Plan, Constraints, Scope Fence, Go/No-Go), and
considers the artefact "filed". The Recommendation block is templated
at the bottom and easy to skip when the agent's working memory is on
"finish the structured sections so the user can decide". L-300 is
exactly this class of failure.

**Why structurally allowed:** Three doors all open simultaneously:
  1. `fw inception start` does not check the resulting artefact for a
     non-template Recommendation section.
  2. `fw work-on --type inception` (which created T-1713) likewise has
     no check.
  3. The inception template ships with `## Recommendation` as a
     comment-block placeholder that LOOKS filled-out from a glance —
     making the agent feel "the section exists" without verifying
     non-comment content.
There is no audit cron check counting inception tasks lacking
non-template Recommendation. There is no PreToolUse hook on git commit
that lints the new artefact. There is no Watchtower badge that flags
"Recommendation empty".

**Prevention:** Pick one (or stack):
  1. **Filing-time gate.** `fw inception start` requires `--recommendation
     "GO|NO-GO|DEFER"` and `--rationale "..."` flags at create time,
     mirroring T-1668 `--headline-mechanic` for arc create. Captures the
     agent's initial advisory at the moment evidence is freshest.
  2. **Pre-review-link gate.** `fw task review T-XXX` for an inception
     task refuses if the Recommendation section is empty/template-only,
     pointing the agent at how to add it. Mirrors the T-1259 gate at
     `fw inception decide`.
  3. **Audit detective.** Daily cron check enumerates active inception
     tasks; flags any with empty Recommendation as drift. Discovery of
     the pattern with daily granularity rather than per-incident.
  4. **Watchtower visual gate.** /inception/T-XXX page shows
     "Recommendation: <empty>" in red banner instead of just rendering
     nothing. Forces the agent (and the human) to see the gap.

T-1715 explores which combination is right.

## Assumptions

A1. The pattern is real and recurring beyond this session. Verifiable by
    `git log --diff-filter=A --name-only` for `.tasks/active/T-*.md`
    inceptions, then grepping each for `## Recommendation` non-template
    content. Sample size N≥10.
A2. The advisory-text-fails-to-fix pattern (L-300) applies: making the
    rule more prominent in CLAUDE.md will NOT fix recurrence. Only
    structural enforcement will.
A3. The cheapest fix (filing-time gate, prevention path 1) catches the
    pattern at minimum cost — agent has the recommendation context at
    `fw inception start` time better than at any later point.
A4. No legitimate use case for filing an inception WITHOUT an initial
    recommendation. If the agent doesn't have enough evidence to even
    say "DEFER pending more info", the inception isn't ready to file.

## Exploration Plan

Three time-boxed spikes, 1 session each:

1. **Pattern survey spike** — `git log --diff-filter=A --name-only
   --pretty=format: -- .tasks/active/T-*.md` since 2026-01-01. For each
   inception task, check if the original commit had a non-template
   `## Recommendation` block. Compute drift rate. Test A1.
2. **CLAUDE.md effectiveness spike** — Look at L-300 evidence (T-1550
   completion gate replaced advisory rule that failed for months).
   Quantify: how long was T-679 advisory before T-1259/T-1260 structural
   gate? How much drift in that window? Test A2.
3. **Filing-time gate spike** — Prototype `fw inception start
   --recommendation GO --rationale "..."` flag, enforced at create. Show
   the artefact with non-template Recommendation block written from the
   flag values. Verify it composes with `fw work-on --type inception`.
   Test A3 + A4.

## Technical Constraints

- The fix must NOT block legitimate workflows where the agent legitimately
  doesn't yet have advisory context (e.g. captured-during-meeting,
  user-typed-incept-this-thing). For those cases the recommendation
  flag should accept "DEFER" with rationale "captured for later
  exploration; advisory pending discovery".
- Mirror existing gate patterns (T-1668, T-1259, T-1671) so the
  enforcement contract is consistent across arcs and tasks.
- The gate must be bypassable for scripted/migration cases, with the
  bypass logged to existing Tier 2 mechanism.

## Scope Fence

IN scope:
- RCA confirmed/refined by spike data.
- Pick one (or a stacked combination) of the 4 Prevention paths.
- Estimate cost (LOC + risk + agent-prompt update + migration).
- Decision: GO (pick path), NO-GO (advisory text was good enough),
  DEFER (fold into a larger meta-governance inception).

OUT of scope:
- The build itself. T-1715 is inception only.
- Generalising to other CLAUDE.md advisory rules. Stay focused on the
  T-679 Recommendation-block rule. Other recurring rule decay (e.g.
  bug-class RCA section, AC classification compliance) gets its own
  meta-RCA inception if needed.
- Backfilling Recommendation blocks on historical work-completed
  inceptions. Forward-only.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Pattern survey confirms drift rate ≥30% on inception filings (T-1713,
  T-1714 alone make this almost certain).
- Filing-time gate spike produces a working `--recommendation` /
  `--rationale` flag pair on `fw inception start` with bounded LOC.
- L-300 evidence holds: making the rule more prominent in CLAUDE.md is
  insufficient; structural enforcement is necessary.

**NO-GO if:**
- Drift rate is <10% across the survey AND existing CLAUDE.md prominence
  fixes catch the rest → advisory was working, this session was an
  outlier. (Strongly unexpected — three explicit failures this session.)
- The filing-time gate forces all inception filings into a "decide now"
  shape that breaks legitimate captured-for-later use → friction exceeds
  value.

**DEFER if:**
- The broader "CLAUDE.md advisory rules decay" pattern (L-300, also
  evidenced in bug-class RCA decay before T-1550) warrants a single
  meta-meta-inception covering the whole class rather than per-rule
  fixes. Fold T-1715 into that.

## Recommendation

**Recommendation:** GO

**Rationale:**

Three convergent reasons:

1. **In-session evidence is overwhelming.** Same session, same agent,
   same conversation: T-1709 included the Recommendation block; T-1713
   skipped it; T-1714 skipped it and had to be retrofitted after human
   pushback. The rule was applied 1/3 times in 30 minutes despite being
   in active CLAUDE.md context. L-300 ("advisory text fails to fix
   recurring patterns") generalises here cleanly.

2. **The fix mirrors existing structural-gate patterns.** T-1668 added
   `--headline-mechanic` at `fw arc create`; T-1671 added CLAUDECODE
   refusal at `fw arc close`; T-1259/T-1260 added the `fw inception
   decide` agent-refusal gate. T-1715's filing-time gate is the missing
   left-bracket of the pair: agent sets `--recommendation` /
   `--rationale` at filing, human decides at decide-time. Symmetric.

3. **Cost is bounded; alternative is recurrence.** Path 1 (filing-time
   gate) is ~50 LOC in `lib/inception.sh do_inception_start` plus
   `fw work-on --type inception` plumb-through. Path 4 (Watchtower
   visual gate) is templated banner — ~10 LOC. Either one closes the
   pattern. Without structural enforcement, every future "incept this"
   instruction has a >50% chance of producing a Recommendation-less
   artefact.

**Evidence:**

- This session's git log: T-1713 (commit `22156caf9`) and T-1714
  (commit `eb8a73e34`) both filed without `## Recommendation` block;
  T-1714 retrofitted after human caught it (commit pending). T-1709
  (commits `bcaf582b2` + `31e885427`) shipped with full block.
- CLAUDE.md §"Presenting Work for Human Review" carries the rule
  explicitly: "never present a blank decision for them to fill in."
- L-300 (from T-1550): "Behavioral rules in CLAUDE.md (advisory text)
  fail to fix recurring patterns. Need structural enforcement."
- T-1259/T-1260 prior: same shape (T-679 rule structurally enforced
  at `fw inception decide` time). T-1715 closes the symmetric gap at
  the filing time.
- The inception template ships with Recommendation as a comment-block
  placeholder, which the agent skims as "section exists" without
  verifying non-comment content. Visible in
  `.tasks/templates/zzz-default.md` (or equivalent).

**Risk acknowledged:**

- The filing-time flag may force premature recommendation in cases where
  the agent legitimately doesn't yet have the evidence. Mitigation:
  accept "DEFER" with rationale "captured for later, advisory pending
  exploration" — that IS a valid recommendation.
- Adding required flags to `fw inception start` breaks any external
  scripts that don't pass them. Mitigation: emit a clear error message
  with the new flag syntax; provide a one-session migration window
  before hard-enforcement (warn-then-block).
- Recurrence of the meta-pattern itself (other CLAUDE.md rules decaying
  similarly) is the bigger worry. Mitigation: T-1715 NO-GO/DEFER paths
  explicitly route to a meta-meta-inception if drift is broader.

## Post-Decision Amendment — 2026-05-04 (sweep finding)

After T-1715 was decided GO at 09:56 UTC, the human's next-session
sweep flagged T-1710 + T-1713 *still* missing real Recommendation
blocks (template-only). Pattern continued firing post-RCA-filing.

**Meta-meta-lesson:** Filing an RCA inception is itself subject to the
§ACD substrate-vs-deliverable pattern (G-066). The RCA is substrate
(future-prevention proposal); the actual deliverable (zero in-flight
inceptions in the queue with template-only Recommendation blocks) was
never produced. Filing T-1715 was treated as the corrective action.
T-1714 was retrofitted only because the human named it specifically;
T-1710 and T-1713 — filed earlier in the same arc — were never swept.

**Sub-causes identified:**
1. **No sweep-on-RCA-filing.** When T-1715 was filed, the agent did
   not enumerate `.tasks/active/T-*.md` for inceptions matching the
   pattern and retrofit them.
2. **Local fix instead of class fix.** When retrofitting T-1714, the
   agent had hard evidence the pattern was recurring (T-1715's own
   dialogue table cited T-1713). It did not generalise.
3. **Watchtower has no visual marker** distinguishing real vs template-
   only Recommendation. Template-only inceptions look identical in the
   inception list to ones with real Recommendations.
4. **Handover emits URLs without validating Recommendation presence.**
   "Awaiting Decision" list passes any inception with the
   `## Recommendation` heading regardless of body.

**Added prevention paths (extending Section 6 above):**

- **Path 5 — Sweep step (immediate, manual).** When this RCA is
  filed/decided, the agent MUST scan all active inceptions for
  template-only Recommendation blocks and retrofit them, before
  declaring the RCA complete. Performed manually 2026-05-04 during
  this amendment: T-1710 + T-1713 retrofitted in the same commit.
- **Path 6 — Audit detective (continuous).** `fw audit` should add
  a check: any active inception with `## Recommendation` whose body
  is template-only (matches `<!-- REQUIRED before fw inception
  decide`) emits a WARN. Catches drift between sweeps.
- **Path 7 — Watchtower visual marker.** Inception list page should
  show a "no recommendation" badge when the Recommendation body is
  template-only. Closes the handover-emit blind spot.
- **Path 8 — Retroactive retrofit on structural shipment.** When the
  filing-time gate (Path 1) ships, it should ALSO sweep existing
  inceptions in `active/` and either retrofit (DEFER with rationale
  "captured pre-gate, no exploration done") or flag for human review.
  Forward-only enforcement leaves the existing pile broken.

**Generalisation:** L-300 ("advisory text fails → need structural
enforcement") needs an addendum: "even *filing* a structural-
enforcement RCA fails if the immediate sweep is missing." Filing the
RCA is not the corrective action; the corrective action is the
sweep + the structural fix together.

## Decisions

<!-- Filled at completion via: fw inception decide T-XXX go|no-go|defer --rationale "..." -->

## Verification

# Inception — no shell verification required.

## Updates

<!-- Auto-populated. -->

### 2026-05-04T08:17:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-04T09:56:17Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Three convergent reasons:

1. **In-session evidence is overwhelming.** Same session, same agent,
   same conversation: T-1709 included the Recommendation block; T-1713
   skipped it; T-1714 skipped it and had to be retrofitted after human
   pushback. The rule was applied 1/3 times in 30 minutes despite being
   in active CLAUDE.md context. L-300 ("advisory text fails to fix
   recurring patterns") generalises here cleanly.

2. **The fix mirrors existing structural-gate patterns.** T-1668 added
   `--headline-mechanic` at `fw arc create`; T-1671 added CLAUDECODE
   refusal at `fw arc close`; T-1259/T-1260 added the `fw inception
   decide` agent-refusal gate. T-1715's filing-time gate is the missing
   left-bracket of the pair: agent sets `--recommendation` /
   `--rationale` at filing, human decides at decide-time. Symmetric.

3. **Cost is bounded; alternative is recurrence.** Path 1 (filing-time
   gate) is ~50 LOC in `lib/inception.sh do_inception_start` plus
   `fw work-on --type inception` plumb-through. Path 4 (Watchtower
   visual gate) is templated banner — ~10 LOC. Either one closes the
   pattern. Without structural enforcement, every future "incept this"
   instruction has a >50% chance of producing a Recommendation-less
   artefact.

## Reviewer Verdict (v1.4)

- **Scan ID:** R-b8a351f1
- **Timestamp:** 2026-05-04T09:56:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-04T09:56:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
