---
id: T-2122
name: "arc-close agent recommendation+rationale codification"
description: >
  Codify on arc-close (same pattern as task close): agent provides Recommendation
  block with verdict + rationale + evidence. _anchor_recommendation already reads
  from anchor-task ## Recommendation but the arc itself may warrant its own scope-of-closure
  recommendation distinct from the anchor inception's. Options A-D for build path;
  decide on GO.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-05-30T20:37:50Z
last_update: 2026-05-30T21:32:15Z
date_finished: 2026-05-30T21:32:15Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-30T20:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-30T20:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2122: arc-close agent recommendation+rationale codification

## Problem Statement

User trying to close arc-007 (watchtower-redesign) via `/arcs/<slug>/close`
observed: *"agent provides recommendation and rationale [for tasks], this needs
to be codified [for arc close], file inception for that."*

The codification gap exists in three places:

1. **Task close** has clear pattern (T-679 codified `## Recommendation` in task
   bodies; `fw task review` renders the palette; `fw task update --status work-completed`
   surfaces it). The agent reflexively writes `## Recommendation` on task close.
2. **Arc close** (T-1960) partially codified: `web/blueprints/arcs.py:_anchor_recommendation`
   reads the **anchor task's** `## Recommendation` block and renders it on the
   close form as an "Agent Recommendation" panel. **BUT:** the recommendation
   shown is the **inception's GO recommendation** (e.g. T-1987's "GO with
   adjustments"), not a fresh **arc-closure** recommendation answering
   *"should this arc CLOSE now, and on what evidence?"*
3. **Agent chat behaviour** — when the user is about to close an arc (or has
   opened the close form), the agent should proactively surface a closure
   recommendation in chat: "arc-007: GO to close — headline_mechanic fires
   on `http://192.168.10.107:3000/settings/appearance`, 9/61 children closed
   but the remaining 52 are partial-completes awaiting [REVIEW] (not blockers)",
   OR "arc-007: NO-GO — headline_mechanic still needs slice X to ship before
   it actually fires". Today the agent leaves the human to assess.

**Why this matters:** arcs are higher-stakes than tasks (multi-month, multi-task,
strategic). Closing one without a fresh closure-time recommendation echoes the
G-062 pattern — "'shipped' declared before fresh-substrate behavioral
verification". The anchor-task's inception recommendation is months stale by
arc-close time; the work has evolved.

**Why now:** four prior memory entries already establish the agent's habit
of skimping on human handoffs (`feedback_use_fw_task_review.md`,
`feedback_human_review_links.md`, `feedback_review_concrete_links.md`,
`feedback_post_grill_governance.md`). T-2118 inception (this session) addresses
the chat-side palette emission; this inception addresses the structured
recommendation surfaced on the arc close form itself.

## Assumptions

- **A1.** The codification gap is **structural**, not behavioural — the close
  form already renders Agent Recommendation, but pulls from a stale source
  (anchor-task inception). A fresh arc-scope recommendation block doesn't exist.
- **A2.** Symmetry argument: tasks have `## Recommendation`; arcs should have
  a comparable closure-time block. Either on the **arc YAML** or on the **arc
  anchor task** as a `## Arc Closure Recommendation` distinct from the
  inception's `## Recommendation`.
- **A3.** The agent should be required to **populate** this block before the
  close form will accept submission (parallel to render-surface gate P-013
  requiring [REVIEW] Human AC on render-touching tasks).
- **A4.** Even with the block populated, the agent should proactively surface
  the recommendation in chat when the user opens or asks about the close form
  — `fw arc review <slug>` as a verb (parallel to `fw task review`).

## Exploration Plan

- **Spike 1 (research, 15min):** Inspect `web/blueprints/arcs.py:_anchor_recommendation`
  to confirm it reads ONLY the anchor task's `## Recommendation`. Confirm no
  arc-YAML-level recommendation field exists. **Done as part of filing this
  inception** — `_anchor_recommendation` at arcs.py:556 reads anchor-task
  body; no arc-YAML field exists.
