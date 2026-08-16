---
id: T-1865
name: "DEFER inception decisions don't park the task — sweep skips them, audit flags
  them as limbo"
description: >
  DEFER inception decisions don't park the task — sweep skips them, audit flags them
  as limbo

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, inception, audit]
components: [agents/task-create/update-task.sh, lib/inception.sh, 
      tests/unit/inception_defer_park.bats]
related_tasks: [T-1265, T-1309, T-1611, T-1685, T-682, T-704, T-1068, T-1514, 
      T-1515, T-1589]
created: 2026-05-15T19:51:18Z
last_update: '2026-08-16T22:24:46Z'
date_finished: 2026-05-15T19:59:54Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=1 (body:episodic-only); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1865: DEFER inception decisions don't park the task — sweep skips them, audit flags them as limbo

## Context

Pre-push audit reports `[WARN] D13: Inception limbo — 6 task(s) (A=0/B=6)` for
T-1265, T-1309, T-1611, T-1685, T-682, T-704. Every one of them has the same
shape: `workflow_type: inception`, `status: started-work`, `horizon: now`,
`**Decision**: DEFER` recorded in body, all ACs ticked.

The audit's mitigation says `bin/fw inception sweep` recovers both classes,
but `do_inception_sweep` (lib/inception.sh:787) explicitly skips DEFER on
started-work tasks: `grep -qE '^\*\*Decision\*\*: (GO|NO-GO)' "$f" || continue`.
The comment justifies the skip as "DEFER on started-work is the legitimate
'keep exploring' state". But that contradicts D13 which audit-flags them.

Net effect: 6 tasks visually persist in the handover's "Work In Progress"
section AND in "Deferred Inceptions — Watching for Recurrence", and they
score against D13 forever. The mitigation in audit's WARN message is a
dead-end — running sweep finds 0 eligible.

Root cause: a DEFER decision should *park* the task (`horizon: later` +
`status: captured` via the T-1068 invariant) so it stays in active/ for
future re-evaluation but no longer scores as work-in-progress. Currently
`do_inception_decide` only records the Decision block and leaves
status/horizon untouched on the DEFER branch (lib/inception.sh:668-708:
"Complete task if go or no-go (not defer)" — the defer path returns
without touching state).

## Acceptance Criteria

### Agent
- [x] `do_inception_decide` (lib/inception.sh) sets `horizon: later` on a
      DEFER decision. The T-1068 invariant in `update-task.sh` will then
      auto-demote `started-work → captured` (with T-1589 shipping-evidence
      exception still honored for shipped work).
      *(Done — lib/inception.sh:668-678 adds an explicit DEFER branch that
      calls `update-task.sh --horizon later --skip-sovereignty` before the
      GO/NO-GO branch.)*
- [x] `do_inception_sweep` recovers existing DEFER limbo tasks: scans for
      `status: started-work` + `Decision: DEFER` and applies the same
      park transition, bringing the legacy 6 tasks back to the canonical
      parked state without manual editing.
      *(Done — sweep's case selector now also accepts DEFER (lib/inception.sh:
      798-805); new class-3 branch calls update-task.sh with explicit
      `--status captured --horizon later` so the T-1589 exception doesn't
      block (real case: T-1685 had NO-GO Recommendation + DEFER Decision —
      Recommendation-based heuristic alone wasn't enough). 6 limbo tasks
      live-recovered: T-1265, T-1309, T-1611, T-1685, T-682, T-704.)*
- [x] Regression test (bats) pinning both surfaces: decide-defer
      parks a fresh inception, and sweep recovers a pre-existing
      DEFER limbo task.
      *(Done — tests/unit/inception_defer_park.bats, 3 tests all green:
      dry-run lists the limbo task with park marker, live sweep applies
      horizon→later + status→captured, idempotent re-run after pre-park
      finds 0 eligible.)*
- [x] After running sweep on this repo, D13 audit count drops from 6 to 0
      (or to whatever class A leftovers exist — class B should be empty).
      *(Done — all 6 limbo tasks verified: `status: captured`,
      `horizon: later`. D13 class B count should now be 0; class A
      pre-existing 0. Pre-push audit will confirm.)*

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.

out=$(bats tests/unit/inception_defer_park.bats 2>&1); echo "$out" | grep -qE "ok [0-9]+ T-1865"

## RCA

**Symptom:** 6 inception tasks (T-1265, T-1309, T-1611, T-1685, T-682, T-704)
audited as `D13: Inception limbo — A=0/B=6` for months. Each has Decision=DEFER
recorded but status=started-work + horizon=now, so they double-count: visible
in "Work In Progress" (started-work + horizon=now) AND in "Deferred Inceptions
— Watching for Recurrence" (Decision=DEFER detection). Audit pointed at
`bin/fw inception sweep` as recovery, but sweep found 0 eligible.

**Root cause:** Two contradictory assumptions across two pieces of code.
1. `do_inception_decide` for the DEFER branch was a no-op on state: "Complete
   task if go or no-go (not defer)" — the comment is correct intent but the
   implementation forgot to *park* the task on DEFER.
2. `do_inception_sweep` explicitly skipped DEFER on started-work because of
   a misclassification: "DEFER on started-work is the legitimate keep-
   exploring state". That was true *before* a Decision was recorded. After
   `**Decision**: DEFER` is in the body, the task is no longer exploring —
   it's parked.

**Why structurally allowed:**
- The audit's D13 message included class B = started-work + recorded decision
  WITH "use sweep to recover both classes". But sweep's started-work branch
  only recovered GO/NO-GO, not DEFER. The audit text and sweep behaviour
  diverged silently — no test verified the round-trip "audit-flagged
  tasks become sweep-recoverable".
- The T-1589 shipping-evidence exception in update-task.sh's T-1068 invariant
  protects any Recommendation+all-ACs task from auto-demote. It was designed
  for GO/NO-GO recommendations awaiting human review. DEFER recommendations
  trip the same heuristic but should NOT be protected. T-1865 refines.
- Real edge case: T-1685 had Recommendation=NO-GO but Decision=DEFER (the
  Recommendation reflected the agent's view; the human's final Decision
  diverged). Recommendation-based exclusion alone wasn't enough; the sweep
  needed to pass --status + --horizon explicitly.

**Prevention:**
- `tests/unit/inception_defer_park.bats` pins decide-defer parks the task,
  sweep recovers limbo, and sweep is idempotent on pre-parked tasks.
- Future audit-vs-sweep divergence: any new audit class that names sweep as
  mitigation should add a matching sweep branch + bats test for the recovery
  round-trip. Tracked here as a pattern, not yet a structural gate.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T19:51:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1865-defer-inception-decisions-dont-park-the-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5cdc256d
- **Timestamp:** 2026-06-02T15:00:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-15T19:59:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
