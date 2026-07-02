---
id: T-1573
name: "Surface .gate-bypass-log.yaml in fw audit (F8 from T-1565 audit)"
description: >
  Surface .gate-bypass-log.yaml in fw audit (F8 from T-1565 audit)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004]
related_tasks: []
created: 2026-04-27T21:45:11Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-27T21:57:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1573: Surface .gate-bypass-log.yaml in fw audit (F8 from T-1565 audit)

## Context

F8 from the T-1565 approval-arc audit. Gate bypasses (--skip-sovereignty,
--skip-acceptance-criteria, --skip-recommendation, --skip-rca,
--skip-verification, --skip-human-ownership) are logged to
`.context/working/.gate-bypass-log.yaml` by `update-task.sh:32-42` but
nothing reads the file: no Watchtower page, no audit warning, no doctor
check. The log is "an audit artefact without auditor."

`fw audit` already has an ENFORCEMENT section that checks a different file
(`bypass-log.yaml` for Tier 0 actions). Adding a parallel check for the
gate-bypass log is the minimum viable surface.

## Acceptance Criteria

### Agent
- [x] `fw audit --section enforcement` checks `.context/working/.gate-bypass-log.yaml`.
- [x] Reports total bypass count and last-7-days count.
- [x] WARN when last-7-day count exceeds 10. Live: 27 in last 7d → WARN fired.
- [x] PASS when log absent or count low.
- [x] Bats test `tests/unit/audit_gate_bypass_log.bats` — 4/4 passing.
      (3 specified + 1 bonus: 7d window correctly excludes old entries.)

cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/audit_gate_bypass_log.bats
bin/fw audit --section enforcement 2>&1 | grep -qiE "gate.bypass|gate-bypass" && echo gate-bypass-surfaced

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

**Rationale:** F8 closes the "audit artefact without auditor" gap. The
gate-bypass log is now read every audit run, with a graduated alert
(info line always, WARN when last-7d > 10). Live signal already firing:
27 bypasses in the last 7 days surfaces as the project's bypass pattern.

**Evidence:**
- `agents/audit/audit.sh` ENFORCEMENT section now reads
  `.context/working/.gate-bypass-log.yaml` and reports counts.
- `tests/unit/audit_gate_bypass_log.bats` — 4/4 passing.

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

### 2026-04-27T21:45:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1573-surface-gate-bypass-logyaml-in-fw-audit-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-aba2df4c
- **Timestamp:** 2026-06-02T14:58:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T21:57:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** F8 implemented and tested