- **Spike 2 (data check, 5min):** Inspect arc-007's current close-form
  rendering. Is the "Agent Recommendation" the T-1987 inception GO, or a
  closure-time recommendation? **Done** — it's T-1987's "GO-with-adjustments"
  from 2026-05-22 (8 days stale; 52 children still open).
- **Spike 3 (option synthesis):** Four candidate placement options below.

## Technical Constraints

- The arc YAML schema is read by `lib/arc.sh`, `web/blueprints/arcs.py`,
  `agents/audit/*` — adding a new top-level field has multi-consumer blast
  radius. Use an existing extension point (`recommendation:` mirrors task
  frontmatter convention) or co-locate on the anchor task as a new section.
- `fw arc close` is CLAUDECODE-gated (T-1671) — agent cannot decide; the
  recommendation IS the agent's contribution. The decision verb stays human.
- The close form must not silently render a stale recommendation. Either
  require a fresh one OR mark the stale one with `(generated YYYY-MM-DD —
  N days before close attempt)` so the human knows.

## Scope Fence

**IN.** Define the placement (arc YAML field vs anchor-task section vs new
file), the trigger (close-form requires populated; or audit WARN; or close-form
renders staleness banner), and the chat-side counterpart (`fw arc review
<slug>` verb).

**OUT (for this inception — file as separate builds on GO).**

- Implementing the chosen placement
- Writing the `fw arc review <slug>` command
- Migrating existing arcs to populate the new block

