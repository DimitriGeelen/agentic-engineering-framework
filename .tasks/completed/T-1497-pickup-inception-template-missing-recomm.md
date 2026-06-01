---
id: T-1497
name: "Pickup: Inception template missing Recommendation/Decision sections — fail-fast at creation + audit check (downstream T-013) (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-013. Type: bug-report.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [pickup, bug-report]
components: [C-004, lib/inception.sh, lib/task-audit.sh]
related_tasks: []
created: 2026-04-26T11:13:05Z
last_update: 2026-04-26T20:31:32Z
date_finished: 2026-04-26T13:54:59Z
source_task_id_in_origin: T-013
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1497: Pickup: Inception template missing Recommendation/Decision sections — fail-fast at creation + audit check (downstream T-013) (from 003-NTB-ATC-Plugin)

## Context

**Structural governance regression:** pickup-created inception tasks (`lib/pickup.sh:268`) get an inception template skeleton with `## Recommendation`/`## Decision` sections that contain ONLY HTML-comment placeholders. They land in the "Awaiting Decision" queue with no body content. Watchtower's `/inception/T-XXX` and `/approvals` cards render blank decision forms. The human is asked to GO/NO-GO on nothing.

Live evidence: T-1501 and T-1502 (this session) — both reached the human's review queue with empty Recommendation sections. User flagged the regression directly: "what am I deciding for / on?".

The framework already has an advisory warning (`lib/review.sh:74-85` "WARNING: No ## Recommendation written yet" → stderr) but no structural block. `audit_task_placeholders` (T-1111) checks for `[First criterion]` placeholders but not for an empty Recommendation section.

Same class of failure as G-020 (build readiness gate for placeholder ACs) — the fix shape mirrors that gate, applied to inception decides.

Source pickup: 003-NTB-ATC-Plugin / T-013 / P-002. Pickup proposed (1) creation-time validation, (2) audit rule, (3) framework-side propagation. This task implements (1)+(2); creation-time (the template DOES create the section, just with a comment placeholder) is implicit — the hard gate at decide-time achieves the same goal without restricting the agent's authoring window.

## Acceptance Criteria

### Agent
- [x] `lib/inception.sh:do_inception_decide` refuses with a clear error when `## Recommendation` section has no `**Recommendation:**` line outside HTML comments. Error message points at `fw task review T-XXX` for the agent and includes the path to fix.
- [x] New helper `audit_inception_recommendation` lives in `lib/task-audit.sh` (or equivalent) — pure function, returns 0 if Recommendation has substantive content (a non-commented `**Recommendation:**` line), 1 otherwise.
- [x] `fw audit` discovery check flags inception tasks in `started-work` or `captured` status with empty Recommendation. New rule e.g. `discoveries/empty-inception-recommendation.yaml`.
- [x] Regression test `tests/unit/inception_decide_recommendation_gate.bats` — 4 cases: (a) empty Recommendation blocks, (b) HTML-comment-only blocks, (c) `**Recommendation:**` line allows decide, (d) DEFER decisions also gated (consistency).
- [x] Existing tests still pass: `inception_decide_atomicity.bats`, `inception_decide_emit_review_post_move.bats`, `hook_enable_absolute_path.bats`, `tier0_hash_normalization.bats`.

### Human
- [x] [REVIEW] After landing, attempt to decide a fresh inception with empty Recommendation via Watchtower
  **Steps:**
  1. Pick any inception in the "Awaiting Decision" queue with empty body (or create a test one)
  2. Click GO at http://192.168.10.107:3000/inception/T-XXXX
  3. Confirm Watchtower shows a clear error pointing at the missing Recommendation
  4. Fill in the Recommendation in the task file, retry — confirm decide succeeds
  **Expected:** Empty Recommendation → blocked with actionable error; filled Recommendation → decide succeeds
  **If not:** The gate didn't land or the parsing logic has a false negative — capture the task body and re-open T-1497

## Verification

# Regression test passes
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/inception_decide_recommendation_gate.bats
# Sister suites still pass
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/inception_decide_atomicity.bats tests/unit/inception_decide_emit_review_post_move.bats

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

### 2026-04-26T11:13:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1497-pickup-inception-template-missing-recomm.md
- **Context:** Initial task creation

### 2026-04-26T13:45:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-138e62a4
- **Timestamp:** 2026-04-26T13:55:04Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `fw audit` discovery check flags inception tasks in `started-work` or `captured` status with empty Recommendation. New rule e.g. `discoveries/empty-inception-recommendation.yaml`.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=discoveries/empty-inception-recommendation.yaml in: `fw audit` discovery check flags inception tasks in `started-work` or `captured` status with empty Recommendation. New rule e.g. `discoveries/empty-in`

### 2026-04-26T13:54:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
