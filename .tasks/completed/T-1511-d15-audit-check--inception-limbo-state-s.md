---
id: T-1511
name: "D15 audit check — inception limbo state (started-work + owner: agenthuman + all Human ACs ticked + no Decision recorded)"
description: >
  D15 audit check — inception limbo state (started-work + owner:human + all Human ACs ticked + no Decision recorded)

status: work-completed
workflow_type: build
owner:
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-26T14:23:33Z
last_update: 2026-04-26T14:35:45Z
date_finished: 2026-04-26T14:35:45Z
---

# T-1511: D15 audit check — inception limbo state (started-work + owner:human + all Human ACs ticked + no Decision recorded)

## Context

OBS-025 surfaced "inception limbo": tasks with `workflow_type: inception`, `status: started-work`, `owner: human`, all Human ACs ticked, but NO `**Decision**:` line in the body. The operator checked the AC boxes intending to complete, then forgot to run `fw inception decide`. Task stays in active/ as a ghost — D5 anomaly check only fires on age (T-1346 was 6d, T-1388 4d), so the bug is invisible until tasks rot.

Live evidence today: T-1388 has `**Decision**: GO` recorded but is still `started-work` (different bug — the decide call wrote the body but the lifecycle didn't transition; that's T-1509 family, already partially fixed). T-1346 is no longer in active/ (resolved separately). So the live D15 trigger is small now, but the structural gap remains: nothing flags "Human ACs done + no decision" before the task ages out.

Same pattern as D14 (T-1497 + T-1510). New rule lives next to D14 in `agents/audit/audit.sh`. No code other than audit logic is touched.

## Acceptance Criteria

### Agent
- [x] New D15 discovery in `agents/audit/audit.sh` — flags inception tasks with `status: started-work`, `owner: human`, zero unchecked Human ACs, AND no `**Decision**:` line in the body.
- [x] D15 emits one of three states: `PASS no_limbo`, `WARN N_limbo: T-XXX...`, or `WARN` summary listing flagged task IDs.
- [x] Limbo detector excludes tasks with `**Decision**: DEFER` (intentional keep-active) — ANY `**Decision**:` line excludes (covers DEFER, GO, NO-GO).
- [x] Running `bin/fw audit` after the change shows D15 in the output and does not break any existing check — D14 still reports `PASS no_empty_recommendations`, D15 reports `PASS no_limbo`.
- [x] No false positives on tasks that legitimately belong in active/ — manually verified across all 17 active inception tasks; none currently in true limbo. Near-misses (T-1284, T-1388 with Decision recorded but status not transitioned) are a different bug class (T-1509 family, not D15's concern).

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

# Read persisted audit YAML rather than re-running audit (which collides with the
# update-task.sh auto-trigger audit lock). The YAML is rewritten on every audit run.
grep -q '^  - id: D15$' /opt/999-Agentic-Engineering-Framework/.context/audits/discoveries/LATEST.yaml
grep -q '^  - id: D14$' /opt/999-Agentic-Engineering-Framework/.context/audits/discoveries/LATEST.yaml

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

### 2026-04-26T14:23:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1511-d15-audit-check--inception-limbo-state-s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a3c39136
- **Timestamp:** 2026-04-26T14:35:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — New D15 discovery in `agents/audit/audit.sh` — flags inception tasks with `status: started-work`, `owner: human`, zero unchecked Human ACs, AND no `**Decision**:` line in the body.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: New D15 discovery in `agents/audit/audit.sh` — flags inception tasks with `status: started-work`, `owner: human`, zero unchecked Human ACs, AND no `**`

### 2026-04-26T14:35:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
