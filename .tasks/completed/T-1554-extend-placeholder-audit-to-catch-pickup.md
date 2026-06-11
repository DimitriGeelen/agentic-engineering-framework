---
id: T-1554
name: "Extend placeholder audit to catch pickup-template stubs ([First criterion],
  [Second criterion])"
description: >
  Extend placeholder audit to catch pickup-template stubs ([First criterion], [Second
  criterion])

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/task-audit.sh]
related_tasks: []
created: 2026-04-27T16:40:54Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T16:44:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1554: Extend placeholder audit to catch pickup-template stubs ([First criterion], [Second criterion])

## Context

`audit_task_placeholders` (lib/task-audit.sh:73) catches `[Criterion N]`, `[TODO]`, `[PLACEHOLDER]`, `[Your recommendation here]`, `[REQUIRED before` — but the actual default.md template ships `[First criterion]` / `[Second criterion]`. Result: T-1545 itself shipped to review with literal placeholder ACs visible in the rendered queue. Same silent-quality-decay pattern as T-1545 (audit exists, doesn't fire on the real placeholders). Fix the regex; add regression test; remove the loophole.

## Acceptance Criteria

### Agent
- [x] audit_task_placeholders regex extended to catch the bracketed Nth-criterion stubs that the default template ships (numeric+ordinal forms).
- [x] Pickup-template AC stubs trigger BLOCKED on fw task review, fw inception decide, and fw task update --status work-completed.
- [x] Regression test in tests/unit/placeholder_audit.bats covers: ordinal stubs block; numeric form still blocks; TODO and PLACEHOLDER still block; substantive authored ACs pass clean.
- [x] No false positives on legitimate authored content — smoke against rca_gate.bats and review_pipefail.bats (both must still pass — they use real ACs).

## Verification

bats tests/unit/placeholder_audit.bats
bats tests/unit/rca_gate.bats
bats tests/unit/review_pipefail.bats

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Recommendation

**Recommendation:** GO

**Rationale:** Tight, surgical extension of an existing audit. Same silent-quality-decay class as T-1545 (audit exists, doesn't match the actual template strings). One regex change in lib/task-audit.sh + 7 regression bats covering all five ordinal stubs, the prior numeric form, TODO/PLACEHOLDER, substantive ACs (must pass), and the backtick-strip behavior (pinned). 17/17 across rca_gate + review_pipefail + placeholder_audit. No source changes outside the audit and the test suite.

**Evidence:**
- `lib/task-audit.sh:88` — alternation extended with `\[(First|Second|Third|Fourth|Fifth) criterion\]`
- `tests/unit/placeholder_audit.bats` — 7 cases, 7 green, including a no-regression check on numeric/TODO/PLACEHOLDER patterns
- Cross-arc smoke: 17/17 across the three review-arc bats suites

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-27T16:40:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1554-extend-placeholder-audit-to-catch-pickup.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3aeac011
- **Timestamp:** 2026-06-02T14:58:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T16:44:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
