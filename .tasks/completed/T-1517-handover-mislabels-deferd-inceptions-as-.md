---
id: T-1517
name: "Handover mislabels DEFER'd inceptions as 'Awaiting Decision'"
description: >
  Handover mislabels DEFER'd inceptions as 'Awaiting Decision'

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/handover/handover.sh]
related_tasks: []
created: 2026-04-26T21:04:40Z
last_update: 2026-04-26T21:08:18Z
date_finished: 2026-04-26T21:08:18Z
---

# T-1517: Handover mislabels DEFER'd inceptions as 'Awaiting Decision'

## Context

User reported: /approvals shows 0 GO/NO-GO Decisions but the handover lists 10 inceptions as "Inception Phases — Awaiting Decision". Investigation: all 10 have a recorded `**Decision**: DEFER` line in their task body. /approvals correctly filters by `_extract_decision(body) == "pending"` so DEFER is excluded. Handover (`agents/handover/handover.sh:559-576`) only filters by `tstatus != 'work-completed'` — DEFER'd tasks have `status: captured`, so they pass through the filter and get mis-labeled.

DEFER'd inceptions ARE legitimately in active/ (parked, watching for promotion criteria) but they are NOT awaiting a first decision. The label mismatch causes the user to scan /approvals expecting them and find nothing.

## Acceptance Criteria

### Agent
- [x] Handover's "Inception Phases — Awaiting Decision" section excludes inceptions that have any recorded `**Decision**:` line (GO, NO-GO, DEFER) — only truly-pending shows up
- [x] DEFER'd inceptions still surface in handover under a separate "Deferred Inceptions — Watching for Recurrence" section (so they remain visible without being mislabeled)
- [x] Section is omitted entirely when there are no deferred inceptions
- [x] Existing /approvals behaviour unchanged (only handover wording changes)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.

# T-1517 fix: the "Awaiting Decision" filter now parses Decision lines
grep -q "decision_re" agents/handover/handover.sh
# Deferred-inceptions section helper exists
grep -q "Deferred Inceptions" agents/handover/handover.sh
grep -q "Watching for Recurrence" agents/handover/handover.sh
# Smoke: regenerate handover (auto-commits but stays bounded) and check sections
bin/fw handover >/dev/null 2>&1
# Awaiting Decision section, when present, must NOT list any DEFER'd inception
awk '/^### Inception Phases — Awaiting Decision/{f=1;next} /^### |^## /{f=0} f{print}' .context/handovers/LATEST.md > /tmp/T-1517-awaiting.txt
! grep -qE 'T-(1265|1501|558)' /tmp/T-1517-awaiting.txt
# Deferred section must list at least one of the known DEFER'd inceptions
awk '/^### Deferred Inceptions/{f=1;next} /^### |^## /{f=0} f{print}' .context/handovers/LATEST.md > /tmp/T-1517-deferred.txt
grep -qE 'T-(1265|1501|558)' /tmp/T-1517-deferred.txt

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

### 2026-04-26T21:04:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1517-handover-mislabels-deferd-inceptions-as-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-70bd7823
- **Timestamp:** 2026-06-02T14:58:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 10
     - evidence: `bin/fw handover >/dev/null 2>&1`
### 2026-04-26T21:08:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Handover bug fixed; verification commands corrected
