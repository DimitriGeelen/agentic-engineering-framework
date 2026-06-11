---
id: T-1305
name: "Pickup: Watchtower load_latest_audit picks upgrades.yaml instead of newest
  audit (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1128. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-18T18:44:08Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T22:47:09Z
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

# T-1305: Pickup: Watchtower load_latest_audit picks upgrades.yaml instead of newest audit (from termlink)

## Problem Statement

`web/shared.py:301` uses `sorted(audit_dir.glob("*.yaml"), reverse=True)[0]` to pick the latest audit. When any non-date YAML sits in `.context/audits/` (termlink has `upgrades.yaml`; framework could develop similar), reverse-alphabetical sort puts it first. That file lacks a `summary` key, so `load_latest_audit()` returns empty data and the Watchtower ambient strip shows "Audit: unknown" even when fresh audits exist.

Source: pickup P-032 from termlink (T-1128). Upstream fix already proven.

## Assumptions

1. Audit files follow the `YYYY-MM-DD.yaml` convention (verified — all 50+ existing audits match).
2. No legitimate audit filename begins with non-digit characters.
3. Filter pattern `[0-9][0-9][0-9][0-9]-*.yaml` is a safe subset.

## Exploration Plan

None needed — fix is a one-character-class glob change. Already proven upstream.

## Technical Constraints

- `Path.glob` supports character classes (Python `pathlib` wraps fnmatch).
- Must keep the reverse-sort behaviour so newest wins.

## Scope Fence

**IN:** Change one glob pattern in `web/shared.py::load_latest_audit`.
**OUT:** Restructure audit filenames, migrate existing audits, add schema validation.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (T-1307 build + regression tests confirm glob filter works)
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

grep -q 'glob("\[0-9\]\[0-9\]\[0-9\]\[0-9\]-\*\.yaml")' web/shared.py
python3 -m pytest tests/web/ -q

## Recommendation

**Recommendation:** GO

**Rationale:** One-character-class glob change. Fix is already implemented and verified upstream (termlink@T-1128). Defensive — framework hasn't yet grown a non-date YAML in `.context/audits/`, but nothing prevents it (e.g. future `upgrades.yaml` following consumer conventions).

**Evidence:**
- `web/shared.py:301` globs `*.yaml` then reverse-sorts — no content validation.
- All existing 50+ audit files in `.context/audits/` match `[0-9][0-9][0-9][0-9]-*.yaml`.
- Termlink hit this bug when `upgrades.yaml` was written into their audits dir by a cron; same class of file could land here.

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

Rationale: One-character-class glob change. Fix is already implemented and verified upstream (termlink@T-1128). Defensive — framework hasn't yet grown a non-date YAML in `.context/audits/`, but nothing prevents it (e.g. future `upgrades.yaml` following consumer conventions).

Evidence:
- `web/shared.py:301` globs `.yaml` then reverse-sorts — no content validation.
- All existing 50+ audit files in `.context/audits/` match `[0-9][0-9][0-9][0-9]-.yaml`.
- Termlink hit this bug when `upgrades.yaml` was written into their audits dir by a cron; same class of file could land here.

**Date**: 2026-04-18T22:48:17Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T19:48:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:47:09Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: One-character-class glob change. Fix is already implemented and verified upstream (termlink@T-1128). Defensive — framework hasn't yet grown a non-date YAML in `.context/audits/`, but nothing prevents it (e.g. future `upgrades.yaml` following consumer conventions).

Evidence:
- `web/shared.py:301` globs `.yaml` then reverse-sorts — no content validation.
- All existing 50+ audit files in `.context/audits/` match `[0-9][0-9][0-9][0-9]-.yaml`.
- Termlink hit this bug when `upgrades.yaml` was written into their audits dir by a cron; same class of file could land here.

### 2026-04-18T22:47:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:48:17Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: One-character-class glob change. Fix is already implemented and verified upstream (termlink@T-1128). Defensive — framework hasn't yet grown a non-date YAML in `.context/audits/`, but nothing prevents it (e.g. future `upgrades.yaml` following consumer conventions).

Evidence:
- `web/shared.py:301` globs `.yaml` then reverse-sorts — no content validation.
- All existing 50+ audit files in `.context/audits/` match `[0-9][0-9][0-9][0-9]-.yaml`.
- Termlink hit this bug when `upgrades.yaml` was written into their audits dir by a cron; same class of file could land here.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f36d4df9
- **Timestamp:** 2026-06-02T14:56:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
