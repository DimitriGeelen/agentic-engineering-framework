---
id: T-1517
name: "Handover mislabels DEFER'd inceptions as 'Awaiting Decision'"
description: >
  Handover mislabels DEFER'd inceptions as 'Awaiting Decision'

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-26T21:04:40Z
last_update: 2026-04-26T21:05:50Z
date_finished: null
---

# T-1517: Handover mislabels DEFER'd inceptions as 'Awaiting Decision'

## Context

User reported: /approvals shows 0 GO/NO-GO Decisions but the handover lists 10 inceptions as "Inception Phases — Awaiting Decision". Investigation: all 10 have a recorded `**Decision**: DEFER` line in their task body. /approvals correctly filters by `_extract_decision(body) == "pending"` so DEFER is excluded. Handover (`agents/handover/handover.sh:559-576`) only filters by `tstatus != 'work-completed'` — DEFER'd tasks have `status: captured`, so they pass through the filter and get mis-labeled.

DEFER'd inceptions ARE legitimately in active/ (parked, watching for promotion criteria) but they are NOT awaiting a first decision. The label mismatch causes the user to scan /approvals expecting them and find nothing.

## Acceptance Criteria

### Agent
- [ ] Handover's "Inception Phases — Awaiting Decision" section excludes inceptions that have any recorded `**Decision**:` line (GO, NO-GO, DEFER) — only truly-pending shows up
- [ ] DEFER'd inceptions still surface in handover under a separate "Deferred Inceptions — Watching for Recurrence" section (so they remain visible without being mislabeled)
- [ ] Section is omitted entirely when there are no deferred inceptions
- [ ] Existing /approvals behaviour unchanged (only handover wording changes)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.

# T-1517 fix: the "Awaiting Decision" filter now checks for recorded Decision
test -n "$(grep -E 'Decision\\*\\*:' agents/handover/handover.sh || true)"
# Deferred-inceptions section helper exists
test -n "$(grep -E 'Deferred Inceptions|Watching for Recurrence' agents/handover/handover.sh || true)"
# Smoke: a DEFER'd task in active/ no longer appears under "Awaiting Decision"
# (run handover, grep its output)
bin/fw handover >/tmp/T-1517-handover.txt 2>&1
test -n "$(awk '/^### Inception Phases — Awaiting Decision/{f=1;next} /^### |^## /{f=0} f{print}' /tmp/T-1517-handover.txt | grep -c 'T-1501\\|T-1265\\|T-558' || true)" && echo "FAIL: DEFER'd tasks still in Awaiting Decision" && exit 1
echo "T-1517 verification ok"

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
