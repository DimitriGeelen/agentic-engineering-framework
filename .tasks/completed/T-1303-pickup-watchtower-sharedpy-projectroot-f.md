---
id: T-1303
name: "Pickup: Watchtower shared.py PROJECT_ROOT fallback is wrong — falls to FRAMEWORK_ROOT,
  not discovered (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1123. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-18T18:43:21Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T22:46:05Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1303: Pickup: Watchtower shared.py PROJECT_ROOT fallback is wrong — falls to FRAMEWORK_ROOT, not discovered (from termlink)

## Problem Statement

`web/shared.py:22` reads `PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", str(FRAMEWORK_ROOT)))`. When `PROJECT_ROOT` is unset (e.g. `python3 -m web.app` from a consumer project), Python falls back to the framework's own directory — ambient strip is blank, approvals page empty, because reads hit framework's `.context/` / `.tasks/` instead of the consumer's.

Bash-side `paths.sh` already does git-toplevel + `.framework.yaml` discovery. Python was never kept in sync.

Source: pickup P-030 from termlink (T-1123). Fix ported from termlink commit `d3723d9c`.

## Assumptions

1. Consumer projects have `.framework.yaml` at the project root — confirmed (fw init creates it).
2. Walking up from `os.getcwd()` is the canonical discovery method — matches `paths.sh`.
3. The env var must keep winning — operators and wrappers pass it explicitly.

## Exploration Plan

None — fix is surgical. Implementation: `_discover_project_root()` walks up from CWD looking for `.framework.yaml` (bounded at filesystem root). `_resolve_project_root()` returns `(path, source_label)` where source ∈ {`env`, `discovered`, `framework`}. Log source label at import.

## Technical Constraints

- Must be non-intrusive: the env-var path (set by `bin/fw`) must continue to work unchanged.
- Must not break when CWD is `/` or a parent of `.framework.yaml`-less dir — degrade to FRAMEWORK_ROOT.
- No new dependencies.

## Scope Fence

**IN:** `_discover_project_root` + `_resolve_project_root` helpers in `web/shared.py`. PROJECT_ROOT derived from those. One log line at module load.

**OUT:** Consumer auto-init, `.framework.yaml` schema validation, multi-root discovery.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (T-1310 build + 4 regression tests confirm)
- [x] Recommendation written with rationale

### Human
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
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

grep -q "_discover_project_root" web/shared.py
grep -q "_resolve_project_root" web/shared.py
python3 -m pytest tests/web/test_project_root_discovery.py -q

## Recommendation

**Recommendation:** GO

**Rationale:** Bash-side discovery in `paths.sh` is canonical; Python-side fallback is stale and bites anyone who bypasses `bin/fw`. Fix is bounded (two helpers + derived global), reversible, and proven upstream in termlink@d3723d9c.

**Evidence:**
- `web/shared.py:22` — FRAMEWORK_ROOT fallback with no discovery.
- `bin/fw` and `lib/paths.sh` do walk-up-for-`.framework.yaml`. Python was ignored.
- Termlink's T-1123 verified: cwd in `/opt/termlink/subdir` discovers `/opt/termlink`; cwd in `/tmp` falls back to framework; env still wins.

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

**Rationale**: Recommendation: GO

Rationale: Bash-side discovery in `paths.sh` is canonical; Python-side fallback is stale and bites anyone who bypasses `bin/fw`. Fix is bounded (two helpers + derived global), reversible, and proven upstream in termlink@d3723d9c.

Evidence:
- `web/shared.py:22` — FRAMEWORK_ROOT fallback with no discovery.
- `bin/fw` and `lib/paths.sh` do walk-up-for-`.framework.yaml`. Python was ignored.
- Termlink's T-1123 verified: cwd in `/opt/termlink/subdir` discovers `/opt/termlink`; cwd in `/tmp` falls back to framework; env still wins.

**Date**: 2026-04-18T22:46:29Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T20:01:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:46:05Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Bash-side discovery in `paths.sh` is canonical; Python-side fallback is stale and bites anyone who bypasses `bin/fw`. Fix is bounded (two helpers + derived global), reversible, and proven upstream in termlink@d3723d9c.

Evidence:
- `web/shared.py:22` — FRAMEWORK_ROOT fallback with no discovery.
- `bin/fw` and `lib/paths.sh` do walk-up-for-`.framework.yaml`. Python was ignored.
- Termlink's T-1123 verified: cwd in `/opt/termlink/subdir` discovers `/opt/termlink`; cwd in `/tmp` falls back to framework; env still wins.

### 2026-04-18T22:46:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:46:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Bash-side discovery in `paths.sh` is canonical; Python-side fallback is stale and bites anyone who bypasses `bin/fw`. Fix is bounded (two helpers + derived global), reversible, and proven upstream in termlink@d3723d9c.

Evidence:
- `web/shared.py:22` — FRAMEWORK_ROOT fallback with no discovery.
- `bin/fw` and `lib/paths.sh` do walk-up-for-`.framework.yaml`. Python was ignored.
- Termlink's T-1123 verified: cwd in `/opt/termlink/subdir` discovers `/opt/termlink`; cwd in `/tmp` falls back to framework; env still wins.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9b901346
- **Timestamp:** 2026-06-02T14:56:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
