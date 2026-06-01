---
id: T-1572
name: "Extend Recommendation gate to fire on reviewer.needs_human signals (F6 from T-1565 audit)"
description: >
  Extend Recommendation gate to fire on reviewer.needs_human signals (F6 from T-1565 audit)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-04-27T21:41:48Z
last_update: 2026-04-27T21:44:24Z
date_finished: 2026-04-27T21:44:24Z
---

# T-1572: Extend Recommendation gate to fire on reviewer.needs_human signals (F6 from T-1565 audit)

## Context

F6 from the T-1565 approval-arc audit — cross-component decoupling. The
Recommendation gate (T-679/T-1529) at `agents/task-create/update-task.sh:172`
fires only when `PARTIAL_COMPLETE=true` (Human ACs remain). But
`lib/reviewer/static_scan.py:668` defines `needs_human=True` when
`risk_declared in {high, medium}` OR `human_signoff_declared == "required"`
OR there are escalations — independent signals.

A task with `human_signoff: required` in frontmatter and no Human ACs in
body completes silently with no Recommendation written: the reviewer flagged
it; the artefact gate didn't enforce. Two systems with different definitions
of "needs human." Aligning them closes the gap.

## Acceptance Criteria

### Agent
- [x] `check_recommendation_for_review` in `agents/task-create/update-task.sh`
      computes a unified `needs_human` flag, true when ANY of:
      - PARTIAL_COMPLETE=true (existing trigger)
      - frontmatter `human_signoff: required`
      - frontmatter `risk: high` or `risk: medium`
      - prior `## Reviewer Verdict` block has `Needs Human: yes`
- [x] Gate fires when needs_human=true AND Recommendation missing/empty.
      `--skip-recommendation` bypasses with log (test 6 confirms).
- [x] No regression: 4 false-positive guards (risk:low, needs_human=no,
      baseline no-signal, partial-complete path) all complete cleanly.
- [x] Bats test `tests/unit/recommendation_gate_needs_human.bats` pins
      the 4 trigger shapes + 4 no-false-positive guards. 8/8 passing.
      `skip_ac_partial_complete.bats` 4/4 still passing — no regression.

cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/recommendation_gate_needs_human.bats

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

**Rationale:** F6 closes the cross-component decoupling — the artefact gate
now matches the reviewer's `needs_human` definition exactly. No silent
completion path exists for `human_signoff: required` or `risk: high/medium`
tasks without an explicit agent recommendation.

**Evidence:**
- `agents/task-create/update-task.sh:172-205` — `check_recommendation_for_review`
  now computes a unified `needs_human` flag from PARTIAL_COMPLETE OR frontmatter
  signals OR prior reviewer verdict. Same Python helper shape as the existing
  recommendation parser.
- `tests/unit/recommendation_gate_needs_human.bats` — 8 tests pinning the
  contract: 4 triggers (signoff/risk-high/risk-medium/reviewer-verdict),
  3 no-false-positive guards (baseline/risk-low/needs-human-no), 1 bypass test.
- No regression: `skip_ac_partial_complete.bats` 4/4 still passing.

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

### 2026-04-27T21:41:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1572-extend-recommendation-gate-to-fire-on-re.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-1c160012
- **Timestamp:** 2026-04-27T21:44:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-27T21:44:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** F6 implemented and tested
