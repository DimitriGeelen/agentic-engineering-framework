---
id: T-1862
name: "audit gate-bypass WARN conflates --switch-focus drift overrides with safety
  bypasses — split classes"
description: >
  audit gate-bypass WARN conflates --switch-focus drift overrides with safety bypasses
  — split classes

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/audit/audit.sh]
related_tasks: [T-1573, T-1730, T-1861]
created: 2026-05-15T18:38:17Z
last_update: '2026-06-11T22:24:01Z'
date_finished: 2026-05-15T20:45:18+02:00
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1862: audit gate-bypass WARN conflates --switch-focus drift overrides with safety bypasses — split classes

## Context

`agents/audit/audit.sh:1026-1047` counts all entries in `.gate-bypass-log.yaml` from the last 7 days and emits WARN if > 10. With the log now parseable (T-1861), the real breakdown for the current 54-entry-in-7-days bucket is:

- **51 × `--switch-focus`** — `check-active-task` focus-drift overrides. These are not safety bypasses; they are "I'm intentionally working across tasks" signals introduced by T-1730 specifically to be lightweight and frequent. Normal operational signal.
- **1 × `--skip-rca`** — bug-class task shipped without RCA (the real flag worth surfacing).
- **1 × `--skip-sovereignty`** — human-owned task completed by agent.
- **1 × `--scope-reduction-acknowledged`** — §ACD pattern override.

51 normal-operational events drown the 3 genuine-safety bypasses in the same WARN. The audit message ("53 bypasses in last 7 days, bypass-as-pattern signal") is technically accurate but operationally misleading — the actual high-signal events are buried 17:1 in noise.

Same audit-data category (T-1573 F8), now with one more layer of signal-to-noise refinement.

## Acceptance Criteria

### Agent
- [x] **A1** Identify the bypass-flag taxonomy in `agents/audit/audit.sh`. Two classes: SAFETY bypasses (`--skip-*`, `--scope-reduction-acknowledged`) vs OPERATIONAL overrides (`--switch-focus`). Coded as a flag list.
- [x] **A2** `agents/audit/audit.sh` gate-bypass section counts each class separately and emits:
  - `pass`/`warn` based on **safety** count (threshold lower, e.g., > 3 in 7d → WARN)
  - `pass` (informational only) for **operational** count regardless of magnitude
- [x] **A3** Output message names both counts explicitly: e.g., `Gate-bypass log: 3 safety bypasses + 51 drift overrides in last 7 days` so reviewers can see both at a glance.
- [x] **A4** Bats test pins: log with 5 `--switch-focus` + 1 `--skip-rca` → PASS-with-info (not WARN, because safety count is below threshold).
- [x] **A5** Bats test pins: log with 4 `--skip-rca` → WARN (safety threshold crossed even though total is low).
- [x] **A6** Existing `audit_gate_bypass_log.bats` tests still pass (no regression on PASS-clean and old-entries-only paths).
- [x] **A7** RCA section filled.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bats tests/unit/audit_gate_bypass_log.bats
out=$(bin/fw audit --section enforcement 2>&1); echo "$out" | grep -qE "Gate-bypass log: [0-9]+ safety \+ [0-9]+ drift"

## RCA

**Symptom:** `fw audit` emits `Gate-bypass log: 53 bypasses in last 7 days [bypass-as-pattern signal]` WARN. With the log now parseable (T-1861), the actual breakdown is 51 × `--switch-focus` (operational drift overrides) + 3 × safety bypasses (`--skip-rca`, `--scope-reduction-acknowledged`, `--skip-sovereignty`). The high-signal 3 are hidden in the noisy 51.

**Root cause:** `agents/audit/audit.sh:1026-1047` (T-1573 F8) treated all log entries as equivalent. The threshold-10 design assumed safety bypasses dominated. After T-1730 introduced `--switch-focus` (intentionally lightweight to encourage logged-but-frequent cross-task overrides), drift entries can outnumber safety ones 17:1 in normal sessions, overwhelming the signal.

**Why structurally allowed:** T-1573 F8 added the audit surface when only `--skip-*` flags existed in the bypass-log writer. T-1730 added `--switch-focus` to the same log because it shared the log_gate_bypass infrastructure, but the audit aggregator was not revisited to distinguish operational vs safety classes. Two correct local decisions composed into a misleading aggregate.

**Prevention:**
1. Audit aggregator now splits into `safety` (correctness-gate skips) vs `drift` (operational overrides). Safety threshold lowered to >3/7d; drift count is informational only.
2. Output message names both counts explicitly so reviewers see at-a-glance distribution.
3. `tests/unit/audit_gate_bypass_log.bats` tests #4 + #5 pin both behaviours (noisy-drift PASSes, low-safety-burst WARNs). Any future regression that lumps the classes fails CI.

**Pattern lesson:** when a logging surface is extended to a new event class, audit aggregators consuming it must be reviewed for semantic compatibility with the new class. Captured as L-386.

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

### 2026-05-15T18:38:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1862-audit-gate-bypass-warn-conflates---switc.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-43fc56e9
- **Timestamp:** 2026-06-02T15:00:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