**OUT (deferred).** Auto-generated closure recommendation (LLM-drafted from
constituent task evidence) — manual capture first, automation later if
the manual habit takes.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — user request cited verbatim; codification gap confirmed in `web/blueprints/arcs.py:_anchor_recommendation` (reads anchor inception's stale recommendation, not arc-closure recommendation).
<!-- @auto-tick-on-decide -->
- [x] Assumptions A1-A4 tested via Spike 1+2 (research already done as part of filing — anchor-task body is the only source, no arc-YAML field, 8-day-stale on arc-007 example).
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale — see `## Recommendation` below.

### Human
- [x] [REVIEW] Decide GO/NO-GO/DEFER on the codification approach. Optionally: pick a placement sub-option (A/B/C/D). Reply via Watchtower review form.
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-2122
  2. Read `## Recommendation` block (below) — four candidate placements; agent recommends combined A+D.
  3. Record decision via the Watchtower form.
  **Expected:** Decision recorded; sibling build task(s) created on GO.
  **If not:** Tell agent which option is too narrow / too broad.

## Go/No-Go Criteria

**GO if:** the codification gap is real (anchor-inception recommendation
is stale at arc-close time; no fresh arc-scope recommendation surfaces in
the close form) AND a bounded fix exists with reversible cost. **CURRENT
EVIDENCE: confirmed.**

**NO-GO if:** the per-arc closure recommendation can be inferred mechanically
from constituent task evidence (BVP rollup, headline_mechanic firing,
demo_evidence) without requiring a manually-written block.

**DEFER if:** a broader arc-lifecycle redesign already underway (none known)
supersedes this scope.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO on combined **Option A + Option D** (placement + verb).

**Rationale:**

Arcs are higher-stakes than tasks (multi-month, multi-task, strategic). The
existing close-form Agent Recommendation panel reads a STALE source (the
anchor-task's inception GO recommendation, written months before arc close).
Fresh evidence — what actually shipped, what's deferred, whether the
headline_mechanic visibly fires — needs its own structured block.

Four placement candidates:

- **Option A — `## Arc Closure Recommendation` section on the anchor task.**
  New section distinct from the inception's `## Recommendation`. The arc
  close blueprint reads THIS section if present, falls back to the inception's
  if absent. Lowest blast radius: no schema change to arc YAML; reuses the
  existing markdown parser. Stale-marker added when no Arc-Closure section
  exists (form renders inception recommendation with a "⚠️ generated
  YYYY-MM-DD — N days before close attempt" badge).

- **Option B — `recommendation:` field on the arc YAML.**
  Structured field with `{verdict, rationale, evidence, ts, generated_by}`.
  Cleanest data model, but every arc YAML consumer
  (`lib/arc.sh`, `web/blueprints/arcs.py`, `agents/audit/*`) needs to learn
  the field. Higher blast radius.

- **Option C — Standalone `docs/reports/<arc-id>-closure-recommendation.md`.**
  Mirrors the C-001 inception-research-artefact convention. Survives close,
  immutable. Discoverable by `fw arc show <id>`. But: adds a new file class
  the agent must remember to create — same "memory-based prevention failed
  N times" pattern as T-2118.

- **Option D — `fw arc review <slug>` verb.**
  Parallel to `fw task review T-XXX`. Renders the arc close palette in
  terminal + Markdown — Watchtower link, headline_mechanic recap, completion
  ratio, constituent task summary, **freshly drafted recommendation** read
  from wherever Option A/B/C places it. Agent reflexively runs this verb
  when the user mentions arc close.

**Why A+D:**

- A adds the SOURCE (a fresh, dated recommendation block) with minimum
  schema change.
- D adds the HABIT (a verb the agent runs reflexively) parallel to
  `fw task review`.
- Together they close both the structural gap (no source) and the
  behavioural gap (agent doesn't proactively surface).
- Option B is over-engineering for sample-size-2 use; revisit if pattern
  proves out.
- Option C duplicates Option A's information; C-001's value for inceptions
  is that they pre-date the task; here the recommendation post-dates work.

**Evidence:**

- `web/blueprints/arcs.py:556 _anchor_recommendation` reads anchor-task body
  only — confirmed by inspection.
- `web/templates/arc_close.html:79-105` renders verdict badge + rationale +
  evidence from the anchor recommendation; no staleness indicator.
- arc-007 example: T-1987 `## Recommendation` is the 2026-05-22 inception
  GO. 8 days later, 9/61 constituents are formally completed, 52 remain
  partial-complete or in-flight. The closure question — "should this arc
  close NOW?" — is materially different from the GO question of 2026-05-22.
- T-2118 (this session) addresses the **chat-side palette emission** gap.
  This inception addresses the **close-form recommendation source** gap.
  Both are children of the broader §ACD class.

**GO decision unblocks build tasks:**

- **T-NEW-A1:** `web/blueprints/arcs.py` + `web/templates/arc_close.html` —
  read `## Arc Closure Recommendation` section if present; staleness badge
  on inception-fallback path.
- **T-NEW-A2:** `lib/arc.sh do_arc_show` — surface the closure recommendation
  in `fw arc show <slug>` output.
- **T-NEW-D:** `lib/arc.sh do_arc_review` — new verb `fw arc review <slug>`
  rendering the close palette.

**Hand to human:** http://192.168.10.107:3000/review/T-2122 — Watchtower
decision form. Agent cannot decide (CLAUDECODE-gated per T-1671).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Arcs are higher-stakes than tasks (multi-month, multi-task, strategic). The
existing close-form Agent Recommendation panel reads a STALE source (the
anchor-task's inception GO recommendation, written months before arc close).
Fresh evidence — what actually shipped, what's deferred, whether the
headline_mechanic visibly fires — needs its own structured block.

Four placement candidates:

**Date**: 2026-05-30T21:32:15Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-30T21:32:15Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Arcs are higher-stakes than tasks (multi-month, multi-task, strategic). The
existing close-form Agent Recommendation panel reads a STALE source (the
anchor-task's inception GO recommendation, written months before arc close).
Fresh evidence — what actually shipped, what's deferred, whether the
headline_mechanic visibly fires — needs its own structured block.

Four placement candidates:

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9957a3a8
- **Timestamp:** 2026-06-02T15:01:12Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Problem statement validated — user request cited verbatim; codification gap confirmed in `web/blueprints/arcs.py:_anchor_recommendation` (reads anchor inception's stale recommendation, not arc-closure
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/arcs.py in: Problem statement validated — user request cited verbatim; codification gap confirmed in `web/blueprints/arcs.py:_anchor_recommendation` (reads anchor`
### 2026-05-30T21:32:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
