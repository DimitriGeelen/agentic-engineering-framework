---
id: T-1631
name: "B-3b (T-1626): hook-failure threshold rule — auto-register G-XXX in concerns.yaml"
description: >
  Scan .hook-counter + .hook-failure-counter (T-1628 telemetry); when any hook's failure
  ratio exceeds N% over M total fires, auto-write a G-XXX entry to concerns.yaml.
  Closes detection half of the L-329/G-019 immune-system loop.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004, agents/context/post-compact-resume.sh, bin/fw, 
      lib/doctor-hook-exercise.py, lib/hook-threshold.py, 
      tests/unit/doctor_hook_exercise.bats, tests/unit/hook_threshold.bats, 
      tests/unit/session_start_hook_warning.bats]
related_tasks: [T-1626, T-1628, T-1629]
created: 2026-05-01T07:22:34Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T09:51:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1631: B-3b (T-1626): hook-failure threshold rule — auto-register G-XXX in concerns.yaml

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Context

B-2 (T-1628) wired per-hook fire/failure telemetry to `.context/working/.hook-counter` and `.hook-failure-counter`. B-3a (T-1629) added an active probe in `fw doctor`. This task closes the detection-to-escalation half of the loop: when telemetry shows a hook is *failing in production* (not just resolvable from /tmp), auto-register a G-XXX entry in `concerns.yaml` so the failure surfaces in audit, /gaps, and Watchtower without depending on agent vigilance.

## Acceptance Criteria

### Agent
- [x] `lib/hook-threshold.py` reads `.hook-counter` and `.hook-failure-counter`, sums duplicate keys defensively, and emits one machine-readable line per hook that crosses both thresholds (default: total >= 20 fires AND failure ratio >= 0.10)
- [x] Thresholds are configurable via env vars `FW_HOOK_THRESHOLD_MIN_FIRES` and `FW_HOOK_THRESHOLD_FAIL_RATIO`
- [x] `--register` flag upserts a G-XXX entry into `.context/project/concerns.yaml` with `tags: [hook-failure-threshold, hook:<name>]`, idempotent: skips if an OPEN entry already exists for the same hook (re-occurrence after closure creates a new entry)
- [x] Audit `structure` section invokes the helper as a new check; reports PASS when no hooks cross threshold, WARN when any do (with action: register via cron or manually)
- [x] `tests/unit/hook_threshold.bats` covers: source invariant (helper exists), healthy-state silent, broken-state emits, threshold respected, idempotent upsert, duplicate-key summing
- [x] All existing audit checks still pass (`bin/fw audit --section structure`)

## Verification

bats tests/unit/hook_threshold.bats
bin/fw audit --section structure >/tmp/t1631-audit.log 2>&1; grep -qE "Hook threshold" /tmp/t1631-audit.log
python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"

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

### 2026-05-01T07:22:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1631-b-3b-t-1626-hook-failure-threshold-rule-.md
- **Context:** Initial task creation

### 2026-05-01T09:45:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0d75d93a
- **Timestamp:** 2026-06-02T14:58:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T09:51:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
